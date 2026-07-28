#!/bin/bash
set -e

# =====================================================================
# Módulo: 13-finalize.sh
# Descripción: Limpieza del sistema, eliminación del kernel base,
#              limpieza de caché y optimizaciones finales.
# =====================================================================

# --- Importar utilidades ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/utils.sh"

# --- Validar que se ejecute como root ---
if [ "$(id -u)" -ne 0 ]; then
    error "Este módulo debe ejecutarse como root. Usa 'sudo ./13-finalize.sh'."
    exit 1
fi

# --- 1. Eliminar el kernel base (linux) si no está en uso ---
msg "Verificando kernel en uso..."
CURRENT_KERNEL=$(uname -r)
if [[ "$CURRENT_KERNEL" == *"cachyos"* ]]; then
    msg "Kernel actual: $CURRENT_KERNEL (CachyOS)."
    if paquete_instalado "linux"; then
        msg "Eliminando kernel base 'linux' (no está en uso)..."
        pacman -Rns --noconfirm linux linux-headers
        success "Kernel base 'linux' eliminado."
    else
        msg "El kernel base 'linux' ya no está instalado."
    fi
else
    error "El kernel actual NO es CachyOS ($CURRENT_KERNEL). No se eliminará el kernel base por seguridad."
    exit 1
fi

# --- 2. Limpiar caché de pacman ---
msg "Limpieza de caché de pacman..."
pacman -Scc --noconfirm
success "Caché de pacman limpiada."

# --- 3. Limpiar caché de AUR (yay/paru) ---
msg "Limpieza de caché de AUR..."
if command -v yay &>/dev/null; then
    runuser -u "$(awk -F: '$3 >= 1000 && $3 < 60000 {print $1; exit}' /etc/passwd)" -- yay -Sc --noconfirm
elif command -v paru &>/dev/null; then
    runuser -u "$(awk -F: '$3 >= 1000 && $3 < 60000 {print $1; exit}' /etc/passwd)" -- paru -Sc --noconfirm
else
    msg "No se encontró yay ni paru. Omitiendo limpieza de caché AUR."
fi

# --- 4. Limpiar archivos temporales ---
msg "Limpieza de archivos temporales..."
rm -rf /tmp/* /var/tmp/* 2>/dev/null || true
success "Archivos temporales limpiados."

# --- 5. Limpiar logs antiguos ---
msg "Limpieza de logs antiguos..."
find /var/log -type f -name "*.log.*" -mtime +7 -delete 2>/dev/null || true
find /var/log -type f -name "*.gz" -mtime +7 -delete 2>/dev/null || true
success "Logs antiguos limpiados."

# --- 6. Limpiar caché de systemd ---
msg "Limpieza de caché de systemd..."
systemd-tmpfiles --clean
journalctl --vacuum-time=7d
success "Caché de systemd limpiada."


# --- 8. Verificación final ---
msg "Verificando estado del sistema..."
msg "Kernel actual: $(uname -r)"
msg "Kernel instalados:"
pacman -Q | grep -E "^linux(-cachyos|-headers)?$" || true
msg "Espacio en disco:"
df -h /

success "🎉 ¡Módulo de limpieza y optimización completado con éxito!"
msg "⚠️  Recomendación: Reinicia el sistema para aplicar todos los cambios."