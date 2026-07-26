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

# --- Instalar un paquete con pacman ---
instalar_paquete() {
    if ! paquete_instalado "$1"; then
        msg "Instalando paquete: $1..."
        if ! pacman -S --needed --noconfirm "$1"; then
            error "Falló la instalación de $1."
            return 1
        fi
        success "Paquete $1 instalado."
    else
        msg "El paquete $1 ya está instalado."
    fi
}