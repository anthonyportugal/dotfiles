# zoxide adds `z` and `zi` next to `cd` (never replacing it). It runs after the
# plugins and only defines functions and a chpwd hook, so the widgets of
# zsh-autosuggestions and zsh-syntax-highlighting stay untouched.
if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh)"
fi
