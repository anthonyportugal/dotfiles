# Public defaults. Private and machine-local drop-ins may override them later.

typeset -gU PATH path
path=("$HOME/.local/bin" $path)

export EDITOR="${EDITOR:-micro}"
export VISUAL="${VISUAL:-$EDITOR}"
export BROWSER="${BROWSER:-brave}"
export FZF_DEFAULT_OPTS="--multi --height=50% --layout=reverse --border"

# Colors rendered by dotfiles-theme. Each tool keeps its own defaults while
# no theme has been rendered yet.
() {
  local theme_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/theme/current"
  local config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  local bat_theme="${BAT_CONFIG_DIR:-$config_home/bat}/themes/dotfiles.tmTheme"
  local bat_cache="${BAT_CACHE_PATH:-${XDG_CACHE_HOME:-$HOME/.cache}/bat}/themes.bin"

  # bat only knows the rendered theme once its cache was rebuilt after the
  # render (the render.d hook on every promoted revision, or the cli post-link).
  if [[ -z "${BAT_THEME-}" ]]; then
    if [[ -e "$bat_theme" && -e "$bat_cache" && ! "$bat_theme" -nt "$bat_cache" ]]; then
      export BAT_THEME=dotfiles
    else
      export BAT_THEME=Catppuccin-mocha
    fi
  fi
  if [[ -z "${LG_CONFIG_FILE-}" && -r "$config_home/lazygit/config.yml" && \
        -r "$theme_dir/lazygit/theme.yml" ]]; then
    export LG_CONFIG_FILE="$config_home/lazygit/config.yml,$theme_dir/lazygit/theme.yml"
  fi
  if [[ -z "${FZF_DEFAULT_OPTS_FILE-}" && -r "$theme_dir/fzf/options" ]]; then
    export FZF_DEFAULT_OPTS_FILE="$theme_dir/fzf/options"
  fi
  # starship reads the copy with the theme palette (cli render hook) while it
  # is not older than starship.toml; after editing starship.toml the plain
  # file applies until the next render.
  if [[ -z "${STARSHIP_CONFIG-}" ]]; then
    local starship_config="$config_home/starship.toml"
    local starship_themed="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/starship.toml"
    if [[ -r "$starship_themed" && ! "$starship_config" -nt "$starship_themed" ]]; then
      export STARSHIP_CONFIG="$starship_themed"
    else
      export STARSHIP_CONFIG="$starship_config"
    fi
  fi
}

if (( $+commands[fd] )); then
  export FZF_DEFAULT_COMMAND="fd --type f --strip-cwd-prefix --hidden --follow --exclude .git"
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND="fd --type d --strip-cwd-prefix --hidden --follow --exclude .git"
fi

if [[ -n "${WAYLAND_DISPLAY-}" ]]; then
  export TERMINAL="${TERMINAL:-foot}"
else
  export TERMINAL="${TERMINAL:-alacritty}"
fi

if [[ -z "${SSH_AUTH_SOCK-}" && -n "${XDG_RUNTIME_DIR-}" ]]; then
  export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR}/ssh-agent.socket"
fi
