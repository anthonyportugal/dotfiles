#!/usr/bin/env bash
# lib/completions.sh - Shell completion generation (bash / zsh) for dotfiles
#
# shellcheck shell=bash

# Fallback defaults for standalone execution / linting
COMPLETION_SHELL=${COMPLETION_SHELL:-zsh}

cmd_completion() {
  local shell_target=${COMPLETION_SHELL:-zsh}
  case "$shell_target" in
    zsh)
      cat <<'EOF'
#compdef dotfiles

_dotfiles() {
  local curcontext="$curcontext" state line
  typeset -A opt_args

  local -a commands
  commands=(
    'setup:Interactive guided assistant to configure and install by layers'
    'sync:Re-synchronizes local symlinks and packages without touching Git'
    'update:Pulls updates from remote repositories (fast-forward) and syncs'
    'doctor:Verifies dependencies, syntax, and symlinks without modifying'
    'unlink:Removes GNU Stow symlinks from the system'
    'help:Shows help'
  )

  local -a common_options
  common_options=(
    '--profile[Cumulative profile]:profile:(core cli desktop)'
    '--lang[Interface language]:language:(en es)'
    '*--feature[Opt-in feature]:feature:(yazi-extras)'
    '--backend[Package backend]:backend:(auto shelly paru yay pacman)'
    '--platform[Platform override]:platform:(auto cachyos arch)'
    '--target[Target directory]:directory:_files -/'
    '--base-only[Run diagnostics solely for base repository]'
    '--all[Diagnose or synchronize all available components]'
    '(-y --yes)'{-y,--yes}'[Automatic yes to prompts]'
    '(-h --help)'{-h,--help}'[Shows help]'
  )

  _arguments -C \
    '1: :->command' \
    '*:: :->args' && return 0

  case "$state" in
    command)
      _describe -t commands 'dotfiles command' commands
      ;;
    args)
      case "$line[1]" in
        setup|sync|update|doctor|unlink)
          _arguments -s $common_options
          ;;
        help)
          _describe -t commands 'command' commands
          ;;
      esac
      ;;
  esac
}

_dotfiles "$@"
EOF
      ;;
    bash)
      cat <<'EOF'
_dotfiles_completion() {
  local cur prev words cword
  _init_completion || return

  local commands="setup sync update bootstrap doctor unlink completion help"
  local options="--profile --feature --backend --platform --target --base-only --all --packages-only --stow-only --wm --wm-path --wm-profile --wallpapers --wallpapers-path --private --private-path --private-profile --private-work --agent-harness --agent-harness-path --apply -h --help"

  if (( cword == 1 )); then
    COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
    return 0
  fi

  case "$prev" in
    --profile)
      COMPREPLY=( $(compgen -W "core cli desktop" -- "$cur") )
      return 0
      ;;
    --feature)
      COMPREPLY=( $(compgen -W "yazi-extras" -- "$cur") )
      return 0
      ;;
    --backend)
      COMPREPLY=( $(compgen -W "auto shelly paru yay pacman" -- "$cur") )
      return 0
      ;;
    --platform)
      COMPREPLY=( $(compgen -W "auto cachyos arch" -- "$cur") )
      return 0
      ;;
    --wm)
      COMPREPLY=( $(compgen -W "bspwm mangowm" -- "$cur") )
      return 0
      ;;
    --wm-profile)
      COMPREPLY=( $(compgen -W "core desktop" -- "$cur") )
      return 0
      ;;
    --private-profile)
      COMPREPLY=( $(compgen -W "core dev" -- "$cur") )
      return 0
      ;;
    --target|--wm-path|--wallpapers-path|--private-path|--agent-harness-path)
      COMPREPLY=( $(compgen -d -- "$cur") )
      return 0
      ;;
    completion)
      COMPREPLY=( $(compgen -W "bash zsh" -- "$cur") )
      return 0
      ;;
  esac

  if [[ "$cur" == -* ]]; then
    COMPREPLY=( $(compgen -W "$options" -- "$cur") )
  fi
}

complete -F _dotfiles_completion dotfiles
EOF
      ;;
    *)
      usage_error "shell no soportado para completion: $shell_target (use: bash, zsh)"
      ;;
  esac
}
