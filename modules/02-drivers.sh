#!/bin/bash
set -e

# =====================================================================
# Módulo: 02-drivers.sh
# Descripción: Instala y configura controladores híbridos Intel/NVIDIA,
#              modifica cmdline, mkinitcpio.conf, y regenera initramfs.
# =====================================================================

# --- Importar utilidades ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/utils.sh"

# --- Validar que se ejecute como root ---
if [ "$(id -u)" -ne 0 ]; then
    error "Este módulo debe ejecutarse como root. Usa 'sudo ./02-drivers.sh'."
    exit 1
fi

# --- Variables ---
CMDLINE_FILE="/etc/kernel/cmdline"
MK_CONF="/etc/mkinitcpio.conf"
CHANGES_APPLIED=0

# Lista de paquetes a instalar (Intel + NVIDIA)
PACKAGES=(
    # NVIDIA Base & Wayland
    "linux-cachyos-bore-nvidia-open" "nvidia-utils" "nvidia-settings" "egl-wayland"
    # Vulkan & Mesa Nvidia
    "vulkan-icd-loader" "vulkan-tools" "mesa" "mesa-utils"
    # Hardware Acceleration Nvidia
    "libva-utils" "libva-nvidia-driver"
    # Gestión Híbrida
    "nvidia-prime" "switcheroo-control"
    # Intel iGPU Drivers
    "vulkan-intel" "intel-media-driver" "intel-ucode"
    # Soporte 32-bits (Juegos)
    "lib32-nvidia-utils" "lib32-vulkan-icd-loader" "lib32-mesa" "lib32-vulkan-intel"
)

# Parámetros obligatorios en cmdline
PARAMS=(
    "quiet" "splash" "loglevel=3" "rd.udev.log_level=3"
    "systemd.show_status=false" "vt.global_cursor_default=0"
    "nvidia_drm.modeset=1" "nvidia-drm.fbdev=1"
)

# Módulos obligatorios en mkinitcpio.conf
REQUIRED_MODULES=("i915" "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm")

# --- 2. Instalación de Paquetes ---
msg "Verificando instalación de controladores gráficos..."
MISSING_PKGS=()
for pkg in "${PACKAGES[@]}"; do
    if ! paquete_instalado "$pkg"; then
        MISSING_PKGS+=("$pkg")
    fi
done

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    msg "Instalando paquetes faltantes: ${MISSING_PKGS[*]}..."
    if pacman -Syu --needed --noconfirm "${MISSING_PKGS[@]}"; then
        CHANGES_APPLIED=1
        success "Controladores instalados con éxito."
    else
        error "Error al instalar controladores gráficos."
        exit 1
    fi
else
    msg "Todos los controladores ya están instalados."
fi

# --- 3. Configuración de Servicios ---
msg "Configurando servicios de sistema..."
# Switcheroo-control para hibridación de GPU
if ! systemctl is-enabled switcheroo-control.service &>/dev/null; then
    systemctl enable switcheroo-control.service
    systemctl start switcheroo-control.service || true
    CHANGES_APPLIED=1
fi

# Nvidia-powerd (Solo laptops dinámicas, puede fallar en VM QEMU de forma segura)
if ! systemctl is-enabled nvidia-powerd.service &>/dev/null; then
    systemctl enable nvidia-powerd.service
    systemctl start nvidia-powerd.service &>/dev/null || true
    CHANGES_APPLIED=1
fi

# --- 4. Configuración de /etc/kernel/cmdline ---
msg "Verificando parámetros del Kernel en $CMDLINE_FILE..."
if [ ! -f "$CMDLINE_FILE" ]; then
    touch "$CMDLINE_FILE"
fi

CURRENT_CMDLINE=$(cat "$CMDLINE_FILE")
MISSING_PARAMS=()
for param in "${PARAMS[@]}"; do
    if ! echo "$CURRENT_CMDLINE" | grep -q -w "$param"; then
        MISSING_PARAMS+=("$param")
    fi
done

if [ ${#MISSING_PARAMS[@]} -gt 0 ]; then
    msg "Añadiendo parámetros faltantes al cmdline: ${MISSING_PARAMS[*]}..."
    CLEANED_CMDLINE=$(echo "$CURRENT_CMDLINE" | xargs)
    echo "$CLEANED_CMDLINE ${MISSING_PARAMS[*]}" | xargs > "$CMDLINE_FILE"
    CHANGES_APPLIED=1
    success "cmdline actualizado."
else
    msg "Los parámetros del kernel ya están configurados."
fi

# --- 5. Configuración de MODULES en mkinitcpio.conf ---
msg "Verificando módulos KMS en $MK_CONF..."
if [ -f "$MK_CONF" ]; then
    MODULES_LINE=$(grep -E "^MODULES=\(" "$MK_CONF")
    MISSING_MODS=()
    for mod in "${REQUIRED_MODULES[@]}"; do
        if ! echo "$MODULES_LINE" | grep -q -w "$mod"; then
            MISSING_MODS+=("$mod")
        fi
    done

    if [ ${#MISSING_MODS[@]} -gt 0 ]; then
        msg "Añadiendo módulos faltantes a mkinitcpio: ${MISSING_MODS[*]}..."
        for mod in "${MISSING_MODS[@]}"; do
            # Inserta el módulo de forma segura dentro del paréntesis de MODULES=(...)
            sed -i "s/^MODULES=(\([^)]*\))/MODULES=(\1 $mod)/" "$MK_CONF"
        done
        # Limpieza estética de espacios dobles e internos
        sed -i -E '/^MODULES=/s/ +/ /g' "$MK_CONF"
        sed -i -E 's/MODULES=\( /MODULES=\(/' "$MK_CONF"
        sed -i -E 's/ \)/\)/' "$MK_CONF"
        CHANGES_APPLIED=1
        success "Módulos de mkinitcpio actualizados."
    else
        msg "Los módulos KMS ya están correctamente configurados."
    fi
else
    error "No se encontró el archivo $MK_CONF."
    exit 1
fi

# --- 6. Regeneración y Sincronización (Solo si hubo cambios reales) ---
if [ $CHANGES_APPLIED -eq 1 ]; then
    msg "Se detectaron cambios en la configuración. Regenerando imágenes de arranque..."
    
    msg "Ejecutando mkinitcpio -P..."
    if ! mkinitcpio -P; then
        error "Falló la regeneración del initramfs."
        exit 1
    fi

    msg "Sincronizando kernels con kernel-install..."
    # Registra el kernel activo actual
    RUNNING_K=$(uname -r)
    if [ -d "/usr/lib/modules/$RUNNING_K" ]; then
        kernel-install add "$RUNNING_K" "/usr/lib/modules/$RUNNING_K/vmlinuz"
    fi

    # Registra todos los kernels cachyos-bore instalados
    for k in /usr/lib/modules/*cachyos*bore*; do
        if [ -d "$k" ]; then
            k_ver="${k##*/}"
            msg "Sincronizando kernel: $k_ver"
            kernel-install add "$k_ver" "/usr/lib/modules/$k_ver/vmlinuz"
        fi
    done
    success "Imágenes de arranque regeneradas y sincronizadas."
else
    success "No se detectaron cambios pendientes. ¡Módulo de Video Drivers omitido!"
fi

success "🎉 ¡Módulo de Video Drivers completado con éxito!"