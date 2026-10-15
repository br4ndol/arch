#!/usr/bin/env bash
# desc: Instala el sistema base (config/packages/base.list) y genera fstab

TARGET=/mnt

module_run() {
  local -a pkgs missing
  local p

  if ! is_mounted "$TARGET"; then
    ((DRY_RUN)) || die "$TARGET no está montado (módulo disk)"
    log_dry "pacstrap -P $TARGET … (en dry-run no hay nada montado)"
    return 0
  fi

  mapfile -t pkgs < <(list_read "$CONFIG_DIR/packages/base.list")
  pkgs+=("$KERNEL" "$CPU-ucode")

  for p in "${pkgs[@]}"; do
    pacman --dbpath "$TARGET/var/lib/pacman" -Q -- "$p" >/dev/null 2>&1 || missing+=("$p")
  done

  log_step "Sistema base"
  if ((${#missing[@]} == 0)); then
    log_ok "Ya instalado: ${pkgs[*]}"
  else
    log_info "Paquetes: ${missing[*]}"
    # -P copia el pacman.conf de la ISO (repos ya configurados). Sin -K se copia
    # también el keyring de la ISO, con las llaves de CachyOS/Chaotic firmadas.
    retry 2 10 pacstrap -P "$TARGET" --needed "${missing[@]}"
  fi

  log_step "fstab"
  genfstab -U "$TARGET" >"$RUN_TMPDIR/fstab"
  install_file "$RUN_TMPDIR/fstab" "$TARGET/etc/fstab" 644
  log_ok "fstab listo"
}
