# Public Zsh configuration.
#
# Precedence is intentional:
#   public conf.d -> optional private.zsh -> optional local.zsh -> init.d
# Tool and plugin initialization runs last so private/local values can configure it.

typeset -g DOTFILES_ZSH_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
typeset -ga DOTFILES_ZSH_OVERRIDE_FILES=(
  "$DOTFILES_ZSH_CONFIG_DIR/private.zsh"
  "$DOTFILES_ZSH_CONFIG_DIR/local.zsh"
)

typeset dotfiles_zsh_file

for dotfiles_zsh_file in "$DOTFILES_ZSH_CONFIG_DIR"/conf.d/*.zsh(N); do
  source "$dotfiles_zsh_file"
done

for dotfiles_zsh_file in "${DOTFILES_ZSH_OVERRIDE_FILES[@]}"; do
  [[ -r "$dotfiles_zsh_file" ]] && source "$dotfiles_zsh_file"
done

for dotfiles_zsh_file in "$DOTFILES_ZSH_CONFIG_DIR"/init.d/*.zsh(N); do
  source "$dotfiles_zsh_file"
done

unset dotfiles_zsh_file DOTFILES_ZSH_OVERRIDE_FILES DOTFILES_ZSH_CONFIG_DIR
