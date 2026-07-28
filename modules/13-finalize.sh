#!/bin/bash
set -e

# =====================================================================
# Módulo: 13-finalize.sh
# Descripción: Limpieza del sistema, limpieza de caché y preparación
#              para reinicio con el kernel CachyOS.
# =====================================================================

# --- Importar utilidades ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/utils.sh"

# --- Validar que se ejecute como root ---
if [ "$(id -u)" -ne 0 ]; then
    error "Este módulo debe ejecutarse como root. Usa 'sudo ./13-finalize.sh'."
    exit 1
fi

# --- 2. Limpiar caché de pacman ---
msg "Limpieza de caché de pacman..."
pacman -Scc --noconfirm
success "Caché de pacman limpiada."

# --- 3. Limpiar caché de AUR (yay/paru) ---
msg "Limpieza de caché de AUR..."
TARGET_USER=$(awk -F: '$3 >= 1000 && $3 < 60000 {print $1; exit}' /etc/passwd)

# Esperar 2 segundos para asegurarnos de que no haya procesos de descarga activos
sleep 2

if command -v yay &>/dev/null; then
    runuser -u "$TARGET_USER" -- yay -Sc --noconfirm 2>/dev/null || {
        msg "Advertencia: No se pudo limpiar la caché de yay (puede haber procesos de descarga activos)."
    }
elif command -v paru &>/dev/null; then
    runuser -u "$TARGET_USER" -- paru -Sc --noconfirm 2>/dev/null || {
        msg "Advertencia: No se pudo limpiar la caché de paru (puede haber procesos de descarga activos)."
    }
else
    msg "No se encontró yay ni paru. Omitiendo limpieza de caché AUR."
fi
# --- 4. Limpiar archivos temporales ---
msg "Limpieza de archivos temporales..."
rm -rf /tmp/* /var/tmp/* 2>/dev/null || true
success "Archivos temporales limpiados."

# --- 5. Limpiar logs ---
msg "Limpieza de logs..."
find /var/log -type f \( -name "*.log" -o -name "*.gz" \) -delete 2>/dev/null || true
success "Logs limpiados."

# --- 6. Limpiar caché de systemd ---
msg "Limpieza de caché de systemd..."
systemd-tmpfiles --clean
journalctl --vacuum-time=7d
success "Caché de systemd limpiada."

# --- 6. Verificación final ---
msg "Verificando estado del sistema..."
msg "Kernel actual: $(uname -r)"
msg "Kernel CachyOS instalado:"
pacman -Q | grep "linux-cachyos-bore" || true
msg "Espacio en disco:"
df -h /

# --- 7. Instrucciones para el usuario ---
msg "⚠️  El kernel CachyOS está instalado y configurado."
msg "⚠️  Después de reiniciar, el sistema arrancará con el kernel CachyOS."
msg "⚠️  Si deseas eliminar el kernel base 'linux' después de reiniciar, ejecuta:"
msg "     sudo pacman -Rns linux linux-headers"

success "🎉 ¡Módulo de limpieza completado con éxito!"
msg "⚠️  Reinicia el sistema para aplicar todos los cambios."