#!/bin/bash
set -e

# --- Directorios ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="${SCRIPT_DIR}/modules"
VALIDATE_SCRIPT="${SCRIPT_DIR}/utils/validate.sh"

# --- Importar utilidades ---
source "${SCRIPT_DIR}/utils/utils.sh"

# --- Validar que se ejecute como root ---
if [ "$(id -u)" -ne 0 ]; then
    error "Este script debe ejecutarse como root. Usa 'sudo ./setup.sh'."
    exit 1
fi

# --- Validar repositorios del sistema ---
msg "Validando repositorios..."
chmod +x "$VALIDATE_SCRIPT" # Asegura permisos antes de ejecutar
"$VALIDATE_SCRIPT"

msg "🚀 Iniciando configuración del sistema..."

# --- Asegurar permisos de ejecución en los módulos ---
msg "Asegurando permisos de ejecución para los módulos..."
if [ -d "$MODULES_DIR" ]; then
    chmod +x "${MODULES_DIR}"/*.sh
else
    error "No se encontró el directorio de módulos en: $MODULES_DIR"
    exit 1
fi

# --- Lista de módulos a ejecutar (en orden) ---
MODULES=(
    "00-tools.sh"
    "01-kernel.sh"
    #"02-drivers.sh"
    "03-plymouth.sh"
    "04-auth.sh"
    "05-zsh.sh"
    "06-networkmanager.sh"
    "07-audio.sh"
)

# --- Ejecutar módulos ---
for module in "${MODULES[@]}"; do
    module_path="${MODULES_DIR}/${module}"
    if [ -f "$module_path" ]; then
        msg "Ejecutando: ${module}..."
        if ! "$module_path"; then
            error "El módulo ${module} falló. Deteniendo setup."
            exit 1
        fi
    else
        error "Módulo no encontrado: ${module_path}"
        exit 1
    fi
done

success "🎉 ¡Proceso de setup completado con éxito!"