# Keep only portable, generic aliases in the public repository.

# --- Navegación ---
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias -- -='cd -'

# --- Archivos ---
alias l='ls --color=auto -lh'
alias la='ls --color=auto -A'
alias ll='ls --color=auto -lah'
alias lg='ls --color=auto -l --group-directories-first'
alias e='$EDITOR'
alias y='yazi'

# --- Git Core & Estado ---
alias gst='git status -sb'
alias gi='git init'
alias gcl='git clone'
alias gcld='git clone --depth 1'

# --- Git Add & Commit ---
alias ga='git add'
alias gaa='git add -A'
alias gc='git commit'
alias gcm='git commit -m'
alias gca='git commit --amend'

# --- Git Branches & Checkout ---
alias gb='git branch'
alias gba='git branch -a'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gsw='git switch'
alias gswc='git switch -c'

# --- Git Diff ---
alias gd='git diff'
alias gds='git diff --staged'

# --- Git Push / Pull / Fetch ---
alias gp='git push'
alias gpu='git push -u origin HEAD'
alias gl='git pull'
alias gfp='git fetch --prune'

# --- Git Log (con verificación de firma %G?) ---
baseLogFormat="%C(yellow)%h%C(reset) - %C(cyan)%an%C(reset), %C(magenta)%ar%C(reset) %C(red)%d%C(reset) : %C(green)%s%C(reset) %C(blue)[%G?]%C(reset)"
alias glg="git log --graph --pretty=format:'$baseLogFormat' --decorate"
alias glgs="git log --graph --pretty=format:'$baseLogFormat' --decorate --stat"

# --- Git Stash ---
alias gsu='git stash -um'
alias gsl='git stash list'
alias gsa='git stash apply'
alias gsp='git stash pop'
alias gsd='git stash drop'

# --- Git Undo / Reset ---
alias gr='git reset'
alias grs='git reset --soft'
alias grs1='git reset --soft HEAD~1'
alias grev1='git revert -m 1'

