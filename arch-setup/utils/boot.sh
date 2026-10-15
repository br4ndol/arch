#!/usr/bin/env bash
# boot.sh — cmdline del kernel, arrays de mkinitcpio.conf y regeneración del UKI.
#
# Las funciones de edición dejan FILE_CHANGED=1 si cambiaron algo; el módulo
# decide si regenera el UKI con uki_rebuild.

[[ -n ${_UTILS_BOOT_LOADED:-} ]] && return 0
_UTILS_BOOT_LOADED=1

CMDLINE_FILE=/etc/kernel/cmdline
MKINITCPIO_CONF=/etc/mkinitcpio.conf

# cmdline_add PARAM... — Añade parámetros a /etc/kernel/cmdline. Si ya existe
# uno con la misma clave (loglevel=4 frente a loglevel=3) lo reemplaza en su sitio.
cmdline_add() {
  local -a params
  local p i found
  [[ -f $CMDLINE_FILE ]] || die "No existe $CMDLINE_FILE (lo crea install.sh, módulo boot)"
  read -ra params <"$CMDLINE_FILE"
  for p; do
    found=0
    for i in "${!params[@]}"; do
      if [[ ${params[i]%%=*} == "${p%%=*}" ]]; then
        params[i]=$p
        found=1
      fi
    done
    ((found)) || params+=("$p")
  done
  write_file "$CMDLINE_FILE" <<<"${params[*]}"
}

# mkinitcpio_add VARIABLE ELEMENTO [DESPUES_DE...] — Añade ELEMENTO al array
# VARIABLE (MODULES, HOOKS…) de mkinitcpio.conf, justo después del primero de
# DESPUES_DE que exista; si ninguno existe, al final.
# Ej.: mkinitcpio_add HOOKS plymouth systemd udev
mkinitcpio_add() {
  local var=$1 item=$2 line after x inserted=0
  local -a arr out=()
  shift 2
  # shellcheck disable=SC2034  # lo leen los módulos
  FILE_CHANGED=0
  line=$(grep -m1 -E "^${var}=\(" "$MKINITCPIO_CONF") || die "No encuentro ${var}=(…) en $MKINITCPIO_CONF"
  line=${line#*\(}
  read -ra arr <<<"${line%\)*}"
  for x in "${arr[@]}"; do
    if [[ $x == "$item" ]]; then
      log_debug "$var ya contiene $item"
      return 0
    fi
  done
  for after; do
    for x in "${arr[@]}"; do
      if [[ $x == "$after" ]]; then inserted=1; fi
    done
    ((inserted)) || continue
    for x in "${arr[@]}"; do
      out+=("$x")
      if [[ $x == "$after" ]]; then out+=("$item"); fi
    done
    break
  done
  ((inserted)) || out=("${arr[@]}" "$item")
  set_kv "$MKINITCPIO_CONF" "$var" "(${out[*]})" =
}

# uki_rebuild — Regenera el UKI del kernel configurado (KERNEL).
uki_rebuild() {
  log_info "Regenerando el UKI ($KERNEL)"
  run mkinitcpio -p "$KERNEL"
}
