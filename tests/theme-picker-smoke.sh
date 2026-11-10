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

[[ "$(git -C "$REPO_ROOT" status --porcelain)" == "$CHECKOUT_STATE" ]] || \
  fail 'el selector modificó el checkout'
printf 'OK: theme-picker-smoke\n'
