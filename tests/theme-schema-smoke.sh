#!/usr/bin/env bash
# Renders every palette in themes/palettes with the shared, bspwm and MangoWM
# templates into a throwaway home, and checks that no marker is left over and
# that schema 2 roles land where the templates expect them.

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
ENGINE="$REPO_ROOT/layers/desktop/home/theme/.local/bin/dotfiles-theme"
BSPWM_TEMPLATES="$REPO_ROOT/layers/wm/bspwm/home/bspwm/.local/share/dotfiles/theme/templates/bspwm"
MANGO_TEMPLATES="$REPO_ROOT/layers/wm/mangowm/home/mango/.local/share/dotfiles/theme/templates/mangowm"
TEST_ROOT=""
TEST_TMP_PARENT=${DOTFILES_TEST_TMPDIR:-/tmp}

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  [[ -n "$TEST_ROOT" && "$TEST_ROOT" == "$TEST_TMP_PARENT"/dotfiles-theme-schema-smoke.* ]] || return 0
  rm -rf -- "$TEST_ROOT"
}

trap cleanup EXIT

[[ -x "$ENGINE" ]] || fail "falta el motor de temas: $ENGINE"
[[ -d "$TEST_TMP_PARENT" ]] || fail "no existe el directorio temporal: $TEST_TMP_PARENT"
TEST_ROOT=$(mktemp -d "$TEST_TMP_PARENT/dotfiles-theme-schema-smoke.XXXXXX")

# Value of key $2 in palette $1.
palette_value() {
  sed -n "s/^$2=//p" "$1"
}

# Fails unless file $1 holds the exact line $2.
expect_line() {
  grep -Fxq -- "$2" "$1" || fail "falta '$2' en ${1#"$TEST_ROOT"/}"
}

rendered=0
for palette in "$REPO_ROOT"/themes/palettes/*.conf; do
  [[ -f "$palette" ]] || continue
  id=$(basename -- "$palette" .conf)
  home="$TEST_ROOT/$id"
  mkdir -p "$home/.local/share/dotfiles/theme/templates"
  cp -R -- "$BSPWM_TEMPLATES" "$MANGO_TEMPLATES" "$home/.local/share/dotfiles/theme/templates/"
  revision=$(env -u DOTFILES_THEME HOME="$home" XDG_STATE_HOME="$home/.local/state" \
    XDG_DATA_HOME="$home/.local/share" XDG_CONFIG_HOME="$home/.config" \
    "$ENGINE" render "$id") || fail "no se pudo renderizar $id"

  # grep exits 1 when no marker is left; 2 is an error, never a pass.
  status=0
  leftovers=$(grep -rlF '{{' "$revision") || status=$?
  case "$status" in
    0) fail "marcadores sin renderizar en $id: $leftovers" ;;
    1) ;;
    *) fail "grep falló ($status) en $id" ;;
  esac
  expect_line "$revision/metadata" 'schema=2'
  expect_line "$revision/metadata" "id=$id"
  expect_line "$revision/mangowm/foot.ini" "regular5=$(palette_value "$palette" ansi_magenta | tr -d '#')"
  expect_line "$revision/mangowm/foot.ini" "bright7=$(palette_value "$palette" ansi_bright_white | tr -d '#')"
  expect_line "$revision/mangowm/mango.conf" "border_color=0x$(palette_value "$palette" border | tr -d '#')ff"
  expect_line "$revision/mangowm/waybar.css" "@define-color base $(palette_value "$palette" background);"
  expect_line "$revision/bspwm/polybar-colors.ini" "ALTWHITE = $(palette_value "$palette" ansi_white)"
  expect_line "$revision/gtk.css" "@define-color accent_color $(palette_value "$palette" accent);"
  ((rendered++)) || true
done

(( rendered >= 50 )) || fail "se esperaban al menos 50 paletas, renderizadas: $rendered"

printf 'OK: %d paletas schema 2 renderizadas sin marcadores pendientes\n' "$rendered"
