#!/usr/bin/env bash
# desc: Tema oscuro adw-gtk3, iconos MoreWaita, cursor Bibata y Qt con el tema gtk3
#
# Ver ArchLinux2/Theme.md. El settings.ini de GTK4 lo copia el módulo dotfiles.

module_run() {
  log_step "Paquetes"
  install_list "$CONFIG_DIR/packages/theme.list"

  log_step "Tema, iconos y cursor por defecto (dconf)"
  if cmd_exists dconf && [[ -d /etc/dconf/db/local.d ]]; then
    install_file "$CONFIG_DIR/files/gnome/theme.dconf" /etc/dconf/db/local.d/20-arch-setup-theme
    if ((FILE_CHANGED)); then run dconf update; fi
  else
    log_warn "No hay perfil dconf (¿falta el módulo desktop/gnome?); se omite"
  fi

  # Las apps Flatpak usan los paquetes org.gtk.Gtk3theme.adw-gtk3* de theme.list
  # (Flatpak elige solo el que coincide con gtk-theme): sin overrides ni masks.

  log_step "Qt: sigue el tema de GNOME"
  set_kv /etc/environment QT_QPA_PLATFORMTHEME gtk3 =
  set_kv /etc/environment QT_WAYLAND_DECORATION adwaita =
}
