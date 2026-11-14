#!/usr/bin/env bash
# Waybar layout and its helpers: per-output bars that share one module file,
# modules that hide when they have nothing to say, the quick settings menu,
# do not disturb and the pending updates counter.

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
MANGO_HOME="$REPO_ROOT/home/mango"
CONFIG="$MANGO_HOME/.config/waybar/config.json"
MODULES="$MANGO_HOME/.config/waybar/modules.json"
CSS="$MANGO_HOME/.local/share/dotfiles/theme/templates/mangowm/waybar.css"
TEST_ROOT=''
ORIGINAL_HOME=$HOME
ORIGINAL_PATH=$PATH

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  [[ -n "$TEST_ROOT" && "$TEST_ROOT" == /tmp/mangowm-waybar-smoke.* ]] || return 0
  find "$TEST_ROOT" -mindepth 1 -delete
  find "$TEST_ROOT" -depth -type d -empty -delete
}
trap cleanup EXIT

command -v jq >/dev/null 2>&1 || fail 'falta jq para validar Waybar'

# --- Bars -------------------------------------------------------------------

jq empty "$CONFIG" || fail 'config.json no es JSON válido'
jq empty "$MODULES" || fail 'modules.json no es JSON válido'
jq -e 'type == "array" and length == 2' "$CONFIG" >/dev/null || \
  fail 'Waybar no define dos barras (completa y compacta)'
jq -e 'all(.[]; .include == ["~/.config/waybar/modules.json"])' "$CONFIG" >/dev/null || \
  fail 'las barras no comparten modules.json'
jq -e '.[0].output == ["!eDP-1", "!eDP-2", "*"]' "$CONFIG" >/dev/null || \
  fail 'la barra completa no excluye las pantallas de laptop'
jq -e '.[1].output == ["eDP-1", "eDP-2"]' "$CONFIG" >/dev/null || \
  fail 'la barra compacta no se limita a las pantallas de laptop'

# Every module a bar lists is defined once in modules.json.
while IFS= read -r module; do
  jq -e --arg m "$module" 'has($m)' "$MODULES" >/dev/null || \
    fail "el módulo $module no está definido en modules.json"
done < <(jq -r '.[] | (."modules-left" + ."modules-center" + ."modules-right")[]' "$CONFIG" | sort -u)
while IFS= read -r module; do
  jq -e --arg m "$module" 'has($m)' "$MODULES" >/dev/null || \
    fail "el grupo usa $module, que no está definido"
done < <(jq -r 'to_entries[] | select(.key | startswith("group/")) | .value.modules[]' "$MODULES")

# Left: launcher, layout, workspaces, music. The layout sits before the
# workspaces so a new or emptied workspace never moves it.
jq -e '.[0]."modules-left" == ["custom/launcher", "mango/layout", "mango/workspaces", "mpris"]' \
  "$CONFIG" >/dev/null || fail 'la izquierda de la barra completa no es launcher · layout · workspaces · música'
jq -e '.[1]."modules-left" == ["custom/launcher", "mango/layout", "mango/workspaces", "mpris#compact"]' \
  "$CONFIG" >/dev/null || fail 'la barra compacta no muestra la música solo con icono'
jq -e 'all(.[]; ."modules-center" == ["clock", "custom/recording"])' "$CONFIG" >/dev/null || \
  fail 'el centro no es el reloj con el indicador de grabación'
jq -e '[.[] | (."modules-left" + ."modules-center" + ."modules-right")[]] |
  (index("mango/window") == null and index("ext/workspaces") == null and
   index("custom/power-profile") == null and index("tray") == null)' "$CONFIG" >/dev/null || \
  fail 'la barra aún muestra el título, ext/workspaces, el perfil de energía o el tray suelto'
jq -e '.[0]."modules-right" == ["custom/nightlight", "custom/idle", "custom/updates", "group/quick",
  "wireplumber", "network", "bluetooth", "custom/keyboard", "battery", "custom/power"]' \
  "$CONFIG" >/dev/null || fail "la derecha de la barra completa cambió: $(jq -c '.[0]."modules-right"' "$CONFIG")"
jq -e '.[1]."modules-right" == ["custom/nightlight", "custom/idle", "custom/updates", "group/quick",
  "wireplumber", "backlight", "network#compact", "bluetooth#compact", "custom/keyboard", "battery", "custom/power"]' \
  "$CONFIG" >/dev/null || fail "la derecha de la barra compacta cambió: $(jq -c '.[1]."modules-right"' "$CONFIG")"

# --- Modules ----------------------------------------------------------------

jq -e '."mango/workspaces" | ."hide-empty" == true and ."on-click" == "activate"' "$MODULES" >/dev/null || \
  fail 'los workspaces vacíos no se ocultan'
for symbol in T S G M K CT RT VS VT VG VK DW F VF; do
  jq -e --arg k "format-$symbol" '."mango/layout"[$k] | type == "string" and test("\\{symbol\\}")' \
    "$MODULES" >/dev/null || fail "el layout $symbol no tiene icono propio"
done
[[ $(jq -r '[."mango/layout" | to_entries[] | select(.key | startswith("format-")) | .value | .[0:1]] | unique | length' "$MODULES") == 14 ]] || \
  fail 'dos layouts comparten el mismo icono'
for family in '#layout.S' '#layout.VS' '#layout.M' '#layout.K' '#layout.VK'; do
  grep -Fq "$family" "$CSS" || fail "el CSS no distingue la familia de $family"
done
jq -e '.clock.format | test("%[dbaY]") | not' "$MODULES" >/dev/null || fail 'el reloj muestra la fecha de forma fija'
jq -e '.clock."format-alt" | test("%d")' "$MODULES" >/dev/null || fail 'el reloj perdió la fecha al hacer clic'

jq -e '.network | (."format-disabled" | length > 0) and (."format-disconnected" | length > 0) and
  (."format-linked" | length > 0) and (."format-wifi" | test("\\{icon\\}") and test("\\{essid\\}")) and
  (."format-ethernet" | length > 0) and (."format-icons" | length == 4)' "$MODULES" >/dev/null || \
  fail 'la red no distingue apagada, sin conectar, sin IP, wifi y ethernet'
jq -e '."network#compact" | (."format-wifi" | test("\\{essid\\}") | not) and (."format-icons" | length == 4)' \
  "$MODULES" >/dev/null || fail 'la red compacta muestra el nombre de la red'
jq -e '.bluetooth | ."format-no-controller" == "" and (."format-off" | length > 0) and
  (."format-on" | length > 0) and (."format-connected" | test("device_alias")) and
  (."format-connected-battery" | test("device_battery_percentage"))' "$MODULES" >/dev/null || \
  fail 'el bluetooth no distingue sin adaptador, apagado, encendido y conectado'
jq -e '."bluetooth#compact" | (."format-connected" | test("device_alias") | not)' "$MODULES" >/dev/null || \
  fail 'el bluetooth compacto muestra el nombre del dispositivo'
jq -e '."group/quick" | .modules == ["custom/notifications", "tray"] and (.drawer | type == "object")' \
  "$MODULES" >/dev/null || fail 'la campana no despliega el tray'
jq -e '."custom/notifications" | ."on-click" == "$HOME/.local/lib/mangowm/quick-settings" and
  ."on-click-right" == "$HOME/.local/lib/mangowm/notifications dnd"' "$MODULES" >/dev/null || \
  fail 'la campana no abre ajustes rápidos o no alterna No molestar'
jq -e '."custom/updates" | .exec == "$HOME/.local/lib/mangowm/updates waybar" and
  ."on-click" == "$HOME/.local/lib/mangowm/updates upgrade" and (.signal | type == "number")' \
  "$MODULES" >/dev/null || fail 'el módulo de actualizaciones no lee el contador o no abre la actualización'
grep -Fq ':hover' "$CSS" || fail 'los módulos no comparten un estado hover'

# --- Helpers ----------------------------------------------------------------

TEST_ROOT=$(mktemp -d /tmp/mangowm-waybar-smoke.XXXXXX)
FAKE_HOME="$TEST_ROOT/home"
FAKE_BIN="$TEST_ROOT/bin"
LOG="$TEST_ROOT/commands.log"
THEME="$TEST_ROOT/theme"
mkdir -p "$FAKE_HOME/.local/lib" "$FAKE_HOME/.local/bin" "$FAKE_HOME/.config/mango" \
  "$FAKE_BIN" "$THEME/mangowm" "$TEST_ROOT/runtime"
ln -s "$MANGO_HOME/.local/lib/mangowm" "$FAKE_HOME/.local/lib/mangowm"
: > "$THEME/mangowm/fuzzel.ini"
: > "$LOG"
cat > "$FAKE_HOME/.local/bin/dotfiles-theme" <<FAKE
#!/usr/bin/env bash
printf '%s\n' "$THEME"
FAKE
chmod +x "$FAKE_HOME/.local/bin/dotfiles-theme"

# One double for every external command: it logs its arguments and answers
# the few queries the helpers make.
cat > "$FAKE_BIN/fake" <<'FAKE'
#!/usr/bin/env bash
set -Eeuo pipefail
name=${0##*/}
printf '%s\n' "$name${*:+ $*}" >> "$TEST_LOG"
case "$name" in
  fuzzel)
    cat > "$TEST_ROOT/fuzzel.rows"
    [[ -n "${FUZZEL_PICK-}" ]] || exit 1
    printf '%s\n' "$FUZZEL_PICK"
    ;;
  makoctl)
    if [[ "${1-}" == mode && $# == 1 ]]; then
      printf '%s\n' "${MAKO_MODE:-default}"
    fi
    ;;
  checkupdates)
    # FAIL_UPDATES=<n> fails the first n calls, like a sync without network.
    if [[ -n "${FAIL_UPDATES-}" ]]; then
      calls=$(( $(cat "$TEST_ROOT/checkupdates.calls" 2>/dev/null || echo 0) + 1 ))
      printf '%s\n' "$calls" > "$TEST_ROOT/checkupdates.calls"
      (( calls > FAIL_UPDATES )) || exit 1
    fi
    for (( i = 1; i <= ${PENDING_UPDATES:-0}; i++ )); do
      printf 'pkg%s 1.0-1 -> 1.1-1\n' "$i"
    done
    (( ${PENDING_UPDATES:-0} > 0 )) || exit 2
    ;;
  powerprofilesctl)
    [[ "${1-}" == get ]] && printf 'balanced\n'
    ;;
  notify-send)
    # Like libnotify: --print-id prints the id, a new one unless replacing.
    if [[ " $* " == *' --print-id '* || " $* " == *' -p '* ]]; then
      replace=$(sed -n 's/.*--replace-id=\([0-9]*\).*/\1/p' <<< "$*")
      if [[ -n "$replace" ]]; then
        printf '%s\n' "$replace"
      else
        next=$(( $(cat "$TEST_ROOT/notify.next" 2>/dev/null || echo 100) + 1 ))
        printf '%s\n' "$next" > "$TEST_ROOT/notify.next"
        printf '%s\n' "$next"
      fi
    fi
    ;;
  wpctl)
    [[ "${1-}" == get-volume ]] && printf 'Volume: %s%s\n' "${WPCTL_VOLUME:-0.45}" "${WPCTL_MUTED:+ [MUTED]}"
    ;;
  brightnessctl)
    [[ "${1-}" == -m ]] && printf 'intel_backlight,backlight,600,%s,1000\n' "${BRIGHTNESS:-60%}"
    ;;
esac
exit 0
FAKE
chmod +x "$FAKE_BIN/fake"
for tool in fuzzel makoctl checkupdates pkill gammastep notify-send systemctl wpctl brightnessctl \
  systemd-run powerprofilesctl mmsg foot; do
  ln -s "$FAKE_BIN/fake" "$FAKE_BIN/$tool"
done

export HOME="$FAKE_HOME" XDG_CONFIG_HOME="$FAKE_HOME/.config" XDG_RUNTIME_DIR="$TEST_ROOT/runtime" \
  XDG_CACHE_HOME="$TEST_ROOT/cache" XDG_STATE_HOME="$TEST_ROOT/state" \
  TEST_LOG="$LOG" TEST_ROOT PATH="$FAKE_BIN:/usr/bin"
LIB="$FAKE_HOME/.local/lib/mangowm"

text_of() { jq -r '.text' <<< "$1"; }

# Night light and idle inhibit only show while they are on.
out=$("$LIB/night-light" waybar)
[[ $(text_of "$out") == '' ]] || fail "la luz nocturna apagada sigue visible: $out"
"$LIB/night-light" on
out=$("$LIB/night-light" waybar)
[[ -n $(text_of "$out") ]] || fail 'la luz nocturna activa no se muestra'
[[ $("$LIB/night-light" status | jq -r '.text') != '' ]] || \
  fail 'night-light status dejó de describir el estado apagado/encendido'
"$LIB/night-light" off
out=$("$LIB/idle-inhibit" waybar)
[[ $(text_of "$out") == '' ]] || fail "el idle sin inhibir sigue visible: $out"
"$LIB/idle-inhibit" toggle
out=$("$LIB/idle-inhibit" waybar)
[[ -n $(text_of "$out") ]] || fail 'la pantalla siempre encendida no se muestra'
"$LIB/idle-inhibit" toggle

# The keyboard only shows with more than one layout configured.
printf 'xkb_rules_layout=us,latam\n' > "$FAKE_HOME/.config/mango/config.conf"
[[ $(text_of "$("$LIB/keyboard" status)") == US ]] || fail 'con dos distribuciones el teclado no se muestra'
printf 'xkb_rules_layout=us,latam\n' > "$FAKE_HOME/.config/mango/config.conf"
printf 'xkb_rules_layout=us\n' > "$FAKE_HOME/.config/mango/config.local.conf"
[[ $(text_of "$("$LIB/keyboard" status)") == '' ]] || \
  fail 'con una sola distribución (override local) el teclado sigue visible'
[[ $("$LIB/keyboard" get) == US ]] || fail 'keyboard get dejó de devolver la distribución'
rm "$FAKE_HOME/.config/mango/config.local.conf"
# Without any xkb_rules_layout line the layouts come from elsewhere, so the
# indicator stays visible instead of guessing a single layout.
: > "$FAKE_HOME/.config/mango/config.conf"
[[ $(text_of "$("$LIB/keyboard" status)") == US ]] || \
  fail 'sin xkb_rules_layout en la config el teclado se ocultó'
printf 'xkb_rules_layout=us,latam\n' > "$FAKE_HOME/.config/mango/config.conf"

# Do not disturb: the bell reflects mako's mode and the right click toggles it.
out=$("$LIB/notifications" waybar)
jq -e '.class == "normal" and (.text | length > 0)' <<< "$out" >/dev/null || fail "campana normal incorrecta: $out"
out=$(MAKO_MODE=do-not-disturb "$LIB/notifications" waybar)
jq -e '.class == "dnd"' <<< "$out" >/dev/null || fail "la campana no refleja No molestar: $out"
: > "$LOG"
"$LIB/notifications" dnd
grep -Fqx 'makoctl mode -t do-not-disturb' "$LOG" || fail "No molestar no alternó el modo de mako: $(<"$LOG")"
grep -q '^pkill -RTMIN+13 waybar' "$LOG" || fail 'No molestar no refrescó la campana'
grep -A2 -Fx '[mode=do-not-disturb]' "$MANGO_HOME/.local/share/dotfiles/theme/templates/mangowm/mako.conf" | \
  grep -Fqx 'invisible=1' || fail 'mako no oculta las notificaciones en No molestar'

# Quick settings lists every toggle with its state and runs the chosen one.
: > "$LOG"
FUZZEL_PICK=0 "$LIB/quick-settings"
grep -q '^gammastep ' "$LOG" || fail "ajustes rápidos no alternó la luz nocturna: $(<"$LOG")"
rows=$(<"$TEST_ROOT/fuzzel.rows")
for label in 'Luz nocturna' 'Pantalla siempre encendida' 'No molestar' 'Perfil de energía' 'Última notificación'; do
  [[ "$rows" == *"$label"* ]] || fail "ajustes rápidos no ofrece: $label"
done
: > "$LOG"
FUZZEL_PICK=2 "$LIB/quick-settings"
grep -Fqx 'makoctl mode -t do-not-disturb' "$LOG" || fail 'ajustes rápidos no alternó No molestar'
: > "$LOG"
FUZZEL_PICK=4 "$LIB/quick-settings"
grep -Fqx 'makoctl restore' "$LOG" || fail 'ajustes rápidos no recuperó la última notificación'
: > "$LOG"
"$LIB/quick-settings"
grep -Eq '^(gammastep|makoctl mode -t|makoctl restore|powerprofilesctl set|systemctl --user (stop|start))' "$LOG" && \
  fail "cerrar ajustes rápidos ejecutó algo: $(<"$LOG")"
grep -q '^fuzzel ' "$LOG" || fail 'ajustes rápidos no abrió el menú'

# Updates: a check counts and caches, the bar reads the cache, zero hides it.
[[ $(text_of "$("$LIB/updates" waybar)") == '' ]] || fail 'sin comprobar, el contador de actualizaciones se muestra'
: > "$LOG"
PENDING_UPDATES=3 "$LIB/updates" check
grep -q '^checkupdates$' "$LOG" || fail 'check no sincronizó con checkupdates'
grep -q '^pkill -RTMIN+12 waybar' "$LOG" || fail 'check no refrescó el contador'
out=$("$LIB/updates" waybar)
jq -e '(.text | endswith(" 3")) and .class == "pending"' <<< "$out" >/dev/null || fail "contador incorrecto: $out"
: > "$LOG"
PENDING_UPDATES=0 "$LIB/updates" refresh
grep -q '^checkupdates --nosync$' "$LOG" || fail 'refresh descargó en lugar de usar --nosync'
[[ $(text_of "$("$LIB/updates" waybar)") == '' ]] || fail 'con 0 pendientes el contador sigue visible'
PENDING_UPDATES=150 "$LIB/updates" check
jq -e '.class == "many"' <<< "$("$LIB/updates" waybar)" >/dev/null || fail 'más de 100 no se resalta'

# A failed sync (no network at login) retries instead of waiting 3 hours.
: > "$LOG"
FAIL_UPDATES=2 PENDING_UPDATES=5 MANGOWM_UPDATES_RETRY_DELAY=0 "$LIB/updates" check || \
  fail 'check falló aunque el tercer intento sincronizó'
[[ $(grep -c '^checkupdates$' "$LOG") == 3 ]] || fail "check no reintentó tras fallar: $(<"$LOG")"
jq -e '.text | endswith(" 5")' <<< "$("$LIB/updates" waybar)" >/dev/null || fail 'el reintento no guardó el contador'
rm -f "$TEST_ROOT/checkupdates.calls"
status=0
FAIL_UPDATES=9 PENDING_UPDATES=1 MANGOWM_UPDATES_RETRY_DELAY=0 "$LIB/updates" check || status=$?
(( status != 0 )) || fail 'check terminó bien aunque todos los intentos fallaron'
jq -e '.text | endswith(" 5")' <<< "$("$LIB/updates" waybar)" >/dev/null || fail 'un check fallido borró el último contador'
rm -f "$TEST_ROOT/checkupdates.calls"

# A cache that cannot be written is a failed check, not a silent success.
chmod 555 "$XDG_CACHE_HOME/mangowm"
status=0
PENDING_UPDATES=9 MANGOWM_UPDATES_RETRY_DELAY=0 "$LIB/updates" check 2>/dev/null || status=$?
chmod 755 "$XDG_CACHE_HOME/mangowm"
(( status != 0 )) || fail 'check terminó bien sin poder escribir el contador'
jq -e '.text | endswith(" 5")' <<< "$("$LIB/updates" waybar)" >/dev/null || fail 'un check sin escritura cambió el contador'

# A timer check and a pacman refresh can overlap, so each writer needs its own
# temporary file: an mv double records the source of every rename.
cat > "$FAKE_BIN/mv" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "${@: -2:1}" >> "$TEST_ROOT/mv.sources"
exec /usr/bin/mv "$@"
FAKE
chmod +x "$FAKE_BIN/mv"
PENDING_UPDATES=7 "$LIB/updates" refresh
PENDING_UPDATES=7 "$LIB/updates" refresh
rm "$FAKE_BIN/mv"
[[ $(sort -u "$TEST_ROOT/mv.sources" | wc -l) == 2 ]] || \
  fail "dos escritores del contador comparten el temporal: $(<"$TEST_ROOT/mv.sources")"
jq -e '.text | endswith(" 7")' <<< "$("$LIB/updates" waybar)" >/dev/null || fail 'el recuento no guardó el contador'
find "$XDG_CACHE_HOME/mangowm" -name 'updates.*' | grep -q . && fail 'quedaron temporales del contador'

# The session schedules the check 2 minutes after login and every 3 hours,
# and refreshes after any pacman transaction (its lock file).
start=$(<"$MANGO_HOME/.local/lib/mangowm/session-start")
[[ "$start" == *'--unit=mangowm-updates --on-active=2min --on-unit-active=3h'* ]] || \
  fail 'session-start no programa la comprobación de actualizaciones'
[[ "$start" == *'--path-property=PathChanged=/var/lib/pacman/db.lck'* ]] || \
  fail 'session-start no refresca el contador tras pacman'
stop=$(<"$MANGO_HOME/.local/lib/mangowm/session-stop")
for unit in mangowm-updates.timer mangowm-updates-refresh.path; do
  [[ "$stop" == *"$unit"* ]] || fail "session-stop no detiene $unit"
done

# The portability guard accepts the laptop panel selectors and nothing else:
# a real output name in the same line still fails.
MONOREPO="$REPO_ROOT/../../.."
GUARD="$TEST_ROOT/guard"
mkdir -p "$GUARD/layers/wm"
cp -a "$REPO_ROOT" "$GUARD/layers/wm/mangowm"
ln -s "$MONOREPO/layers/desktop" "$GUARD/layers/desktop"
run_guard() {
  env -u HOME HOME="$ORIGINAL_HOME" PATH="$ORIGINAL_PATH" DOTFILES_LIB="$MONOREPO/lib" \
    LAYER_DIR="$GUARD/layers/wm/mangowm" PROFILE=desktop OPERATION=bootstrap \
    "$GUARD/layers/wm/mangowm/hooks/validate" 2>&1 || true
}
[[ $(run_guard) != *'nombres de hardware fijos'* ]] || fail 'el guard rechaza los selectores eDP de la barra compacta'
sed -i 's/"output": \["eDP-1", "eDP-2"\]/"output": ["eDP-1", "HDMI-A-1"]/' \
  "$GUARD/layers/wm/mangowm/home/mango/.config/waybar/config.json"
[[ $(run_guard) == *'nombres de hardware fijos'* ]] || fail 'el guard dejó pasar HDMI-A-1 junto a eDP'

# --- Notifications ------------------------------------------------------------

notify_lines() { grep '^notify-send ' "$LOG" || true; }

# Volume and brightness are an OSD: one notification per channel that each
# press replaces, with the level as a progress value.
: > "$LOG"
"$LIB/volume" up
WPCTL_VOLUME=0.50 "$LIB/volume" up
mapfile -t sent < <(notify_lines)
(( ${#sent[@]} == 2 )) || fail "el volumen no notificó dos veces: $(<"$LOG")"
[[ "${sent[0]}" == *'--category=osd'* && "${sent[0]}" == *'int:value:45'* ]] || fail "el OSD de volumen no lleva categoría y nivel: ${sent[0]}"
first_id=$(<"$TEST_ROOT/notify.next")
[[ "${sent[1]}" == *"--replace-id=$first_id"* && "${sent[1]}" == *'int:value:50'* ]] || \
  fail "la segunda pulsación de volumen no reemplazó la primera: ${sent[1]}"
grep -q 'x-canonical-private-synchronous' "$LOG" && fail 'el volumen aún usa un hint que mako ignora'
: > "$LOG"
WPCTL_MUTED=1 "$LIB/volume" mute
[[ "$(notify_lines)" == *'--category=osd-muted'* && "$(notify_lines)" == *"--replace-id=$first_id"* ]] || \
  fail "silenciar no reemplazó el OSD de volumen con su estilo tenue: $(notify_lines)"
: > "$LOG"
"$LIB/brightness" up
BRIGHTNESS=65% "$LIB/brightness" up
mapfile -t sent < <(notify_lines)
[[ "${sent[0]}" == *'--category=osd'* && "${sent[0]}" == *'int:value:60'* ]] || fail "el OSD de brillo no lleva categoría y nivel: ${sent[0]}"
[[ "${sent[1]}" == *'--replace-id='* && "${sent[1]}" == *'int:value:65'* ]] || fail "el brillo se apiló: ${sent[1]}"
[[ "${sent[1]}" != *"--replace-id=$first_id"* ]] || fail 'el brillo reemplazó la notificación del volumen'
: > "$LOG"
"$LIB/volume" mic-mute
"$LIB/volume" mic-mute
mapfile -t sent < <(notify_lines)
[[ "${sent[1]}" == *'--replace-id='* ]] || fail "el micrófono se apiló: ${sent[1]}"

# Toggles replace their previous state instead of stacking.
: > "$LOG"
"$LIB/night-light" on
"$LIB/night-light" off
mapfile -t sent < <(notify_lines)
[[ "${sent[1]}" == *'--replace-id='* ]] || fail "la luz nocturna se apiló: ${sent[1]}"
grep -c 'mangowm_notify_replace' "$MANGO_HOME/.local/lib/mangowm/wifi" >/dev/null || fail 'wifi no reemplaza su progreso'
for script in idle-inhibit power-profile keyboard recording wallpaper monitors wifi; do
  grep -q 'mangowm_notify_replace' "$MANGO_HOME/.local/lib/mangowm/$script" || \
    fail "$script no reemplaza sus notificaciones"
done

# mako: OSD at the bottom centre with an accent bar (dim when muted), shown
# even in do not disturb; repeated notifications group with a count; low
# urgency is discreet and short.
MAKO="$MANGO_HOME/.local/share/dotfiles/theme/templates/mangowm/mako.conf"
section() { awk -v h="[$1]" '$0 == h { on = 1; next } /^\[/ { on = 0 } on' "$MAKO"; }
section 'category=osd' | grep -Fxq 'anchor=bottom-center' || fail 'el OSD no está abajo al centro'
section 'category=osd' | grep -Fxq 'progress-color=over {{accent}}' || fail 'la barra del OSD no usa el acento'
section 'category=osd-muted' | grep -Fxq 'anchor=bottom-center' || fail 'el OSD silenciado no comparte posición'
section 'category=osd-muted' | grep -q '^progress-color=over {{foreground_disabled}}' || fail 'el OSD silenciado no es tenue'
section 'mode=do-not-disturb category=osd' | grep -Fxq 'invisible=0' || fail 'No molestar oculta el OSD'
grep -Fxq 'group-by=app-name,summary' "$MAKO" || fail 'mako no agrupa notificaciones repetidas'
section 'grouped' | grep -q '%g' || fail 'las notificaciones agrupadas no muestran el contador'
section 'urgency=low' | grep -q '^default-timeout=' || fail 'la urgencia baja no tiene su propio tiempo'
section 'urgency=critical' | grep -Fxq 'default-timeout=0' || fail 'las críticas se cierran solas'
# mako parses the config before it claims the bus; with the markers replaced
# by a color, a parse error is reported before any bus error.
if command -v mako >/dev/null 2>&1; then
  sed -E 's/\{\{[a-z_.]+\}\}/#101010/g' "$MAKO" > "$TEST_ROOT/mako.conf"
  mako_out=$(env -u WAYLAND_DISPLAY DBUS_SESSION_BUS_ADDRESS=unix:path=/nonexistent \
    timeout 3 /usr/bin/mako -c "$TEST_ROOT/mako.conf" 2>&1 || true)
  [[ "$mako_out" != *'Failed to parse'* ]] || fail "mako rechazó la configuración: $mako_out"
else
  printf 'SKIP: validación de mako.conf con mako (no instalado)\n'
fi

# Low battery: one warning at 15 % and a critical one at 5 %, each once per
# discharge, replacing each other; charging re-arms them. No battery, no unit.
SUPPLY="$TEST_ROOT/power_supply"
mkdir -p "$SUPPLY/BAT0"
battery_at() { printf '%s\n' "$1" > "$SUPPLY/BAT0/capacity"; printf '%s\n' "$2" > "$SUPPLY/BAT0/status"; }
battery_check() { MANGOWM_POWER_SUPPLY="$SUPPLY" "$LIB/battery" check; }
: > "$LOG"
battery_at 40 Discharging; battery_check
[[ -z "$(notify_lines)" ]] || fail "la batería al 40 % avisó: $(notify_lines)"
battery_at 15 Discharging; battery_check; battery_check
mapfile -t sent < <(notify_lines)
(( ${#sent[@]} == 1 )) || fail "el aviso del 15 % no salió una sola vez: $(notify_lines)"
[[ "${sent[0]}" == *'--urgency=normal'* && "${sent[0]}" == *'15'* ]] || fail "aviso del 15 % incorrecto: ${sent[0]}"
battery_at 5 Discharging; battery_check
mapfile -t sent < <(notify_lines)
[[ "${sent[1]}" == *'--urgency=critical'* && "${sent[1]}" == *'--replace-id='* ]] || \
  fail "el aviso del 5 % no es crítico o no reemplazó al del 15 %: ${sent[1]-}"
battery_at 5 Charging; battery_check
battery_at 14 Discharging; battery_check
mapfile -t sent < <(notify_lines)
(( ${#sent[@]} == 3 )) || fail "cargar no volvió a armar el aviso: $(notify_lines)"
: > "$LOG"
MANGOWM_POWER_SUPPLY="$TEST_ROOT/no-supply" "$LIB/battery" check || fail 'sin batería el check falló'
[[ -z "$(notify_lines)" ]] || fail 'sin batería hubo un aviso'
start=$(<"$MANGO_HOME/.local/lib/mangowm/session-start")
[[ "$start" == *'start_unit mangowm-battery'* ]] || fail 'session-start no vigila la batería'
grep -Fq 'mangowm-battery.service' "$MANGO_HOME/.local/lib/mangowm/session-stop" || fail 'session-stop no detiene el aviso de batería'

printf 'OK: Waybar, ajustes rápidos, notificaciones y actualizaciones validados\n'
