#!/usr/bin/env bash
# desc: Nautilus: extras, carpetas XDG (sin Templates ni Public), bookmarks y Samba
#
# Ver ArchLinux2/nautilus.md.

module_run() {
  local user=$SYS_USER home d dirs bookmarks path
  home=$(user_home "$user")
  [[ -n $home ]] || die "No encuentro el HOME de $user"

  log_step "Paquetes"
  install_list "$CONFIG_DIR/packages/nautilus.list"

  log_step "Carpetas XDG (sin Templates ni Public)"
  # Sin user-dirs.dirs, xdg-user-dir responde "$HOME" para todo y el primer
  # inicio de sesión crearía todas las carpetas: se genera ya para editarlo.
  dirs="$home/.config/user-dirs.dirs"
  [[ -f $dirs ]] || run_as_user "$user" xdg-user-dirs-update
  # Borrar la línea no sirve (xdg-user-dirs-update la vuelve a crear);
  # apuntarla al HOME la desactiva para siempre.
  for d in TEMPLATES PUBLICSHARE; do
    if ! grep -qxF "XDG_${d}_DIR=\"\$HOME/\"" "$dirs" 2>/dev/null; then
      run_as_user "$user" xdg-user-dirs-update --set "$d" "$home"
    fi
  done
  # Solo se borran si están vacías.
  for d in Templates Public; do
    if [[ -d $home/$d && -z $(ls -A -- "$home/$d") ]]; then
      run rmdir -- "$home/$d"
      log_ok "Borrada ~/$d (vacía)"
    fi
  done

  log_step "Bookmarks: Downloads, Pictures, Documents y File System"
  bookmarks="$home/.config/gtk-3.0/bookmarks"
  for d in DOWNLOAD PICTURES DOCUMENTS; do
    path=$(runuser -u "$user" -- env HOME="$home" xdg-user-dir "$d")
    path=${path%/}
    if [[ $path != "$home" ]]; then
      user_ensure_line "$user" "$bookmarks" "file://${path// /%20} ${path##*/}"
    fi
  done
  user_ensure_line "$user" "$bookmarks" "file:/// File System"
}
