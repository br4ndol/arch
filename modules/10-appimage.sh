#!/bin/bash
set -e

# =====================================================================
# Módulo: 10-appimage.sh
# Descripción: Instala fuse y GearLever (Flatpak), descarga de forma automatizada
#              las últimas versiones de Obsidian y Ryujinx Canary, las integra
#              en el sistema y asigna sus fuentes de actualización en GearLever.
# =====================================================================

# --- Importar utilidades ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/utils.sh"

# --- Validar que se ejecute como root ---
if [ "$(id -u)" -ne 0 ]; then
    error "Este módulo debe ejecutarse como root. Usa 'sudo ./10-appimage.sh'."
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
TARGET_UID=$(id -u "$TARGET_USER")
XDG_RUNTIME="/run/user/$TARGET_UID"

# Función auxiliar para ejecutar flatpak como usuario objetivo con entorno XDG correcto
run_gearlever() {
    runuser -u "$TARGET_USER" -- env XDG_RUNTIME_DIR="$XDG_RUNTIME" flatpak run it.mijorus.gearlever "$@"
}

# --- 1. Instalación de Dependencias ---
msg "Verificando instalación de 'fuse' y 'GearLever'..."
if ! paquete_instalado "fuse2" && ! paquete_instalado "fuse3" && ! paquete_instalado "fuse"; then
    instalar_paquete "fuse3"
fi

instalar_flatpak "it.mijorus.gearlever"

# --- 2. Verificar aplicaciones ya integradas ---
msg "Verificando AppImages integradas en GearLever..."
INSTALLED_APPS=""
if [ -d "$XDG_RUNTIME" ]; then
    INSTALLED_APPS=$(run_gearlever --list-installed 2>/dev/null || true)
fi

# --- 3. Integración de Obsidian ---
if echo "$INSTALLED_APPS" | grep -i -q "Obsidian"; then
    msg "Obsidian ya está integrado en GearLever."
else
    msg "Obteniendo la última versión de Obsidian desde GitHub..."
    OBSIDIAN_URL=$(curl -s https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest | grep -i "browser_download_url" | grep -i "Obsidian-.*\.AppImage" | cut -d '"' -f 4 | head -n 1)

    if [ -n "$OBSIDIAN_URL" ]; then
        TMP_OBSIDIAN="/tmp/Obsidian.AppImage"
        msg "Descargando Obsidian AppImage..."
        curl -sL "$OBSIDIAN_URL" -o "$TMP_OBSIDIAN"
        chmod +x "$TMP_OBSIDIAN"
        chown "$TARGET_USER:$TARGET_USER" "$TMP_OBSIDIAN"

        msg "Integrando Obsidian en GearLever..."
        echo "y" | run_gearlever --integrate "$TMP_OBSIDIAN" || true

        # Buscar el archivo integrado en ~/AppImages o ~/.local/share/gearlever
        INTEGRATED_FILE=$(find "$TARGET_HOME/AppImages" "$TARGET_HOME/.local/share/gearlever" -iname "*obsidian*.appimage" 2>/dev/null | head -n 1)

        if [ -n "$INTEGRATED_FILE" ]; then
            msg "Configurando fuente de actualización de GitHub para Obsidian..."
            run_gearlever --set-update-source "$INTEGRATED_FILE" --manager GithubUpdater repo=obsidianmd/obsidian-releases repo_filename="Obsidian-*.AppImage" || true
            success "Obsidian configurado correctamente."
        fi

        rm -f "$TMP_OBSIDIAN"
    else
        error "No se pudo obtener la URL de descarga para Obsidian."
    fi
fi

# --- 4. Integración de Ryujinx Canary ---
if echo "$INSTALLED_APPS" | grep -i -q "Ryujinx"; then
    msg "Ryujinx Canary ya está integrado en GearLever."
else
    msg "Obteniendo la última versión de Ryujinx Canary desde Forgejo..."
    RYUJINX_URL=$(curl -s https://git.ryujinx.app/api/v1/repos/Ryubing/Canary/releases/latest | grep -o 'https://[^"]*ryujinx-canary-[^"]*-x64\.AppImage' | head -n 1)

    # Fallback a scraping HTML en caso de que la API requiera autorización
    if [ -z "$RYUJINX_URL" ]; then
        REL_PATH=$(curl -s https://git.ryujinx.app/Ryubing/Canary/releases | grep -o '/Ryubing/Canary/releases/download/[^"]*ryujinx-canary-[^"]*-x64\.AppImage' | head -n 1)
        if [ -n "$REL_PATH" ]; then
            RYUJINX_URL="https://git.ryujinx.app${REL_PATH}"
        fi
    fi

    if [ -n "$RYUJINX_URL" ]; then
        TMP_RYUJINX="/tmp/Ryujinx.AppImage"
        msg "Descargando Ryujinx Canary AppImage..."
        curl -sL "$RYUJINX_URL" -o "$TMP_RYUJINX"
        chmod +x "$TMP_RYUJINX"
        chown "$TARGET_USER:$TARGET_USER" "$TMP_RYUJINX"

        msg "Integrando Ryujinx Canary en GearLever..."
        echo "y" | run_gearlever --integrate "$TMP_RYUJINX" || true

        # Buscar el archivo integrado
        INTEGRATED_RYU=$(find "$TARGET_HOME/AppImages" "$TARGET_HOME/.local/share/gearlever" -iname "*ryujinx*.appimage" 2>/dev/null | head -n 1)

        if [ -n "$INTEGRATED_RYU" ]; then
            msg "Configurando fuente de actualización de Forgejo para Ryujinx Canary..."
            run_gearlever --set-update-source "$INTEGRATED_RYU" --manager ForgejoUpdater repo_url="https://git.ryujinx.app/Ryubing/Canary" repo_filename="ryujinx-canary-*-x64.AppImage" || true
            success "Ryujinx Canary configurado correctamente."
        fi

        rm -f "$TMP_RYUJINX"
    else
        error "No se pudo obtener la URL de descarga para Ryujinx Canary."
    fi
fi

success "🎉 ¡Módulo de AppImages y GearLever completado con éxito!"