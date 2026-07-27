#!/bin/bash
set -e

# =====================================================================
# Módulo: 03-plymouth.sh
# Descripción: Instala Plymouth, configura el HOOK en mkinitcpio.conf,
#              establece el tema 'bgrt' y reconstruye el initramfs.
# =====================================================================

# --- Importar utilidades ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/utils.sh"

# --- Validar que se ejecute como root ---
if [ "$(id -u)" -ne 0 ]; then
    error "Este módulo debe ejecutarse como root. Usa 'sudo ./03-plymouth.sh'."
    exit 1
fi

# --- Variables ---
PKG="plymouth"
MK_CONF="/etc/mkinitcpio.conf"
PLY_CONF="/etc/plymouth/plymouthd.conf"
CHANGES_APPLIED=0

# --- 1. Verificación de Estado Real ---
msg "Verificando estado de Plymouth..."

pkg_instalado=0
hook_configurado=0
tema_configurado=0

if paquete_instalado "$PKG"; then
    pkg_instalado=1
fi

# Verificar de forma segura si 'plymouth' es un hook activo en HOOKS=(...)
if [ -f "$MK_CONF" ] && grep -E "^HOOKS=\(.*[[:space:]]plymouth[[:space:]]|\(plymouth[[:space:]]|[[:space:]]plymouth\)" "$MK_CONF" &>/dev/null; then
    hook_configurado=1
fi

# Verificar si el tema bgrt ya está configurado por defecto
if [ -f "$PLY_CONF" ] && grep -q "^Theme=bgrt" "$PLY_CONF"; then
    tema_configurado=1
fi

# Omitir si todo ya está aplicado
if [ $pkg_instalado -eq 1 ] && [ $hook_configurado -eq 1 ] && [ $tema_configurado -eq 1 ]; then
    success "Plymouth ya está instalado y configurado con el tema bgrt. ¡Módulo omitido!"
    exit 0
fi

# --- 2. Instalación de Plymouth ---
if [ $pkg_instalado -eq 0 ]; then
    msg "Instalando Plymouth..."
    if instalar_paquete "$PKG"; then
        CHANGES_APPLIED=1
    else
        error "No se pudo instalar Plymouth."
        exit 1
    fi
else
    msg "Plymouth ya está instalado."
fi

# --- 3. Configurar HOOK en mkinitcpio.conf ---
if [ $hook_configurado -eq 0 ]; then
    msg "Configurando HOOK 'plymouth' después de 'udev' en $MK_CONF..."
    if grep -q "\budev\b" "$MK_CONF"; then
        # Inserta 'plymouth' exactamente después de la palabra 'udev' en la línea de HOOKS
        sed -i '/^HOOKS=/s/\budev\b/udev plymouth/' "$MK_CONF"
        CHANGES_APPLIED=1
        success "HOOK 'plymouth' añadido con éxito."
    else
        error "No se encontró el hook 'udev' en $MK_CONF. No se puede posicionar Plymouth automáticamente."
        exit 1
    fi
else
    msg "HOOK 'plymouth' ya está configurado en $MK_CONF."
fi

# --- 4. Aplicar Tema 'bgrt' y Regenerar (Solo si es necesario) ---
if [ $tema_configurado -eq 0 ] || [ $CHANGES_APPLIED -eq 1 ]; then
    msg "Estableciendo tema bgrt y regenerando initramfs (esta tarea puede demorar)..."
    # El comando plymouth-set-default-theme con -R reconstruye el initramfs automáticamente
    if plymouth-set-default-theme -R bgrt; then
        success "Tema 'bgrt' configurado y reconstruido con éxito."
    else
        error "Error al establecer el tema de Plymouth o reconstruir initramfs."
        exit 1
    fi
else
    msg "El tema bgrt ya está configurado por defecto."
fi

success "🎉 ¡Módulo de Plymouth completado con éxito!"