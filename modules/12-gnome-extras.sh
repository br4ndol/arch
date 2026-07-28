#!/bin/bash
set -e

# =====================================================================
# Módulo: 12-gnome-extras.sh
# Descripción: Configura Bluetooth, Nautilus, extensiones, temas, cursor
#              y compatibilidad QT para GNOME.
# =====================================================================

# --- Importar utilidades ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/utils.sh"

# --- Validar que se ejecute como root ---
if [ "$(id -u)" -ne 0 ]; then
    error "Este módulo debe ejecutarse como root. Usa 'sudo ./12-gnome-extras.sh'."
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
CONFIG_DIR="${SCRIPT_DIR}/../configs/gnome"
TEMP_DIR="/tmp/gnome_extras"

# --- Función Auxiliar Silenciosa para gsettings/dconf ---
user_gsettings() {
    runuser -u "$TARGET_USER" -- dbus-run-session gsettings "$@" 2>/dev/null
}

# --- 1. Bluetooth ---
msg "Configurando Bluetooth..."
PACKAGES_BLUETOOTH=("bluez" "bluez-utils" "gnome-bluetooth-3.0")

MISSING_PKGS=()
for pkg in "${PACKAGES_BLUETOOTH[@]}"; do
    if ! paquete_instalado "$pkg"; then
        MISSING_PKGS+=("$pkg")
    fi
done

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    instalar_paquete "${MISSING_PKGS[@]}"
fi

msg "Habilitando servicio Bluetooth..."
if ! systemctl is-enabled bluetooth.service &>/dev/null; then
    systemctl enable --now bluetooth.service
    success "Servicio Bluetooth habilitado."
else
    msg "Servicio Bluetooth ya está habilitado."
fi

msg "Reiniciando servicios de audio para Bluetooth..."
systemctl --user restart pipewire pipewire-pulse wireplumber 2>/dev/null || true

msg "Verificando módulo btusb..."
if ! lsmod | grep -q btusb; then
    msg "Cargando módulo btusb..."
    modprobe btusb
else
    msg "Módulo btusb ya está cargado."
fi

# --- 2. Nautilus ---
msg "Configurando Nautilus..."
PACKAGES_NAUTILUS=("sushi" "file-roller" "p7zip" "unrar" "unzip" "ghostty-nautilus")

MISSING_PKGS=()
for pkg in "${PACKAGES_NAUTILUS[@]}"; do
    if ! paquete_instalado "$pkg"; then
        MISSING_PKGS+=("$pkg")
    fi
done

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    instalar_paquete "${MISSING_PKGS[@]}"
fi

# Instalar nautilus-create-file desde AUR
if ! paquete_instalado "nautilus-create-file"; then
    msg "Instalando nautilus-create-file desde AUR..."
    runuser -u "$TARGET_USER" -- yay -S --needed --noconfirm nautilus-create-file
fi

msg "Configurando marcadores de GTK..."
GTK_BOOKMARKS="$TARGET_HOME/.config/gtk-3.0/bookmarks"
mkdir -p "$(dirname "$GTK_BOOKMARKS")"
if ! grep -q "file:/// File System" "$GTK_BOOKMARKS"; then
    echo "file:/// File System" >> "$GTK_BOOKMARKS"
    chown "$TARGET_USER:$TARGET_USER" "$GTK_BOOKMARKS"
    success "Marcador 'File System' añadido."
else
    msg "Marcador 'File System' ya existe."
fi

msg "Eliminando directorios de usuario innecesarios..."
xdg-user-dirs-update --set TEMPLATES "$TARGET_HOME" 2>/dev/null || true
xdg-user-dirs-update --set PUBLICSHARE "$TARGET_HOME" 2>/dev/null || true
rm -rf "$TARGET_HOME/Public" "$TARGET_HOME/Templates" "$TARGET_HOME/Projects" 2>/dev/null || true
success "Directorios innecesarios eliminados."

# --- 3. Extensiones de GNOME ---
msg "Configurando extensiones de GNOME..."
if ! paquete_instalado "gnome-browser-connector"; then
    instalar_paquete "gnome-browser-connector"
else
    msg "gnome-browser-connector ya está instalado."
fi

# --- 4. Temas ---
msg "Configurando tema ADW-GTK..."
if ! paquete_instalado "adw-gtk-theme"; then
    instalar_paquete "adw-gtk-theme"
fi

user_gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark'
user_gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

msg "Configurando GTK-4.0..."
GTK4_SETTINGS="$TARGET_HOME/.config/gtk-4.0/settings.ini"
mkdir -p "$(dirname "$GTK4_SETTINGS")"
if [ -f "$CONFIG_DIR/settings.ini" ]; then
    cp -f "$CONFIG_DIR/settings.ini" "$GTK4_SETTINGS"
    chown "$TARGET_USER:$TARGET_USER" "$GTK4_SETTINGS"
    success "Configuración de GTK-4.0 aplicada."
else
    error "No se encontró el archivo de configuración GTK-4.0 en $CONFIG_DIR/settings.ini"
    exit 1
fi

# --- 5. Cursor Bibata ---
msg "Configurando cursor Bibata-Modern-Classic..."
CURSOR_DIR="/usr/share/icons/Bibata-Modern-Classic"
CURSOR_URL="https://github.com/ful1e5/Bibata_Cursor/releases/download/v2.0.7/Bibata-Modern-Classic.tar.xz"
CURSOR_ARCHIVE="${TEMP_DIR}/Bibata-Modern-Classic.tar.xz"

mkdir -p "$TEMP_DIR"

if [ ! -d "$CURSOR_DIR" ]; then
    msg "Descargando cursor Bibata-Modern-Classic..."
    curl -sL "$CURSOR_URL" -o "$CURSOR_ARCHIVE"
    tar -xvf "$CURSOR_ARCHIVE" -C "$TEMP_DIR"
    mv "${TEMP_DIR}/Bibata-Modern-Classic" "$CURSOR_DIR"
    rm -f "$CURSOR_ARCHIVE"
    user_gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Classic'
    success "Cursor Bibata-Modern-Classic instalado y configurado."
else
    msg "Cursor Bibata-Modern-Classic ya está instalado."
fi

# --- 6. Temas Flatpak ---
msg "Configurando temas para Flatpak..."
instalar_flatpak "org.gtk.Gtk3theme.adw-gtk3" "org.gtk.Gtk3theme.adw-gtk3-dark"

msg "Aplicando permisos para temas Flatpak..."
flatpak override --filesystem=xdg-data/themes 2>/dev/null || true
flatpak mask org.gtk.Gtk3theme.adw-gtk3 2>/dev/null || true
flatpak mask org.gtk.Gtk3theme.adw-gtk3-dark 2>/dev/null || true
success "Temas Flatpak configurados."

# --- 7. QT para GNOME ---
msg "Configurando compatibilidad QT..."
PACKAGES_QT=("qt5ct" "qt6ct" "qgnomeplatform-qt5" "qgnomeplatform-qt6" "qadwaitadecorations-qt6")

MISSING_PKGS=()
for pkg in "${PACKAGES_QT[@]}"; do
    if ! paquete_instalado "$pkg"; then
        MISSING_PKGS+=("$pkg")
    fi
done

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    instalar_paquete "${MISSING_PKGS[@]}"
fi

msg "Configurando QT_QPA_PLATFORMTHEME en /etc/environment..."
if ! grep -q "QT_QPA_PLATFORMTHEME=qt5ct" /etc/environment; then
    echo "QT_QPA_PLATFORMTHEME=qt5ct" >> /etc/environment
    success "QT_QPA_PLATFORMTHEME configurado."
else
    msg "QT_QPA_PLATFORMTHEME ya está configurado."
fi

# --- Limpieza ---
rm -rf "$TEMP_DIR"

success "🎉 ¡Módulo de GNOME Extras completado con éxito!"