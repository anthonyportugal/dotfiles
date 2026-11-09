#!/usr/bin/env bash
# lib/external.sh - Pinned downloads (fonts, cursor themes) installed per user.
#
# A layer lists recipe names in packages/external/<tier|feature>.txt, and
# each name has a data-only recipe at packages/external/<name>.conf:
#
#   version=2.0.7
#   dest=share/icons/Bibata-Modern-Classic
#   archive=<sha256> <https URL>        one tar archive with one top-level directory
#   file=<name> <sha256> <https URL>    or one or more plain files
#   refresh=fonts                       optional: rebuild the font cache of dest
#
# dest is relative to $TARGET_DIR/.local and belongs to the recipe: an install
# replaces it whole, and a dest the adapter did not install is never touched.
# Every download is checked against its sha256 before dest changes, and
# nothing downloaded is executed. The receipt external-<name> records the
# recipe's own sha256, so editing a recipe reinstalls it. No root is needed.
#
# Reads TARGET_DIR, PACKAGES_DIR and EXTERNAL_PACKAGES; fills
# INSTALLED_EXTERNAL_PACKAGES and MISSING_EXTERNAL_PACKAGES. Requires
# lib/colors.sh, lib/core.sh and lib/receipts.sh.
#
# shellcheck shell=bash

INSTALLED_EXTERNAL_PACKAGES=()
MISSING_EXTERNAL_PACKAGES=()
# The install in progress, for the SIGINT/SIGTERM cleanup.
EXTERNAL_STAGING='' EXTERNAL_DEST='' EXTERNAL_NAME='' EXTERNAL_DOWNLOAD_PID=''
EXTERNAL_SWAPPING=0

external_prefix() {
  printf '%s' "$TARGET_DIR/.local"
}

external_recipe_path() {
  printf '%s/external/%s.conf' "$PACKAGES_DIR" "$1"
}

# Parses recipe $1 into the associative array named $2 (version, dest,
# refresh, kind=archive|file) and the indexed array named $3, one
# "<name> <sha256> <url>" entry per download (the archive's name is
# "archive"). Prints the first problem and returns 1 when the recipe is
# missing or invalid.
# shellcheck disable=SC2034
external_read_recipe() {
  local name=$1
  local -n recipe_ref=$2
  local -n sources_ref=$3
  local path raw_line line key value file_name sha url segment entry
  local -a fields=() segments=()
  # Letters, digits and ._@+-[] (as in "Font[wght].ttf"); ']' leads the set.
  local file_name_pattern='^[A-Za-z0-9][]A-Za-z0-9._@+[-]*$'

  recipe_ref=()
  sources_ref=()
  [[ "$name" =~ ^[a-z0-9][a-z0-9._-]*$ ]] || { error "nombre de receta externa inválido: $name"; return 1; }
  path=$(external_recipe_path "$name")
  [[ -f "$path" ]] || { error "no existe la receta externa $name ($path)"; return 1; }

  while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    line=$(trim_line "$raw_line")
    [[ -n "$line" && "$line" != \#* ]] || continue
    [[ "$line" == *=* ]] || { error "línea inválida en $path: $line"; return 1; }
    key=${line%%=*}
    value=${line#*=}
    case "$key" in
      version|dest|refresh)
        [[ ! -v "recipe_ref[$key]" ]] || { error "$key repetido en $path"; return 1; }
        recipe_ref["$key"]=$value
        ;;
      archive|file)
        read -r -a fields <<< "$value"
        if [[ "$key" == archive ]]; then
          (( ${#fields[@]} == 2 )) || { error "archive espera <sha256> <url> en $path"; return 1; }
          fields=(archive "${fields[@]}")
        else
          (( ${#fields[@]} == 3 )) || { error "file espera <nombre> <sha256> <url> en $path"; return 1; }
        fi
        file_name=${fields[0]} sha=${fields[1]} url=${fields[2]}
        [[ "${recipe_ref[kind]:-$key}" == "$key" ]] || { error "$path mezcla archive y file"; return 1; }
        [[ "$key" == file || ${#sources_ref[@]} -eq 0 ]] || { error "$path declara más de un archive"; return 1; }
        recipe_ref[kind]=$key
        [[ "$file_name" =~ $file_name_pattern ]] || { error "nombre de archivo inválido en $path: $file_name"; return 1; }
        for entry in "${sources_ref[@]}"; do
          [[ "${entry%% *}" != "$file_name" ]] || { error "archivo repetido en $path: $file_name"; return 1; }
        done
        [[ "$sha" =~ ^[0-9a-f]{64}$ ]] || { error "sha256 inválido en $path: $sha"; return 1; }
        [[ "$url" =~ ^https://[^[:space:]]+$ ]] || { error "sólo se aceptan URLs https en $path: $url"; return 1; }
        sources_ref+=("$file_name $sha $url")
        ;;
      *)
        error "clave desconocida en $path: $key"
        return 1
        ;;
    esac
  done < "$path"

  [[ "${recipe_ref[version]:-}" =~ ^[A-Za-z0-9._+-]+$ ]] || { error "version inválida o ausente en $path"; return 1; }
  (( ${#sources_ref[@]} > 0 )) || { error "$path no declara archive ni file"; return 1; }
  case "${recipe_ref[refresh]:-}" in
    ''|fonts) ;;
    *) error "refresh desconocido en $path: ${recipe_ref[refresh]}"; return 1 ;;
  esac
  # dest is share/<dir>/<name>[/...]: never share itself, never above it.
  [[ "${recipe_ref[dest]:-}" =~ ^share(/[A-Za-z0-9._-]+){2,}$ ]] || {
    error "dest debe ser share/<directorio>/<nombre> en $path: ${recipe_ref[dest]:-}"
    return 1
  }
  IFS=/ read -r -a segments <<< "${recipe_ref[dest]}"
  for segment in "${segments[@]}"; do
    [[ "$segment" != . && "$segment" != .. ]] || { error "dest no puede contener . ni .. en $path"; return 1; }
  done
}

external_recipe_hash() {
  sha256sum -- "$(external_recipe_path "$1")" | cut -d' ' -f1
}

# A recipe counts as installed when its receipt matches the current recipe
# and its dest still exists.
external_is_installed() {
  local name=$1
  local -A receipt=() recipe=()
  local -a sources=()

  external_read_recipe "$name" recipe sources 2>/dev/null || return 1
  read_receipt "external-$name" receipt || return 1
  [[ "${receipt[RECIPE_SHA256]:-}" == "$(external_recipe_hash "$name")" ]] || return 1
  [[ -d "$(external_prefix)/${recipe[dest]}" ]]
}

classify_external_packages() {
  local name

  INSTALLED_EXTERNAL_PACKAGES=()
  MISSING_EXTERNAL_PACKAGES=()
  for name in "${EXTERNAL_PACKAGES[@]}"; do
    if external_is_installed "$name"; then
      INSTALLED_EXTERNAL_PACKAGES+=("$name")
    else
      MISSING_EXTERNAL_PACKAGES+=("$name")
    fi
  done
}

validate_external_plan() {
  local name tool result=0
  local -A recipe=()
  local -a sources=()

  for name in "${EXTERNAL_PACKAGES[@]}"; do
    external_read_recipe "$name" recipe sources || result=1
  done
  # A tool may be missing now when the repository step of this same run
  # installs its package (sha256sum comes from coreutils).
  if (( ${#MISSING_EXTERNAL_PACKAGES[@]} > 0 )); then
    for tool in curl:curl sha256sum:coreutils tar:tar; do
      command_exists "${tool%%:*}" || array_contains MISSING_REPO_PACKAGES "${tool#*:}" || {
        error "${tool%%:*} es necesario para las descargas externas"
        result=1
      }
    done
  fi
  return "$result"
}

show_external_commands() {
  local name
  local -A recipe=()
  local -a sources=()

  for name in "${MISSING_EXTERNAL_PACKAGES[@]}"; do
    external_read_recipe "$name" recipe sources 2>/dev/null || continue
    printf '    descarga verificada (sha256, sin root): %s %s -> %s/%s\n' \
      "$name" "${recipe[version]}" "$(external_prefix)" "${recipe[dest]}"
  done
}

# Downloads and checks every source of recipe $1 into $2/payload: the plain
# files, or the single top-level directory of the archive.
_external_stage() {
  local name=$1 staging=$2
  local entry file_name sha url download
  local -A recipe=()
  local -a sources=() entries=()

  external_read_recipe "$name" recipe sources || return 1
  mkdir -p -- "$staging/downloads" "$staging/payload" "$staging/extract"
  for entry in "${sources[@]}"; do
    read -r file_name sha url <<< "$entry"
    download="$staging/downloads/$file_name"
    # In the background, so a signal reaches the installer's trap at once.
    curl -fsSL --proto '=https' --retry 2 --connect-timeout 20 \
      --speed-limit 1024 --speed-time 60 -o "$download" "$url" &
    EXTERNAL_DOWNLOAD_PID=$!
    wait "$EXTERNAL_DOWNLOAD_PID" || {
      EXTERNAL_DOWNLOAD_PID=''
      error "no se pudo descargar $url"
      return 1
    }
    EXTERNAL_DOWNLOAD_PID=''
    printf '%s  %s\n' "$sha" "$download" | sha256sum --check --status || {
      error "la suma sha256 de $url no coincide con la receta $name"
      return 1
    }
    if [[ "${recipe[kind]}" == file ]]; then
      install -m 0644 -- "$download" "$staging/payload/$file_name"
    fi
  done

  if [[ "${recipe[kind]}" == archive ]]; then
    tar -xf "$staging/downloads/archive" -C "$staging/extract" \
      --no-same-owner --no-same-permissions || {
      error "no se pudo extraer el archivo de $name"
      return 1
    }
    mapfile -t entries < <(find "$staging/extract" -mindepth 1 -maxdepth 1)
    if (( ${#entries[@]} != 1 )) || [[ ! -d "${entries[0]}" || -L "${entries[0]}" ]]; then
      error "el archivo de $name debe contener un único directorio de primer nivel"
      return 1
    fi
    rmdir -- "$staging/payload"
    mv -- "${entries[0]}" "$staging/payload"
  fi
}

# Installs recipe $1 into its dest, replacing only a dest it installed.
external_install() {
  local name=$1
  local prefix staging dest current segment receipt_file status=0
  local -A recipe=() receipt=()
  local -a sources=() segments=()

  external_read_recipe "$name" recipe sources || return 1
  prefix=$(external_prefix)
  dest="$prefix/${recipe[dest]}"
  if [[ -e "$dest" || -L "$dest" ]]; then
    if ! read_receipt "external-$name" receipt || [[ "${receipt[DEST]:-}" != "${recipe[dest]}" ]]; then
      error "$dest ya existe y no lo instaló dotfiles; muévalo o elimínelo para instalar $name"
      return 1
    fi
  fi

  # Below ~/.local every directory must be real: a symlinked one (a folded
  # Stow package, say) would send the download into the link's target.
  current=$prefix
  IFS=/ read -r -a segments <<< "${recipe[dest]}"
  for segment in "${segments[@]}"; do
    current="$current/$segment"
    [[ ! -L "$current" ]] || { error "$current es un symlink; no se instala $name a través de él"; return 1; }
  done

  mkdir -p -- "$prefix" "${dest%/*}" || return 1
  # Staged next to dest's filesystem, so the final rename is atomic.
  staging=$(mktemp -d "$prefix/.dotfiles-external.XXXXXX") || return 1
  EXTERNAL_STAGING=$staging EXTERNAL_DEST=$dest EXTERNAL_NAME=$name
  if ! _external_stage "$name" "$staging"; then
    _external_discard_staging
    return 1
  fi

  # The swap: dest and its receipt change together, or neither does.
  receipt_file=$(receipt_path "external-$name")
  [[ ! -f "$receipt_file" ]] || cp -p -- "$receipt_file" "$staging/previous.receipt" || {
    _external_discard_staging
    return 1
  }
  EXTERNAL_SWAPPING=1
  if [[ -e "$dest" ]] && ! mv -T -- "$dest" "$staging/previous"; then
    error "no se pudo apartar la versión instalada de $name en $dest"
    status=1
  elif ! mv -T -- "$staging/payload" "$dest"; then
    error "no se pudo mover $name a $dest"
    status=1
  elif ! _external_record "$name" "${recipe[version]}" "${recipe[dest]}"; then
    error "no se pudo guardar el recibo de $name; se deshace la instalación"
    status=1
  fi
  (( status == 0 )) || _external_undo
  EXTERNAL_SWAPPING=0

  if (( status == 0 )) && [[ "${recipe[refresh]:-}" == fonts ]] && command_exists fc-cache; then
    fc-cache -f "$dest" >/dev/null 2>&1 || warn "fc-cache no pudo refrescar $dest"
  fi
  _external_discard_staging
  return "$status"
}

# Puts back dest and the receipt as they were before the swap in progress.
# The payload is no longer staged once it became dest.
_external_undo() {
  local receipt_file

  if [[ ! -e "$EXTERNAL_STAGING/payload" && -e "$EXTERNAL_DEST" ]]; then
    mv -T -- "$EXTERNAL_DEST" "$EXTERNAL_STAGING/undone"
  fi
  if [[ ! -e "$EXTERNAL_DEST" && -e "$EXTERNAL_STAGING/previous" ]]; then
    mv -T -- "$EXTERNAL_STAGING/previous" "$EXTERNAL_DEST"
  fi
  receipt_file=$(receipt_path "external-$EXTERNAL_NAME")
  if [[ -f "$EXTERNAL_STAGING/previous.receipt" ]]; then
    mv -f -- "$EXTERNAL_STAGING/previous.receipt" "$receipt_file"
  else
    rm -f -- "$receipt_file"
  fi
}

# Writes the receipt of recipe $1 (version $2, dest $3) and reads it back:
# write_receipt reports no failure of its own once errexit is off.
_external_record() {
  local name=$1 version=$2 dest=$3 hash
  local -A written=()

  hash=$(external_recipe_hash "$name")
  (write_receipt "external-$name" VERSION="$version" DEST="$dest" RECIPE_SHA256="$hash") >/dev/null 2>&1
  read_receipt "external-$name" written && [[ "${written[RECIPE_SHA256]:-}" == "$hash" ]]
}

_external_discard_staging() {
  [[ "$EXTERNAL_STAGING" == "$(external_prefix)"/.dotfiles-external.* ]] && rm -rf -- "$EXTERNAL_STAGING"
  EXTERNAL_STAGING='' EXTERNAL_DEST='' EXTERNAL_NAME=''
}

# On SIGINT or SIGTERM: stop the download, undo a swap in progress, and
# remove the staging directory.
_external_interrupted() {
  [[ -z "$EXTERNAL_DOWNLOAD_PID" ]] || kill "$EXTERNAL_DOWNLOAD_PID" 2>/dev/null || true
  (( EXTERNAL_SWAPPING == 0 )) || _external_undo
  _external_discard_staging
  exit 130
}

# Installs every missing recipe; one failure does not skip the others.
execute_external_install() {
  local name status=0 previous_traps

  previous_traps=$(trap -p INT TERM)
  trap _external_interrupted INT TERM
  for name in "${MISSING_EXTERNAL_PACKAGES[@]}"; do
    info "Instalando $name (descarga verificada con sha256, sin root)"
    external_install "$name" || status=1
  done
  trap - INT TERM
  eval "$previous_traps"
  return "$status"
}
