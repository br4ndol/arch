#!/usr/bin/env bash
# checks.sh — Comprobaciones de solo lectura sobre el entorno.
#
# Las funciones is_*/has_*/in_* devuelven 0/1 y no imprimen nada.
# Las require_* terminan el script con un mensaje si no se cumple.

[[ -n ${_UTILS_CHECKS_LOADED:-} ]] && return 0
_UTILS_CHECKS_LOADED=1

cmd_exists() { command -v -- "$1" >/dev/null 2>&1; }

# require_cmd CMD... — Falla si falta alguno, listándolos todos.
require_cmd() {
  local c missing=()
  for c; do cmd_exists "$c" || missing+=("$c"); done
  ((${#missing[@]} == 0)) || die "Faltan comandos: ${missing[*]}"
}

is_root() { ((EUID == 0)); }
require_root() { is_root || die "Ejecuta este script como root (sudo $0)"; }

user_exists() { id -u -- "$1" >/dev/null 2>&1; }

# is_uefi — Arrancado en modo UEFI (efivars presente y no vacío).
is_uefi() {
  local d=/sys/firmware/efi/efivars
  [[ -d $d ]] && [[ -n $(ls -A -- "$d" 2>/dev/null) ]]
}
require_uefi() { is_uefi || die "No se detecta UEFI. ¿Arrancaste la ISO en modo BIOS/Legacy?"; }

# has_internet — Prueba HTTPS contra archlinux.org; si no hay curl, ping.
has_internet() {
  if cmd_exists curl; then
    curl -fsS --max-time 8 -o /dev/null https://archlinux.org 2>/dev/null && return 0
  fi
  ping -c 1 -W 5 archlinux.org >/dev/null 2>&1
}
require_internet() { has_internet || die "Sin conexión a internet (prueba iwctl o revisa el cable)"; }

# in_chroot — Estamos dentro de un chroot (p. ej. arch-chroot /mnt).
in_chroot() {
  if cmd_exists systemd-detect-virt; then
    systemd-detect-virt --quiet --chroot
  else
    [[ $(stat -c %d:%i /) != "$(stat -c %d:%i /proc/1/root/. 2>/dev/null)" ]]
  fi
}

# in_live_iso — Estamos en la ISO de instalación de Arch.
in_live_iso() {
  [[ -d /run/archiso ]] || grep -qw archisobasedir /proc/cmdline 2>/dev/null
}

# systemd_running — systemd es PID 1 (no en chroot ni en contenedores simples).
systemd_running() { [[ -d /run/systemd/system ]] && ! in_chroot; }

is_arch() { [[ -f /etc/arch-release ]]; }

is_block_device() { [[ -b $1 ]]; }

# detect_gpu — Propuesta de drivers: none en una VM, nvidia-hybrid si hay una
# Nvidia, si no intel.
detect_gpu() {
  if systemd-detect-virt --quiet --vm 2>/dev/null; then
    echo none
  elif [[ -n $(lspci -d 10de: 2>/dev/null) ]]; then
    echo nvidia-hybrid
  else
    echo intel
  fi
}

# is_mounted RUTA — RUTA es un punto de montaje.
is_mounted() { findmnt -rn --mountpoint "$1" >/dev/null 2>&1; }
