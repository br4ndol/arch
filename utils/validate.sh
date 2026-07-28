#!/bin/bash
set -e

# --- Importar utilidades ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# --- Función auxiliar para ejecutar rate-mirrors sin root ---
run_rate_mirrors() {
    local target="$1"
    local user="${SUDO_USER}"

    # Si no se detecta SUDO_USER o es root, busca el primer usuario normal o usa 'nobody'
    if [ -z "$user" ] || [ "$user" = "root" ]; then
        user=$(awk -F: '$3 >= 1000 && $3 < 60000 {print $1; exit}' /etc/passwd)
        user="${user:-nobody}"
    fi

    runuser -u "$user" -- rate-mirrors --protocol=https --disable-comments "$target"
}

# --- 1. Validar repositorios en pacman.conf ---
validar_repositorios() {
    local repos=("cachyos" "cachyos-v3" "cachyos-core-v3" "cachyos-extra-v3" "chaotic-aur" "multilib")
    local faltantes=()

    for repo in "${repos[@]}"; do
        # Soporta espacios iniciales pero ignora si está comentado con #
        if ! grep -q "^[[:space:]]*\[$repo\]" /etc/pacman.conf; then
            faltantes+=("$repo")
        fi
    done

    if [ ${#faltantes[@]} -gt 0 ]; then
        error "Faltan repositorios esenciales en /etc/pacman.conf: ${faltantes[*]}"
        exit 1
    fi
    success "Todos los repositorios validados correctamente."
}

# --- 2. Actualizar mirrors con rate-mirrors ---
actualizar_mirrors() {
    msg "Verificando dependencia 'rate-mirrors'..."
    if ! command -v rate-mirrors &>/dev/null; then
        msg "Instalando 'rate-mirrors'..."
        pacman -S --needed --noconfirm rate-mirrors
    fi

    local ts
    ts=$(date +%F-%H%M%S)
    local mirror_files=(
        /etc/pacman.d/mirrorlist
        /etc/pacman.d/cachyos-mirrorlist
        /etc/pacman.d/cachyos-v3-mirrorlist
        /etc/pacman.d/chaotic-mirrorlist
    )

    msg "Respaldando listas de mirrors actuales..."
    for f in "${mirror_files[@]}"; do
        if [ -f "$f" ]; then
            cp -a "$f" "$f.bak-$ts"
        fi
    done

    msg "Buscando los mejores mirrors para Arch Linux..."
    if ! run_rate_mirrors arch > /etc/pacman.d/mirrorlist; then
        error "Falló la actualización de mirrors para Arch Linux."
        exit 1
    fi
    head -n 5 /etc/pacman.d/mirrorlist

    msg "Buscando los mejores mirrors para CachyOS..."
    if ! run_rate_mirrors cachyos > /etc/pacman.d/cachyos-mirrorlist; then
        error "Falló la actualización de mirrors para CachyOS."
        exit 1
    fi
    head -n 5 /etc/pacman.d/cachyos-mirrorlist

    msg "Generando mirrors para CachyOS-v3..."
    cp -f /etc/pacman.d/cachyos-mirrorlist /etc/pacman.d/cachyos-v3-mirrorlist
    sed -i 's|/$arch/|/$arch_v3/|g' /etc/pacman.d/cachyos-v3-mirrorlist
    head -n 5 /etc/pacman.d/cachyos-v3-mirrorlist

    msg "Buscando los mejores mirrors para Chaotic-AUR..."
    if ! run_rate_mirrors chaotic-aur > /etc/pacman.d/chaotic-mirrorlist; then
        error "Falló la actualización de mirrors para Chaotic-AUR."
        exit 1
    fi
    head -n 5 /etc/pacman.d/chaotic-mirrorlist

    msg "Refrescando bases de datos de pacman (pacman -Syy)..."
    pacman -Syy
    success "¡Mirrors actualizados y bases de datos sincronizadas con éxito!"
}

# --- EJECUCIÓN ---
validar_repositorios
#actualizar_mirrors