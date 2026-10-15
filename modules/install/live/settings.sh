#!/usr/bin/env bash
# desc: Preguntas iniciales (particiones, usuario, hostname…) -> settings.local.conf
#
# La primera vez pregunta todo, proponiendo los valores de settings.conf.
# Las siguientes veces muestra lo guardado y solo pregunta si quieres cambiarlo.

LOCAL_CONF="$CONFIG_DIR/settings.local.conf"
SAVED_VARS=(ESP_PART ROOT_PART SYS_USER SYS_HOSTNAME TIMEZONE LOCALE KEYMAP GPU PASSWORD_HASH)

module_run() {
  if [[ -f $LOCAL_CONF && -n $ESP_PART && -n $ROOT_PART && -n $GPU && -n $PASSWORD_HASH ]]; then
    _summary
    confirm "¿Usar esta configuración?" s && return 0
  fi
  _ask_partitions
  _ask_system
  _ask_password
  _summary
  confirm "¿Es correcto?" s || die "Cancelado; vuelve a ejecutar para corregir"
  _save
}

_ask_partitions() {
  local -a parts others
  local p

  log_step "Particiones (créalas antes con cfdisk)"
  if [[ -z $ESP_PART || -z $ROOT_PART ]] && { ((ASSUME_YES)) || [[ ! -t 0 ]]; }; then
    die "Define ESP_PART y ROOT_PART en config/settings.local.conf para usar --yes"
  fi
  lsblk -po NAME,SIZE,FSTYPE,PARTTYPENAME,MOUNTPOINTS >&2
  mapfile -t parts < <(lsblk -lnpo NAME,TYPE | awk '$2 == "part" { print $1 }')
  ((${#parts[@]} >= 2)) || die "Hacen falta al menos 2 particiones; créalas con cfdisk"

  choose "Partición para /efi (se formatea en FAT32)" ESP_PART "${parts[@]}"
  for p in "${parts[@]}"; do [[ $p == "$ESP_PART" ]] || others+=("$p"); done
  choose "Partición para / (se formatea en ext4)" ROOT_PART "${others[@]}"
}

_ask_system() {
  log_step "Sistema"
  ask "Usuario" SYS_USER "" _valid_user
  ask "Hostname" SYS_HOSTNAME "" _valid_hostname
  ask "Zona horaria" TIMEZONE "" _valid_timezone
  ask "Locale" LOCALE "" _valid_locale
  ask "Keymap de la consola" KEYMAP "" _valid_keymap

  log_step "Drivers de vídeo"
  log_info "nvidia-hybrid = Intel + Nvidia (portátil) · intel = solo Intel · none = ninguno (VM)"
  : "${GPU:=$(detect_gpu)}"
  choose "¿Qué drivers instalar?" GPU nvidia-hybrid intel none
}

# Una sola contraseña para el usuario y root. Solo se guarda su hash SHA-512
# (el mismo formato de /etc/shadow), nunca el texto.
_ask_password() {
  local pw
  log_step "Contraseña (para $SYS_USER y root)"
  if [[ -n $PASSWORD_HASH ]] && ! confirm "Ya hay una contraseña guardada. ¿Cambiarla?" n; then
    return 0
  fi
  [[ -t 0 ]] || die "Hace falta una terminal para pedir la contraseña"
  ask_secret "Contraseña" pw
  PASSWORD_HASH=$(openssl passwd -6 -stdin <<<"$pw")
  unset pw
}


_summary() {
  local v
  log_step "Configuración"
  for v in "${SAVED_VARS[@]}"; do
    if [[ $v == PASSWORD_HASH ]]; then
      printf '   %s%-13s%s %s\n' "$_C_CYAN" "CONTRASEÑA" "$_C_RESET" "$([[ -n $PASSWORD_HASH ]] && echo '(guardada)' || echo '(vacía)')" >&2
    else
      printf '   %s%-13s%s %s\n' "$_C_CYAN" "$v" "$_C_RESET" "${!v:-(vacío)}" >&2
    fi
  done
}

# Guardar las respuestas no cambia el sistema, así que se hace también en dry-run.
_save() {
  local v content
  content="# Generado por el módulo settings. Puedes editarlo a mano."$'\n'
  for v in "${SAVED_VARS[@]}"; do
    printf -v content '%s%s=%q\n' "$content" "$v" "${!v}"
  done
  DRY_RUN=0 write_file "$LOCAL_CONF" 600 <<<"${content%$'\n'}"
}

_valid_user() { [[ $1 =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; }
_valid_hostname() { [[ $1 =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$ ]]; }
_valid_timezone() { [[ $1 != *..* && -f /usr/share/zoneinfo/$1 ]]; }
_valid_locale() { awk -v l="$1" '$1 == l { found = 1 } END { exit !found }' /usr/share/i18n/SUPPORTED; }
_valid_keymap() { [[ -n $(find /usr/share/kbd/keymaps -name "$1.map.gz" -print -quit 2>/dev/null) ]]; }
