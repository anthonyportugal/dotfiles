# Development layer: global pnpm binaries (feature dev-js) on PATH.

typeset -gU PATH path

if (( $+commands[pnpm] )); then
  export PNPM_HOME="${PNPM_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/pnpm}"
  path=("$PNPM_HOME" $path)
fi
