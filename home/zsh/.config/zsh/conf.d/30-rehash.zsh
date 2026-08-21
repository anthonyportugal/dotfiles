# Refresh command discovery after pacman updates its completion cache.

autoload -Uz add-zsh-hook

if zmodload -F zsh/stat b:zstat 2>/dev/null; then
  typeset -gi _dotfiles_pacman_cache_mtime=0

  _dotfiles_rehash_after_package_change() {
    local -A package_cache_stat

    [[ -e /var/cache/zsh/pacman ]] || return 0
    zstat -H package_cache_stat +mtime /var/cache/zsh/pacman 2>/dev/null || return 0

    if (( package_cache_stat[mtime] > _dotfiles_pacman_cache_mtime )); then
      rehash
      _dotfiles_pacman_cache_mtime=$package_cache_stat[mtime]
    fi
  }

  add-zsh-hook precmd _dotfiles_rehash_after_package_change
fi
