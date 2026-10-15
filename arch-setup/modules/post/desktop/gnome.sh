#!/usr/bin/env bash
# desc: GNOME: paquetes, GDM, apps Flatpak, ajustes y atajos por defecto
#
# Ver ArchLinux2/gnome-base.md. Los ajustes y atajos se instalan como valores
# por defecto del sistema (dconf), así no hace falta una sesión gráfica abierta.

DCONF_DIR=/etc/dconf/db/local.d
KEYBINDING_PATH=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings

module_run() {
  local dconf_changed=0 keyfile

  log_step "Paquetes y apps"
  install_list "$CONFIG_DIR/packages/gnome.list"

  log_step "GDM"
  # Solo se habilita: arrancarlo ahora abriría la sesión gráfica en mitad del script.
  service_enable gdm.service

  log_step "Ajustes por defecto (dconf)"
  write_file /etc/dconf/profile/user <<'EOF'
user-db:user
system-db:local
EOF
  if ((FILE_CHANGED)); then dconf_changed=1; fi
  install_file "$CONFIG_DIR/files/gnome/settings.dconf" "$DCONF_DIR/00-arch-setup"
  if ((FILE_CHANGED)); then dconf_changed=1; fi

  log_step "Atajos de teclado"
  keyfile="$RUN_TMPDIR/keybindings.dconf"
  _keybindings_keyfile "$CONFIG_DIR/files/gnome/keybindings.list" >"$keyfile"
  install_file "$keyfile" "$DCONF_DIR/10-arch-setup-keybindings"
  if ((FILE_CHANGED)); then dconf_changed=1; fi

  if ((dconf_changed)) || [[ ! -f /etc/dconf/db/local ]]; then
    run dconf update
  fi

  log_step "ddcutil sin sudo (grupo i2c)"
  user_add_group "$SYS_USER" i2c
}

# _gv_str TEXTO — Cadena GVariant entre comillas simples.
_gv_str() {
  local s=${1//\\/\\\\}
  printf "'%s'" "${s//\'/\\\'}"
}

_trim() {
  local s=$1
  s=${s#"${s%%[![:space:]]*}"}
  printf '%s' "${s%"${s##*[![:space:]]}"}"
}

# _keybindings_keyfile LISTA — Genera el keyfile de dconf con los atajos.
# Salta los de brillo si MONITOR_SERIAL está vacío.
_keybindings_keyfile() {
  local line name binding command n=0 paths='' body=''
  while IFS= read -r line || [[ -n $line ]]; do
    line=${line%$'\r'}
    [[ $line =~ ^[[:space:]]*(#|$) ]] && continue
    IFS='|' read -r name binding command <<<"$line"
    name=$(_trim "$name")
    binding=$(_trim "$binding")
    command=$(_trim "$command")
    if [[ $command == *'{{MONITOR_SERIAL}}'* ]]; then
      if [[ -z ${MONITOR_SERIAL:-} ]]; then
        log_debug "Atajo '$name' omitido (MONITOR_SERIAL vacío)"
        continue
      fi
      command=${command//'{{MONITOR_SERIAL}}'/$MONITOR_SERIAL}
    fi
    paths+="${paths:+, }'$KEYBINDING_PATH/custom$n/'"
    body+=$'\n'"[${KEYBINDING_PATH#/}/custom$n]"$'\n'
    body+="name=$(_gv_str "$name")"$'\n'
    body+="command=$(_gv_str "$command")"$'\n'
    body+="binding=$(_gv_str "$binding")"$'\n'
    n=$((n + 1))
  done <"$1"

  printf '# Generado por arch-setup desde config/files/gnome/keybindings.list\n'
  printf '[org/gnome/settings-daemon/plugins/media-keys]\n'
  printf 'custom-keybindings=[%s]\n' "$paths"
  printf '%s' "$body"
}
