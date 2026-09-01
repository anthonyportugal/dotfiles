# Public defaults. Private and machine-local drop-ins may override them later.

typeset -gU PATH path
path=("$HOME/.local/bin" $path)

export EDITOR="${EDITOR:-micro}"
export VISUAL="${VISUAL:-$EDITOR}"
export BROWSER="${BROWSER:-brave}"
export BAT_THEME="${BAT_THEME:-Catppuccin-mocha}"
export STARSHIP_CONFIG="${STARSHIP_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml}"

if [[ -n "${WAYLAND_DISPLAY-}" ]]; then
  export TERMINAL="${TERMINAL:-foot}"
else
  export TERMINAL="${TERMINAL:-alacritty}"
fi
