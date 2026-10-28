#!/usr/bin/env bash
# lib/components.sh - External components declared in components.conf.
#
# components.conf is parsed, never sourced. Each entry line is
#   name url ref [src=dst ...]
# where ref is the full pinned commit SHA, src a path inside the component
# checkout and dst a path inside the target home. `dotfiles add <name>` clones
# the component into ~/.local/share/dotfiles/<name>, checks out the pinned ref
# detached and links every dst to its src; the components receipt records it,
# so sync and update keep it at the pinned ref, doctor audits it and unlink
# removes its links. Reads TARGET_DIR and REPO_ROOT. Requires lib/colors.sh,
# lib/core.sh and lib/receipts.sh.
#
# shellcheck shell=bash

COMPONENTS_FILE=${DOTFILES_COMPONENTS_FILE:-$REPO_ROOT/components.conf}
COMPONENT_NAME_PATTERN='^[a-z0-9][a-z0-9-]*$'
COMPONENTS_LOADED=0
declare -a COMPONENT_NAMES=()
declare -A COMPONENT_URLS=() COMPONENT_REFS=() COMPONENT_LINKS=()

# True when $1 is a relative path without empty, '.' or '..' segments.
component_path_valid() {
  local path=$1 segment
  local -a segments=()

  [[ -n "$path" && "$path" != /* && "$path" != */ ]] || return 1
  IFS=/ read -r -a segments <<< "$path"
  for segment in "${segments[@]}"; do
    [[ -n "$segment" && "$segment" != . && "$segment" != .. ]] || return 1
  done
}

# Parses components.conf once; any invalid entry stops the command.
load_components() {
  local raw line where name url ref link src dst lineno=0
  local -a fields=()
  local -A declared_by=()

  (( COMPONENTS_LOADED == 0 )) || return 0
  COMPONENTS_LOADED=1
  [[ -f "$COMPONENTS_FILE" ]] || return 0

  while IFS= read -r raw || [[ -n "$raw" ]]; do
    lineno=$(( lineno + 1 ))
    line=$(trim_line "$raw")
    [[ -n "$line" && "$line" != \#* ]] || continue
    where="$COMPONENTS_FILE:$lineno"
    read -r -a fields <<< "$line"
    (( ${#fields[@]} >= 3 )) || die "$where: entrada incompleta, se espera: nombre url ref [src=dst ...]"
    name=${fields[0]} url=${fields[1]} ref=${fields[2]}
    [[ "$name" =~ $COMPONENT_NAME_PATTERN ]] || die "$where: nombre de componente inválido: $name"
    [[ -z "${COMPONENT_URLS[$name]:-}" ]] || die "$where: componente duplicado: $name"
    [[ "$url" != -* ]] || die "$where: url inválida para $name: $url"
    [[ "$ref" =~ ^[0-9a-f]{40}$ ]] || \
      die "$where: ref fijada inválida para $name (se espera el SHA completo de 40 caracteres hexadecimales): $ref"
    for link in "${fields[@]:3}"; do
      [[ "$link" == *=* ]] || die "$where: enlace inválido en $name (se espera src=dst): $link"
      src=${link%%=*} dst=${link#*=}
      if ! component_path_valid "$src" || ! component_path_valid "$dst"; then
        die "$where: ruta inválida en $name (relativa, sin '.' ni '..'): $link"
      fi
      [[ -z "${declared_by[$dst]:-}" ]] || die "$where: el destino $dst ya lo declara ${declared_by[$dst]}"
      declared_by["$dst"]=$name
    done
    COMPONENT_NAMES+=("$name")
    COMPONENT_URLS["$name"]=$url
    COMPONENT_REFS["$name"]=$ref
    COMPONENT_LINKS["$name"]="${fields[*]:3}"
  done < "$COMPONENTS_FILE"
}

component_dir() {
  printf '%s/.local/share/dotfiles/%s' "$TARGET_DIR" "$1"
}

# Fills the array named $1 with the recorded components still declared in
# components.conf; components.conf is only read when a receipt exists.
recorded_components() {
  local -n recorded_components_ref=$1
  local -A saved=()
  local -a entries=()
  local entry

  recorded_components_ref=()
  read_receipt components saved || return 0
  load_components
  read -r -a entries <<< "${saved[COMPONENTS]:-}"
  for entry in "${entries[@]}"; do
    if [[ "$entry" =~ $COMPONENT_NAME_PATTERN && -n "${COMPONENT_URLS[$entry]:-}" ]]; then
      array_contains "$1" "$entry" || recorded_components_ref+=("$entry")
    else
      warn "se ignora un componente registrado que no está en components.conf: $entry"
    fi
  done
}

# Returns 1 when the checkout of $1 does not exist yet; stops when it exists
# but is not a clean clone of the declared URL.
component_checkout_ready() {
  local name=$1 dir toplevel origin changes

  dir=$(component_dir "$name")
  [[ -e "$dir" || -L "$dir" ]] || return 1
  # Git prints the physical toplevel; TARGET_DIR or one of its parents (such
  # as ~/.local/share) may be a symlink, so both sides are compared canonical.
  toplevel=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || true)
  if [[ -L "$dir" || ! -d "$dir" || -z "$toplevel" || \
        "$(realpath -e -- "$toplevel")" != "$(realpath -e -- "$dir")" ]]; then
    die "$dir existe pero no es un checkout Git de $name; muévalo antes de continuar"
  fi
  origin=$(git -C "$dir" remote get-url origin 2>/dev/null || true)
  [[ "$origin" == "${COMPONENT_URLS[$name]}" ]] || \
    die "el checkout de $name ($dir) usa otro origin: ${origin:-ninguno} (se esperaba ${COMPONENT_URLS[$name]}); muévalo o corrija su origin"
  changes=$(git -C "$dir" status --porcelain) || die "no se pudo leer el estado del checkout de $name ($dir)"
  [[ -z "$changes" ]] || \
    die "el checkout de $name ($dir) tiene cambios locales; confírmelos o descártelos antes de continuar"
}

# Stops when a declared destination, or one of its parents, is not a symlink
# that can be replaced.
component_check_destinations() {
  local name=$1 link path parent
  local -a links=()

  read -r -a links <<< "${COMPONENT_LINKS[$name]}"
  for link in "${links[@]}"; do
    path="$TARGET_DIR/${link#*=}"
    [[ ! -e "$path" || -L "$path" ]] || \
      die "$path ya existe y no es un enlace simbólico; muévalo antes de añadir $name (no se modificó nada)"
    parent=${path%/*}
    while [[ "$parent" != "$TARGET_DIR" && "$parent" == "$TARGET_DIR"/* ]]; do
      [[ ! -e "$parent" || -d "$parent" ]] || die "$parent no es un directorio; no se puede enlazar $path"
      parent=${parent%/*}
    done
  done
}

# Makes the pinned ref of $2 available in repository $1 and checks that every
# declared src exists in it. Prints an error and returns 1 otherwise.
component_verify_ref() {
  local dir=$1 name=$2 ref=${COMPONENT_REFS[$2]} link src
  local -a links=()

  if ! git -C "$dir" cat-file -e "$ref^{commit}" 2>/dev/null; then
    info "Descargando la ref fijada $ref de $name"
    git -C "$dir" fetch --quiet origin "$ref" 2>/dev/null || git -C "$dir" fetch --quiet origin || true
    if ! git -C "$dir" cat-file -e "$ref^{commit}" 2>/dev/null; then
      error "no se encontró la ref fijada $ref de $name en ${COMPONENT_URLS[$name]}"
      return 1
    fi
  fi
  read -r -a links <<< "${COMPONENT_LINKS[$name]}"
  for link in "${links[@]}"; do
    src=${link%%=*}
    if ! git -C "$dir" cat-file -e "$ref:$src" 2>/dev/null; then
      error "$name no contiene $src en la ref fijada $ref"
      return 1
    fi
  done
}

# Plans ($2 = 0) or applies ($2 = 1) component $1: checkout at the pinned ref
# and its links. Everything is validated before anything changes.
component_apply() {
  local name=$1 apply_mode=$2
  local dir url ref link src path staging="" work exists=0 head
  local -a links=()

  dir=$(component_dir "$name")
  url=${COMPONENT_URLS[$name]}
  ref=${COMPONENT_REFS[$name]}
  read -r -a links <<< "${COMPONENT_LINKS[$name]}"

  component_checkout_ready "$name" && exists=1
  component_check_destinations "$name"

  if (( apply_mode == 0 )); then
    info "Plan del componente $name"
    printf '  %-24s %s\n' 'Origen:' "$url" 'Ref fijada:' "$ref" 'Checkout:' "$dir"
    if (( exists == 0 )); then
      printf '  %-24s %s\n' 'Plan:' 'clonar y fijar la ref'
    else
      head=$(git -C "$dir" rev-parse HEAD 2>/dev/null || true)
      if [[ "$head" == "$ref" ]]; then
        printf '  %-24s %s\n' 'Plan:' 'ya está en la ref fijada'
      else
        printf '  %-24s %s\n' 'Plan:' "mover de ${head:-?} a la ref fijada"
      fi
      if git -C "$dir" cat-file -e "$ref^{commit}" 2>/dev/null; then
        component_verify_ref "$dir" "$name" || exit 1
      fi
    fi
    for link in "${links[@]}"; do
      printf '  %-24s %s -> %s\n' 'Enlace:' "$TARGET_DIR/${link#*=}" "$dir/${link%%=*}"
    done
    return 0
  fi

  work=$dir
  if (( exists == 0 )); then
    mkdir -p -- "${dir%/*}"
    staging=$(mktemp -d "${dir%/*}/.$name.clone.XXXXXX")
    info "Clonando $name desde $url"
    if ! git clone --quiet -- "$url" "$staging"; then
      rm -rf -- "$staging"
      die "no se pudo clonar $name desde $url"
    fi
    work=$staging
  fi
  if ! component_verify_ref "$work" "$name"; then
    [[ -z "$staging" ]] || rm -rf -- "$staging"
    exit 1
  fi
  if ! git -C "$work" -c advice.detachedHead=false checkout --quiet --detach "$ref"; then
    [[ -z "$staging" ]] || rm -rf -- "$staging"
    die "no se pudo fijar $name en la ref $ref"
  fi
  [[ -z "$staging" ]] || mv -T -- "$staging" "$dir"
  info "Componente $name en la ref fijada $ref ($dir)"

  for link in "${links[@]}"; do
    src="$dir/${link%%=*}"
    path="$TARGET_DIR/${link#*=}"
    if [[ -L "$path" && "$(readlink -- "$path")" == "$src" ]]; then
      info "Enlace ya presente: $path"
      continue
    fi
    [[ ! -L "$path" ]] || info "Reemplazando el enlace $path (apuntaba a $(readlink -- "$path"))"
    mkdir -p -- "${path%/*}"
    ln -sfn -- "$src" "$path"
    info "Enlazado $path -> $src"
  done
}

# Plans or applies every component named in the array $2 (apply mode $1).
apply_components() {
  local apply_mode=$1 name
  local -n apply_components_ref=$2

  (( ${#apply_components_ref[@]} > 0 )) || return 0
  command_exists git || die "git es necesario para los componentes registrados"
  for name in "${apply_components_ref[@]}"; do
    component_apply "$name" "$apply_mode"
  done
}

# Read-only audit of component $1: checkout, pinned ref and links.
doctor_component() {
  local name=$1 dir ref head link path src status=0
  local -a links=()

  dir=$(component_dir "$name")
  ref=${COMPONENT_REFS[$name]}
  if [[ ! -e "$dir/.git" ]]; then
    error "Componente $name: falta el checkout $dir; ejecute '$PROGRAM_NAME add $name'"
    return 1
  fi
  head=$(git -C "$dir" rev-parse HEAD 2>/dev/null || true)
  if [[ "$head" != "$ref" ]]; then
    error "Componente $name: el checkout está en ${head:-una ref desconocida}, no en la ref fijada $ref; ejecute '$PROGRAM_NAME add $name'"
    status=1
  fi
  read -r -a links <<< "${COMPONENT_LINKS[$name]}"
  for link in "${links[@]}"; do
    src="$dir/${link%%=*}"
    path="$TARGET_DIR/${link#*=}"
    if [[ ! -L "$path" || "$(readlink -- "$path")" != "$src" ]]; then
      error "Componente $name: $path no enlaza a $src; ejecute '$PROGRAM_NAME add $name'"
      status=1
    fi
  done
  (( status == 1 )) || info "Componente $name validado en la ref fijada $ref"
  return "$status"
}

# Removes (apply mode $1 = 1) the links of the components in array $2 that
# point into their checkout, keeps the checkouts and forgets them in the receipt.
unlink_components() {
  local apply_mode=$1 name dir link path destination
  local -n unlink_components_ref=$2
  local -a links=()

  for name in "${unlink_components_ref[@]}"; do
    # Canonical on both sides: the link may spell the checkout through a
    # symlinked parent; only the parent of the destination is resolved, so a
    # src that is itself a symlink still counts as inside the checkout.
    dir=$(realpath -m -- "$(component_dir "$name")")
    read -r -a links <<< "${COMPONENT_LINKS[$name]}"
    for link in "${links[@]}"; do
      path="$TARGET_DIR/${link#*=}"
      [[ -L "$path" ]] || continue
      destination=$(readlink -- "$path")
      [[ "$destination" == /* ]] || destination="${path%/*}/$destination"
      destination=$(realpath -m -s -- "$destination")
      destination="$(realpath -m -- "${destination%/*}")/${destination##*/}"
      if [[ "$destination" != "$dir/"* ]]; then
        warn "$path enlaza fuera del checkout de $name ($destination); se conserva"
        continue
      fi
      if (( apply_mode == 1 )); then
        rm -f -- "$path"
        info "Enlace del componente $name retirado: $path"
      else
        info "Simulando el retiro del enlace del componente $name: $path"
      fi
    done
    info "El checkout de $name se conserva en $dir"
  done
  (( apply_mode == 0 )) || forget_unlinked_components "$2"
}

# Drops from the receipt only the components in array $1, which were just
# unlinked; recorded components that were filtered out stay tracked.
forget_unlinked_components() {
  local -A saved=()
  local -a entries=() remaining=()
  local entry

  read_receipt components saved || return 0
  read -r -a entries <<< "${saved[COMPONENTS]:-}"
  for entry in "${entries[@]}"; do
    array_contains "$1" "$entry" || remaining+=("$entry")
  done
  (( ${#remaining[@]} < ${#entries[@]} )) || return 0
  if (( ${#remaining[@]} == 0 )); then
    rm -f -- "$(receipt_path components)"
  else
    write_receipt components COMPONENTS="${remaining[*]}"
  fi
}

cmd_add() {
  local name="" dry_run=0 available
  local -a recorded=()

  while (( $# > 0 )); do
    case "$1" in
      -n|--dry-run)
        dry_run=1
        shift
        ;;
      --target)
        require_option_value "$1" "${2-}"
        TARGET_DIR=$2
        shift 2
        ;;
      --target=*)
        TARGET_DIR=${1#*=}
        require_option_value "--target" "$TARGET_DIR"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      -*)
        usage_error "opción desconocida para add: $1"
        ;;
      *)
        [[ -z "$name" ]] || usage_error "add acepta un solo componente: $1"
        name=$1
        shift
        ;;
    esac
  done

  load_components
  available=${COMPONENT_NAMES[*]:-ninguno}
  [[ -n "$name" ]] || usage_error "add necesita el nombre de un componente (disponibles: $available)"
  [[ "$name" =~ $COMPONENT_NAME_PATTERN && -n "${COMPONENT_URLS[$name]:-}" ]] || \
    usage_error "componente desconocido: $name (disponibles: $available)"
  command_exists git || die "git es necesario para añadir componentes"
  command_exists realpath || die "falta el comando requerido: realpath"
  TARGET_DIR=$(realpath -m -- "$TARGET_DIR")

  if (( dry_run == 1 )); then
    component_apply "$name" 0
    return 0
  fi
  component_apply "$name" 1
  recorded_components recorded
  append_unique recorded "$name"
  write_receipt components COMPONENTS="${recorded[*]}"
  success "$(_t "Component $name added at its pinned ref." "Componente $name añadido en su ref fijada.")"
}
