# Public defaults. Private and machine-local drop-ins may override them later.

typeset -gU PATH path
path=("$HOME/.local/bin" $path)

export EDITOR="${EDITOR:-micro}"
export VISUAL="${VISUAL:-$EDITOR}"
export BROWSER="${BROWSER:-brave}"
export BAT_THEME="${BAT_THEME:-Catppuccin-mocha}"
export STARSHIP_CONFIG="${STARSHIP_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml}"
export FZF_DEFAULT_OPTS="--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc --color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8 --color=selected-bg:#45475a --multi --height=50% --layout=reverse --border"

if [[ -n "${WAYLAND_DISPLAY-}" ]]; then
  export TERMINAL="${TERMINAL:-foot}"
else
  export TERMINAL="${TERMINAL:-alacritty}"
fi

if [[ -z "${SSH_AUTH_SOCK-}" && -n "${XDG_RUNTIME_DIR-}" ]]; then
  export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR}/ssh-agent.socket"
fi
