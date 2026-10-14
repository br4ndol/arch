#!/usr/bin/env bash
# desc: Comprobaciones previas: UEFI, comandos, internet, CPU x86-64-v3 y reloj

module_run() {
  log_step "Comprobando el entorno"

  require_uefi
  log_ok "Arranque en modo UEFI"

  require_cmd pacstrap genfstab arch-chroot pacman-key mkfs.fat mkfs.ext4 lsblk findmnt curl openssl bsdtar gpg
  require_internet
  log_ok "Conexión a internet"

  _require_x86_64_v3
  log_ok "CPU compatible con x86-64-v3"

  if systemd_running && [[ $(timedatectl show -p NTP --value 2>/dev/null) != yes ]]; then
    run timedatectl set-ntp true
  fi
  log_ok "Reloj sincronizado por NTP"
}

# Los repos cachyos-v3 solo funcionan si la CPU soporta x86-64-v3.
_require_x86_64_v3() {
  local out
  out=$(/lib/ld-linux-x86-64.so.2 --help 2>/dev/null) || true
  [[ $out == *"x86-64-v3 (supported, searched)"* ]] ||
    die "La CPU no soporta x86-64-v3: los repos cachyos-v3 no funcionarían en esta máquina"
}
