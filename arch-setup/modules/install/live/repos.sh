#!/usr/bin/env bash
# desc: Repos en la ISO: CachyOS v3, multilib, Chaotic-AUR y [cachyos]
#
# Ver ArchLinux2/Servers.md. pacstrap copia luego este pacman.conf y el
# keyring de la ISO al sistema nuevo.
#
# Las llaves NO se piden a un keyserver (keyserver.ubuntu.com falla a menudo):
# se sacan del propio paquete *-keyring, descargado por HTTPS del mirror
# oficial, y solo se aceptan si su huella completa coincide con estas.

CACHYOS_KEY=882DCFE48E2051D48E2562ABF3B607488DB35A47   # …F3B607488DB35A47 en Servers.md
CHAOTIC_KEY=EF925EA60F33D0CB85C44AD13056513887B78AEB   # …3056513887B78AEB en Servers.md

CACHYOS_REPO_URL=https://mirror.cachyos.org/repo/x86_64/cachyos
# Si el listado del mirror falla, se usan estas versiones (las de Servers.md).
CACHYOS_FALLBACK=(cachyos-keyring-20240331-1-any cachyos-mirrorlist-27-1-any cachyos-v3-mirrorlist-27-1-any)
CHAOTIC_URLS=(
  https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst
  https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst
)

PACMAN_CONF=/etc/pacman.conf

module_run() {
  local repo
  local -a urls
  mapfile -t urls < <(_cachyos_urls)

  log_step "Llaves de CachyOS y Chaotic-AUR"
  _trust_key "$CACHYOS_KEY" "${urls[0]}"
  _trust_key "$CHAOTIC_KEY" "${CHAOTIC_URLS[0]}"

  log_step "Paquetes de llaves y mirrorlists"
  if pkg_installed cachyos-keyring && pkg_installed cachyos-mirrorlist && pkg_installed cachyos-v3-mirrorlist; then
    log_ok "CachyOS: ya instalados"
  else
    _install_urls "${urls[@]}"
  fi
  if pkg_installed chaotic-keyring && pkg_installed chaotic-mirrorlist; then
    log_ok "Chaotic-AUR: ya instalados"
  else
    _install_urls "${CHAOTIC_URLS[@]}"
  fi

  log_step "pacman.conf"
  ensure_uncommented "$PACMAN_CONF" Color
  ensure_line_after "$PACMAN_CONF" ILoveCandy Color
  set_kv "$PACMAN_CONF" Architecture 'x86_64 x86_64_v3'
  # Los v3 van antes de [core] para que tengan prioridad.
  for repo in cachyos-v3 cachyos-core-v3 cachyos-extra-v3; do
    ensure_ini_section "$PACMAN_CONF" "$repo" --before core 'Include = /etc/pacman.d/cachyos-v3-mirrorlist'
  done
  ensure_ini_section "$PACMAN_CONF" multilib 'Include = /etc/pacman.d/mirrorlist'
  # Al final: complementos tipo AUR, con menos prioridad que los oficiales.
  ensure_ini_section "$PACMAN_CONF" chaotic-aur 'Include = /etc/pacman.d/chaotic-mirrorlist'
  ensure_ini_section "$PACMAN_CONF" cachyos 'Include = /etc/pacman.d/cachyos-mirrorlist'

  log_step "Sincronizando"
  pkg_sync
  # Una ISO algo vieja puede traer un keyring desactualizado.
  retry 3 5 pacman -S --needed --noconfirm archlinux-keyring
}

# _trust_key HUELLA URL_KEYRING — Si la llave no está en el keyring de pacman,
# la saca del paquete keyring, comprueba la huella, la añade y la firma localmente.
_trust_key() {
  local fpr=$1 url=$2 dir="$RUN_TMPDIR/key-${1: -8}"
  if ! pacman-key --list-keys "$fpr" >/dev/null 2>&1; then
    mkdir -p -- "$dir/pkg"
    mkdir -m 700 -- "$dir/gnupg"
    retry 3 5 curl -fsSL --max-time 60 -o "$dir/keyring.pkg.tar.zst" "$url"
    if ((DRY_RUN)); then
      log_dry "Añadiría la llave $fpr sacada de ${url##*/}"
    else
      bsdtar -xf "$dir/keyring.pkg.tar.zst" -C "$dir/pkg" 'usr/share/pacman/keyrings/*.gpg'
      gpg --homedir "$dir/gnupg" --quiet --import "$dir"/pkg/usr/share/pacman/keyrings/*.gpg 2>/dev/null
      gpg --homedir "$dir/gnupg" --list-keys "$fpr" >/dev/null 2>&1 ||
        die "${url##*/} no contiene la llave $fpr (¿paquete alterado?)"
      gpg --homedir "$dir/gnupg" --export "$fpr" >"$dir/key.gpg"
      run_quiet pacman-key --add "$dir/key.gpg"
    fi
  fi
  run_quiet pacman-key --lsign-key "$fpr"
  log_ok "Llave de confianza: $fpr"
}

# _cachyos_urls — URLs de la última versión de cada paquete, leídas del listado
# del mirror; si falla, las versiones de CACHYOS_FALLBACK.
_cachyos_urls() {
  local listing name file fallback
  listing=$(curl -fsSL --max-time 20 "$CACHYOS_REPO_URL/") || listing=''
  for fallback in "${CACHYOS_FALLBACK[@]}"; do
    name=${fallback%-*-*-any}
    file=$(grep -oE "${name}-[0-9][^\"/<>]*-any\.pkg\.tar\.zst" <<<"$listing" | sort -uV | tail -n 1) || file=''
    if [[ -z $file ]]; then
      log_warn "No encontré $name en el mirror; uso $fallback"
      file="$fallback.pkg.tar.zst"
    fi
    printf '%s\n' "$CACHYOS_REPO_URL/$file"
  done
}

_install_urls() {
  log_info "Instalando: ${*##*/}"
  retry 3 5 pacman -U --needed --noconfirm "$@"
}
