#!/bin/bash

# =============================================
# Funciones utilitarias básicas para los módulos
# =============================================

# --- Colores para mensajes ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# --- Mensajes ---
msg() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# --- Verificar si un paquete está instalado ---
paquete_instalado() {
    pacman -Q "$1" &> /dev/null
    return $?
}

# --- Instalar uno o varios paquetes con pacman ---
instalar_paquete() {
    local pkgs=("$@")
    if [ ${#pkgs[@]} -eq 0 ]; then
        return 0
    fi

    msg "Instalando paquete(s): ${pkgs[*]}..."
    if ! pacman -S --needed --noconfirm "${pkgs[@]}"; then
        error "Falló la instalación de: ${pkgs[*]}"
        return 1
    fi
    success "Paquete(s) instalado(s) con éxito."
}

# --- Instalar uno o varios paquetes con Flatpak ---
instalar_flatpak() {
    local pkgs=("$@")
    if [ ${#pkgs[@]} -eq 0 ]; then
        return 0
    fi

    local missing=()
    for pkg in "${pkgs[@]}"; do
        if ! flatpak list --system | grep -q "$pkg"; then
            missing+=("$pkg")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        msg "Instalando paquete(s) Flatpak: ${missing[*]}..."
        if ! flatpak install -y flathub "${missing[@]}"; then
            error "Falló la instalación de Flatpak: ${missing[*]}"
            return 1
        fi
        success "Paquete(s) Flatpak instalado(s) con éxito."
    else
        msg "Todos los paquetes Flatpak solicitados ya están instalados."
    fi
}