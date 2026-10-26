typeset dotfiles_zsh_completions_dir="${XDG_CONFIG_HOME:-$HOME/.config}/zsh/completions"
if [[ -d "$dotfiles_zsh_completions_dir" ]]; then
  fpath=("$dotfiles_zsh_completions_dir" $fpath)
fi

# The Arch/CachyOS zsh-completions package installs definitions in
# /usr/share/zsh/site-functions, already present in Zsh's default fpath.
autoload -Uz compinit

typeset dotfiles_zsh_cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
typeset dotfiles_zcompdump="$dotfiles_zsh_cache_dir/zcompdump-$ZSH_VERSION"

if [[ -d "$dotfiles_zsh_cache_dir" ]] || mkdir -p -- "$dotfiles_zsh_cache_dir" 2>/dev/null; then
  zmodload zsh/datetime 2>/dev/null
  zmodload -F zsh/stat b:zstat 2>/dev/null

  typeset -A dotfiles_dump_stat
  if [[ -s "$dotfiles_zcompdump" ]] && zstat -H dotfiles_dump_stat +mtime "$dotfiles_zcompdump" 2>/dev/null && (( EPOCHSECONDS - dotfiles_dump_stat[mtime] < 86400 )); then
    compinit -C -i -d "$dotfiles_zcompdump"
  else
    compinit -i -d "$dotfiles_zcompdump"
    { zcompile "$dotfiles_zcompdump" } 2>/dev/null &!
  fi
  unset dotfiles_dump_stat
else
  compinit -i -D
fi

unset dotfiles_zcompdump dotfiles_zsh_cache_dir dotfiles_zsh_completions_dir
