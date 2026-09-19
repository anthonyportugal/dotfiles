# Keep only portable, generic aliases in the public repository.

# --- Navigation ---
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias -- -='cd -'

# --- Files & Editor ---
alias l='ls --color=auto -lh'
alias la='ls --color=auto -A'
alias ll='ls --color=auto -lah'
alias ld='ls --color=auto -l --group-directories-first'
alias lg='lazygit'
alias ldo='lazydocker'
alias e='$EDITOR'
alias y='yazi'

# --- Git Status & Remotes ---
alias gst='git status -sb'
alias gi='git init'
alias gcl='git clone'
alias gcld='git clone --depth 1'
alias gremv='git remote -v'
alias grema='git remote add'
alias gremd='git remote remove'

# --- Git Add & Commit ---
alias ga='git add'
alias gaa='git add -A'
alias gap='git add -p'
alias gc='git commit'
alias gcm='git commit -m'
alias gca='git commit --amend'
alias gcan='git commit --amend --no-edit'

# --- Git Branches & Switch / Checkout ---
alias gb='git branch'
alias gba='git branch -a'
alias gbd='git branch -d'
alias gbD='git branch -D'
alias gsw='git switch'
alias gswc='git switch -c'
alias gsw-='git switch -'
alias gco='git checkout'
alias gcb='git checkout -b'

# --- Git Diff ---
alias gd='git diff'
alias gds='git diff --staged'

# --- Git Push, Pull & Fetch ---
alias gp='git push'
alias gpu='git push -u origin HEAD'
alias gpf='git push --force-with-lease'
alias gpl='git pull'
alias gplr='git pull --rebase'
alias gf='git fetch'
alias gfp='git fetch --prune'

# --- Git Log (with signature verification %G?) ---
baseLogFormat="%C(yellow)%h%C(reset) - %C(cyan)%an%C(reset), %C(magenta)%ar%C(reset) %C(red)%d%C(reset) : %C(green)%s%C(reset) %C(blue)[%G?]%C(reset)"
alias gl='git log --oneline -n 20'
alias glg="git log --graph --pretty=format:'$baseLogFormat' --decorate"
alias glgs="git log --graph --pretty=format:'$baseLogFormat' --decorate --stat"

# --- Git Stash ---
alias gsh='git stash -u'
alias gshp='git stash pop'
alias gsha='git stash apply'
alias gshl='git stash list'
alias gshd='git stash drop'

# --- Git Undo & Restore ---
alias gundo='git reset --soft HEAD~1'
alias gunstage='git restore --staged'
alias gdiscard='git restore'

# --- Fast search & preview ---
fp() {
  local target
  target=$(fzf --preview '
    if [ -d {} ]; then
      ls -la --color=always {} 2>/dev/null || ls -la {}
    else
      case {} in
        *.md|*.MD|*.markdown|*.mdown)
          if command -v glow >/dev/null 2>&1; then
            glow -s dark -w "${FZF_PREVIEW_COLUMNS:-80}" {}
          elif command -v bat >/dev/null 2>&1; then
            bat --color=always --style=numbers,changes --line-range :300 {} 2>/dev/null || head -n 200 {}
          else
            head -n 200 {}
          fi
          ;;
        *)
          if command -v bat >/dev/null 2>&1; then
            bat --color=always --style=numbers,changes --line-range :300 {} 2>/dev/null || head -n 200 {}
          else
            head -n 200 {}
          fi
          ;;
      esac
    fi
  ') || return 0
  [[ -n "$target" ]] && ${EDITOR:-micro} "$target"
}
