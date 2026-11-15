# Login shells only. Display managers such as ly start the graphical session
# through a zsh login shell that reads this file but never ~/.zshrc, so the
# compositor and everything it launches (desktop entries, keybindings,
# launchers) inherit this PATH. Keep it to environment: nothing interactive.

typeset -gU PATH path
path=("$HOME/.local/bin" $path)
export PATH
