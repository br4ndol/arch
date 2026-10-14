#!/usr/bin/env bash
# post.sh — Fase 2: configura el sistema ya instalado.
#
# Se ejecuta como root desde tu usuario: sudo ./post.sh [opciones]
# El usuario objetivo es SYS_USER (settings) o, si no está, quien llamó a sudo.

# shellcheck source=utils/common.sh
source "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")/utils/common.sh"
# shellcheck source=utils/modules.sh
source "$UTILS_DIR/modules.sh"

# Módulos en orden de ejecución (modules/post/<nombre>.sh).
POST_MODULES=(
)

usage() {
  cat <<EOF
Uso: sudo ${0##*/} [opciones]

Configura el sistema instalado según config/settings.conf.

$(common_usage)
EOF
}

main() {
  parse_common_args "$@"
  ((${#EXTRA_ARGS[@]} == 0)) || die "Opción desconocida: ${EXTRA_ARGS[0]} (ver --help)"

  if ((LIST_ONLY)); then
    list_modules "Post-instalación" "$MODULES_DIR/post" "${POST_MODULES[@]}"
    exit 0
  fi

  require_root
  load_config
  log_init
  in_chroot && die "post.sh es para el sistema ya arrancado, no para el chroot"
  is_arch || die "Esto no parece Arch Linux"

  : "${SYS_USER:=${SUDO_USER:-}}"
  [[ -n $SYS_USER && $SYS_USER != root ]] || die "Define SYS_USER en settings o ejecuta con sudo desde tu usuario"
  user_exists "$SYS_USER" || die "No existe el usuario '$SYS_USER'"
  export SYS_USER

  log_section "arch-setup · post-instalación (usuario: $SYS_USER, escritorio: ${DESKTOP:-ninguno})"
  run_modules "$MODULES_DIR/post" "${POST_MODULES[@]}" || exit 1
}

main "$@"
