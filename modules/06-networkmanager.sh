#!/bin/bash
set -e

# =====================================================================
# Módulo: 06-networkmanager.sh
# Descripción: Instala NetworkManager e iwd, configura iwd como el backend
#              de WiFi, deshabilita servicios en conflicto y habilita NM.
# =====================================================================

# --- Importar utilidades ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/utils.sh"

# --- Validar que se ejecute como root ---
if [ "$(id -u)" -ne 0 ]; then
    error "Este módulo debe ejecutarse como root. Usa 'sudo ./06-networkmanager.sh'."
    exit 1
fi

# --- Variables ---
PACKAGES=("networkmanager" "iwd")
CONF_DIR="/etc/NetworkManager/conf.d"
CONF_FILE="${CONF_DIR}/wifi_backend.conf"
CHANGES_APPLIED=0

# --- 1. Verificación de Estado Real ---
msg "Verificando estado de NetworkManager e iwd..."

pkgs_instalados=1
for pkg in "${PACKAGES[@]}"; do
    if ! paquete_instalado "$pkg"; then
        pkgs_instalados=0
        break
    fi
done

conf_ok=0
if [ -f "$CONF_FILE" ] && grep -q "wifi.backend=iwd" "$CONF_FILE"; then
    conf_ok=1
fi

nm_activo=0
if systemctl is-enabled NetworkManager.service &>/dev/null && systemctl is-active NetworkManager.service &>/dev/null; then
    nm_activo=1
fi

# Omitir si todo ya está instalado, configurado y activo
if [ $pkgs_instalados -eq 1 ] && [ $conf_ok -eq 1 ] && [ $nm_activo -eq 1 ]; then
    success "NetworkManager con backend iwd ya está configurado y activo. ¡Módulo omitido!"
    exit 0
fi

# --- 2. Instalación de Paquetes ---
msg "Verificando e instalando paquetes..."
MISSING_PKGS=()
for pkg in "${PACKAGES[@]}"; do
    if ! paquete_instalado "$pkg"; then
        MISSING_PKGS+=("$pkg")
    fi
done

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    instalar_paquete "${MISSING_PKGS[@]}"
    CHANGES_APPLIED=1
else
    msg "Paquetes networkmanager e iwd ya están instalados."
fi

# --- 3. Configuración del Backend iwd ---
if [ $conf_ok -eq 0 ]; then
    msg "Configurando iwd como backend WiFi para NetworkManager..."
    mkdir -p "$CONF_DIR"
    cat > "$CONF_FILE" <<EOF
[device]
wifi.backend=iwd
EOF
    CHANGES_APPLIED=1
    success "Archivo $CONF_FILE creado/actualizado correctamente."
else
    msg "El backend iwd ya está configurado en $CONF_FILE."
fi

# --- 4. Deshabilitar Servicios en Conflicto ---
msg "Deshabilitando servicios de red secundarios/en conflicto..."
COMPETING_SERVICES=("iwd.service" "systemd-networkd.service" "dhcpcd.service" "wpa_supplicant.service")

for srv in "${COMPETING_SERVICES[@]}"; do
    if systemctl is-enabled "$srv" &>/dev/null || systemctl is-active "$srv" &>/dev/null; then
        msg "Deshabilitando $srv..."
        systemctl disable --now "$srv" 2>/dev/null || true
        CHANGES_APPLIED=1
    fi
done

# --- 5. Habilitar y Reiniciar NetworkManager ---
msg "Asegurando servicio NetworkManager..."
if ! systemctl is-enabled NetworkManager.service &>/dev/null; then
    systemctl enable NetworkManager.service
    CHANGES_APPLIED=1
fi

if [ $CHANGES_APPLIED -eq 1 ] || [ $nm_activo -eq 0 ]; then
    msg "Reiniciando/Iniciando NetworkManager.service..."
    systemctl restart NetworkManager.service
fi

# --- 6. Encender Radio WiFi (Si existe hardware WiFi) ---
msg "Verificando dispositivos y radio WiFi..."
if command -v nmcli &>/dev/null; then
    nmcli radio wifi on 2>/dev/null || true
    msg "Estado de dispositivos de red:"
    nmcli device || true
fi

success "🎉 ¡Módulo de NetworkManager completado con éxito!"