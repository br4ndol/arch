#!/bin/bash
set -e

# =====================================================================
# Módulo: 04-auth.sh
# Descripción: Configura asteriscos visuales en sudo (pwfeedback)
#              y ajusta las políticas de bloqueo en faillock.conf.
# =====================================================================

# --- Importar utilidades ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/utils.sh"

# --- Validar que se ejecute como root ---
if [ "$(id -u)" -ne 0 ]; then
    error "Este módulo debe ejecutarse como root. Usa 'sudo ./04-auth.sh'."
    exit 1
fi

# --- Variables ---
SUDO_PW_FILE="/etc/sudoers.d/pwfeedback"
FAILLOCK_CONF="/etc/security/faillock.conf"

# --- 1. Verificación de Estado Real ---
msg "Verificando estado de configuración de seguridad..."

sudo_ok=0
faillock_ok=0

# Verificar si el archivo de feedback de sudo existe, tiene permisos 0440 y contenido correcto
if [ -f "$SUDO_PW_FILE" ] && [ "$(stat -c "%a" "$SUDO_PW_FILE")" = "440" ] && grep -q "^Defaults[[:space:]]*pwfeedback" "$SUDO_PW_FILE"; then
    sudo_ok=1
fi

# Verificar si deny=10 y unlock_time=300 están activos (sin comentar) en faillock.conf
if [ -f "$FAILLOCK_CONF" ] && \
   grep -E "^[[:space:]]*deny[[:space:]]*=[[:space:]]*10" "$FAILLOCK_CONF" &>/dev/null && \
   grep -E "^[[:space:]]*unlock_time[[:space:]]*=[[:space:]]*300" "$FAILLOCK_CONF" &>/dev/null; then
    faillock_ok=1
fi

# Si todo coincide con lo deseado, omitir el script de forma segura
if [ $sudo_ok -eq 1 ] && [ $faillock_ok -eq 1 ]; then
    success "Configuración de Sudo y Faillock ya aplicadas. ¡Módulo omitido!"
    exit 0
fi

# --- 2. Configurar retroalimentación visual de Sudo (pwfeedback) ---
if [ $sudo_ok -eq 0 ]; then
    msg "Configurando asteriscos visuales para sudo..."
    
    # Crear el archivo drop-in de sudoers de manera segura
    echo "Defaults pwfeedback" > "$SUDO_PW_FILE"
    
    # Sudo exige estrictamente que los archivos en sudoers.d tengan permisos 0440 (solo lectura root)
    chmod 0440 "$SUDO_PW_FILE"
    
    # Validar que la sintaxis de sudoers sea correcta usando visudo
    if visudo -cf "$SUDO_PW_FILE" &>/dev/null; then
        success "Retroalimentación visual de sudo aplicada correctamente."
    else
        error "Error en la sintaxis del archivo de sudo generado. Revirtiendo..."
        rm -f "$SUDO_PW_FILE"
        exit 1
    fi
else
    msg "La retroalimentación visual de sudo ya estaba configurada."
fi

# --- 3. Configurar faillock.conf (Límites de contraseña fallida) ---
if [ $faillock_ok -eq 0 ]; then
    msg "Configurando políticas de bloqueo de cuenta en $FAILLOCK_CONF..."
    
    if [ -f "$FAILLOCK_CONF" ]; then
        # Configurar 'deny = 10' (Uncomment o editar)
        if grep -E "^#?[[:space:]]*deny[[:space:]]*=" "$FAILLOCK_CONF" &>/dev/null; then
            sed -i -E 's/^#?[[:space:]]*deny[[:space:]]*=.*/deny = 10/' "$FAILLOCK_CONF"
        else
            echo "deny = 10" >> "$FAILLOCK_CONF"
        fi

        # Configurar 'unlock_time = 300' (Uncomment o editar)
        if grep -E "^#?[[:space:]]*unlock_time[[:space:]]*=" "$FAILLOCK_CONF" &>/dev/null; then
            sed -i -E 's/^#?[[:space:]]*unlock_time[[:space:]]*=.*/unlock_time = 300/' "$FAILLOCK_CONF"
        else
            echo "unlock_time = 300" >> "$FAILLOCK_CONF"
        fi

        success "Políticas de Faillock actualizadas correctamente (deny = 10, unlock_time = 300)."
    else
        error "No se encontró el archivo $FAILLOCK_CONF."
        exit 1
    fi
else
    msg "Las políticas de Faillock ya estaban configuradas."
fi

success "🎉 ¡Módulo de Autenticación completado con éxito!"