#!/usr/bin/env bash
# lib/completions.sh - Shell completion generation (bash / zsh) for dotfiles
#
# shellcheck shell=bash

# Fallback defaults for standalone execution / linting
COMPLETION_SHELL=${COMPLETION_SHELL:-zsh}

# Component names come from components.conf when the script is generated, so
# a new component completes without editing this file.
cmd_completion() {
  local names script
  names=$( (load_components && printf '%s' "${COMPONENT_NAMES[*]}") 2>/dev/null || true)
  script=$(completion_script)
  printf '%s\n' "${script//@COMPONENTS@/$names}"
}

completion_script() {
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
    'setup:Short guided setup (profile, WMs, extras, overlay), then apply, dry-run or cancel'
    'bootstrap:Installs the selection given by flags without the wizard (--apply to apply)'
    'sync:Re-synchronizes local symlinks and packages without touching Git'
    'update:Pulls updates from remote repositories (fast-forward) and syncs'
    'doctor:Verifies dependencies, syntax, and symlinks without modifying'
    'unlink:Removes GNU Stow symlinks from the system'
    'add:Adds an external component from components.conf at its pinned commit'
    'switch:Makes another checkout the active one (plan; --apply; --rollback undoes it)'
    'system:Optional system layer (Ly, Limine, DNS-over-TLS) under sudo'
    'completion:Prints the shell completion script (zsh or bash)'
    'help:Shows help'
  )

  local -a common_options
  common_options=(
    '--profile[Cumulative profile]:profile:(core cli desktop)'
    '--lang[Interface language]:language:(en es)'
    '*--feature[Opt-in feature]:feature:(yazi-extras dev-containers dev-js)'
    '*--layer[Opt-in layer]:layer:(dev)'
    '(--no-overlay)--overlay[Overlay repository with its own layers/]:directory:_files -/'
    '(--overlay)--no-overlay[Stop applying the saved overlay]'
    '--backend[Package backend]:backend:(auto shelly paru yay pacman)'
    '--platform[Platform override]:platform:(auto cachyos arch)'
    '--target[Target directory]:directory:_files -/'
    '--base-only[Run diagnostics solely for base repository]'
    '--all[Diagnose or synchronize all available components]'
    '--apply[Apply bootstrap or unlink instead of printing the plan]'
    '(--packages-only)--stow-only[Links only, no packages]'
    '(--stow-only)--packages-only[Packages only, no links]'
    '*--wm[Window manager layer]:wm:(bspwm mangowm all)'
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
        setup|bootstrap|sync|update|doctor|unlink)
          _arguments -s $common_options
          ;;
        completion)
          _arguments '1:shell:(zsh bash)'
          ;;
        add)
          _arguments -s \
            '1:component:(@COMPONENTS@)' \
            '--target[Target directory]:directory:_files -/' \
            '(-n --dry-run)'{-n,--dry-run}'[Print the plan only]'
          ;;
        switch)
          _arguments -s \
            '1:checkout:_files -/' \
            '(--no-overlay)--overlay[Overlay repository with its own layers/]:directory:_files -/' \
            '(--overlay)--no-overlay[Apply no overlay]' \
            '--from[Current install when it cannot be detected]:directory:_files -/' \
            '--with-packages[Also install packages (default: links only)]' \
            '--rollback[Undo the last switch]' \
            '--target[Target directory]:directory:_files -/' \
            '--apply[Apply instead of printing the plan]'
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

  local commands="setup bootstrap sync update doctor unlink add switch system completion help"
  local options="--profile --feature --layer --backend --platform --target --base-only --all --packages-only --stow-only --wm --wm-profile --overlay --no-overlay --apply --dry-run -h --help"

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
      COMPREPLY=( $(compgen -W "yazi-extras dev-containers dev-js" -- "$cur") )
      return 0
      ;;
    --layer)
      COMPREPLY=( $(compgen -W "dev" -- "$cur") )
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
    --target|--overlay|--from|switch)
      COMPREPLY=( $(compgen -d -- "$cur") )
      return 0
      ;;
    completion)
      COMPREPLY=( $(compgen -W "bash zsh" -- "$cur") )
      return 0
      ;;
    add)
      COMPREPLY=( $(compgen -W "@COMPONENTS@" -- "$cur") )
      return 0
      ;;
  esac

  if [[ "$cur" == -* ]]; then
    [[ "${words[1]}" != switch ]] || options="--overlay --no-overlay --from --with-packages --rollback --target --apply -h --help"
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
