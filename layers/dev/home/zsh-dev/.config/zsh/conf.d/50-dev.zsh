# Development layer: Neovim as the editor, direnv, and pnpm with its global
# binaries on PATH, whether pnpm comes from a package (feature dev-js) or is
# installed standalone under PNPM_HOME.

typeset -gU PATH path

() {
  local pnpm_home="${PNPM_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/pnpm}"

  if (( $+commands[pnpm] )) || [[ -x "$pnpm_home/pnpm" ]]; then
    export PNPM_HOME="$pnpm_home"
    path=("$PNPM_HOME" "$PNPM_HOME/bin" $path)
  fi
}

# direnv loads and unloads each project's .envrc when entering its directory.
if (( $+commands[direnv] )); then
  eval "$(direnv hook zsh)"
fi

# Neovim (LazyVim) is the editor when installed. It replaces only core's micro
# default (${EDITOR:-micro} loads before this file), so an editor exported
# earlier is kept; git's own core.editor (micro) yields to GIT_EDITOR.
# private.zsh and local.zsh, sourced later, can still override all three.
if (( $+commands[nvim] )); then
  [[ -n $EDITOR && $EDITOR != micro ]] || export EDITOR=nvim
  [[ -n $VISUAL && $VISUAL != micro ]] || export VISUAL=nvim
  [[ $EDITOR != nvim || -n $GIT_EDITOR ]] || export GIT_EDITOR=nvim
fi
