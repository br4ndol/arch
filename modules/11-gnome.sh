#!/bin/bash
set -e

# =====================================================================
# Módulo: 11-gnome.sh
# Descripción: Instala GNOME, configura ajustes con dbus-run-session,
#              instala apps Flatpak y aplica atajos personalizados.
# =====================================================================

# --- Importar utilidades ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/utils.sh"

# --- Validar que se ejecute como root ---
if [ "$(id -u)" -ne 0 ]; then
    error "Este módulo debe ejecutarse como root. Usa 'sudo ./11-gnome.sh'."
    exit 1
fi

# --- Detectar Usuario Objetivo ---
TARGET_USER="${SUDO_USER}"
if [ -z "$TARGET_USER" ] || [ "$TARGET_USER" = "root" ]; then
    TARGET_USER=$(awk -F: '$3 >= 1000 && $3 < 60000 {print $1; exit}' /etc/passwd)
fi

if [ -z "$TARGET_USER" ]; then
    error "No se pudo determinar el usuario normal del sistema."
    exit 1
fi

TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
KEYBINDINGS_CONF="${SCRIPT_DIR}/../configs/gnome/keybindings.dconf"

# --- Función Auxiliar para Ejecutar gsettings/dconf sin interfaz gráfica ---
user_gsettings() {
    runuser -u "$TARGET_USER" -- dbus-run-session gsettings "$@"
}

# --- Lista de Paquetes Pacman ---
PACKAGES=(
    "gnome-shell" "gdm" "gnome-control-center" "gnome-backgrounds"
    "gnome-disk-utility" "gnome-tweaks" "ghostty" "ocean-sound-theme"
    "ddcutil" "noto-fonts" "noto-fonts-cjk" "noto-fonts-emoji" "dbus"
    "pavucontrol"
)

# --- Lista de Flatpaks ---
FLATPAKS=(
    "org.gnome.Calculator"
    "org.gnome.TextEditor"
    "org.gnome.Loupe"
    "org.gnome.Showtime"
    "be.alexandervanhee.gradia"
    "it.mijorus.smile"
    "io.github.realmazharhussain.GdmSettings"
    "page.codeberg.libre_menu_editor.LibreMenuEditor"
    "org.onlyoffice.desktopeditors"
    "com.github.tchx84.Flatseal"
    "ca.desrt.dconf-editor"
    "net.nokyan.Resources"
)

# --- 1. Instalación de Paquetes ---
msg "Verificando e instalando paquetes de GNOME..."
MISSING_PKGS=()
for pkg in "${PACKAGES[@]}"; do
    if ! paquete_instalado "$pkg"; then
        MISSING_PKGS+=("$pkg")
    fi
done

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    instalar_paquete "${MISSING_PKGS[@]}"
else
    msg "Todos los paquetes de GNOME ya están instalados."
fi

# --- 2. Habilitar GDM ---
msg "Habilitando GDM..."
if ! systemctl is-enabled gdm.service &>/dev/null; then
    systemctl enable gdm.service
    success "GDM habilitado."
else
    msg "GDM ya está habilitado."
fi

# --- 3. Configuración de gsettings ---
msg "Aplicando configuraciones de GNOME para $TARGET_USER..."

# Configuración de interfaz y sonido
user_gsettings set org.gnome.desktop.interface clock-format '24h'
user_gsettings set org.gnome.desktop.calendar week-start-day 'monday'
user_gsettings set org.gnome.desktop.sound theme-name 'ocean'
user_gsettings set org.gnome.desktop.sound allow-volume-above-100-percent true

# Configuración de energía
user_gsettings set org.gnome.settings-daemon.plugins.power power-button-action 'nothing'
user_gsettings set org.gnome.settings-daemon.plugins.power power-saver-profile-on-low-battery true
user_gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
user_gsettings set org.gnome.settings-daemon.plugins.power idle-dim false

# Configuración de sesión
user_gsettings set org.gnome.desktop.session idle-delay 0

# Configuración de Nautilus
user_gsettings set org.gnome.nautilus.preferences default-sort-order 'type'
user_gsettings set org.gnome.nautilus.preferences show-image-thumbnails 'always'
user_gsettings set org.gnome.nautilus.preferences show-create-link true

# Configuración de GNOME Shell
user_gsettings set org.gnome.shell always-show-log-out true

# Asegurar permisos correctos en la carpeta de configuraciones dconf
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.config"

success "Configuraciones de GNOME aplicadas correctamente."

# --- 4. Instalación de Flatpaks ---
msg "Verificando e instalando aplicaciones Flatpak..."
instalar_flatpak "${FLATPAKS[@]}"

# --- 5. Configuración de Atajos de Teclado Personalizados ---
msg "Configurando atajos de teclado personalizados..."
if [ -f "$KEYBINDINGS_CONF" ]; then
    runuser -u "$TARGET_USER" -- dbus-run-session dconf load /org/gnome/settings-daemon/plugins/media-keys/ < "$KEYBINDINGS_CONF"
    chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.config"
    success "Atajos de teclado personalizados aplicados."
else
    error "No se encontró el archivo de configuración en $KEYBINDINGS_CONF"
    exit 1
fi

success "🎉 ¡Módulo de GNOME completado con éxito!"