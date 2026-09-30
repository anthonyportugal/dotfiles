#!/usr/bin/env bash
# lib/colors.sh - Catppuccin Mocha terminal UI and logging helpers for dotfiles
#
# shellcheck shell=bash

# Fallback defaults for standalone execution / linting
PROGRAM_NAME=${PROGRAM_NAME:-dotfiles}
DOTFILES_LANG=${DOTFILES_LANG:-en}
C_RESET=${C_RESET:-}
C_BOLD=${C_BOLD:-}
C_PINK=${C_PINK:-}
C_MAUVE=${C_MAUVE:-}
C_BLUE=${C_BLUE:-}
C_GREEN=${C_GREEN:-}
C_YELLOW=${C_YELLOW:-}
C_RED=${C_RED:-}
C_SUBTEXT=${C_SUBTEXT:-}

_t() {
  local en_text=$1
  local es_text=${2:-$1}
  if [[ "${DOTFILES_LANG:-en}" == "es" ]]; then
    printf '%b' "$es_text"
  else
    printf '%b' "$en_text"
  fi
}

setup_colors() {
  if [[ -t 1 ]] && command -v tput >/dev/null 2>&1 && (( $(tput colors 2>/dev/null || echo 0) >= 8 )); then
    C_RESET='\033[0m'
    C_BOLD='\033[1m'
    C_PINK='\033[38;2;245;194;231m'
    C_MAUVE='\033[38;2;203;166;247m'
    C_BLUE='\033[38;2;137;180;250m'
    C_GREEN='\033[38;2;166;227;161m'
    C_YELLOW='\033[38;2;249;226;175m'
    C_RED='\033[38;2;243;139;168m'
    C_SUBTEXT='\033[38;2;166;173;200m'
  else
    C_RESET='' C_BOLD='' C_PINK='' C_MAUVE='' C_BLUE=''
    C_GREEN='' C_YELLOW='' C_RED='' C_SUBTEXT=''
  fi
}

info() {
  printf '%b%b[%s]%b %b==>%b %s\n' "$C_MAUVE" "$C_BOLD" "$PROGRAM_NAME" "$C_RESET" "$C_BLUE" "$C_RESET" "$*"
}

success() {
  printf '%b%b[%s]%b %b✓%b %b%s%b\n' "$C_MAUVE" "$C_BOLD" "$PROGRAM_NAME" "$C_RESET" "$C_GREEN" "$C_RESET" "$C_BOLD" "$*" "$C_RESET"
}

warn() {
  local label
  label=$(_t "warning:" "aviso:")
  printf '%b%b[%s]%b %b%b%s%b %s\n' "$C_MAUVE" "$C_BOLD" "$PROGRAM_NAME" "$C_RESET" "$C_YELLOW" "$C_BOLD" "$label" "$C_RESET" "$*" >&2
}

error() {
  local label
  label=$(_t "error:" "error:")
  printf '%b%b[%s]%b %b%b%s%b %s\n' "$C_MAUVE" "$C_BOLD" "$PROGRAM_NAME" "$C_RESET" "$C_RED" "$C_BOLD" "$label" "$C_RESET" "$*" >&2
}

die() {
  error "$*"
  exit 1
}

usage_error() {
  error "$*"
  printf "%s\n" "$(_t "Use '$PROGRAM_NAME help' to view usage." "Use '$PROGRAM_NAME help' para ver la interfaz.")" >&2
  exit 2
}
