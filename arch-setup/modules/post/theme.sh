#!/usr/bin/env bash
# desc: Tema oscuro adw-gtk3, iconos MoreWaita, cursor Bibata y Qt (qt5ct)
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

  log_step "Flatpak: temas del sistema"
  _flatpak_themes

  log_step "Qt: qt5ct"
  set_kv /etc/environment QT_QPA_PLATFORMTHEME qt5ct =
}

# Como en Theme.md: las apps Flatpak leen los temas de xdg-data/themes y se
# enmascaran los paquetes adw-gtk3 de Flathub.
_flatpak_themes() {
  local overrides masks ref
  overrides=$(flatpak override --show 2>/dev/null) || overrides=''
  if [[ $overrides != *xdg-data/themes* ]]; then
    run flatpak override --filesystem=xdg-data/themes
  fi
  masks=$(flatpak mask 2>/dev/null) || masks=''
  for ref in org.gtk.Gtk3theme.adw-gtk3 org.gtk.Gtk3theme.adw-gtk3-dark; do
    if [[ $'\n'$masks$'\n' != *[[:space:]]"$ref"[[:space:]]* ]]; then
      run flatpak mask "$ref"
    fi
  done
  log_ok "Overrides y máscaras de Flatpak al día"
}
