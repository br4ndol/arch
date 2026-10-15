#!/usr/bin/env bash
# desc: Nautilus: extras, marcador "File System", carpetas XDG y Samba
#
# Ver ArchLinux2/nautilus.md.

module_run() {
  local user=$SYS_USER home d
  home=$(user_home "$user")
  [[ -n $home ]] || die "No encuentro el HOME de $user"

  log_step "Paquetes"
  install_list "$CONFIG_DIR/packages/nautilus.list"

  log_step "Marcador \"File System\""
  user_ensure_line "$user" "$home/.config/gtk-3.0/bookmarks" "file:/// File System"

  log_step "Plantillas y Público apuntan al HOME"
  for d in TEMPLATES PUBLICSHARE; do
    if [[ $(runuser -u "$user" -- env HOME="$home" xdg-user-dir "$d" 2>/dev/null) != "$home" ]]; then
      run_as_user "$user" xdg-user-dirs-update --set "$d" "$home"
    fi
  done
  # Solo se borran si están vacías.
  for d in Public Templates Projects; do
    if [[ -d $home/$d && -z $(ls -A -- "$home/$d") ]]; then
      run rmdir -- "$home/$d"
      log_ok "Borrada ~/$d (vacía)"
    fi
  done
}
