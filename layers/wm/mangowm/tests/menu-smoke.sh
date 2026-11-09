#!/usr/bin/env bash
# mangowm_menu: fuzzel menus size themselves to their entries, shorten what
# does not fit in the middle, and always return the original entry.

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
COMMON="$REPO_ROOT/home/mango/.local/lib/mangowm/common"
TEST_ROOT=''

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  [[ -n "$TEST_ROOT" && "$TEST_ROOT" == /tmp/mangowm-menu-smoke.* ]] || return 0
  find "$TEST_ROOT" -mindepth 1 -delete
  find "$TEST_ROOT" -depth -type d -empty -delete
}
trap cleanup EXIT

TEST_ROOT=$(mktemp -d /tmp/mangowm-menu-smoke.XXXXXX)
FAKE_BIN="$TEST_ROOT/bin"
ARGS_LOG="$TEST_ROOT/fuzzel.args"
ROWS_LOG="$TEST_ROOT/fuzzel.rows"
mkdir -p -- "$FAKE_BIN" "$TEST_ROOT/theme"

# The double records its arguments and the rows it was given, then picks row
# FUZZEL_PICK and prints its zero-based index when --index is passed, like
# fuzzel. FUZZEL_PICK=0 dismisses the menu.
cat > "$FAKE_BIN/fuzzel" <<'FAKE'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s\n' "$@" > "$FUZZEL_ARGS_LOG"
cat > "$FUZZEL_ROWS_LOG"
pick=${FUZZEL_PICK:-1}
(( pick > 0 )) || exit 1
if [[ " $* " == *' --index '* ]]; then
  printf '%s\n' "$(( pick - 1 ))"
else
  sed -n "${pick}p" "$FUZZEL_ROWS_LOG"
fi
FAKE
cat > "$FAKE_BIN/notify-send" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$NOTIFY_LOG"
FAKE
chmod +x "$FAKE_BIN/notify-send"
chmod +x "$FAKE_BIN/fuzzel"

export PATH="$FAKE_BIN:$PATH"
export FUZZEL_ARGS_LOG="$ARGS_LOG" FUZZEL_ROWS_LOG="$ROWS_LOG"
export NOTIFY_LOG="$TEST_ROOT/notify.log"
# Lengths are counted in characters, which needs a UTF-8 locale.
export LC_ALL=C.UTF-8
export HOME="$TEST_ROOT/home"

# shellcheck source-path=SCRIPTDIR source=../home/mango/.local/lib/mangowm/common
source "$COMMON"
mangowm_theme_dir() { printf '%s\n' "$TEST_ROOT/theme"; }

arg() {
  sed -n "s/^--$1=//p" "$ARGS_LOG"
}

shown() {
  sed -n "${1}p" "$ROWS_LOG"
}

# 1. Short entries keep the floor width and pass the caller's arguments on.
picked=$(printf '%s\n' 'Conectar' 'Olvidar' | \
  FUZZEL_PICK=2 mangowm_menu 'Red ❯ ' --lines=2)
[[ "$picked" == 'Olvidar' ]] || fail "devolvió '$picked' en vez de 'Olvidar'"
[[ $(arg width) == "$MANGOWM_MENU_MIN_WIDTH" ]] || \
  fail "ancho $(arg width) en vez del mínimo $MANGOWM_MENU_MIN_WIDTH"
[[ $(arg lines) == 2 ]] || fail 'no reenvió --lines'
[[ $(arg prompt) == 'Red ❯ ' ]] || fail "prompt '$(arg prompt)'"
[[ $(arg config) == "$TEST_ROOT/theme/fuzzel.ini" ]] || fail 'no usó el fuzzel.ini del tema'

# 2. A wider entry widens the menu to fit it whole.
entry='🔊  Super + V / Clic Der. Volumen  Menú de Dispositivos de Audio (Salidas / Micrófonos)'
picked=$(printf '%s\n' 'corto' "$entry" | FUZZEL_PICK=2 mangowm_menu 'Atajos ❯ ')
[[ "$picked" == "$entry" ]] || fail 'no devolvió la entrada ancha completa'
[[ $(shown 2) == "$entry" ]] || fail 'acortó una entrada que entraba'
(( $(arg width) == ${#entry} + MANGOWM_MENU_PADDING )) || \
  fail "ancho $(arg width) para una entrada de ${#entry} caracteres"

# 3. A path longer than the cap shows $HOME as ~, keeps its end and is cut in
# the middle; the action still receives the full path.
long="$HOME/Pictures/Wallpapers/2026/landscapes/mountains/very-long-directory-name/another-level/sunrise-over-the-lake.png"
picked=$(printf '%s\n' "$long" | mangowm_menu 'Wallpaper ❯ ')
[[ "$picked" == "$long" ]] || fail "devolvió '$picked' en vez de la ruta completa"
label=$(shown 1)
# The displayed label holds a literal ~.
# shellcheck disable=SC2088
[[ "$label" == '~/Pictures/'*'…'*'/sunrise-over-the-lake.png' ]] || \
  fail "etiqueta acortada inesperada: $label"
(( ${#label} == MANGOWM_MENU_MAX_WIDTH - MANGOWM_MENU_PADDING )) || \
  fail "la etiqueta mide ${#label}"
[[ $(arg width) == "$MANGOWM_MENU_MAX_WIDTH" ]] || \
  fail "ancho $(arg width) supera o no alcanza el tope $MANGOWM_MENU_MAX_WIDTH"

# 4. "label<TAB>value" entries show the label and return the value.
picked=$(printf 'sunrise.png\t%s\n' "$long" | mangowm_menu 'Wallpaper ❯ ')
[[ "$picked" == "$long" ]] || fail 'no devolvió el valor de una entrada etiqueta<TAB>valor'
[[ $(shown 1) == 'sunrise.png' ]] || fail "mostró '$(shown 1)' en vez de la etiqueta"

# 5. A prompt longer than the cap is shortened too.
long_prompt="Error en $(printf 'x%.0s' {1..120}) ❯ "
printf '%s\n' 'Cancelar' | mangowm_menu "$long_prompt" >/dev/null
prompt=$(arg prompt)
(( ${#prompt} <= MANGOWM_MENU_MAX_WIDTH - MANGOWM_MENU_PADDING )) || \
  fail "prompt de ${#prompt} caracteres"
[[ "$prompt" == *'… ❯ '* || "$prompt" == *'❯ ' ]] || fail "prompt sin su final: $prompt"

# 6. Values may hold tabs, and duplicated labels return their own value.
picked=$(printf 'Red\tuuid-1\twlan0\nRed\tuuid-2\twlan1\n' | \
  FUZZEL_PICK=2 mangowm_menu 'Wi-Fi ❯ ')
[[ "$picked" == $'uuid-2\twlan1' ]] || fail "valor con tabs devuelto como '$picked'"
[[ "$(cat "$ROWS_LOG")" == $'Red\nRed' ]] || fail 'fuzzel recibió algo más que las etiquetas'

# 7. A dismissed menu prints nothing and reports fuzzel's status.
status=0
picked=$(printf '%s\n' 'Conectar' | FUZZEL_PICK=0 mangowm_menu 'Red ❯ ') || status=$?
[[ -z "$picked" && $status -eq 1 ]] || fail "menú cerrado: '$picked', estado $status"

# 8. A theme that cannot be loaded is reported instead of failing silently.
mangowm_theme_dir() { return 1; }
status=0
printf '%s\n' 'Conectar' | mangowm_menu 'Red ❯ ' >/dev/null || status=$?
(( status == 1 )) || fail "sin tema devolvió $status"
grep -q 'Menú no disponible' "$NOTIFY_LOG" || fail 'no notificó la falla del tema'

printf 'OK: menu-smoke\n'
