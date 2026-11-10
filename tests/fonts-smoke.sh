#!/usr/bin/env bash
# Font contract: every config names a family a declared package installs, and
# the fontconfig fallbacks render emoji in color after the role font.

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
DESKTOP_MANIFEST="$REPO_ROOT/layers/desktop/packages/repo/desktop.txt"
FONTS_CONF="$REPO_ROOT/layers/desktop/home/xdg-defaults/.config/fontconfig/fonts.conf"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

declares() {
  grep -qxF -- "$1" "$DESKTOP_MANIFEST"
}

# 1. Packages: the Nerd variant replaces plain JetBrains Mono, and Noto covers
# text, emoji and CJK glyphs the role fonts lack.
for package in ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji noto-fonts-cjk; do
  declares "$package" || fail "la capa desktop no declara $package"
done
! declares ttf-jetbrains-mono || \
  fail 'la capa desktop aún declara ttf-jetbrains-mono (sin glifos Nerd)'

# The Sanctuary role fonts: Cormorant (display) from extra; Hanken Grotesk
# (text) and Cinzel (inscription) are not packaged, so they are pinned
# downloads of the external adapter.
declares ttf-cormorant || fail 'la capa desktop no declara ttf-cormorant'
for recipe in hanken-grotesk cinzel; do
  grep -qxF -- "$recipe" "${DESKTOP_MANIFEST%/repo/*}/external/desktop.txt" || \
    fail "la capa desktop no declara la descarga externa $recipe"
done

# 2. Configs: plain "JetBrains Mono" is not installed by any declared package.
if plain=$(grep -rnE 'JetBrains Mono([^A-Za-z]|$)' "$REPO_ROOT/layers" \
    --exclude='*.md' --exclude-dir=tests); then
  fail "configuraciones con la familia JetBrains Mono sin Nerd:"$'\n'"$plain"
fi

# 3. Fallbacks: every generic family prefers its role font, the Nerd symbols
# and Noto Color Emoji, in that order.
[[ -f "$FONTS_CONF" ]] || fail "falta $FONTS_CONF"
for generic in monospace sans-serif serif; do
  chain=$(awk -v generic="$generic" '
    /<alias/ { in_alias = 1; family = ""; prefer = 0; next }
    /<\/alias>/ { in_alias = 0; next }
    in_alias && family == "" && match($0, /<family>[^<]+<\/family>/) {
      family = substr($0, RSTART + 8, RLENGTH - 17); next
    }
    in_alias && /<prefer>/ { prefer = (family == generic); next }
    in_alias && /<\/prefer>/ { prefer = 0; next }
    prefer && match($0, /<family>[^<]+<\/family>/) {
      print substr($0, RSTART + 8, RLENGTH - 17)
    }' "$FONTS_CONF" | paste -sd'|')
  [[ "$chain" == *'Symbols Nerd Font'*'|Noto Color Emoji' ]] || \
    fail "$generic no termina en Symbols Nerd Font → Noto Color Emoji: $chain"
done

# 4. Resolution on a host that has the fonts (skipped elsewhere, e.g. CI).
# Applications draw a glyph with the first font of the sorted fallback list
# that covers it, so that is what is asserted, not fc-match's single best.
first_covering() {
  local pattern=$1 codepoint=$2 covering family

  covering=$(fc-list ":charset=$codepoint" family | tr ',' '\n' | sort -u)
  while IFS= read -r family; do
    if grep -qxF -- "$family" <<< "$covering"; then
      printf '%s\n' "$family"
      return 0
    fi
  done < <(fc-match -s -f '%{family[0]}\n' "$pattern")
}

installed=''
command -v fc-list >/dev/null 2>&1 && installed=$(fc-list : family)
if grep -q 'Noto Color Emoji' <<< "$installed"; then
  export XDG_CONFIG_HOME="$REPO_ROOT/layers/desktop/home/xdg-defaults/.config"
  for pattern in monospace sans-serif serif 'JetBrainsMono Nerd Font'; do
    emoji=$(first_covering "$pattern" 1f600)
    [[ "$emoji" == 'Noto Color Emoji' ]] || \
      fail "$pattern dibuja emoji con ${emoji:-ninguna fuente} en vez de Noto Color Emoji"
    digit=$(first_covering "$pattern" 30)
    [[ -n "$digit" && "$digit" != 'Noto Color Emoji' ]] || \
      fail "$pattern dibuja dígitos con ${digit:-ninguna fuente}"
  done
  if grep -q 'JetBrainsMono Nerd Font' <<< "$installed"; then
    [[ $(first_covering monospace 41) == 'JetBrainsMono Nerd Font' ]] || \
      fail 'monospace no dibuja texto con JetBrainsMono Nerd Font'
  fi
else
  printf 'SKIP: resolución con fc-match (Noto Color Emoji no instalada)\n'
fi

# Waybar mixes text and icons in proportional widgets: the Propo variant gives
# Nerd icons their real advance, so a wide icon does not run into the next
# module (the plain variant keeps them at one cell and lets them overflow).
waybar_css="$REPO_ROOT/layers/wm/mangowm/home/mango/.local/share/dotfiles/theme/templates/mangowm/waybar.css"
grep -q 'font-family: "JetBrainsMono Nerd Font Propo"' "$waybar_css" || \
  fail 'waybar no usa JetBrainsMono Nerd Font Propo'

printf 'OK: fonts-smoke\n'
