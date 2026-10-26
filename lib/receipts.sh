#!/usr/bin/env bash
# lib/receipts.sh - Per-component state receipts under ~/.local/state/dotfiles.
#
# A receipt is a KEY="value" file written atomically. Every receipt carries
# RECEIPT_VERSION, COMPONENT and UPDATED_AT. Reads TARGET_DIR. Requires
# lib/colors.sh and lib/core.sh.
#
# shellcheck shell=bash

RECEIPT_VERSION_CURRENT=1

receipt_dir() {
  printf '%s' "$TARGET_DIR/.local/state/dotfiles"
}

receipt_path() {
  [[ "$1" =~ ^[a-z0-9][a-z0-9._-]*$ ]] || die "componente de recibo inválido: $1"
  printf '%s/%s.receipt' "$(receipt_dir)" "$1"
}

# Fills the associative array named by $2 with the receipt of component $1.
# Returns 1 when the receipt does not exist or is unreadable.
# ShellCheck cannot follow the array filled through the nameref.
# shellcheck disable=SC2034
read_receipt() {
  local component=$1
  local -n receipt_values_ref=$2
  local receipt_file line key raw_value

  receipt_file=$(receipt_path "$component")
  receipt_values_ref=()
  [[ -f "$receipt_file" && -r "$receipt_file" ]] || return 1

  while IFS= read -r line || [[ -n "$line" ]]; do
    line=$(trim_line "$line")
    [[ -n "$line" && "$line" != \#* && "$line" == *=* ]] || continue
    key=$(trim_line "${line%%=*}")
    raw_value=$(trim_line "${line#*=}")
    if [[ "$raw_value" =~ ^\"(.*)\"$ || "$raw_value" =~ ^\'(.*)\'$ ]]; then
      raw_value=${BASH_REMATCH[1]}
    fi
    receipt_values_ref["$key"]=$raw_value
  done < "$receipt_file"
}

# Writes the receipt of component $1 from KEY=VALUE arguments.
write_receipt() {
  local component=$1
  shift
  local directory receipt_file tmp_receipt entry key value

  [[ "$component" =~ ^[a-z0-9][a-z0-9._-]*$ ]] || die "componente de recibo inválido: $component"
  directory=$(receipt_dir)
  receipt_file=$(receipt_path "$component")

  for entry in "$@"; do
    [[ "$entry" == *=* ]] || die "entrada de recibo inválida: $entry"
    key=${entry%%=*}
    value=${entry#*=}
    [[ "$key" =~ ^[A-Z][A-Z0-9_]*$ ]] || die "clave de recibo inválida: $key"
    [[ "$value" != *[\"$'\n']* ]] || die "valor de recibo inválido para $key"
  done

  mkdir -p -- "$directory"
  tmp_receipt=$(mktemp "$receipt_file.XXXXXX")
  {
    printf 'RECEIPT_VERSION=%s\n' "$RECEIPT_VERSION_CURRENT"
    printf 'COMPONENT="%s"\n' "$component"
    for entry in "$@"; do
      printf '%s="%s"\n' "${entry%%=*}" "${entry#*=}"
    done
    printf 'UPDATED_AT="%s"\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  } > "$tmp_receipt"
  mv -f -- "$tmp_receipt" "$receipt_file"
  info "Recibo de estado guardado en $receipt_file"
}
