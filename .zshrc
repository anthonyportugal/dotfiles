export ZSH=$HOME/.oh-my-zsh

zstyle ':omz:update' mode disabled # disable automatic updates

# Plugins
ZSH_GLOBAL_PLUGINS_DIR=/usr/share/zsh/plugins

plugins=(git)

[[ -f $ZSH_GLOBAL_PLUGINS_DIR/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh ]] && source $ZSH_GLOBAL_PLUGINS_DIR/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh
[[ -f $ZSH_GLOBAL_PLUGINS_DIR/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh ]] && source $ZSH_GLOBAL_PLUGINS_DIR/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh

source $ZSH/oh-my-zsh.sh

# User configuration

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='nvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# On-demand rehash
zshcache_time="$(date +%s%N)"

autoload -Uz add-zsh-hook

rehash_precmd() {
  if [[ -e /var/cache/zsh/pacman ]]; then
    local paccache_time="$(date -r /var/cache/zsh/pacman +%s%N)"
    if ((zshcache_time < paccache_time)); then
      rehash
      zshcache_time="$paccache_time"
    fi
  fi
}

add-zsh-hook -Uz precmd rehash_precmd

# omz
alias zshconfig="geany ~/.zshrc"
alias ohmyzsh="thunar ~/.oh-my-zsh"

# ls
alias l='ls -lh'
alias ll='ls -lah'
alias la='ls -A'
alias lm='ls -m'
alias lr='ls -R'
alias lg='ls -l --group-directories-first'

# git
alias gcl='git clone'
alias gcld='git clone --depth'
alias gi='git init'
alias ga='git add'
alias gc='git commit -m'
alias gch='git checkout'
alias gchd='git checkout dev'
alias gchm='git checkout main'
alias gpd='git pull origin dev'
alias gpm='git pull origin main'
alias gm='git merge'
alias gpush='git push origin'
alias glg='git log --pretty=short --graph --decorate'
alias gsu='git stash -um'
alias gsl='git stash list'
alias gsa='git stash apply'
alias gsp='git stash pop'
alias gsd='git stash drop'
alias gr='git reset'
alias grs='git reset --soft HEAD~1'
alias gfp='git fetch --prune'
alias grev='git revert -m 1'

# yarn
alias yd='yarn dev'
alias yl='yarn lint'
alias yf='yarn format'
alias yb='yarn build'
alias yad='yarn add'
alias yar='yarn remove'
alias yui='yarn upgrade-interactive'
alias yuil='yarn upgrade-interactive --latest'

# npm
alias nd='npm run dev'
alias nl='npm run lint'
alias nf='npm run format'
alias nb='npm run build'

# pnpm
alias pm='pnpm'
alias pma='pnpm add'
alias pmi='pnpm install'
alias pmu='pnpm update'
alias pmr='pnpm remove'
alias pmimp='pnpm import'
alias pmex='pnpm exec'
alias pmdlx='pnpm dlx'
alias pmcre='pnpm create'

# dir
alias cdd='cd ~/.dotfiles'

# private config
private_zshrc=~/.dotfiles-private/.zshrc
[[ -f $private_zshrc ]] && source $private_zshrc

# bat
export BAT_THEME="Catppuccin-mocha"

# node
export NODE_OPTIONS=--max-old-space-size=4096

# pnpm - https://pnpm.io/installation
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
*":$PNPM_HOME:"*) ;;
*) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# starship - https://starship.rs/
export STARSHIP_CONFIG=~/.config/starship.toml
eval "$(starship init zsh)"

export BROWSER=brave

# lvim
export PATH="$HOME/.local/bin:$PATH"

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
