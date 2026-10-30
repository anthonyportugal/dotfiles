# Development layer: pnpm and its global binaries on PATH, whether pnpm comes
# from a package (feature dev-js) or is installed standalone under PNPM_HOME.

typeset -gU PATH path

() {
  local pnpm_home="${PNPM_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/pnpm}"

  if (( $+commands[pnpm] )) || [[ -x "$pnpm_home/pnpm" ]]; then
    export PNPM_HOME="$pnpm_home"
    path=("$PNPM_HOME" "$PNPM_HOME/bin" $path)
  fi
}
