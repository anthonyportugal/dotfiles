autoload -Uz compinit

typeset dotfiles_zsh_cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"

if [[ -d "$dotfiles_zsh_cache_dir" ]] || mkdir -p -- "$dotfiles_zsh_cache_dir" 2>/dev/null; then
  compinit -i -d "$dotfiles_zsh_cache_dir/zcompdump-$ZSH_VERSION"
else
  compinit -i -D
fi

unset dotfiles_zsh_cache_dir
