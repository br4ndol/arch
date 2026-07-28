#!/bin/bash
set -e

# =====================================================================
# Módulo: 07-audio.sh
# Descripción: Instala PipeWire, WirePlumber, herramientas de audio,
#              configura permisos realtime, habilita servicios de usuario,
#              añade Flathub, instala EasyEffects y sus presets.
# =====================================================================

# --- Importar utilidades ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/utils.sh"

# --- Validar que se ejecute como root ---
if [ "$(id -u)" -ne 0 ]; then
    error "Este módulo debe ejecutarse como root. Usa 'sudo ./07-audio.sh'."
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

# --- Lista de paquetes de pacman ---
PACKAGES=(
    "pipewire" "pipewire-audio" "pipewire-alsa" "pipewire-pulse" "pipewire-jack"
    "alsa-utils" "alsa-ucm-conf" "sof-firmware" "rtkit" "realtime-privileges"
    "gst-plugin-pipewire" "lib32-pipewire" "lib32-pipewire-jack" "wireplumber"
    "pavucontrol" "curl" "flatpak"
)

# --- 1. Instalación de Paquetes ---
msg "Verificando e instalando paquetes de PipeWire y utilidades de audio..."
MISSING_PKGS=()
for pkg in "${PACKAGES[@]}"; do
    if ! paquete_instalado "$pkg"; then
        MISSING_PKGS+=("$pkg")
    fi
done

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    instalar_paquete "${MISSING_PKGS[@]}"
else
    msg "Todos los paquetes de audio ya están instalados."
fi

# --- 2. Añadir usuario al grupo realtime ---
msg "Asegurando permisos de realtime para $TARGET_USER..."
if ! groups "$TARGET_USER" | grep -q "\brealtime\b"; then
    usermod -aG realtime "$TARGET_USER"
    success "Usuario $TARGET_USER añadido al grupo 'realtime'."
else
    msg "El usuario $TARGET_USER ya pertenece al grupo 'realtime'."
fi

# --- 3. Habilitar Servicios de Usuario de PipeWire ---
msg "Habilitando servicios de PipeWire a nivel global para usuarios..."
# Usar --global permite que el servicio quede activo para cualquier sesión de usuario al iniciar
systemctl --global enable pipewire.socket pipewire-pulse.socket wireplumber.service

# --- 4. Instalar EasyEffects (Flatpak) ---
instalar_flatpak "com.github.wwmm.easyeffects"

# --- 6. Instalar Presets de EasyEffects (JackHack96) ---
PRESETS_DIR="$TARGET_HOME/.config/easyeffects/output"
msg "Verificando Presets de EasyEffects para $TARGET_USER..."

if [ ! -d "$PRESETS_DIR" ] || [ -z "$(ls -A "$PRESETS_DIR" 2>/dev/null)" ]; then
    msg "Instalando Presets de EasyEffects (Opción 1: Todos)..."
    
    # Enviamos "1" automáticamente al script interactivo
    echo "1" | runuser -u "$TARGET_USER" -- bash -c "$(curl -fsSL https://raw.githubusercontent.com/JackHack96/EasyEffects-Presets/master/install.sh)" || true

    # Corregir permisos en caso necesario
    chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.config/easyeffects" 2>/dev/null || true
    success "Presets de EasyEffects instalados con éxito."
else
    msg "Los Presets de EasyEffects ya están instalados."
fi

success "🎉 ¡Módulo de Audio completado con éxito!"