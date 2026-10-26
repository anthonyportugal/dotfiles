#!/usr/bin/env bash
# lib/layers.sh - Layer manifests (layer.conf), requires= resolution and hooks.
#
# A layer is a directory under layers/ with a layer.conf made of key=value
# lines. The file is parsed, never sourced. Optional executables in
# layers/<name>/hooks/ run as separate processes. Requires lib/colors.sh and
# lib/core.sh.
#
# Internal locals use the _lyr_ prefix so they cannot shadow the array names
# callers pass in.
#
# shellcheck shell=bash

# Pure bash: sourcing must not depend on external commands being on PATH.
_layers_source=${BASH_SOURCE[0]}
[[ "$_layers_source" == */* ]] || _layers_source="./$_layers_source"
DOTFILES_LIB_DIR=$(cd -- "${_layers_source%/*}" && pwd -P)
unset _layers_source

# Both lists are read through array_contains by name.
# shellcheck disable=SC2034
LAYER_CONF_KEYS=(requires profiles receipt features prune_dirs prune_links)
# shellcheck disable=SC2034
LAYER_HOOK_PHASES=(validate post-link)
LAYER_NAME_PATTERN='^[a-z0-9][a-z0-9-]*(/[a-z0-9][a-z0-9-]*)*$'
LAYER_WORD_PATTERN='^[a-z0-9][a-z0-9._-]*$'
LAYER_PATH_PATTERN='^[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*$'

# Validates the words of one layer.conf value for key $1 (file $2 for errors).
_lyr_validate_value() {
  local _lyr_key=$1
  local _lyr_file=$2
  shift 2
  local _lyr_word

  if [[ "$_lyr_key" == receipt ]] && (( $# != 1 )); then
    die "receipt debe tener exactamente un valor en $_lyr_file"
  fi
  for _lyr_word in "$@"; do
    case "$_lyr_key" in
      requires)
        [[ "$_lyr_word" =~ $LAYER_NAME_PATTERN ]] ;;
      profiles|receipt|features)
        [[ "$_lyr_word" =~ $LAYER_WORD_PATTERN ]] ;;
      prune_dirs|prune_links)
        # Relative to TARGET_DIR and never climbing out of it.
        [[ "$_lyr_word" =~ $LAYER_PATH_PATTERN && "/$_lyr_word/" != */../* && "/$_lyr_word/" != */./* ]] ;;
    esac || die "valor inválido para $_lyr_key en $_lyr_file: $_lyr_word"
  done
}

# Fills the associative array named by $2 with the layer.conf of layer dir $1.
# Values are space-separated words, stored joined by single spaces.
# ShellCheck cannot follow the array filled through the nameref, and the file
# name is only reused in error messages, never written.
# shellcheck disable=SC2034,SC2094
read_layer_conf() {
  local _lyr_layer_dir=$1
  local -n _lyr_conf_ref=$2
  local _lyr_file="$_lyr_layer_dir/layer.conf"
  local _lyr_raw _lyr_line _lyr_key _lyr_value
  local -a _lyr_words=()
  local IFS=$' \t\n'

  _lyr_conf_ref=()
  [[ -f "$_lyr_file" && -r "$_lyr_file" ]] || die "no existe el manifiesto de capa $_lyr_file"

  while IFS= read -r _lyr_raw || [[ -n "$_lyr_raw" ]]; do
    _lyr_line=$(trim_line "$_lyr_raw")
    [[ -n "$_lyr_line" && "$_lyr_line" != \#* ]] || continue
    [[ "$_lyr_line" == *=* ]] || die "línea inválida en $_lyr_file: $_lyr_line"
    _lyr_key=$(trim_line "${_lyr_line%%=*}")
    _lyr_value=$(trim_line "${_lyr_line#*=}")
    array_contains LAYER_CONF_KEYS "$_lyr_key" || die "clave desconocida en $_lyr_file: $_lyr_key"
    [[ ! -v "_lyr_conf_ref[$_lyr_key]" ]] || die "clave duplicada en $_lyr_file: $_lyr_key"

    read -r -a _lyr_words <<< "$_lyr_value"
    _lyr_validate_value "$_lyr_key" "$_lyr_file" "${_lyr_words[@]}"
    _lyr_conf_ref["$_lyr_key"]="${_lyr_words[*]}"
  done < "$_lyr_file"
}

# Appends to the array named by $2 the layers named in $3.. under root $1,
# each preceded by everything it requires, without duplicates.
resolve_layers() {
  local _lyr_root=$1
  local _lyr_output=$2
  shift 2
  local -A _lyr_state=()
  local _lyr_name

  for _lyr_name in "$@"; do
    _lyr_resolve "$_lyr_root" "$_lyr_output" "$_lyr_name" ""
  done
}

_lyr_resolve() {
  local _lyr_root=$1
  local _lyr_output=$2
  local _lyr_name=$3
  local _lyr_chain=$4
  local _lyr_dependency
  local -A _lyr_dep_conf=()
  local -a _lyr_dependencies=()
  local IFS=$' \t\n'

  [[ "$_lyr_name" =~ $LAYER_NAME_PATTERN ]] || die "nombre de capa inválido: $_lyr_name"
  case "${_lyr_state[$_lyr_name]:-}" in
    done) return 0 ;;
    visiting) die "dependencia circular entre capas: ${_lyr_chain}${_lyr_name}" ;;
  esac
  [[ -d "$_lyr_root/$_lyr_name" ]] || \
    die "la capa '$_lyr_name' no existe en $_lyr_root${_lyr_chain:+ (requerida por ${_lyr_chain% -> })}"

  _lyr_state["$_lyr_name"]="visiting"
  read_layer_conf "$_lyr_root/$_lyr_name" _lyr_dep_conf
  read -r -a _lyr_dependencies <<< "${_lyr_dep_conf[requires]:-}"
  for _lyr_dependency in "${_lyr_dependencies[@]}"; do
    _lyr_resolve "$_lyr_root" "$_lyr_output" "$_lyr_dependency" "${_lyr_chain}${_lyr_name} -> "
  done
  _lyr_state["$_lyr_name"]="done"
  append_unique "$_lyr_output" "$_lyr_name"
}

# Fills the array named by $3 with the tiers of layer dir $1 up to profile $2,
# following the cumulative order declared in profiles=.
# ShellCheck cannot follow the array filled through the nameref.
# shellcheck disable=SC2034
layer_profile_tiers() {
  local _lyr_layer_dir=$1
  local _lyr_profile=$2
  local -n _lyr_tiers_ref=$3
  local -A _lyr_conf=()
  local -a _lyr_profiles=()
  local _lyr_tier
  local IFS=$' \t\n'

  read_layer_conf "$_lyr_layer_dir" _lyr_conf
  read -r -a _lyr_profiles <<< "${_lyr_conf[profiles]:-}"
  _lyr_tiers_ref=()
  for _lyr_tier in "${_lyr_profiles[@]}"; do
    _lyr_tiers_ref+=("$_lyr_tier")
    [[ "$_lyr_tier" != "$_lyr_profile" ]] || return 0
  done
  die "la capa ${_lyr_layer_dir##*/} no declara el perfil '$_lyr_profile' (profiles=${_lyr_conf[profiles]:-})"
}

# Fills the array named by $3 with the Stow packages of layer dir $1 for
# profile $2, read from packages/stow/<tier>.txt and checked under home/.
read_layer_stow_packages() {
  local _lyr_layer_dir=$1
  local _lyr_profile=$2
  local _lyr_output=$3
  local -a _lyr_tiers=() _lyr_entries=()
  local _lyr_tier _lyr_entry _lyr_manifest
  local -n _lyr_packages_ref=$_lyr_output

  _lyr_packages_ref=()
  layer_profile_tiers "$_lyr_layer_dir" "$_lyr_profile" _lyr_tiers
  for _lyr_tier in "${_lyr_tiers[@]}"; do
    _lyr_manifest="$_lyr_layer_dir/packages/stow/$_lyr_tier.txt"
    [[ -f "$_lyr_manifest" ]] || continue
    read_manifest "$_lyr_manifest" _lyr_entries
    for _lyr_entry in "${_lyr_entries[@]}"; do
      [[ -d "$_lyr_layer_dir/home/$_lyr_entry" ]] || \
        die "el paquete Stow '$_lyr_entry' no existe bajo $_lyr_layer_dir/home"
      append_unique "$_lyr_output" "$_lyr_entry"
    done
  done
}

# Runs hook $2 of layer dir $1 when present. On top of the exported
# environment, the hook sees LAYER_DIR, TARGET_DIR, PROFILE, APPLY, OPERATION
# and DOTFILES_LIB.
run_layer_hook() {
  local _lyr_layer_dir=$1
  local _lyr_phase=$2
  local _lyr_hook="$_lyr_layer_dir/hooks/$_lyr_phase"

  array_contains LAYER_HOOK_PHASES "$_lyr_phase" || die "fase de hook desconocida: $_lyr_phase"
  [[ -e "$_lyr_hook" || -L "$_lyr_hook" ]] || return 0
  [[ -f "$_lyr_hook" && -x "$_lyr_hook" ]] || die "el hook $_lyr_hook no es un archivo ejecutable"

  LAYER_DIR="$_lyr_layer_dir" TARGET_DIR="${TARGET_DIR:-}" PROFILE="${PROFILE:-}" \
    APPLY="${APPLY:-0}" OPERATION="${OPERATION:-}" DOTFILES_LIB="$DOTFILES_LIB_DIR" \
    "$_lyr_hook"
}
