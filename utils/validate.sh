#!/bin/bash
set -e

# --- Importar utilidades (para usar msg, error, success) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# --- Validar repositorios en pacman.conf ---
validar_repositorios() {
    local repos=("cachyos" "cachyos-v3" "cachyos-core-v3" "cachyos-extra-v3" "chaotic-aur" "multilib")
    local faltantes=()

    for repo in "${repos[@]}"; do
        if ! grep -q "^\[$repo\]" /etc/pacman.conf; then
            faltantes+=("$repo")
        fi
    done

    if [ ${#faltantes[@]} -gt 0 ]; then
        error "Faltan repositorios esenciales en /etc/pacman.conf: ${faltantes[*]}"
        exit 1
    fi
    success "Todos los repositorios validados correctamente."
}

# --- EJECUTAR LA VALIDACIÓN ---
validar_repositorios