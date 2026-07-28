#!/bin/bash
set -e

# =====================================================================
# Módulo: 08-zram.sh
# Descripción: Instala zram-generator, configura zram0 (4096MB, lz4, prio 100),
#              optimiza sysctl (swappiness=100, page-cluster=0) y reinicia el servicio.
# =====================================================================

# --- Importar utilidades ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/utils.sh"

# --- Validar que se ejecute como root ---
if [ "$(id -u)" -ne 0 ]; then
    error "Este módulo debe ejecutarse como root. Usa 'sudo ./08-zram.sh'."
    exit 1
fi

# --- Variables ---
PKG="zram-generator"
ZRAM_CONF="/etc/systemd/zram-generator.conf"
SYSCTL_CONF="/etc/sysctl.d/99-zram.conf"
CHANGES_APPLIED=0

# --- 1. Verificación de Estado Real ---
msg "Verificando estado de ZRAM..."

pkg_ok=0
zram_conf_ok=0
sysctl_conf_ok=0
zram_activo=0

if paquete_instalado "$PKG"; then
    pkg_ok=1
fi

if [ -f "$ZRAM_CONF" ] && \
   grep -q "zram-size = 4096" "$ZRAM_CONF" && \
   grep -q "compression-algorithm = lz4" "$ZRAM_CONF" && \
   grep -q "swap-priority = 100" "$ZRAM_CONF"; then
    zram_conf_ok=1
fi

if [ -f "$SYSCTL_CONF" ] && \
   grep -q "vm.swappiness=100" "$SYSCTL_CONF" && \
   grep -q "vm.page-cluster=0" "$SYSCTL_CONF"; then
    sysctl_conf_ok=1
fi

if swapon --show=NAME 2>/dev/null | grep -q "/dev/zram0"; then
    zram_activo=1
fi

# Omitir si todo ya está instalado, configurado y activo
if [ $pkg_ok -eq 1 ] && [ $zram_conf_ok -eq 1 ] && [ $sysctl_conf_ok -eq 1 ] && [ $zram_activo -eq 1 ]; then
    success "ZRAM ya está instalado, configurado y activo. ¡Módulo omitido!"
    exit 0
fi

# --- 2. Instalación del Paquete ---
if [ $pkg_ok -eq 0 ]; then
    msg "Instalando $PKG..."
    instalar_paquete "$PKG"
    CHANGES_APPLIED=1
else
    msg "El paquete $PKG ya está instalado."
fi

# --- 3. Configurar /etc/systemd/zram-generator.conf ---
if [ $zram_conf_ok -eq 0 ]; then
    msg "Configurando $ZRAM_CONF..."
    cat > "$ZRAM_CONF" <<'EOF'
[zram0]
zram-size = 4096
compression-algorithm = lz4
swap-priority = 100
EOF
    CHANGES_APPLIED=1
    success "Archivo $ZRAM_CONF creado/actualizado correctamente."
else
    msg "El archivo $ZRAM_CONF ya estaba configurado."
fi

# --- 4. Configurar /etc/sysctl.d/99-zram.conf ---
if [ $sysctl_conf_ok -eq 0 ]; then
    msg "Configurando $SYSCTL_CONF..."
    cat > "$SYSCTL_CONF" <<'EOF'
vm.swappiness=100
vm.page-cluster=0
EOF
    CHANGES_APPLIED=1
    success "Archivo $SYSCTL_CONF creado/actualizado correctamente."
else
    msg "El archivo $SYSCTL_CONF ya estaba configurado."
fi

# --- 5. Reiniciar Servicio y Cargar Sysctl ---
if [ $CHANGES_APPLIED -eq 1 ] || [ $zram_activo -eq 0 ]; then
    msg "Aplicando cambios en ZRAM y recargando daemon de systemd..."
    swapoff /dev/zram0 2>/dev/null || true
    systemctl stop systemd-zram-setup@zram0.service 2>/dev/null || true
    systemctl daemon-reload
    systemctl start systemd-zram-setup@zram0.service

    msg "Cargando parámetros sysctl para ZRAM..."
    sysctl -p "$SYSCTL_CONF" >/dev/null
fi

# --- 6. Verificaciones Finales ---
msg "Verificando estado actual de ZRAM:"
swapon --show=NAME,TYPE,SIZE,USED,PRIO || true

if [ -f /sys/block/zram0/comp_algorithm ]; then
    msg "Algoritmo de compresión activo en zram0:"
    cat /sys/block/zram0/comp_algorithm
fi

msg "Valores activos de sysctl:"
msg "vm.swappiness = $(cat /proc/sys/vm/swappiness)"
msg "vm.page-cluster = $(cat /proc/sys/vm/page-cluster)"

if grep -i "swap" /etc/fstab | grep -v "^#" &>/dev/null; then
    msg "Líneas de swap detectadas en /etc/fstab:"
    grep -i "swap" /etc/fstab | grep -v "^#" || true
fi

success "🎉 ¡Módulo de ZRAM completado con éxito!"