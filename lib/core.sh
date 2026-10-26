#!/usr/bin/env bash
# lib/core.sh - Generic helpers shared by the dotfiles engine: arrays, manifests and output.
#
# Requires die from lib/colors.sh.
#
# shellcheck shell=bash

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

trim_line() {
  local value=$1
  value=${value#"${value%%[![:space:]]*}"}
  value=${value%"${value##*[![:space:]]}"}
  printf '%s' "$value"
}

append_unique() {
  local array_name=$1
  local value=$2
  local -n append_destination_ref=$array_name
  local existing

  for existing in "${append_destination_ref[@]}"; do
    [[ "$existing" != "$value" ]] || return 0
  done
  append_destination_ref+=("$value")
}

array_contains() {
  local array_name=$1
  local expected=$2
  local -n entries=$array_name
  local entry

  for entry in "${entries[@]}"; do
    [[ "$entry" != "$expected" ]] || return 0
  done
  return 1
}

read_manifest() {
  local manifest_path=$1
  local array_name=$2
  local -n manifest_destination_ref=$array_name
  local raw_line line
  declare -A manifest_seen=()

  [[ -f "$manifest_path" ]] || die "no existe el manifiesto $manifest_path"
  manifest_destination_ref=()

  while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    line=$(trim_line "$raw_line")
    [[ -n "$line" ]] || continue
    [[ "$line" != \#* ]] || continue
    [[ "$line" != *\#* ]] || \
      die "comentario inline no permitido en $manifest_path: $line"
    [[ "$line" != -* ]] || die "entrada insegura en $manifest_path: $line"
    [[ "$line" =~ ^[A-Za-z0-9@._+:-]+$ ]] || \
      die "entrada inválida en $manifest_path: $line"
    [[ ! -v "manifest_seen[$line]" ]] || \
      die "entrada duplicada en $manifest_path: $line"
    manifest_seen["$line"]=1
    manifest_destination_ref+=("$line")
  done < "$manifest_path"
}

append_manifest_unique() {
  local array_name=$1
  local manifest_path=$2
  local -a manifest_entries=()
  local entry

  read_manifest "$manifest_path" manifest_entries
  for entry in "${manifest_entries[@]}"; do
    append_unique "$array_name" "$entry"
  done
}

print_array() {
  local label=$1
  local array_name=$2
  local -n entries=$array_name

  if (( ${#entries[@]} == 0 )); then
    printf '  %-24s %s\n' "$label:" '(ninguno)'
  else
    printf '  %-24s %s\n' "$label:" "${entries[*]}"
  fi
}

format_command() {
  local argument
  printf '    '
  for argument in "$@"; do
    printf '%q ' "$argument"
  done
  printf '\n'
}

# True when TARGET_DIR is the home of the user running the command.
target_is_current_home() {
  local current_home target_home

  current_home=$(realpath -m -- "$HOME")
  target_home=$(realpath -m -- "$TARGET_DIR")
  [[ "$target_home" == "$current_home" ]]
}
