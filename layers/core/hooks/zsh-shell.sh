# shellcheck shell=bash
# Login shell helpers shared by the core layer hooks.

select_registered_zsh_shell() {
  local shell_path

  if command_exists chsh; then
    while read -r shell_path _; do
      [[ "${shell_path##*/}" == zsh && -x "$shell_path" ]] || continue
      printf '%s\n' "$shell_path"
      return 0
    done < <(chsh --list-shells 2>/dev/null)
  fi

  if [[ -r /etc/shells ]]; then
    while read -r shell_path _; do
      [[ "${shell_path##*/}" == zsh && -x "$shell_path" ]] || continue
      printf '%s\n' "$shell_path"
      return 0
    done < /etc/shells
  fi

  return 1
}

report_zsh_activation() {
  local account current_home login_shell passwd_entry registered_zsh_shell
  local target_home

  command_exists zsh || return 0

  current_home=$(realpath -m -- "$HOME")
  target_home=$(realpath -m -- "$TARGET_DIR")
  [[ "$target_home" == "$current_home" ]] || return 0

  account=${USER-}
  [[ -n "$account" ]] || account=$(id -un 2>/dev/null || true)
  [[ -n "$account" ]] || return 0

  if command_exists getent; then
    passwd_entry=$(getent passwd "$account" 2>/dev/null || true)
    [[ -n "$passwd_entry" ]] && login_shell=${passwd_entry##*:}
  fi
  login_shell=${login_shell:-${SHELL-}}

  if [[ "${login_shell##*/}" != zsh ]]; then
    warn "Zsh está instalado, pero el shell de login de '$account' es '${login_shell:-desconocido}'; Bash no carga los plugins de .zshrc"
    if registered_zsh_shell=$(select_registered_zsh_shell); then
      warn "prueba inmediata: exec zsh; cambio persistente: chsh -s $registered_zsh_shell (después cierre por completo la sesión)"
    else
      warn "no se encontró una ruta ejecutable de Zsh registrada por chsh; revise 'chsh --list-shells' antes de cambiar la cuenta"
    fi
  elif [[ "${SHELL##*/}" != zsh ]]; then
    warn "el shell de login ya es Zsh, pero esta sesión conserva SHELL='${SHELL:-desconocido}'; cierre la sesión y vuelva a entrar"
  else
    info "Shell de login Zsh validado: $login_shell"
  fi
}
