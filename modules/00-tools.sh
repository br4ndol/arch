#!/bin/bash
set -e

# =====================================================================
# Módulo: 00-tools.sh
# Descripción: Instala herramientas base esenciales (yay, base-devel, git,
#              flatpak) y configura el repositorio Flathub.
# =====================================================================

# --- Importar utilidades ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/utils.sh"

# --- Validar que se ejecute como root ---
if [ "$(id -u)" -ne 0 ]; then
    error "Este módulo debe ejecutarse como root. Usa 'sudo ./00-tools.sh'."
    exit 1
fi

# --- Variables ---
PACKAGES=("base-devel" "git" "yay" "flatpak" "curl")
FLATHUB_URL="https://dl.flathub.org/repo/flathub.flatpakrepo"

# --- 1. Verificación de Estado Real ---
msg "Verificando herramientas base del sistema..."

pkgs_instalados=1
for pkg in "${PACKAGES[@]}"; do
    if ! paquete_instalado "$pkg"; then
        pkgs_instalados=0
        break
    fi
done

flathub_ok=0
if flatpak remotes 2>/dev/null | grep -q "flathub"; then
    flathub_ok=1
fi

if [ $pkgs_instalados -eq 1 ] && [ $flathub_ok -eq 1 ]; then
    success "Herramientas base y repositorio Flathub ya están configurados. ¡Módulo omitido!"
    exit 0
fi

# --- 2. Instalación de Paquetes Base ---
msg "Verificando e instalando paquetes base..."
MISSING_PKGS=()
for pkg in "${PACKAGES[@]}"; do
    if ! paquete_instalado "$pkg"; then
        MISSING_PKGS+=("$pkg")
    fi
done

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    instalar_paquete "${MISSING_PKGS[@]}"
else
    msg "Paquetes base ya instalados."
fi

# --- 3. Configurar Repositorio Flathub ---
if [ $flathub_ok -eq 0 ]; then
    msg "Configurando el repositorio Flathub para Flatpak..."
    if flatpak remote-add --if-not-exists flathub "$FLATHUB_URL"; then
        success "Repositorio Flathub configurado con éxito."
    else
        error "Error al agregar el repositorio Flathub."
        exit 1
    fi
else
    msg "El repositorio Flathub ya está activo."
fi

success "🎉 ¡Módulo de Herramientas Base completado con éxito!"