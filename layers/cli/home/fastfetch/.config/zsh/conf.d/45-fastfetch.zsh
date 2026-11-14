# fastfetch has no include, so the accent of the rendered theme arrives as
# arguments (one per line in fastfetch/args). Without a rendered theme the
# config's ANSI colors apply.
if (( $+commands[fastfetch] )); then
  fastfetch() {
    local args_file="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/theme/current/fastfetch/args"
    local -a theme_args

    [[ -r "$args_file" ]] && theme_args=("${(@f)$(<"$args_file")}")
    command fastfetch "${theme_args[@]}" "$@"
  }
fi
