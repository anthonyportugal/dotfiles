typeset dotfiles_zsh_state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/zsh"

if [[ -d "$dotfiles_zsh_state_dir" ]] || mkdir -p -- "$dotfiles_zsh_state_dir" 2>/dev/null; then
  HISTFILE="$dotfiles_zsh_state_dir/history"
else
  HISTFILE="$HOME/.zsh_history"
fi

HISTSIZE=10000
SAVEHIST=10000

setopt EXTENDED_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
setopt SHARE_HISTORY

unset dotfiles_zsh_state_dir
