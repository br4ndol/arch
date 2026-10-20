#!/usr/bin/env bash
# desc: Limpieza final: dependencias huérfanas, caché de pacman, de yay y de Flatpak
#
# Va al final de post.sh para que el primer arranque sea lo más limpio posible.
# Después, el hook de paccache (módulo maintenance) mantiene la caché a raya.

module_run() {
  local home orphans d
  local -a list
  home=$(user_home "$SYS_USER")

  log_step "Dependencias huérfanas"
  # pacman -Qdtq sale con 1 cuando no hay ninguna. Con una sola -t no lista las
  # dependencias opcionales de algo instalado, así que esas se quedan.
  orphans=$(pacman -Qdtq) || true
  if [[ -n $orphans ]]; then
    mapfile -t list <<<"$orphans"
    run pacman -Rns --noconfirm -- "${list[@]}"
  else
    log_ok "No hay"
  fi

  log_step "Caché de pacman"
  if cmd_exists paccache; then
    run paccache -rqk0
  else
    log_warn "Falta paccache (pacman-contrib, módulo maintenance); se omite"
  fi

  log_step "Caché de yay"
  if [[ -n $home && -d $home/.cache/yay ]]; then
    run rm -rf -- "$home/.cache/yay"
  else
    log_ok "Vacía"
  fi

  log_step "Flatpak: runtimes sin usar y caché temporal"
  if cmd_exists flatpak; then
    # Los runtimes instalados a mano (temas adw-gtk3) quedan fijados y no se tocan.
    run flatpak uninstall --system --unused --noninteractive -y
  fi
  for d in /var/tmp/flatpak-cache-*; do
    if [[ -d $d ]]; then run rm -rf -- "$d"; fi
  done
}
