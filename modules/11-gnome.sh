#!/bin/bash
set -e

# =====================================================================
# Módulo: 11-gnome.sh
# Descripción: Instala GNOME, configura ajustes de sistema, instala apps
#              Flatpak, y aplica atajos de teclado personalizados.
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

# --- Lista de Paquetes Pacman ---
PACKAGES=(
    "gnome-shell" "gdm" "gnome-control-center" "gnome-backgrounds"
    "gnome-disk-utility" "gnome-tweaks" "ghostty" "ocean-sound-theme"
    "ddcutil" "noto-fonts" "noto-fonts-cjk" "noto-fonts-emoji"
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
msg "Aplicando configuraciones de GNOME..."
# Configuración de interfaz y sonido
gsettings set org.gnome.desktop.interface clock-format '24h'
gsettings set org.gnome.desktop.calendar week-start-day 'monday'
gsettings set org.gnome.desktop.sound theme-name 'ocean'
gsettings set org.gnome.desktop.sound allow-volume-above-100-percent true

# Configuración de energía
gsettings set org.gnome.settings-daemon.plugins.power power-button-action 'nothing'
gsettings set org.gnome.settings-daemon.plugins.power power-saver-profile-on-low-battery true
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
gsettings set org.gnome.settings-daemon.plugins.power idle-dim false

# Configuración de sesión
gsettings set org.gnome.desktop.session idle-delay 0

# Configuración de Nautilus
gsettings set org.gnome.nautilus.preferences default-sort-order 'type'
gsettings set org.gnome.nautilus.preferences show-image-thumbnails 'always'
gsettings set org.gnome.nautilus.preferences show-create-link true

# Configuración de GNOME Shell
gsettings set org.gnome.shell always-show-log-out true

success "Configuraciones de GNOME aplicadas."

# --- 4. Instalación de Flatpaks ---
msg "Verificando e instalando aplicaciones Flatpak..."
instalar_flatpak "${FLATPAKS[@]}"

# --- 5. Configuración de Atajos de Teclado Personalizados ---
KEYBINDINGS_CONF="${SCRIPT_DIR}/../configs/gnome/keybindings.dconf"
msg "Configurando atajos de teclado personalizados..."

if [ -f "$KEYBINDINGS_CONF" ]; then
    msg "Aplicando configuración de atajos desde $KEYBINDINGS_CONF..."
    runuser -u "$TARGET_USER" -- dconf load /org/gnome/settings-daemon/plugins/media-keys/ < "$KEYBINDINGS_CONF"
    success "Atajos de teclado personalizados aplicados."
else
    error "No se encontró el archivo de configuración de atajos en $KEYBINDINGS_CONF"
    exit 1
fi

success "Atajos de teclado personalizados aplicados."

success "🎉 ¡Módulo de GNOME completado con éxito!"