#!/usr/bin/env bash
# packages.sh — Instalación idempotente desde repos (pacman), AUR y Flatpak.
#
# Todas las funciones filtran lo que ya está instalado antes de actuar, así
# repetir una instalación no hace nada.

[[ -n ${_UTILS_PACKAGES_LOADED:-} ]] && return 0
_UTILS_PACKAGES_LOADED=1

: "${FLATPAK_REMOTE:=flathub}"
: "${FLATPAK_REMOTE_URL:=https://dl.flathub.org/repo/flathub.flatpakrepo}"

# ---------------------------------------------------------------- pacman ----

# pkg_installed PAQUETE — Admite prefijo de repo (cachyos-v3/linux-cachyos-bore).
pkg_installed() { pacman -Q -- "${1##*/}" >/dev/null 2>&1; }

# _missing_pkgs PAQUETE... — Imprime los que no están instalados.
_missing_pkgs() {
  local p
  for p; do pkg_installed "$p" || printf '%s\n' "$p"; done
}

# pkg_install PAQUETE... — pacman -S solo de los que faltan.
pkg_install() {
  local missing
  mapfile -t missing < <(_missing_pkgs "$@")
  if ((${#missing[@]} == 0)); then
    log_debug "Ya instalados: $*"
    return 0
  fi
  log_info "pacman: ${missing[*]}"
  retry 3 5 pacman -S --needed --noconfirm -- "${missing[@]}"
}

# pkg_remove PAQUETE... — Desinstala (con dependencias huérfanas) los que estén.
pkg_remove() {
  local p present=()
  for p; do pkg_installed "$p" && present+=("${p##*/}"); done
  if ((${#present[@]} == 0)); then
    log_debug "No instalados, nada que quitar: $*"
    return 0
  fi
  log_info "Quitando: ${present[*]}"
  run pacman -Rns --noconfirm -- "${present[@]}"
}

# pkg_sync — Refresca las bases de datos (pacman -Sy).
pkg_sync() { retry 3 5 pacman -Sy --noconfirm; }

# ------------------------------------------------------------------- AUR ----

# aur_helper — Imprime el helper disponible (AUR_HELPER, yay o paru).
aur_helper() {
  local h
  for h in ${AUR_HELPER:-} yay paru; do
    if cmd_exists "$h"; then
      printf '%s\n' "$h"
      return 0
    fi
  done
  return 1
}

# aur_ensure_helper — Instala el helper desde los repos (yay está en chaotic-aur).
aur_ensure_helper() {
  aur_helper >/dev/null && return 0
  log_info "Instalando helper AUR: ${AUR_HELPER:-yay}"
  pkg_install "${AUR_HELPER:-yay}"
}

# _aur_user — Usuario normal que ejecuta el helper (nunca root).
_aur_user() {
  local u=${AUR_USER:-${SUDO_USER:-${SYS_USER:-}}}
  if ! is_root; then
    id -un
    return
  fi
  [[ -n $u && $u != root ]] || die "AUR: define SYS_USER (o ejecuta con sudo desde tu usuario)"
  printf '%s\n' "$u"
}

_AUR_SUDOERS=/etc/sudoers.d/zz-arch-setup-aur

_aur_sudo_cleanup() { rm -f -- "$_AUR_SUDOERS"; }

# _aur_temp_sudo USUARIO — sudo sin contraseña temporal, para que el helper
# pueda llamar a pacman sin pedir contraseña. Se borra al salir del script.
_aur_temp_sudo() {
  local user=$1
  ((DRY_RUN)) && return 0
  [[ -f $_AUR_SUDOERS ]] && return 0
  printf '%s ALL=(ALL:ALL) NOPASSWD: ALL\n' "$user" >"$_AUR_SUDOERS"
  chmod 440 -- "$_AUR_SUDOERS"
  add_cleanup _aur_sudo_cleanup
  if ! visudo -cqf "$_AUR_SUDOERS"; then
    _aur_sudo_cleanup
    die "No se pudo crear la regla temporal de sudo para '$user'"
  fi
}

# aur_install PAQUETE... — Instala desde AUR los que faltan, como usuario normal.
aur_install() {
  local missing helper user
  local -a flags=(-S --needed --noconfirm --removemake)
  mapfile -t missing < <(_missing_pkgs "$@")
  if ((${#missing[@]} == 0)); then
    log_debug "Ya instalados (AUR): $*"
    return 0
  fi
  aur_ensure_helper
  # Compilar desde AUR necesita base-devel; solo se instala si de verdad se usa AUR.
  pkg_install base-devel
  helper=$(aur_helper) || helper=${AUR_HELPER:-yay}
  # Sin preguntas de diff/limpieza; --removemake borra las dependencias de compilación.
  case $helper in
    yay) flags+=(--answerdiff None --answerclean None) ;;
    paru) flags+=(--skipreview) ;;
  esac
  user=$(_aur_user)
  log_info "$helper: ${missing[*]}"
  is_root && _aur_temp_sudo "$user"
  retry 2 5 run_as_user "$user" "$helper" "${flags[@]}" -- "${missing[@]}"
}

# --------------------------------------------------------------- Flatpak ----

# flatpak_ensure_remote [NOMBRE] [URL] — Instala flatpak y añade el remote
# (por defecto Flathub) a nivel de sistema.
flatpak_ensure_remote() {
  local name=${1:-$FLATPAK_REMOTE} url=${2:-$FLATPAK_REMOTE_URL} remotes=''
  pkg_install flatpak
  cmd_exists flatpak && remotes=$(flatpak remotes --system --columns=name 2>/dev/null) || true
  if [[ $'\n'$remotes$'\n' == *$'\n'"$name"$'\n'* ]]; then
    log_debug "Remote flatpak ya existe: $name"
    return 0
  fi
  log_info "Añadiendo remote flatpak: $name"
  retry 3 5 flatpak remote-add --system --if-not-exists "$name" "$url"
}

flatpak_installed() { cmd_exists flatpak && flatpak info --system -- "$1" >/dev/null 2>&1; }

# flatpak_install APP_ID... — Instala desde FLATPAK_REMOTE las que faltan.
flatpak_install() {
  local app missing=()
  for app; do flatpak_installed "$app" || missing+=("$app"); done
  if ((${#missing[@]} == 0)); then
    log_debug "Ya instaladas (flatpak): $*"
    return 0
  fi
  flatpak_ensure_remote
  log_info "flatpak: ${missing[*]}"
  retry 3 10 flatpak install --system --noninteractive -y "$FLATPAK_REMOTE" "${missing[@]}"
}

# ----------------------------------------------------------------- Listas ---

# list_read ARCHIVO — Imprime un elemento por línea. Ignora comentarios (#) y
# líneas vacías; admite varios elementos por línea.
list_read() {
  local file=$1 line words w
  [[ -f $file ]] || die "No existe la lista: $file"
  while IFS= read -r line || [[ -n $line ]]; do
    line=${line%$'\r'}
    line=${line%%#*}
    read -ra words <<<"$line"
    for w in "${words[@]}"; do printf '%s\n' "$w"; done
  done <"$file"
}

# install_list ARCHIVO... — Instala lo listado. Prefijos por elemento:
#   paquete            -> pacman (repos oficiales, cachyos, chaotic-aur…)
#   aur:paquete        -> AUR con el helper
#   flatpak:app.id     -> Flatpak desde FLATPAK_REMOTE
# Ej. de lista (config/packages/gnome.list):
#   gnome-shell gdm
#   aur:ghostty-nautilus
#   flatpak:org.gnome.Calculator
install_list() {
  local file item items repo=() aur=() flat=()
  for file; do
    mapfile -t items < <(list_read "$file")
    for item in "${items[@]}"; do
      case $item in
        aur:*) aur+=("${item#aur:}") ;;
        flatpak:*) flat+=("${item#flatpak:}") ;;
        *) repo+=("$item") ;;
      esac
    done
  done
  ((${#repo[@]} == 0)) || pkg_install "${repo[@]}"
  ((${#aur[@]} == 0)) || aur_install "${aur[@]}"
  ((${#flat[@]} == 0)) || flatpak_install "${flat[@]}"
}
