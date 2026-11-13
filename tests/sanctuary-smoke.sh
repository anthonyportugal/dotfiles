#!/usr/bin/env bash
# Sanctuary palettes: the committed themes/palettes/sanctuary-*.conf equal the
# output of themes/tools/generate-sanctuary-palettes over the vendored
# @sanctuary-ds/tokens palette.json, the engine lists and renders them, and
# `set` maps every pigment to its GNOME accent. gsettings and notify-send are
# doubles so the host session is never touched.

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
ENGINE="$REPO_ROOT/layers/desktop/home/theme/.local/bin/dotfiles-theme"
GENERATOR="$REPO_ROOT/themes/tools/generate-sanctuary-palettes"
PALETTES="$REPO_ROOT/themes/palettes"
TEST_TMP_PARENT=${DOTFILES_TEST_TMPDIR:-/tmp}
TEST_ROOT=''

FLAVORS=(compline vespers matins)
PIGMENTS=(amber amethyst azure cobalt ember gilt indigo murrey rose ruby verdure viridian)

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  [[ -n "$TEST_ROOT" && "$TEST_ROOT" == "$TEST_TMP_PARENT"/sanctuary-smoke.* ]] || return 0
  rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT

[[ -x "$ENGINE" ]] || fail "falta el motor ejecutable: $ENGINE"
[[ -x "$GENERATOR" ]] || fail "falta el generador ejecutable: themes/tools/generate-sanctuary-palettes"
TEST_ROOT=$(mktemp -d "$TEST_TMP_PARENT/sanctuary-smoke.XXXXXX")

STUBS="$TEST_ROOT/stubs"
mkdir -p "$STUBS"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> "%s/gsettings.log"\n' "$TEST_ROOT" > "$STUBS/gsettings"
printf '#!/usr/bin/env bash\nexit 0\n' > "$STUBS/notify-send"
chmod +x "$STUBS/gsettings" "$STUBS/notify-send"

# Runs the engine with HOME and XDG dirs inside the throwaway home $1.
theme_in() {
  local home=$1
  shift
  env -u DOTFILES_THEME PATH="$STUBS:$PATH" HOME="$home" \
    XDG_STATE_HOME="$home/.local/state" XDG_DATA_HOME="$home/.local/share" \
    XDG_CONFIG_HOME="$home/.config" "$ENGINE" "$@"
}

expect_line() {
  grep -Fxq -- "$2" "$1" || fail "falta '$2' en ${1#"$REPO_ROOT"/}"
}

# 1. The committed palettes are the generator output.
output=$("$GENERATOR" --check 2>&1) || fail "generate-sanctuary-palettes --check falló: $output"

# 2. Exactly 3 flavors x 12 pigments, never lauds, same key order as Catppuccin.
mapfile -t sanctuary < <(find "$PALETTES" -maxdepth 1 -name 'sanctuary-*.conf' -printf '%f\n' | LC_ALL=C sort)
(( ${#sanctuary[@]} == 36 )) || fail "se esperaban 36 paletas Sanctuary, hay ${#sanctuary[@]}"
[[ ! -e "$PALETTES/sanctuary-lauds-cobalt.conf" ]] || fail "lauds no debe generarse"
reference_keys=$(sed 's/=.*//' "$PALETTES/catppuccin-mocha-pink.conf")
for flavor in "${FLAVORS[@]}"; do
  for pigment in "${PIGMENTS[@]}"; do
    palette="$PALETTES/sanctuary-$flavor-$pigment.conf"
    [[ -f "$palette" ]] || fail "falta la paleta sanctuary-$flavor-$pigment"
    [[ "$(sed 's/=.*//' "$palette")" == "$reference_keys" ]] || \
      fail "el orden de claves de sanctuary-$flavor-$pigment difiere de Catppuccin"
    expect_line "$palette" "id=sanctuary-$flavor-$pigment"
    expect_line "$palette" 'family=sanctuary'
    expect_line "$palette" "flavour=$flavor"
    expect_line "$palette" "accent_name=$pigment"
    if grep -Eq '^[a-z_]+=#[0-9a-f]*[A-F]' "$palette"; then
      fail "sanctuary-$flavor-$pigment tiene hex en mayúsculas"
    fi
  done
done

# 3. The S9a mapping, spot-checked against palette.json 0.3.2 (compline).
P="$PALETTES/sanctuary-compline-cobalt.conf"
for line in schema=2 background_deep=#090b10 background_alt=#090b10 background=#0f1217 \
  surface=#1d2026 foreground=#eee7d9 border=#393d46 accent=#9bc1fb accent_fg=#001237 \
  selection_bg=#043377 selection_fg=#e1ecfe cursor=#9bc1fb cursor_fg=#001237 \
  hue_blue=#9bc1fb 'font_mono=JetBrainsMono Nerd Font' 'font_text=Hanken Grotesk' \
  'font_display=Cormorant Garamond' font_inscription=Cinzel \
  cursor_theme=Bibata-Modern-Classic cursor_size=24; do
  expect_line "$P" "$line"
done
# matins has its own glass: cobalt differs from compline.
expect_line "$PALETTES/sanctuary-matins-cobalt.conf" 'accent=#6ca3fa'
expect_line "$PALETTES/sanctuary-matins-cobalt.conf" 'background=#040408'

# 4. list holds the 14 Catppuccin and the 36 Sanctuary themes, nothing else.
H="$TEST_ROOT/home"
mkdir -p "$H"
mapfile -t listed < <(theme_in "$H" list)
catppuccin=0 others=0
for theme in "${listed[@]}"; do
  case "$theme" in
    catppuccin-mocha-*) ((catppuccin++)) || true ;;
    sanctuary-compline-*|sanctuary-vespers-*|sanctuary-matins-*) ;;
    *) ((others++)) || true ;;
  esac
done
(( catppuccin == 14 )) || fail "list devolvió $catppuccin temas Catppuccin en lugar de 14"
(( others == 0 )) || fail "list devolvió temas inesperados: ${listed[*]}"
for flavor in "${FLAVORS[@]}"; do
  for pigment in "${PIGMENTS[@]}"; do
    printf '%s\n' "${listed[@]}" | grep -Fxq "sanctuary-$flavor-$pigment" || \
      fail "list no incluye sanctuary-$flavor-$pigment"
  done
done

# 5. set renders the theme and syncs the nearest GNOME accent (OKLCH hue).
declare -A gnome=(
  [ruby]=red [ember]=orange [amber]=yellow [gilt]=yellow [verdure]=green
  [viridian]=green [azure]=teal [cobalt]=blue [indigo]=blue [amethyst]=purple
  [murrey]=pink [rose]=pink
)
STATE="$H/.local/state/dotfiles/theme"
for pigment in "${PIGMENTS[@]}"; do
  : > "$TEST_ROOT/gsettings.log"
  output=$(theme_in "$H" set "sanctuary-compline-$pigment" 2>&1) || \
    fail "set sanctuary-compline-$pigment falló: $output"
  grep -Fxq "set org.gnome.desktop.interface accent-color ${gnome[$pigment]}" "$TEST_ROOT/gsettings.log" || \
    fail "set sanctuary-compline-$pigment no sincronizó el acento GNOME ${gnome[$pigment]}: $(<"$TEST_ROOT/gsettings.log")"
done
: > "$TEST_ROOT/gsettings.log"
theme_in "$H" set sanctuary-compline-cobalt >/dev/null || fail "set sanctuary-compline-cobalt falló"
expect_line "$TEST_ROOT/gsettings.log" 'set org.gnome.desktop.interface accent-color blue'
[[ "$(<"$STATE/selected")" == sanctuary-compline-cobalt ]] || fail "set no guardó sanctuary-compline-cobalt"
expect_line "$STATE/current/gtk.css" '@define-color accent_color #9bc1fb;'
expect_line "$STATE/current/metadata" 'family=sanctuary'
[[ "$(theme_in "$H" current)" == 'sanctuary-compline-cobalt (acento: cobalt, #9bc1fb)' ]] || \
  fail "current no informa del tema Sanctuary"

# 6. --check reports drift and writes nothing; a write repairs it; the pin
#    rejects a changed source.
FAKE="$TEST_ROOT/repo/themes"
mkdir -p "$FAKE"
cp -R -- "$REPO_ROOT/themes/tools" "$REPO_ROOT/themes/sources" "$PALETTES" "$FAKE/"
FAKE_GEN="$FAKE/tools/generate-sanctuary-palettes"
sed -i 's/^accent=.*/accent=#000000/' "$FAKE/palettes/sanctuary-vespers-ruby.conf"
rm -- "$FAKE/palettes/sanctuary-matins-gilt.conf"
cp -- "$FAKE/palettes/sanctuary-compline-rose.conf" "$FAKE/palettes/sanctuary-lauds-rose.conf"
before=$(cd "$FAKE/palettes" && sha256sum -- *.conf)
if output=$("$FAKE_GEN" --check 2>&1); then
  fail "--check aceptó paletas desactualizadas"
fi
for name in sanctuary-vespers-ruby.conf sanctuary-matins-gilt.conf sanctuary-lauds-rose.conf; do
  [[ "$output" == *"$name"* ]] || fail "--check no informó $name: $output"
done
[[ "$output" != *sanctuary-compline-cobalt.conf* ]] || fail "--check informó una paleta al día: $output"
[[ "$(cd "$FAKE/palettes" && sha256sum -- *.conf)" == "$before" ]] || fail "--check escribió paletas"
"$FAKE_GEN" >/dev/null || fail "el generador no pudo escribir las paletas"
output=$("$FAKE_GEN" --check 2>&1) || fail "--check falló tras regenerar: $output"
[[ ! -e "$FAKE/palettes/sanctuary-lauds-rose.conf" ]] || fail "el generador dejó una paleta Sanctuary obsoleta"
[[ -f "$FAKE/palettes/catppuccin-mocha-pink.conf" ]] || fail "el generador tocó las paletas Catppuccin"
cmp -s -- "$FAKE/palettes/sanctuary-vespers-ruby.conf" "$PALETTES/sanctuary-vespers-ruby.conf" || \
  fail "el generador no restauró sanctuary-vespers-ruby"

SOURCE=$(find "$FAKE/sources" -name palette.json)
printf ' ' >> "$SOURCE"
before=$(cd "$FAKE/palettes" && sha256sum -- *.conf)
if output=$("$FAKE_GEN" 2>&1); then
  fail "el generador aceptó un palette.json con otro sha256"
fi
[[ "$output" == *sha256* ]] || fail "el generador falló por otra causa: $output"
[[ "$(cd "$FAKE/palettes" && sha256sum -- *.conf)" == "$before" ]] || \
  fail "el generador escribió con un origen no fijado"

printf 'OK: 36 paletas Sanctuary generadas, listadas y con acento GNOME\n'
