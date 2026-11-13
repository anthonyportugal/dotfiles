#!/usr/bin/env bash
# Cursor roles: every palette's cursor_theme/cursor_size reach MangoWM (config
# and session environment), bspwm (Xcursor resources) and GTK (gsettings on
# `set`). A missing cursor theme falls back to the toolkit default.

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
ENGINE="$REPO_ROOT/layers/desktop/home/theme/.local/bin/dotfiles-theme"
MANGOWM_TEMPLATES="$REPO_ROOT/layers/wm/mangowm/home/mango/.local/share/dotfiles/theme/templates/mangowm"
BSPWM_TEMPLATES="$REPO_ROOT/layers/wm/bspwm/home/bspwm/.local/share/dotfiles/theme/templates/bspwm"
TEST_ROOT=''

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  [[ -n "$TEST_ROOT" && "$TEST_ROOT" == /tmp/cursor-smoke.* ]] || return 0
  find "$TEST_ROOT" -mindepth 1 -delete
  find "$TEST_ROOT" -depth -type d -empty -delete
}
trap cleanup EXIT

TEST_ROOT=$(mktemp -d /tmp/cursor-smoke.XXXXXX)
mkdir -p "$TEST_ROOT/bin"
# gsettings double: records every call.
cat > "$TEST_ROOT/bin/gsettings" <<'EOF'
#!/bin/sh
printf 'gsettings %s\n' "$*" >> "$CURSOR_TEST_LOG"
EOF
# notify-send double: `set` never reaches the host's notification daemon.
printf '#!/bin/sh\nexit 0\n' > "$TEST_ROOT/bin/notify-send"
chmod +x "$TEST_ROOT/bin/gsettings" "$TEST_ROOT/bin/notify-send"
export CURSOR_TEST_LOG="$TEST_ROOT/commands.log"
: > "$CURSOR_TEST_LOG"

# A home with both WM template directories installed, as Stow links them.
new_home() {
  local home=$1
  mkdir -p "$home/.local/share/dotfiles/theme/templates"
  ln -s "$MANGOWM_TEMPLATES" "$home/.local/share/dotfiles/theme/templates/mangowm"
  ln -s "$BSPWM_TEMPLATES" "$home/.local/share/dotfiles/theme/templates/bspwm"
}

engine_in() {
  local home=$1 engine=$2
  shift 2
  env -u DOTFILES_THEME -u XDG_STATE_HOME -u XDG_DATA_HOME -u XDG_CONFIG_HOME \
    HOME="$home" PATH="$TEST_ROOT/bin:/usr/bin:/bin" CURSOR_TEST_LOG="$CURSOR_TEST_LOG" \
    "$engine" "$@"
}

check_render() {
  local revision=$1 theme=$2 size=$3 mango bspwm

  mango="$revision/mangowm/mango.conf"
  bspwm="$revision/bspwm/bspwm.env"
  for line in "cursor_theme=$theme" "cursor_size=$size" \
              "env=XCURSOR_THEME,$theme" "env=XCURSOR_SIZE,$size"; do
    grep -Fxq -- "$line" "$mango" || fail "mango.conf no contiene '$line' ($revision)"
  done
  for line in "BSPWM_CURSOR_THEME='$theme'" "BSPWM_CURSOR_SIZE='$size'"; do
    grep -Fxq -- "$line" "$bspwm" || fail "bspwm.env no contiene \"$line\" ($revision)"
  done
}

# 1. Every shipped palette renders its own cursor roles.
HOME_ALL="$TEST_ROOT/home-all"
new_home "$HOME_ALL"
count=0
for palette in "$REPO_ROOT"/themes/palettes/*.conf; do
  id=$(basename -- "$palette" .conf)
  theme=$(sed -n 's/^cursor_theme=//p' "$palette")
  size=$(sed -n 's/^cursor_size=//p' "$palette")
  revision=$(engine_in "$HOME_ALL" "$ENGINE" render "$id") || fail "render $id falló"
  check_render "$revision" "$theme" "$size"
  count=$((count + 1))
done
(( count > 0 )) || fail 'no hay paletas'

# 2. The values come from the palette, not from the templates: a palette with
# another cursor renders that cursor.
FAKE_REPO="$TEST_ROOT/repo"
mkdir -p "$FAKE_REPO/bin" "$FAKE_REPO/themes/palettes"
cp -- "$ENGINE" "$FAKE_REPO/bin/dotfiles-theme"
cp -R -- "$REPO_ROOT/themes/templates" "$FAKE_REPO/themes/templates"
sed -e 's/^id=.*/id=catppuccin-mocha-cursor/' -e 's/^cursor_theme=.*/cursor_theme=Test-Cursor_2.0/' \
    -e 's/^cursor_size=.*/cursor_size=32/' \
  "$REPO_ROOT/themes/palettes/catppuccin-mocha-pink.conf" \
  > "$FAKE_REPO/themes/palettes/catppuccin-mocha-cursor.conf"
HOME_CUSTOM="$TEST_ROOT/home-custom"
new_home "$HOME_CUSTOM"
revision=$(engine_in "$HOME_CUSTOM" "$FAKE_REPO/bin/dotfiles-theme" render catppuccin-mocha-cursor) || \
  fail 'render de la paleta con otro cursor falló'
check_render "$revision" Test-Cursor_2.0 32
# mango's own parser accepts the rendered keys when it is installed.
if command -v mango >/dev/null 2>&1; then
  output=$(mango -p -c "$revision/mangowm/mango.conf" 2>&1) || fail "mango rechazó mango.conf: $output"
fi

# 3. `set` applies the cursor to GTK through gsettings.
: > "$CURSOR_TEST_LOG"
engine_in "$HOME_CUSTOM" "$FAKE_REPO/bin/dotfiles-theme" set catppuccin-mocha-cursor >/dev/null || \
  fail 'set de la paleta con otro cursor falló'
grep -Fxq 'gsettings set org.gnome.desktop.interface cursor-theme Test-Cursor_2.0' "$CURSOR_TEST_LOG" || \
  fail "set no aplicó cursor-theme a GTK: $(<"$CURSOR_TEST_LOG")"
grep -Fxq 'gsettings set org.gnome.desktop.interface cursor-size 32' "$CURSOR_TEST_LOG" || \
  fail "set no aplicó cursor-size a GTK: $(<"$CURSOR_TEST_LOG")"

printf 'PASS: cursor roles reach MangoWM, bspwm and GTK for %d palettes\n' "$count"
