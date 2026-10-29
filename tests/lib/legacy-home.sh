#!/usr/bin/env bash
# Shared fixtures for the tests that move a home from another install to a
# checkout (switch-smoke.sh, setup-smoke.sh): copies of the checkout, an
# overlay laid out like dotfiles-private, and a home with the pre-monorepo
# ecosystem under ~/.dotfiles as this machine has it. Everything lives under
# the caller's TEST_ROOT; nothing touches the real home or ~/.dotfiles.
#
# Sourced; expects REPO_ROOT and TEST_ROOT, and GNU Stow on PATH.
#
# shellcheck shell=bash

# Prints every entry of $1 (type, path, link value) and the hash of every
# regular file, so two calls differ when anything under $1 changed.
hash_tree() {
  (cd "$1" && find . -printf '%y %p %l\n' | LC_ALL=C sort
   find . -type f -exec sha256sum {} + | LC_ALL=C sort) | sha256sum
}

# Copies the engine and layers of this checkout to $1, so a sibling overlay
# never comes from the real machine and a checkout can be broken on purpose.
copy_checkout() {
  mkdir -p "$1"
  cp -a "$REPO_ROOT"/{bin,lib,layers,themes,packages,components.conf} "$1/"
}

# Writes at $1 an overlay like dotfiles-private: identity (requires core,
# feature work-csti) and dev-personal (requires the public dev layer).
make_legacy_overlay() {
  local overlay=$1 layer package rel
  while read -r layer package rel; do
    mkdir -p "$overlay/layers/$layer/home/$package/${rel%/*}"
    printf '%s\n' "$package" > "$overlay/layers/$layer/home/$package/$rel"
    : > "$overlay/layers/$layer/home/.stow"
  done <<'PACKAGES'
identity git-private .config/git/private.conf
identity work-csti .config/git/work-csti.conf
dev-personal gh .config/gh/hosts.yml
PACKAGES
  mkdir -p "$overlay/layers/identity/packages/stow" "$overlay/layers/dev-personal/packages/stow"
  printf '%s\n' requires=core profiles=identity features=work-csti > "$overlay/layers/identity/layer.conf"
  printf 'git-private\n' > "$overlay/layers/identity/packages/stow/identity.txt"
  printf 'work-csti\n' > "$overlay/layers/identity/packages/stow/work-csti.txt"
  printf '%s\n' requires=dev profiles=dev-personal > "$overlay/layers/dev-personal/layer.conf"
  printf 'gh\n' > "$overlay/layers/dev-personal/packages/stow/dev-personal.txt"
}

H=""
LEGACY=""

# Old Stow package $2 of old repository $1 (under $LEGACY) owning $3.
old_package() {
  mkdir -p "$LEGACY/$1/home/$2/$(dirname -- "$3")"
  printf 'old %s\n' "$2" > "$LEGACY/$1/home/$2/$3"
}

# A home at $TEST_ROOT/$1 (left in H, its ~/.dotfiles in LEGACY) with the
# pre-monorepo ecosystem as this machine has it: base, a MangoWM install with
# its theme, private (development + csti), walls and the independent
# agent-harness, all applied with GNU Stow or absolute links.
new_legacy_home() {
  H="$TEST_ROOT/$1"
  LEGACY="$H/.dotfiles"
  mkdir -p "$H"
  old_package base zsh .zshrc
  old_package base bat .config/bat/config
  old_package base bat .config/bat/themes/old-only.tmTheme
  old_package base xdg-defaults .config/gtk-3.0/settings.ini
  old_package base xdg-defaults .config/mimeapps.list
  printf '[Default Applications]\nx-scheme-handler/foo=foo.desktop\n' > "$LEGACY/base/home/xdg-defaults/.config/mimeapps.list"
  mkdir -p "$LEGACY/base/bin"
  printf '#!/bin/sh\n' > "$LEGACY/base/bin/dotfiles"
  chmod +x "$LEGACY/base/bin/dotfiles"
  old_package wm/mangowm mango .config/mango/config.conf
  old_package wm/bspwm bspwm .config/bspwm/bspwmrc
  old_package private git-private .config/git/private.conf
  old_package private zsh-development .config/zsh/conf.d/90-development.zsh
  mkdir -p "$LEGACY/walls/wallpapers" "$LEGACY/walls/bin" "$LEGACY/agent-harness/bin" "$LEGACY/system"
  printf 'jpg\n' > "$LEGACY/walls/wallpapers/a.jpg"
  printf '#!/bin/sh\n' > "$LEGACY/walls/bin/walls"
  printf '#!/bin/sh\n' > "$LEGACY/agent-harness/bin/agent"
  printf '#!/bin/sh\n' > "$LEGACY/system/install.sh"

  stow -d "$LEGACY/base/home" -t "$H" --no-folding zsh bat xdg-defaults
  stow -d "$LEGACY/wm/mangowm/home" -t "$H" --no-folding mango
  stow -d "$LEGACY/private/home" -t "$H" --no-folding git-private zsh-development
  mkdir -p "$H/.local/bin" "$H/.local/share"
  ln -s "$LEGACY/base/bin/dotfiles" "$H/.local/bin/dotfiles"
  ln -s "$LEGACY/walls/bin/walls" "$H/.local/bin/walls"
  ln -s "$LEGACY/walls/wallpapers" "$H/.local/share/wallpapers"
  ln -s "$LEGACY/agent-harness/bin/agent" "$H/.local/bin/agent"

  local state="$H/.local/state"
  mkdir -p "$state/dotfiles/theme" "$state/mangowm/theme"
  printf 'RECEIPT_VERSION=1\nCOMPONENT="mangowm"\nPROFILE="desktop"\nBACKEND="pacman"\n' > "$state/dotfiles/mangowm.receipt"
  printf 'RECEIPT_VERSION=1\nCOMPONENT="private"\nPROFILE="development"\nWORK="csti"\nBACKEND="pacman"\n' > "$state/dotfiles/private.receipt"
  printf 'RECEIPT_VERSION=1\nCOMPONENT="agent-harness"\nTARGET="all"\n' > "$state/dotfiles/agent-harness.receipt"
  printf 'catppuccin-mocha-mauve\n' > "$state/mangowm/theme/selected"
  ln -s ../../mangowm/theme/current "$state/dotfiles/theme/current"
}
