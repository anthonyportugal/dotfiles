#!/usr/bin/env bash
#
# Dotfiles Installer & Setup Orchestrator
# https://github.com/anthonyportugal/dotfiles
#
# Clones the repository into ~/.dotfiles (DOTFILES_BASE_DIR overrides it,
# e.g. ~/dev/personal/dotfiles) and starts `dotfiles setup` from there.
# DOTFILES_REPO and DOTFILES_BRANCH pick another remote or branch.
#

set -Eeuo pipefail

main() {
  local dotfiles_repo="${DOTFILES_REPO:-https://github.com/anthonyportugal/dotfiles.git}"
  local dotfiles_branch="${DOTFILES_BRANCH:-main}"
  local target_base="${DOTFILES_BASE_DIR:-$HOME/.dotfiles}"

  # Determine if we are already inside the base repository
  local script_dir=""
  script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd -P)" || script_dir=""
  if [[ -n "$script_dir" && -f "$script_dir/bin/dotfiles" ]]; then
    target_base="$script_dir"
  fi

  printf '\033[1;34m::\033[0m \033[1mIniciando instalador de Dotfiles...\033[0m\n'

  # Verify minimal required commands
  local cmd
  for cmd in git bash; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      printf '\033[1;31merror:\033[0m Se requiere el comando "%s" para continuar.\n' "$cmd" >&2
      exit 1
    fi
  done

  # Clone base repository if missing
  if [[ ! -d "$target_base" ]]; then
    printf '\033[1;34m::\033[0m Clonando repositorio base en %s...\n' "$target_base"
    mkdir -p "$(dirname "$target_base")"
    if ! git clone --depth=1 --branch "$dotfiles_branch" "$dotfiles_repo" "$target_base" 2>/dev/null; then
      if ! git clone --depth=1 --branch "main" "$dotfiles_repo" "$target_base" 2>/dev/null; then
        git clone --depth=1 "$dotfiles_repo" "$target_base"
      fi
    fi
  fi

  if [[ ! -x "$target_base/bin/dotfiles" ]]; then
    chmod +x "$target_base/bin/dotfiles"
  fi

  printf '\033[1;32m::\033[0m Ejecutando asistente de configuración...\n\n'

  # Piped from curl, stdin is the script: read answers from the terminal,
  # when there is one that opens (not under cloud-init or `ssh host cmd`).
  if [[ ! -t 0 ]] && { : < /dev/tty; } 2>/dev/null; then
    exec "$target_base/bin/dotfiles" setup "$@" < /dev/tty
  else
    exec "$target_base/bin/dotfiles" setup "$@"
  fi
}

main "$@"
