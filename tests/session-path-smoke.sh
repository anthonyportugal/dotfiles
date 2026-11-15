#!/usr/bin/env bash
# Session PATH: display managers such as ly start the graphical session through
# a zsh login shell that reads ~/.zprofile but never ~/.zshrc. The core layer
# ships a ~/.zprofile that puts ~/.local/bin first, so desktop entries and
# keybindings launched by the compositor find the helpers installed there.

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
ZSH_HOME="$REPO_ROOT/layers/core/home/zsh"
ZPROFILE="$ZSH_HOME/.zprofile"
TEST_ROOT=''

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  [[ -n "$TEST_ROOT" && "$TEST_ROOT" == /tmp/session-path-smoke.* ]] || return 0
  find "$TEST_ROOT" -mindepth 1 -delete
  find "$TEST_ROOT" -depth -type d -empty -delete
}
trap cleanup EXIT

command -v zsh >/dev/null 2>&1 || { printf 'SKIP: session-path-smoke (zsh no está instalado)\n'; exit 0; }

TEST_ROOT=$(mktemp -d /tmp/session-path-smoke.XXXXXX)
H="$TEST_ROOT/home"
mkdir -p "$H/.local/bin"

[[ -f "$ZPROFILE" ]] || fail "la capa core no incluye ~/.zprofile"

# 1. A login shell with the display manager PATH gets ~/.local/bin first.
# shellcheck disable=SC2016 # expanded by the inner zsh
session_path=$(env -i HOME="$H" ZDOTDIR="$ZSH_HOME" PATH=/usr/local/bin:/usr/bin:/bin \
  zsh -l -c 'print -r -- "$PATH"')
# /etc/zsh/zprofile may append system entries, so only the head is fixed.
[[ "$session_path" == "$H/.local/bin:"* ]] || \
  fail "el login de zsh no antepone ~/.local/bin: $session_path"

# 2. A helper in ~/.local/bin resolves by name, as a desktop entry Exec needs.
printf '#!/bin/sh\nexit 0\n' > "$H/.local/bin/session-helper"
chmod +x "$H/.local/bin/session-helper"
found=$(env -i HOME="$H" ZDOTDIR="$ZSH_HOME" PATH=/usr/bin:/bin \
  zsh -l -c 'command -v session-helper')
[[ "$found" == "$H/.local/bin/session-helper" ]] || \
  fail "un programa de ~/.local/bin no se resuelve en la sesión: $found"

# 3. Nested login shells (a terminal started with zsh -l) never duplicate it.
# shellcheck disable=SC2016 # expanded by the inner zsh
nested_path=$(env -i HOME="$H" ZDOTDIR="$ZSH_HOME" PATH=/usr/bin:/bin \
  zsh -l -c 'zsh -l -c '\''print -r -- "$PATH"'\''')
occurrences=$(tr ':' '\n' <<< "$nested_path" | grep -cxF -- "$H/.local/bin" || true)
[[ "$nested_path" == "$H/.local/bin:"* && "$occurrences" == 1 ]] || \
  fail "un login anidado duplica ~/.local/bin: $nested_path"

# 4. Unlinking cleans an orphaned ~/.zprofile link like the other base links.
grep -Eq '^prune_links=(.* )?\.zprofile( |$)' "$REPO_ROOT/layers/core/layer.conf" || \
  fail "layer.conf de core no limpia el enlace huérfano de .zprofile"

printf 'OK: session-path-smoke\n'
