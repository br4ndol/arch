#!/bin/bash
set -e

# =====================================================================
# Módulo: 10-appimages.sh
# Descripción: Instala Gearlever (Flatpak), descarga las versiones más
#              recientes de Obsidian (x86_64) y Ryujinx Canary, y las integra.
# =====================================================================

# --- Importar utilidades ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/utils.sh"

# --- Validar que se ejecute como root ---
if [ "$(id -u)" -ne 0 ]; then
    error "Este módulo debe ejecutarse como root. Usa 'sudo ./10-appimages.sh'."
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
TEMP_DIR="/tmp/appimages_installer"

# --- 1. Instalación de Dependencias ---
msg "Verificando dependencias necesarias (fuse, jq, Gearlever)..."
instalar_paquete "fuse3" "jq" "curl"
instalar_flatpak "it.mijorus.gearlever"

# --- Función auxiliar: Consultar aplicaciones integradas en Gearlever ---
gearlever_installed_apps() {
    runuser -u "$TARGET_USER" -- flatpak run it.mijorus.gearlever --list-installed 2>/dev/null || true
}

INSTALLED_APPS=$(gearlever_installed_apps)

# Preparar directorio temporal
mkdir -p "$TEMP_DIR"
chown "$TARGET_USER:$TARGET_USER" "$TEMP_DIR"

# --- 2. Integración de Obsidian ---
msg "Verificando estado de Obsidian AppImage..."
if echo "$INSTALLED_APPS" | grep -i "obsidian" &>/dev/null; then
    msg "Obsidian ya está integrado en Gearlever."
else
    msg "Obteniendo la última versión x86_64 de Obsidian..."
    
    # Método 1: API de GitHub (usando operadores seguros ?)
    OBSIDIAN_URL=$(curl -s https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest | jq -r '.assets[]? | select(.name? | test("Obsidian-[0-9.]+\\.AppImage$")) | .browser_download_url' 2>/dev/null | head -n 1 || true)

    # Método 2: Fallback vía HTML si la API falló o dio rate limit
    if [ -z "$OBSIDIAN_URL" ] || [ "$OBSIDIAN_URL" = "null" ]; then
        msg "API de GitHub no disponible. Usando respaldo mediante búsqueda en la página oficial..."
        REL_URL=$(curl -sL https://github.com/obsidianmd/obsidian-releases/releases/latest | grep -oP 'href="\K/obsidianmd/obsidian-releases/releases/download/[^"]*Obsidian-[0-9.]+\.AppImage' | head -n 1 || true)
        if [ -n "$REL_URL" ]; then
            OBSIDIAN_URL="https://github.com${REL_URL}"
        fi
    fi

    if [ -n "$OBSIDIAN_URL" ] && [ "$OBSIDIAN_URL" != "null" ]; then
        FILE_NAME=$(basename "$OBSIDIAN_URL")
        DEST_FILE="${TEMP_DIR}/${FILE_NAME}"

        msg "Descargando $FILE_NAME desde: $OBSIDIAN_URL"
        runuser -u "$TARGET_USER" -- curl -sL "$OBSIDIAN_URL" -o "$DEST_FILE"
        chmod +x "$DEST_FILE"

        msg "Integrando Obsidian en Gearlever..."
        echo "y" | runuser -u "$TARGET_USER" -- flatpak run it.mijorus.gearlever --integrate "$DEST_FILE" || true
        rm -f "$DEST_FILE"
        success "Obsidian integrado correctamente."
    else
        error "No se pudo obtener el enlace de descarga para Obsidian x86_64."
        exit 1
    fi
fi

# --- 3. Integración de Ryujinx Canary ---
msg "Verificando estado de Ryujinx Canary AppImage..."
if echo "$INSTALLED_APPS" | grep -i "ryujinx" &>/dev/null; then
    msg "Ryujinx Canary ya está integrado en Gearlever."
else
    msg "Obteniendo la última versión de Ryujinx Canary desde Forgejo..."
    
    # Método 1: API de Forgejo
    RYUJINX_URL=$(curl -s https://git.ryujinx.app/api/v1/repos/Ryubing/Canary/releases | jq -r '.[0]?.assets[]? | select(.name? | test("ryujinx-canary-.*-x64\\.AppImage$")) | .browser_download_url' 2>/dev/null | head -n 1 || true)

    # Método 2: Fallback vía HTML
    if [ -z "$RYUJINX_URL" ] || [ "$RYUJINX_URL" = "null" ]; then
        msg "API de Forgejo no disponible. Usando respaldo vía HTML..."
        REL_URL=$(curl -s https://git.ryujinx.app/Ryubing/Canary/releases | grep -oP 'href="\K/Ryubing/Canary/releases/download/[^"]*ryujinx-canary-[^"]*-x64\.AppImage' | head -n 1 || true)
        if [ -n "$REL_URL" ]; then
            RYUJINX_URL="https://git.ryujinx.app${REL_URL}"
        fi
    fi

    if [ -n "$RYUJINX_URL" ] && [ "$RYUJINX_URL" != "null" ]; then
        FILE_NAME=$(basename "$RYUJINX_URL")
        DEST_FILE="${TEMP_DIR}/${FILE_NAME}"

        msg "Descargando $FILE_NAME desde: $RYUJINX_URL"
        runuser -u "$TARGET_USER" -- curl -sL "$RYUJINX_URL" -o "$DEST_FILE"
        chmod +x "$DEST_FILE"

        msg "Integrando Ryujinx Canary en Gearlever..."
        echo "y" | runuser -u "$TARGET_USER" -- flatpak run it.mijorus.gearlever --integrate "$DEST_FILE" || true
        rm -f "$DEST_FILE"
        success "Ryujinx Canary integrado correctamente."
    else
        error "No se pudo obtener el enlace de descarga para Ryujinx Canary."
        exit 1
    fi
fi

# --- Limpieza final ---
rm -rf "$TEMP_DIR"

success "🎉 ¡Módulo de AppImages completado con éxito!"