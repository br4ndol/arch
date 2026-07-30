#!/bin/bash
set -e

# =====================================================================
# Módulo: 11-kde.sh
# Descripción: Instala KDE Plasma, SDDM, utilidades base, deshabilita KRunner,
#              configura bluetooth y despliega las apps Flatpak.
# =====================================================================

# --- Importar utilidades ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/utils.sh"

# --- Validar que se ejecute como root ---
if [ "$(id -u)" -ne 0 ]; then
    error "Este módulo debe ejecutarse como root. Usa 'sudo ./11-kde.sh'."
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

# --- Lista de Paquetes Pacman para KDE Plasma ---
PACKAGES=(
    # Plasma Desktop & Gestor de inicio
    "plasma-desktop" "sddm" "sddm-kcm" "flatpak-kcm"
    # Integración y utilidades
    "dolphin" "kscreen" "kde-gtk-config" "partitionmanager"
    "plasma-pa" "plasma-nm" "bluedevil" "spectacle"
)

# --- Lista de Flatpaks para KDE ---
FLATPAKS=(
    "org.kde.kwrite"
    "org.kde.kcalc"
    "org.kde.gwenview"
    "org.videolan.VLC"
)

# --- 1. Instalación de Paquetes Pacman ---
msg "Verificando e instalando paquetes de KDE Plasma..."
MISSING_PKGS=()
for pkg in "${PACKAGES[@]}"; do
    if ! paquete_instalado "$pkg"; then
        MISSING_PKGS+=("$pkg")
    fi
done

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    instalar_paquete "${MISSING_PKGS[@]}"
else
    msg "Todos los paquetes de KDE Plasma ya están instalados."
fi

# --- 2. Habilitar SDDM y Bluetooth ---
msg "Configurando servicio SDDM..."
if systemctl is-enabled gdm.service &>/dev/null; then
    systemctl disable gdm.service
fi

if ! systemctl is-enabled sddm.service &>/dev/null; then
    systemctl enable sddm.service
    success "SDDM habilitado."
else
    msg "SDDM ya está habilitado."
fi

msg "Asegurando servicio Bluetooth para KDE..."
if ! systemctl is-enabled bluetooth.service &>/dev/null; then
    systemctl enable --now bluetooth.service
    success "Servicio Bluetooth habilitado."
fi

# --- 3. Deshabilitar KRunner ---
msg "Deshabilitando y enmascarando KRunner..."

# Enmascarar la unidad systemd a nivel global para sesiones de usuario
systemctl --global mask plasma-krunner.service 2>/dev/null || true

# Enmascarar en la sesión del usuario si está activa
runuser -u "$TARGET_USER" -- dbus-run-session systemctl --user mask --now plasma-krunner.service 2>/dev/null || true

# Detener el proceso KRunner si está corriendo
runuser -u "$TARGET_USER" -- kquitapp6 krunner 2>/dev/null || runuser -u "$TARGET_USER" -- killall krunner 2>/dev/null || true

success "KRunner deshabilitado correctamente."

# --- 4. Instalación de Flatpaks ---
msg "Verificando e instalando aplicaciones Flatpak para KDE..."
instalar_flatpak "${FLATPAKS[@]}"

# --- 5. Asegurar Permisos de Usuario ---
if [ -d "$TARGET_HOME/.config" ]; then
    chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.config"
fi

success "🎉 ¡Módulo de KDE Plasma completado con éxito!"