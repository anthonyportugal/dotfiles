#!/usr/bin/env bash
# Renders every palette with the shared and MangoWM templates into a
# throwaway home and checks the application outputs: each one exists, has no
# leftover marker and carries the palette values, and the stowed configs read
# it from the rendered theme.

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
ENGINE="$REPO_ROOT/layers/desktop/home/theme/.local/bin/dotfiles-theme"
SHARED_TEMPLATES="$REPO_ROOT/themes/templates"
MANGO_TEMPLATES="$REPO_ROOT/layers/wm/mangowm/home/mango/.local/share/dotfiles/theme/templates/mangowm"
DESKTOP_HOME="$REPO_ROOT/layers/desktop/home"
# The literal path the stowed configs write; their apps expand the tilde.
# shellcheck disable=SC2088
CURRENT_PATH='~/.local/state/dotfiles/theme/current'
TEST_ROOT=""
TEST_TMP_PARENT=${DOTFILES_TEST_TMPDIR:-/tmp}

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  [[ -n "$TEST_ROOT" && "$TEST_ROOT" == "$TEST_TMP_PARENT"/dotfiles-theme-apps-smoke.* ]] || return 0
  rm -rf -- "$TEST_ROOT"
}

trap cleanup EXIT

[[ -x "$ENGINE" ]] || fail "falta el motor de temas: $ENGINE"
[[ -d "$TEST_TMP_PARENT" ]] || fail "no existe el directorio temporal: $TEST_TMP_PARENT"
TEST_ROOT=$(mktemp -d "$TEST_TMP_PARENT/dotfiles-theme-apps-smoke.XXXXXX")

# Value of key $2 in palette $1, and the same color without its '#'.
palette_value() {
  sed -n "s/^$2=//p" "$1"
}

raw_value() {
  local value
  value=$(palette_value "$1" "$2")
  printf '%s\n' "${value#\#}"
}

# Fails unless file $1 holds the exact line $2.
expect_line() {
  grep -Fxq -- "$2" "$1" || fail "falta '$2' en ${1#"$TEST_ROOT"/}"
}

# Fails unless file $1 exists, is not empty and has no {{ marker left; a grep
# error (exit 2) fails too instead of passing as "no match".
expect_rendered() {
  local status=0

  [[ -s "$1" ]] || fail "output vacío o ausente: ${1#"$TEST_ROOT"/}"
  grep -Fq '{{' "$1" || status=$?
  case "$status" in
    0) fail "marcadores sin renderizar en ${1#"$TEST_ROOT"/}" ;;
    1) ;;
    *) fail "grep falló ($status) en ${1#"$TEST_ROOT"/}" ;;
  esac
}

# Fails when template $1 still holds a literal #rrggbb color.
expect_no_hex() {
  local status=0

  grep -Eq '#[0-9a-fA-F]{6}\b' "$1" || status=$?
  case "$status" in
    0) fail "${1#"$REPO_ROOT"/} conserva colores hexadecimales fijos" ;;
    1) ;;
    *) fail "grep falló ($status) en ${1#"$REPO_ROOT"/}" ;;
  esac
}

# Section [colors-dark] of foot config $1, up to the end of the file.
foot_colors() {
  sed -n '/^\[colors-dark\]$/,$p' "$1"
}

# Renders palette $1 into the throwaway home $2 and prints the revision.
render_in() {
  local id=$1 home=$2

  mkdir -p "$home/.local/share/dotfiles/theme/templates"
  cp -R -- "$MANGO_TEMPLATES" "$home/.local/share/dotfiles/theme/templates/"
  env -u DOTFILES_THEME HOME="$home" XDG_STATE_HOME="$home/.local/state" \
    XDG_DATA_HOME="$home/.local/share" XDG_CONFIG_HOME="$home/.config" \
    "$ENGINE" render "$id" || fail "no se pudo renderizar $id"
}

# Terminals: alacritty imports and foot includes the rendered file; both
# follow the palette, and foot shares its color block with MangoWM.
check_terminals() {
  local palette=$1 revision=$2 index color
  local -a ansi=(black red green yellow blue magenta cyan white)

  expect_rendered "$revision/alacritty/theme.toml"
  expect_line "$revision/alacritty/theme.toml" "background = \"$(palette_value "$palette" background)\""
  expect_line "$revision/alacritty/theme.toml" "foreground = \"$(palette_value "$palette" foreground)\""
  expect_line "$revision/alacritty/theme.toml" "cursor = \"$(palette_value "$palette" cursor)\""
  expect_line "$revision/alacritty/theme.toml" "family = \"$(palette_value "$palette" font_mono)\""
  for index in "${!ansi[@]}"; do
    color=${ansi[$index]}
    expect_line "$revision/alacritty/theme.toml" "$color = \"$(palette_value "$palette" "ansi_$color")\""
  done
  python3 -c 'import sys, tomllib; tomllib.load(open(sys.argv[1], "rb"))' \
    "$revision/alacritty/theme.toml" || fail "alacritty/theme.toml no es TOML válido"

  expect_rendered "$revision/foot/theme.ini"
  expect_line "$revision/foot/theme.ini" "font=$(palette_value "$palette" font_mono):size=11"
  expect_line "$revision/foot/theme.ini" "background=$(raw_value "$palette" background)"
  expect_line "$revision/foot/theme.ini" "cursor=$(raw_value "$palette" cursor_fg) $(raw_value "$palette" cursor)"
  expect_line "$revision/foot/theme.ini" "urls=$(raw_value "$palette" accent)"
  for index in "${!ansi[@]}"; do
    color=${ansi[$index]}
    expect_line "$revision/foot/theme.ini" "regular$index=$(raw_value "$palette" "ansi_$color")"
    expect_line "$revision/foot/theme.ini" "bright$index=$(raw_value "$palette" "ansi_bright_$color")"
  done
  [[ "$(foot_colors "$revision/foot/theme.ini")" == "$(foot_colors "$revision/mangowm/foot.ini")" ]] || \
    fail "foot y MangoWM renderizan bloques de color distintos"
}

rendered=0
for palette in "$REPO_ROOT"/themes/palettes/*.conf; do
  [[ -f "$palette" ]] || continue
  id=$(basename -- "$palette" .conf)
  revision=$(render_in "$id" "$TEST_ROOT/$id")
  check_terminals "$palette" "$revision"
  ((rendered++)) || true
done
(( rendered >= 14 )) || fail "se esperaban al menos 14 paletas, renderizadas: $rendered"

# One color definition for foot: the MangoWM template carries the same
# [colors-dark] block as the shared template.
[[ -n "$(foot_colors "$SHARED_TEMPLATES/foot/theme.ini")" ]] || \
  fail "la plantilla compartida de foot no define [colors-dark]"
[[ "$(foot_colors "$SHARED_TEMPLATES/foot/theme.ini")" == "$(foot_colors "$MANGO_TEMPLATES/foot.ini")" ]] || \
  fail "la plantilla de foot de MangoWM diverge del bloque de color compartido"
grep -Fxq 'font={{font_mono}}:size=10' "$MANGO_TEMPLATES/foot.ini" || \
  fail "la plantilla de foot de MangoWM no toma la fuente de font_mono"

# The stowed terminal configs read the rendered files and keep no colors.
ALACRITTY="$DESKTOP_HOME/alacritty/.config/alacritty/alacritty.toml"
FOOT="$DESKTOP_HOME/foot/.config/foot/foot.ini"
expect_line "$ALACRITTY" "import = [\"$CURRENT_PATH/alacritty/theme.toml\"]"
expect_no_hex "$ALACRITTY"
grep -Eq '^family' "$ALACRITTY" && fail "alacritty.toml fija la familia de la fuente"
python3 -c 'import sys, tomllib; tomllib.load(open(sys.argv[1], "rb"))' "$ALACRITTY" || \
  fail "alacritty.toml no es TOML válido"
expect_line "$FOOT" "include=$CURRENT_PATH/foot/theme.ini"
grep -Eq '^(\[colors|font=|regular[0-7]=)' "$FOOT" && fail "foot.ini define colores o fuentes propios"
for template in alacritty/theme.toml foot/theme.ini; do
  expect_no_hex "$SHARED_TEMPLATES/$template"
done

# foot accepts the stowed config with the rendered include, read through ~.
if command -v foot >/dev/null 2>&1; then
  home="$TEST_ROOT/catppuccin-mocha-pink"
  HOME="$home" foot --check-config --config="$FOOT" || fail "foot rechazó foot.ini con el tema renderizado"
  HOME="$home" foot --check-config --config="$home/.local/state/dotfiles/theme/current/mangowm/foot.ini" || \
    fail "foot rechazó la plantilla de MangoWM"
fi

printf 'OK: %d paletas renderizadas para las aplicaciones\n' "$rendered"
