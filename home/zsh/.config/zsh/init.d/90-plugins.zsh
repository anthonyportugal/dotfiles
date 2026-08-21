# Syntax highlighting must remain the last plugin sourced.

typeset dotfiles_zsh_plugins_dir=/usr/share/zsh/plugins

if [[ -r "$dotfiles_zsh_plugins_dir/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh" ]]; then
  source "$dotfiles_zsh_plugins_dir/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh"
fi

if [[ -r "$dotfiles_zsh_plugins_dir/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh" ]]; then
  source "$dotfiles_zsh_plugins_dir/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh"
fi

unset dotfiles_zsh_plugins_dir
