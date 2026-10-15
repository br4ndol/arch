#!/usr/bin/env bash
# install.sh — Fase 1: instala Arch desde la ISO.
#
# Dos etapas:
#   live    En la ISO: discos, repos, pacstrap… (modules/install/live/)
#   chroot  Se relanza sola dentro de `arch-chroot /mnt` con una copia de este
#           repo: sistema, usuario, UKI… (modules/install/chroot/)
#
# Uso: ./install.sh [opciones]          (ver --help)

# shellcheck source=utils/common.sh
source "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")/utils/common.sh"
# shellcheck source=utils/modules.sh
source "$UTILS_DIR/modules.sh"

# Módulos en orden de ejecución. El nombre es el archivo sin .sh.
LIVE_MODULES=(
  preflight   # UEFI, internet, CPU v3, reloj
  settings    # preguntas -> config/settings.local.conf
  repos       # CachyOS v3, multilib, Chaotic-AUR en la ISO
  disk        # formatea y monta ESP y raíz
  pacstrap    # sistema base + fstab
)
CHROOT_MODULES=(
  system      # zona horaria, locale, teclado, hostname
  users       # usuario + wheel/sudo, contraseña de usuario y root
  network     # NetworkManager + iwd
  boot        # cmdline, UKI y entrada EFI (va al final: el UKI incluye lo anterior)
)

TARGET=/mnt                     # raíz del sistema nuevo
TARGET_REPO=/root/arch-setup    # dónde se copia este repo dentro de TARGET

usage() {
  cat <<EOF
Uso: ${0##*/} [opciones]

Instala Arch Linux desde la ISO según config/settings.conf.

Opciones propias:
  --stage live|chroot   Etapa a ejecutar (defecto: live; chroot es interno)

$(common_usage)
EOF
}

# enter_chroot ARGS... — Copia el repo al sistema nuevo, relanza la etapa
# chroot y, si termina bien, borra la copia para no dejar restos.
enter_chroot() {
  if ! is_mounted "$TARGET"; then
    ((DRY_RUN)) || die "$TARGET no está montado. ¿Se ejecutó el módulo disk?"
    log_dry "Aquí se entraría en arch-chroot $TARGET (en dry-run no hay nada montado)"
    return 0
  fi
  log_section "Entrando en el sistema nuevo ($TARGET)"
  run rm -rf -- "${TARGET:?}$TARGET_REPO"
  run mkdir -p -- "$TARGET$TARGET_REPO"
  run cp -a -- "$ROOT_DIR/." "$TARGET$TARGET_REPO/"
  chroot_run "$TARGET" env RUN_TS="$RUN_TS" bash "$TARGET_REPO/install.sh" "$@" --stage chroot
  run rm -rf -- "${TARGET:?}$TARGET_REPO"
}

main() {
  local stage=live
  local -a orig_args=("$@")

  parse_common_args "$@"
  set -- "${EXTRA_ARGS[@]}"
  while (($#)); do
    case $1 in
      --stage)
        stage=${2:-}
        shift
        ;;
      *) die "Opción desconocida: $1 (ver --help)" ;;
    esac
    shift
  done
  [[ $stage == live || $stage == chroot ]] || die "--stage debe ser live o chroot"

  if ((LIST_ONLY)); then
    list_modules "Etapa live (ISO)" "$MODULES_DIR/install/live" "${LIVE_MODULES[@]}"
    list_modules "Etapa chroot" "$MODULES_DIR/install/chroot" "${CHROOT_MODULES[@]}"
    exit 0
  fi

  require_root
  load_config
  log_init

  case $stage in
    live)
      log_section "arch-setup · instalación (etapa live)"
      in_live_iso || confirm "No parece la ISO de Arch. ¿Continuar igualmente?" n || exit 1
      run_modules "$MODULES_DIR/install/live" "${LIVE_MODULES[@]}" || exit 1
      # Se reenvían los mismos flags; el --stage añadido al final es el que vale.
      enter_chroot "${orig_args[@]}"
      if ! ((DRY_RUN)); then
        cp -f -- "$LOG_FILE" "$TARGET/var/log/arch-setup-live.log" 2>/dev/null || true
      fi
      log_ok "Instalación terminada. Para arrancar el sistema nuevo: umount -R $TARGET, quita la ISO y reinicia."
      ;;
    chroot)
      in_chroot || die "--stage chroot es interno: debe ejecutarse dentro de arch-chroot"
      log_section "arch-setup · instalación (etapa chroot)"
      run_modules "$MODULES_DIR/install/chroot" "${CHROOT_MODULES[@]}" || exit 1
      ;;
  esac
}

main "$@"
