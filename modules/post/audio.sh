#!/usr/bin/env bash
# desc: Audio con PipeWire, EasyEffects (Flatpak) y sus presets (ArchLinux2/Audio.md)

EE_ID=com.github.wwmm.easyeffects
PRESETS_REPO=https://raw.githubusercontent.com/JackHack96/EasyEffects-Presets/master

module_run() {
  log_step "PipeWire y EasyEffects"
  install_list "$CONFIG_DIR/packages/audio.list"

  log_step "Tiempo real para $SYS_USER"
  user_add_group "$SYS_USER" realtime

  log_step "Servicios de usuario"
  service_enable_global pipewire.socket pipewire-pulse.socket wireplumber.service

  log_step "Presets de EasyEffects"
  _easyeffects_presets "$CONFIG_DIR/files/easyeffects-presets.list"
}

# _easyeffects_presets LISTA — Descarga como el usuario los presets que falten.
# EasyEffects 8 (el de Flathub) los busca en data/easyeffects/ de su carpeta Flatpak.
_easyeffects_presets() {
  local user=$SYS_USER home dir line dst url n=0
  home=$(user_home "$user")
  [[ -n $home ]] || die "No encuentro el HOME de $user"
  dir="$home/.var/app/$EE_ID/data/easyeffects"

  while IFS= read -r line || [[ -n $line ]]; do
    line=${line%$'\r'}
    [[ $line =~ ^[[:space:]]*(#|$) ]] && continue
    IFS='|' read -r dst url <<<"$line"
    dst=$(_trim "$dst")
    url=$(_trim "$url")
    [[ -f $dir/$dst ]] && continue
    if [[ -z $url ]]; then
      url="$PRESETS_REPO/${dst#output/}"
      url=${url// /%20}
    fi
    retry 3 5 run_as_user "$user" curl -fsSL --create-dirs -o "$dir/$dst" "$url"
    n=$((n + 1))
  done <"$1"

  if ((n)); then
    log_ok "$n archivos descargados en $dir"
  else
    log_ok "Ya instalados"
  fi
}

_trim() {
  local s=$1
  s=${s#"${s%%[![:space:]]*}"}
  printf '%s' "${s%"${s##*[![:space:]]}"}"
}
