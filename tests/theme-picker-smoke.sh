#!/usr/bin/env bash
# Theme picker: the engine listing and swatches (dotfiles-theme list --tsv),
# the MangoWM (fuzzel) and bspwm (rofi) three-level menus and the fzf TUI
# (dotfiles-theme pick). Every program the code can reach runs from a PATH
# made of test doubles and an allow-list of coreutils, so no real menu,
# notification or session program can start.

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
ENGINE="$REPO_ROOT/layers/desktop/home/theme/.local/bin/dotfiles-theme"
MANGO_HOME="$REPO_ROOT/layers/wm/mangowm/home/mango"
BSPWM_CONFIG="$REPO_ROOT/layers/wm/bspwm/home/bspwm/.config/bspwm"
TEST_TMP_PARENT=${DOTFILES_TEST_TMPDIR:-/tmp}
TEST_ROOT=''

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  [[ -n "$TEST_ROOT" && "$TEST_ROOT" == "$TEST_TMP_PARENT"/theme-picker-smoke.* ]] || return 0
  rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT

TEST_ROOT=$(mktemp -d "$TEST_TMP_PARENT/theme-picker-smoke.XXXXXX")
CHECKOUT_STATE=$(git -C "$REPO_ROOT" status --porcelain)
BIN="$TEST_ROOT/bin"
H="$TEST_ROOT/home"
STATE="$H/.local/state/dotfiles/theme"
export PICKER_LOG="$TEST_ROOT/picker.log" PICKER_DIR="$TEST_ROOT/picker"
mkdir -p -- "$BIN" "$H/.local/bin" "$H/.config" "$PICKER_DIR"

# Allow-list of the tools the scripts need; nothing else from the host.
for tool in bash env cat chmod cut dirname find flock grep head ln ls mkdir \
  mktemp mv readlink realpath rm sed sha256sum sort tr wc awk uniq basename \
  touch stat cmp; do
  path=$(command -v "$tool") || fail "falta la herramienta $tool"
  ln -s -- "$path" "$BIN/$tool"
done
for tool in fuzzel rofi fzf; do
  ln -s -- "$SCRIPT_DIR/fakes/picker" "$BIN/$tool"
done
for tool in notify-send gsettings; do
  ln -s -- "$SCRIPT_DIR/fakes/recorder" "$BIN/$tool"
done

# Runs $@ with the test PATH, HOME and XDG dirs; the menu answers come from
# the words in $1 (1-based rows or "esc").
in_home() {
  local script=$1
  shift
  printf '%s\n' "$script" > "$PICKER_DIR/script"
  rm -f -- "$PICKER_DIR/count" "$PICKER_DIR"/*.in
  : > "$PICKER_LOG"
  env -i PATH="$BIN" HOME="$H" LANG=C.UTF-8 LC_ALL=C.UTF-8 \
    XDG_STATE_HOME="$H/.local/state" XDG_DATA_HOME="$H/.local/share" \
    XDG_CONFIG_HOME="$H/.config" PICKER_LOG="$PICKER_LOG" PICKER_DIR="$PICKER_DIR" \
    "$@"
}

field() {
  awk -F '\t' -v id="$1" -v n="$2" '$1 == id { print $n }'
}

# Labels and icons of the rows menu call $1 received ("label\0icon\x1fpath").
labels() {
  tr '\000' '\036' < "$PICKER_DIR/$1.in" | sed 's/\x1e.*$//'
}
icons() {
  tr '\000' '\036' < "$PICKER_DIR/$1.in" | sed -n 's/^.*\x1eicon\x1f//p'
}
calls() {
  cat "$PICKER_DIR/count" 2>/dev/null || printf '0\n'
}
# Arguments of menu call $1, one per line.
call_args() {
  awk -v n="$1" '/^=== / { on = ($3 == n); next } on' "$PICKER_LOG"
}
selected() {
  cat "$STATE/selected" 2>/dev/null || true
}
# Every icon of menu call $1 is an existing swatch, as many as its rows.
check_icons() {
  local icon count=0
  while IFS= read -r icon; do
    [[ "$icon" == "$STATE/swatches/"*.svg && -s "$icon" ]] || \
      fail "icono inexistente en la llamada $1: $icon"
    count=$((count + 1))
  done < <(icons "$1")
  (( count == $(labels "$1" | wc -l) )) || fail "filas sin icono en la llamada $1"
}

# --- 1. Engine listing and swatches ---------------------------------------

mapfile -t plain < <(in_home '' "$ENGINE" list)
(( ${#plain[@]} == 50 )) || fail "list devolvió ${#plain[@]} temas"
[[ "${plain[0]}" == catppuccin-mocha-blue && "${plain[0]}" != *$'\t'* ]] || \
  fail "list cambió su salida: ${plain[0]}"

tsv=$(in_home '' "$ENGINE" list --tsv)
(( $(wc -l <<< "$tsv") == 50 )) || fail 'list --tsv no devolvió 50 líneas'
awk -F '\t' 'NF != 7 { exit 1 }' <<< "$tsv" || fail 'list --tsv sin 7 columnas'
[[ "$(cut -f1 <<< "$tsv")" == "$(printf '%s\n' "${plain[@]}")" ]] || \
  fail 'list --tsv no sigue el orden de list'
expected=$'catppuccin-mocha-pink\tcatppuccin\tmocha\tpink\t#f5c2e7\t1\t'"$STATE/swatches/catppuccin-mocha-pink.svg"
grep -Fxq "$expected" <<< "$tsv" || fail "fila de pink inesperada: $(grep pink <<< "$tsv")"
(( $(awk -F '\t' '$6 == 1' <<< "$tsv" | wc -l) == 1 )) || fail 'más de un tema activo'
grep -q $'^sanctuary-compline-cobalt\tsanctuary\tcompline\tcobalt\t#[0-9a-f]\\{6\\}\t0\t' <<< "$tsv" || \
  fail 'fila de sanctuary-compline-cobalt inesperada'

# Every swatch exists and draws the accent on the theme background.
while IFS=$'\t' read -r id _ _ _ accent _ swatch; do
  [[ -s "$swatch" ]] || fail "falta la muestra de $id"
  grep -Fq "fill=\"$accent\"" "$swatch" || fail "la muestra de $id no tiene su acento"
  background=$(grep '^background=' "$REPO_ROOT/themes/palettes/$id.conf" | cut -d= -f2)
  grep -Fq "fill=\"$background\"" "$swatch" || fail "la muestra de $id no tiene su fondo"
done <<< "$tsv"
[[ -z $(find "$REPO_ROOT/themes" -name '*.svg') ]] || fail 'se escribieron muestras en el repositorio'

# A fresh swatch is kept as is; a stale or missing one is written again.
swatch="$STATE/swatches/sanctuary-compline-cobalt.svg"
good=$(cat "$swatch")
touch -d '2000-01-01 00:00:00 UTC' "$swatch"
in_home '' "$ENGINE" list --tsv >/dev/null
[[ $(stat -c %Y "$swatch") == 946684800 ]] || fail 'reescribió una muestra vigente'
printf 'viejo\n' > "$swatch"
rm -f -- "$STATE/swatches/catppuccin-mocha-red.svg"
in_home '' "$ENGINE" list --tsv >/dev/null
[[ "$(cat "$swatch")" == "$good" ]] || fail 'no regeneró una muestra desactualizada'
[[ -s "$STATE/swatches/catppuccin-mocha-red.svg" ]] || fail 'no regeneró una muestra ausente'

# The active marker follows the saved selection.
printf 'sanctuary-vespers-ruby\n' > "$STATE/selected"
tsv=$(in_home '' "$ENGINE" list --tsv)
[[ $(field sanctuary-vespers-ruby 6 <<< "$tsv") == 1 && \
   $(field catppuccin-mocha-pink 6 <<< "$tsv") == 0 ]] || fail 'list --tsv no siguió la selección'
rm -f -- "$STATE/selected"

status=0
in_home '' "$ENGINE" list --json >/dev/null 2>&1 || status=$?
(( status == 2 )) || fail "list con una opción desconocida devolvió $status"
help=$(in_home '' "$ENGINE" --help)
[[ "$help" == *'list [--tsv]'* ]] || fail 'la ayuda no documenta list --tsv'

# --- 2. MangoWM: mango-theme menu (fuzzel through mangowm_menu) ------------

mkdir -p -- "$H/.local/lib/mangowm" "$H/.local/share/dotfiles/theme/templates"
ln -s -- "$ENGINE" "$H/.local/bin/dotfiles-theme"
ln -s -- "$MANGO_HOME/.local/bin/mango-theme" "$H/.local/bin/mango-theme"
ln -s -- "$MANGO_HOME/.local/lib/mangowm/common" "$H/.local/lib/mangowm/common"
ln -s -- "$MANGO_HOME/.local/share/dotfiles/theme/templates/mangowm" \
  "$H/.local/share/dotfiles/theme/templates/mangowm"
mango_menu() {
  in_home "$1" "$H/.local/bin/mango-theme" menu
}

# Esc on the first level exits without applying anything.
mango_menu 'esc' || fail 'Esc en el primer nivel no salió con 0'
(( $(calls) == 1 )) || fail "Esc en el primer nivel abrió $(calls) menús"
[[ "$(labels 1)" == $'Catppuccin  (actual)\nSanctuary' ]] || fail "familias: $(labels 1)"
[[ "$(icons 1)" == "$STATE/swatches/catppuccin-mocha-pink.svg"$'\n'"$STATE/swatches/sanctuary-compline-amber.svg" ]] || \
  fail "iconos de familia: $(icons 1)"
check_icons 1
call_args 1 | grep -qx -- '--prompt=Tema ❯ ' || fail "prompt de familias: $(call_args 1)"
[[ -z "$(selected)" ]] || fail 'Esc aplicó un tema'

# Catppuccin has one flavour (mocha): its accents come next, and Esc there
# goes back to the families.
mango_menu '1 esc esc'
(( $(calls) == 3 )) || fail "Catppuccin, Esc, Esc abrió $(calls) menús"
(( $(labels 2 | wc -l) == 14 )) || fail "acentos de Catppuccin: $(labels 2 | wc -l)"
labels 2 | grep -qx 'Pink  (actual)' || fail "Pink sin marca de activo: $(labels 2)"
labels 2 | grep -qx 'Rosewater' || fail 'falta Rosewater'
(( $(labels 2 | grep -c 'actual') == 1 )) || fail 'más de un acento marcado'
check_icons 2
[[ "$(icons 2 | head -1)" == "$STATE/swatches/catppuccin-mocha-blue.svg" ]] || \
  fail "icono del primer acento: $(icons 2 | head -1)"
call_args 2 | grep -qx -- '--prompt=Catppuccin · Mocha ❯ ' || fail "prompt de acentos: $(call_args 2)"
[[ "$(labels 3)" == "$(labels 1)" ]] || fail 'Esc en los acentos no volvió a las familias'
[[ -z "$(selected)" ]] || fail 'Esc aplicó un tema'

# Sanctuary has three flavours; Esc steps back one level at a time.
mango_menu '2 1 esc esc esc'
(( $(calls) == 5 )) || fail "Sanctuary → Compline → Esc ×3 abrió $(calls) menús"
[[ "$(labels 2)" == $'Compline\nMatins\nVespers' ]] || fail "flavours: $(labels 2)"
check_icons 2
call_args 2 | grep -qx -- '--prompt=Sanctuary ❯ ' || fail "prompt de flavours: $(call_args 2)"
[[ "$(labels 3)" == $'Amber\nAmethyst\nAzure\nCobalt\nEmber\nGilt\nIndigo\nMurrey\nRose\nRuby\nVerdure\nViridian' ]] || \
  fail "acentos de Compline: $(labels 3)"
check_icons 3
[[ "$(labels 4)" == "$(labels 2)" && "$(labels 5)" == "$(labels 1)" ]] || \
  fail 'Esc no retrocedió nivel por nivel'

# Choosing an accent applies it through dotfiles-theme set.
mango_menu '2 1 4' >/dev/null || fail 'aplicar Sanctuary Compline Cobalt falló'
[[ "$(selected)" == sanctuary-compline-cobalt ]] || fail "set no guardó cobalt: $(selected)"
grep -q '^notify-send .*Tema aplicado.*sanctuary-compline-cobalt' "$PICKER_LOG" || \
  fail 'set no notificó el tema aplicado'
mango_menu '2 esc esc'
[[ "$(labels 1)" == $'Catppuccin\nSanctuary  (actual)' ]] || fail "familia activa: $(labels 1)"
[[ "$(labels 2)" == $'Compline  (actual)\nMatins\nVespers' ]] || fail "flavour activo: $(labels 2)"
[[ "$(icons 1 | tail -1)" == "$STATE/swatches/sanctuary-compline-cobalt.svg" ]] || \
  fail 'la familia activa no muestra la muestra del tema activo'
rm -f -- "$STATE/selected"

# --- 3. bspwm: bspwm-theme menu (rofi), same levels ------------------------

ln -s -- "$BSPWM_CONFIG" "$H/.config/bspwm"
ln -s -- "$REPO_ROOT/layers/wm/bspwm/home/bspwm/.local/share/dotfiles/theme/templates/bspwm" \
  "$H/.local/share/dotfiles/theme/templates/bspwm"
in_home '' "$ENGINE" render >/dev/null
bspwm_menu() {
  in_home "$1" "$H/.config/bspwm/scripts/bspwm-theme" menu
}

bspwm_menu 'esc' || fail 'Esc en el primer nivel de rofi no salió con 0'
(( $(calls) == 1 )) || fail "Esc en rofi abrió $(calls) menús"
[[ "$(labels 1)" == $'Catppuccin  (actual)\nSanctuary' ]] || fail "familias en rofi: $(labels 1)"
check_icons 1
call_args 1 | grep -qx -- '-dmenu' || fail 'rofi sin -dmenu'
call_args 1 | grep -qx 'Tema ❯' || fail "prompt de rofi: $(call_args 1)"
call_args 1 | grep -q 'show-icons: true' || fail 'rofi sin iconos'
call_args 1 | grep -Fqx -- "@import \"$STATE/current/bspwm/rofi-colors.rasi\"" || \
  fail 'rofi no importó los colores del tema renderizado'
grep -q 'catppuccin-mocha-' "$BSPWM_CONFIG/scripts/bspwm-theme" && \
  fail 'bspwm-theme conserva la lista fija de acentos'

bspwm_menu '1 esc esc'
(( $(calls) == 3 )) || fail "rofi: Catppuccin, Esc, Esc abrió $(calls) menús"
(( $(labels 2 | wc -l) == 14 )) || fail "acentos de Catppuccin en rofi: $(labels 2 | wc -l)"
labels 2 | grep -qx 'Pink  (actual)' || fail 'Pink sin marca de activo en rofi'
check_icons 2
call_args 2 | grep -qx 'Catppuccin · Mocha ❯' || fail "prompt de acentos en rofi: $(call_args 2)"
[[ "$(labels 3)" == "$(labels 1)" ]] || fail 'Esc en rofi no volvió a las familias'

bspwm_menu '2 1 esc esc esc'
(( $(calls) == 5 )) || fail "rofi: Sanctuary → Compline → Esc ×3 abrió $(calls) menús"
[[ "$(labels 2)" == $'Compline\nMatins\nVespers' ]] || fail "flavours en rofi: $(labels 2)"
[[ "$(labels 4)" == "$(labels 2)" && "$(labels 5)" == "$(labels 1)" ]] || \
  fail 'Esc en rofi no retrocedió nivel por nivel'
[[ -z "$(selected)" ]] || fail 'Esc en rofi aplicó un tema'

bspwm_menu '2 3 12' >/dev/null || fail 'aplicar Sanctuary Vespers Viridian con rofi falló'
[[ "$(selected)" == sanctuary-vespers-viridian ]] || fail "rofi no aplicó viridian: $(selected)"
rm -f -- "$STATE/selected"

# --- 4. TUI: dotfiles-theme preview and pick (fzf) -------------------------

preview=$(in_home '' "$ENGINE" preview sanctuary-compline-cobalt)
[[ "$preview" == *'#9bc1fb'* ]] || fail 'preview no muestra el acento'
[[ "$preview" == *$'\e[48;2;155;193;251m'* ]] || fail 'preview sin muestra truecolor del acento'
for role in background_deep surface_strong foreground_disabled accent_fg urgent \
  ansi_black ansi_bright_white hue_red hue_maroon; do
  value=$(grep "^$role=" "$REPO_ROOT/themes/palettes/sanctuary-compline-cobalt.conf" | cut -d= -f2)
  hex=${value#\#}
  printf -v escape '\e[48;2;%d;%d;%dm' "0x${hex:0:2}" "0x${hex:2:2}" "0x${hex:4:2}"
  [[ "$preview" == *"$escape"* ]] || fail "preview sin la muestra de $role"
done
for font in 'JetBrainsMono Nerd Font' 'Hanken Grotesk' 'Cormorant Garamond' Cinzel Bibata-Modern-Classic; do
  [[ "$preview" == *"$font"* ]] || fail "preview sin la fuente $font"
done
status=0
in_home '' "$ENGINE" preview no-existe >/dev/null 2>&1 || status=$?
(( status == 1 )) || fail "preview de un tema desconocido devolvió $status"

# Without fzf, or without a terminal, pick explains why and changes nothing.
mkdir -p -- "$TEST_ROOT/no-fzf"
cp -P -- "$BIN"/* "$TEST_ROOT/no-fzf/"
rm -f -- "$TEST_ROOT/no-fzf/fzf"
status=0
message=$(env -i PATH="$TEST_ROOT/no-fzf" HOME="$H" XDG_STATE_HOME="$H/.local/state" \
  XDG_DATA_HOME="$H/.local/share" XDG_CONFIG_HOME="$H/.config" "$ENGINE" pick 2>&1) || status=$?
(( status == 1 )) && [[ "$message" == *'fzf no está instalado'* ]] || \
  fail "pick sin fzf: estado $status, '$message'"
status=0
message=$(in_home '1' "$ENGINE" pick 2>&1) || status=$?
(( status == 1 )) && [[ "$message" == *'necesita una terminal'* ]] || \
  fail "pick sin terminal: estado $status, '$message'"
(( $(calls) == 0 )) || fail 'pick sin terminal abrió fzf'
[[ -z "$(selected)" ]] || fail 'pick sin fzf o sin terminal aplicó un tema'

# In a terminal (script gives it a pseudo-terminal), fzf lists every theme with
# the active one marked and the preview wired; Enter applies, Esc leaves.
SCRIPT=$(command -v script) || fail 'falta script (util-linux) para simular una terminal'
pick_in_tty() {
  in_home "$1" "$SCRIPT" -qefc "$ENGINE pick" /dev/null < /dev/null
}
pick_in_tty 'esc' >/dev/null || fail 'Esc en pick no salió con 0'
(( $(calls) == 1 )) || fail "pick abrió fzf $(calls) veces"
(( $(wc -l < "$PICKER_DIR/1.in") == 50 )) || fail 'pick no listó los 50 temas'
[[ "$(cut -f1 "$PICKER_DIR/1.in")" == "$(printf '%s\n' "${plain[@]}")" ]] || \
  fail 'pick no lista los ids en la primera columna'
grep -q $'^catppuccin-mocha-pink\t.*Catppuccin · Mocha · Pink  (actual)$' "$PICKER_DIR/1.in" || \
  fail "pick sin la marca del tema activo: $(grep pink "$PICKER_DIR/1.in")"
(( $(grep -c '(actual)' "$PICKER_DIR/1.in") == 1 )) || fail 'pick marcó más de un tema'
grep -q $'^sanctuary-matins-gilt\t.*Sanctuary · Matins · Gilt$' "$PICKER_DIR/1.in" || \
  fail 'pick sin etiqueta legible para Sanctuary'
call_args 1 | grep -qx -- "--preview=$ENGINE preview {1}" || fail "pick sin vista previa: $(call_args 1)"
call_args 1 | grep -qx -- '--with-nth=2' || fail 'pick muestra el id además de la etiqueta'
[[ -z "$(selected)" ]] || fail 'Esc en pick aplicó un tema'
pick_in_tty '20' >/dev/null || fail 'Enter en pick falló'
chosen=$(sed -n 20p "$PICKER_DIR/1.in" | cut -f1)
[[ "$(selected)" == "$chosen" ]] || fail "pick aplicó '$(selected)' en vez de $chosen"
grep -q "^notify-send .*Tema aplicado.*$chosen" "$PICKER_LOG" || fail 'pick no pasó por set'
rm -f -- "$STATE/selected"
help=$(in_home '' "$ENGINE" --help)
[[ "$help" == *'pick'* && "$help" == *'preview <id>'* ]] || fail 'la ayuda no documenta pick y preview'

[[ "$(git -C "$REPO_ROOT" status --porcelain)" == "$CHECKOUT_STATE" ]] || \
  fail 'el selector modificó el checkout'
printf 'OK: theme-picker-smoke\n'
