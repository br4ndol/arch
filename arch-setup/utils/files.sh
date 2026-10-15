#!/usr/bin/env bash
# files.sh — Edición idempotente de archivos de configuración.
#
# Patrón común: cada función genera el contenido deseado en un temporal y lo
# compara (sha256) con el actual. Si es igual no toca nada; si cambia, hace backup
# (una vez por ejecución) y lo escribe. Con DRY_RUN=1 muestra el diff.
#
# Tras cada llamada, FILE_CHANGED vale 1 si el archivo cambió y 0 si no, para
# poder reaccionar (p. ej. regenerar el UKI solo si cambió mkinitcpio.conf).

[[ -n ${_UTILS_FILES_LOADED:-} ]] && return 0
_UTILS_FILES_LOADED=1

FILE_CHANGED=0

# same_content A B — Mismo contenido byte a byte. Usa sha256sum (coreutils)
# porque cmp/diff (diffutils) no vienen en el paquete base.
same_content() {
  [[ -f $1 && -f $2 ]] || return 1
  [[ $(sha256sum <"$1") == "$(sha256sum <"$2")" ]]
}

# backup_file ARCHIVO — Copia ARCHIVO a ARCHIVO.bak-<RUN_TS>. Solo la primera
# vez en cada ejecución, así el backup guarda el estado original.
backup_file() {
  local file=$1 bak="$1.bak-$RUN_TS"
  [[ -e $file && ! -e $bak ]] || return 0
  run cp -a -- "$file" "$bak"
  log_debug "Backup: $bak"
}

# _apply_candidate ARCHIVO CANDIDATO [MODO] — Reemplaza ARCHIVO por CANDIDATO
# si son distintos. Conserva propietario y permisos si ARCHIVO ya existía.
_apply_candidate() {
  local file=$1 candidate=$2 mode=${3:-644}
  FILE_CHANGED=0
  if same_content "$candidate" "$file"; then
    log_debug "Sin cambios: $file"
    return 0
  fi
  FILE_CHANGED=1
  if ((DRY_RUN)); then
    log_dry "Modificaría $file"
    if [[ -f $file ]] && ! cmd_exists diff; then
      log_dry "(instala diffutils para ver el diff)"
    elif [[ -f $file ]]; then
      diff -u --label "$file" --label "$file (nuevo)" -- "$file" "$candidate" | sed 's/^/      /' >&2 || true
    else
      sed 's/^/      + /' -- "$candidate" >&2
    fi
    return 0
  fi
  if [[ -f $file ]]; then
    backup_file "$file"
    cat -- "$candidate" >"$file"
  else
    mkdir -p -- "$(dirname -- "$file")"
    install -m "$mode" -- "$candidate" "$file"
  fi
  log_ok "Actualizado: $file"
}

_candidate() { mktemp -p "$RUN_TMPDIR" candidate.XXXXXX; }

# _ends_without_newline ARCHIVO
_ends_without_newline() { [[ -s $1 && -n $(tail -c 1 -- "$1") ]]; }

# ensure_line ARCHIVO LINEA — Garantiza que LINEA exista tal cual (línea completa).
# Crea el archivo si no existe.
ensure_line() {
  local file=$1 line=$2 cand
  FILE_CHANGED=0
  if [[ -f $file ]] && grep -qxF -- "$line" "$file"; then
    log_debug "Ya presente en $file: $line"
    return 0
  fi
  cand=$(_candidate)
  if [[ -f $file ]]; then
    cat -- "$file" >"$cand"
    _ends_without_newline "$file" && printf '\n' >>"$cand"
  fi
  printf '%s\n' "$line" >>"$cand"
  _apply_candidate "$file" "$cand"
}

# set_kv ARCHIVO CLAVE VALOR [SEPARADOR] — Fija CLAVE<SEP>VALOR.
#   - Si la clave está activa, reemplaza su valor.
#   - Si no, descomenta la primera línea comentada con esa clave.
#   - Si no existe, la añade al final.
# SEPARADOR por defecto " = ". Ejemplos:
#   set_kv /etc/security/faillock.conf deny 10            -> deny = 10
#   set_kv /etc/mkinitcpio.conf MODULES '(i915 nvidia)' = -> MODULES=(i915 nvidia)
#   set_kv /etc/ssh/sshd_config PermitRootLogin no ' '    -> PermitRootLogin no
set_kv() {
  local file=$1 key=$2 value=$3 sep=${4:- = } sep_trim cand
  sep_trim=${sep//[[:space:]]/}
  cand=$(_candidate)
  if [[ ! -s $file ]]; then
    printf '%s\n' "$key$sep$value" >"$cand"
    _apply_candidate "$file" "$cand"
    return
  fi
  # Dos pasadas sobre el archivo: la primera detecta si la clave está activa.
  _K=$key _S=$sep_trim _L="$key$sep$value" awk '
    BEGIN { k = ENVIRON["_K"]; s = ENVIRON["_S"]; nl = ENVIRON["_L"] }
    function matches(line, commented,   t) {
      t = line
      sub(/^[ \t]+/, "", t)
      if (commented) {
        if (substr(t, 1, 1) != "#") return 0
        sub(/^#+[ \t]*/, "", t)
      } else if (substr(t, 1, 1) == "#") return 0
      if (substr(t, 1, length(k)) != k) return 0
      t = substr(t, length(k) + 1)
      if (s == "") return (t ~ /^[ \t]/)
      sub(/^[ \t]+/, "", t)
      return substr(t, 1, length(s)) == s
    }
    NR == FNR { if (matches($0, 0)) active = 1; next }
    {
      if (active && matches($0, 0)) { print nl; next }
      if (!active && !done && matches($0, 1)) { print nl; done = 1; next }
      print
    }
    END { if (!active && !done) print nl }
  ' "$file" "$file" >"$cand"
  _apply_candidate "$file" "$cand"
}

# ensure_uncommented ARCHIVO LINEA — Garantiza que LINEA esté activa: si existe
# comentada ("#LINEA" o "# LINEA") la descomenta; si no existe, la añade.
# Ej.: ensure_uncommented /etc/pacman.conf Color
ensure_uncommented() {
  local file=$1 line=$2 cand
  FILE_CHANGED=0
  if [[ -f $file ]] && grep -qxF -- "$line" "$file"; then
    log_debug "Ya activa en $file: $line"
    return 0
  fi
  cand=$(_candidate)
  if [[ -f $file ]]; then
    _L=$line awk '
      BEGIN { l = ENVIRON["_L"] }
      !done { t = $0; sub(/^[ \t]*#+[ \t]*/, "", t); sub(/[ \t]+$/, "", t)
              if (t == l && $0 ~ /^[ \t]*#/) { print l; done = 1; next } }
      { print }
      END { if (!done) print l }
    ' "$file" >"$cand"
  else
    printf '%s\n' "$line" >"$cand"
  fi
  _apply_candidate "$file" "$cand"
}

# comment_line ARCHIVO LINEA — Comenta LINEA si está activa (operación inversa).
comment_line() {
  local file=$1 line=$2 cand
  FILE_CHANGED=0
  [[ -f $file ]] || return 0
  cand=$(_candidate)
  _L=$line awk '
    BEGIN { l = ENVIRON["_L"] }
    { t = $0; sub(/[ \t]+$/, "", t); if (t == l) print "#" $0; else print }
  ' "$file" >"$cand"
  _apply_candidate "$file" "$cand"
}

# ensure_ini_section ARCHIVO SECCION [--before OTRA] LINEA... — Garantiza una
# sección estilo INI (como los repos de pacman.conf):
#   - Si "[SECCION]" ya está activa, no hace nada.
#   - Si está comentada ("#[SECCION]"), la descomenta junto con sus líneas
#     "#clave = valor" inmediatamente siguientes (caso de [multilib]).
#   - Si no existe, añade el bloque al final, o justo antes de "[OTRA]".
# Ej.: ensure_ini_section /etc/pacman.conf multilib 'Include = /etc/pacman.d/mirrorlist'
#      ensure_ini_section /etc/pacman.conf cachyos-v3 --before core \
#        'Include = /etc/pacman.d/cachyos-v3-mirrorlist'
ensure_ini_section() {
  local file=$1 section=$2 before='' cand body src=$1
  shift 2
  if [[ ${1:-} == --before ]]; then
    before=$2
    shift 2
  fi
  FILE_CHANGED=0
  if [[ -f $file ]] && grep -qxF -- "[$section]" "$file"; then
    log_debug "Sección [$section] ya activa en $file"
    return 0
  fi
  printf -v body '%s\n' "[$section]" "$@"
  cand=$(_candidate)
  [[ -f $file ]] || src=/dev/null
  _SEC="[$section]" _BEFORE="${before:+[$before]}" _BODY=$body awk '
    BEGIN { sec = ENVIRON["_SEC"]; bef = ENVIRON["_BEFORE"]; body = ENVIRON["_BODY"] }
    function trim(x) { sub(/^[ \t]+/, "", x); sub(/[ \t]+$/, "", x); return x }
    {
      t = trim($0)
      if (uncommenting) {
        if (t ~ /^#+[ \t]*[A-Za-z][A-Za-z0-9_]*[ \t]*=/) { sub(/^[ \t]*#+[ \t]*/, ""); print; next }
        uncommenting = 0
      }
      if (!done) {
        c = t; sub(/^#+[ \t]*/, "", c)
        if (t ~ /^#/ && c == sec) { print sec; done = 1; uncommenting = 1; next }
      }
      if (!done && !inserted && bef != "" && t == bef) { printf "%s\n", body; inserted = 1 }
      print
    }
    END { if (!done && !inserted) { if (NR > 0) print ""; printf "%s", body } }
  ' "$src" >"$cand"
  _apply_candidate "$file" "$cand"
}

# install_file ORIGEN DESTINO [MODO] — Copia ORIGEN a DESTINO solo si el
# contenido o el modo difieren. MODO por defecto 644.
install_file() {
  local src=$1 dst=$2 mode=${3:-644}
  [[ -f $src ]] || die "install_file: no existe $src"
  FILE_CHANGED=0
  if same_content "$src" "$dst"; then
    if [[ $(stat -c %a -- "$dst") != "${mode#0}" ]]; then
      run chmod "$mode" -- "$dst"
      FILE_CHANGED=1
    else
      log_debug "Sin cambios: $dst"
    fi
    return 0
  fi
  _apply_candidate "$dst" "$src" "$mode"
  if ((FILE_CHANGED)) && ! ((DRY_RUN)) && [[ $(stat -c %a -- "$dst") != "${mode#0}" ]]; then
    chmod "$mode" -- "$dst"
  fi
}

# write_file DESTINO [MODO] <<'EOF' ... EOF — Escribe el contenido de stdin en
# DESTINO solo si cambió. Pensado para heredocs dentro de los módulos.
write_file() {
  local dst=$1 mode=${2:-644} cand
  cand=$(_candidate)
  cat >"$cand"
  install_file "$cand" "$dst" "$mode"
}

# render_template PLANTILLA DESTINO [MODO] — Sustituye {{VARIABLE}} por el valor
# de la variable (normalmente de settings.conf) y lo instala con install_file.
# Con DESTINO "-" lo imprime por stdout (para procesarlo antes de instalarlo).
# Falla si alguna variable no está definida.
render_template() {
  local src=$1 dst=$2 mode=${3:-644} content var cand
  local -A seen=()
  [[ -f $src ]] || die "render_template: no existe $src"
  content=$(<"$src")
  while [[ $content =~ \{\{([A-Za-z_][A-Za-z0-9_]*)\}\} ]]; do
    var=${BASH_REMATCH[1]}
    [[ -z ${seen[$var]:-} ]] || die "render_template: el valor de $var contiene {{$var}}"
    seen[$var]=1
    [[ -v $var ]] || die "render_template: variable no definida '$var' en $src"
    content=${content//"{{$var}}"/"${!var}"}
  done
  if [[ $dst == - ]]; then
    printf '%s\n' "$content"
    return 0
  fi
  cand=$(_candidate)
  printf '%s\n' "$content" >"$cand"
  install_file "$cand" "$dst" "$mode"
}
