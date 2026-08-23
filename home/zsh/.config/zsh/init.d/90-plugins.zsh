# zsh-history-substring-search explicitly requires syntax highlighting to be
# sourced before it.

typeset dotfiles_zsh_plugins_dir=/usr/share/zsh/plugins
typeset dotfiles_zsh_history_search="$dotfiles_zsh_plugins_dir/zsh-history-substring-search/zsh-history-substring-search.zsh"

if [[ -r "$dotfiles_zsh_plugins_dir/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh" ]]; then
  source "$dotfiles_zsh_plugins_dir/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh"
fi

if [[ -r "$dotfiles_zsh_plugins_dir/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh" ]]; then
  source "$dotfiles_zsh_plugins_dir/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh"
fi

if [[ -r "$dotfiles_zsh_history_search" ]]; then
  source "$dotfiles_zsh_history_search"

  # Cover the common normal-mode sequences as well as the application-mode
  # sequences advertised by the active terminal.
  bindkey '^[[A' history-substring-search-up
  bindkey '^[[B' history-substring-search-down

  if zmodload zsh/terminfo 2>/dev/null; then
    [[ -n "${terminfo[kcuu1]-}" ]] && \
      bindkey "$terminfo[kcuu1]" history-substring-search-up
    [[ -n "${terminfo[kcud1]-}" ]] && \
      bindkey "$terminfo[kcud1]" history-substring-search-down
  fi
fi

unset dotfiles_zsh_history_search dotfiles_zsh_plugins_dir
