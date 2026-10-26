#!/usr/bin/env bash
# lib/layers.sh - Layer manifests (layer.conf), requires= resolution and hooks.
#
# A layer is a directory under layers/ with a layer.conf made of key=value
# lines. The file is parsed, never sourced. Optional executables in
# layers/<name>/hooks/ run as separate processes. Requires lib/colors.sh and
# lib/core.sh.
#
# shellcheck shell=bash

# Pure bash: sourcing must not depend on external commands being on PATH.
_layers_source=${BASH_SOURCE[0]}
[[ "$_layers_source" == */* ]] || _layers_source="./$_layers_source"
DOTFILES_LIB_DIR=$(cd -- "${_layers_source%/*}" && pwd -P)
unset _layers_source

# Both lists are read through array_contains by name.
# shellcheck disable=SC2034
LAYER_CONF_KEYS=(requires profiles receipt prune_dirs)
# shellcheck disable=SC2034
LAYER_HOOK_PHASES=(validate post-link)
LAYER_NAME_PATTERN='^[a-z0-9][a-z0-9-]*(/[a-z0-9][a-z0-9-]*)*$'
LAYER_VALUE_PATTERN='^[A-Za-z0-9._/-]+$'

# Fills the associative array named by $2 with the layer.conf of layer dir $1.
# Values are space-separated words; each word must match LAYER_VALUE_PATTERN.
# ShellCheck cannot follow the array filled through the nameref.
# shellcheck disable=SC2034
read_layer_conf() {
  local layer_dir=$1
  local -n layer_conf_ref=$2
  local conf_file="$layer_dir/layer.conf"
  local raw_line line key value word
  local -a words=()

  layer_conf_ref=()
  [[ -f "$conf_file" && -r "$conf_file" ]] || die "no existe el manifiesto de capa $conf_file"

  while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    line=$(trim_line "$raw_line")
    [[ -n "$line" && "$line" != \#* ]] || continue
    [[ "$line" == *=* ]] || die "línea inválida en $conf_file: $line"
    key=$(trim_line "${line%%=*}")
    value=$(trim_line "${line#*=}")
    array_contains LAYER_CONF_KEYS "$key" || die "clave desconocida en $conf_file: $key"
    [[ ! -v "layer_conf_ref[$key]" ]] || die "clave duplicada en $conf_file: $key"

    read -r -a words <<< "$value"
    for word in "${words[@]}"; do
      [[ "$word" =~ $LAYER_VALUE_PATTERN ]] || die "valor inválido para $key en $conf_file: $word"
    done
    layer_conf_ref["$key"]="${words[*]}"
  done < "$conf_file"
}

# Appends to the array named by $2 the layers named in $3.. under root $1,
# each preceded by everything it requires, without duplicates.
resolve_layers() {
  local layers_root=$1
  local output_name=$2
  shift 2
  local -A resolve_state=()
  local layer_name

  for layer_name in "$@"; do
    _resolve_layer "$layers_root" "$output_name" "$layer_name" ""
  done
}

_resolve_layer() {
  local layers_root=$1
  local output_name=$2
  local layer_name=$3
  local chain=$4
  local dependency
  local -A dependency_conf=()
  local -a dependencies=()

  [[ "$layer_name" =~ $LAYER_NAME_PATTERN ]] || die "nombre de capa inválido: $layer_name"
  case "${resolve_state[$layer_name]:-}" in
    done) return 0 ;;
    visiting) die "dependencia circular entre capas: ${chain}${layer_name}" ;;
  esac
  [[ -d "$layers_root/$layer_name" ]] || \
    die "la capa '$layer_name' no existe en $layers_root${chain:+ (requerida por ${chain% -> })}"

  resolve_state["$layer_name"]="visiting"
  read_layer_conf "$layers_root/$layer_name" dependency_conf
  read -r -a dependencies <<< "${dependency_conf[requires]:-}"
  for dependency in "${dependencies[@]}"; do
    _resolve_layer "$layers_root" "$output_name" "$dependency" "${chain}${layer_name} -> "
  done
  resolve_state["$layer_name"]="done"
  append_unique "$output_name" "$layer_name"
}

# Runs hook $2 of layer dir $1 when present. Reads TARGET_DIR, PROFILE and
# APPLY; the hook sees them plus LAYER_DIR and DOTFILES_LIB in its environment.
run_layer_hook() {
  local layer_dir=$1
  local phase=$2
  local hook="$layer_dir/hooks/$phase"

  array_contains LAYER_HOOK_PHASES "$phase" || die "fase de hook desconocida: $phase"
  [[ -e "$hook" || -L "$hook" ]] || return 0
  [[ -f "$hook" && -x "$hook" ]] || die "el hook $hook no es un archivo ejecutable"

  LAYER_DIR="$layer_dir" TARGET_DIR="$TARGET_DIR" PROFILE="$PROFILE" APPLY="$APPLY" \
    DOTFILES_LIB="$DOTFILES_LIB_DIR" "$hook"
}
