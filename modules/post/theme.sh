#!/usr/bin/env bash
# desc: Tema adw-gtk3 (oscuro, alternable a claro), iconos MoreWaita, cursor Bibata y Qt con el tema gtk3
#
# Ver ArchLinux2/Theme.md. A diferencia de la wiki, no se usa
# ~/.config/gtk-4.0/settings.ini: forzaba el oscuro y no dejaba pasar a claro.

module_run() {
  local home ini old
  home=$(user_home "$SYS_USER")

  log_step "Paquetes"
  install_list "$CONFIG_DIR/packages/theme.list"

  log_step "Tema, iconos y cursor por defecto (dconf)"
  if cmd_exists dconf && [[ -d /etc/dconf/db/local.d ]]; then
    install_file "$CONFIG_DIR/files/gnome/theme.dconf" /etc/dconf/db/local.d/20-arch-setup-theme
    if ((FILE_CHANGED)); then run dconf update; fi
  else
    log_warn "No hay perfil dconf (¿falta el módulo desktop/gnome?); se omite"
  fi

  log_step "GTK4 sigue al tema del sistema"
  # Lo copiaban versiones anteriores de este script. Se borra solo si sigue
  # exactamente igual (si lo editaste, se queda).
  ini="$home/.config/gtk-4.0/settings.ini"
  old="$RUN_TMPDIR/gtk4-settings.ini"
  printf '[Settings]\ngtk-theme-name=adw-gtk3-dark\ngtk-application-prefer-dark-theme=1\n' >"$old"
  if same_content "$old" "$ini"; then
    run rm -f -- "$ini"
  else
    log_ok "Nada que quitar"
  fi

  # Las apps Flatpak usan los paquetes org.gtk.Gtk3theme.adw-gtk3* de theme.list
  # (Flatpak elige solo el que coincide con gtk-theme): sin overrides ni masks.

  log_step "Qt: sigue el tema de GNOME"
  set_kv /etc/environment QT_QPA_PLATFORMTHEME gtk3 =
  set_kv /etc/environment QT_WAYLAND_DECORATION adwaita =
}
