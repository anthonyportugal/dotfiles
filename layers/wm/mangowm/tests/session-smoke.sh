#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
DOTFILES="$REPO_ROOT/../../../bin/dotfiles"
TEST_ROOT=''
LOCK_PID=''
# The session checks export HOME=$TARGET; doctor and unlink run with the real
# HOME so the target is never mistaken for the current user's home.
ORIGINAL_HOME=$HOME
ORIGINAL_PATH=$PATH

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  if [[ "$LOCK_PID" =~ ^[0-9]+$ ]]; then
    kill "$LOCK_PID" 2>/dev/null || true
  fi
  [[ -n "$TEST_ROOT" && "$TEST_ROOT" == /tmp/mangowm-session-smoke.* ]] || return 0
  find "$TEST_ROOT" -mindepth 1 -delete
  find "$TEST_ROOT" -depth -type d -empty -delete
}
trap cleanup EXIT

for command_name in stow jq shellcheck sha256sum; do
  command -v "$command_name" >/dev/null 2>&1 || fail "falta $command_name"
done

TEST_ROOT=$(mktemp -d /tmp/mangowm-session-smoke.XXXXXX)
TARGET="$TEST_ROOT/home with spaces"
STATE="$TEST_ROOT/state"
RUNTIME="$TEST_ROOT/runtime"
FAKE_BIN="$TEST_ROOT/fake-bin"
LOG="$TEST_ROOT/commands.log"
SERVICE_STATE="$TEST_ROOT/recording.state"
MEDIA_ROOT="$TEST_ROOT/media"
mkdir -p "$TARGET" "$STATE" "$RUNTIME" "$FAKE_BIN" "$MEDIA_ROOT"
: > "$LOG"
: > "$SERVICE_STATE"
HOME_STATE_BEFORE=$(git -C "$REPO_ROOT" status --porcelain --ignored -- home)

"$DOTFILES" bootstrap --profile core --wm mangowm --wm-profile desktop \
  --stow-only --target "$TARGET" --apply >/dev/null 2>&1

for managed_path in \
  .config/mango/config.conf \
  .config/mango/conf.d/50-desktop.conf \
  .config/waybar/config.json \
  .config/wlogout/layout \
  .config/swayidle/config \
  .config/xdg-desktop-portal/mango-portals.conf \
  .local/bin/mango-theme \
  .local/bin/dotfiles-theme \
  .local/bin/mangowm-session \
  .local/lib/mangowm/brightness \
  .local/lib/mangowm/color-picker \
  .local/lib/mangowm/keyboard \
  .local/lib/mangowm/recording \
  .local/lib/mangowm/wallpaper; do
  [[ -L "$TARGET/$managed_path" ]] || fail "falta el enlace $managed_path"
done

# The WM only ships templates: they are stowed for the shared engine, and the
# reload hook is executable.
for template in mango.conf foot.ini fuzzel.ini mako.conf swaylock.conf \
  waybar.css wlogout.css icons/logout.svg xdg-config/satty/config.toml; do
  [[ -f "$TARGET/.local/share/dotfiles/theme/templates/mangowm/$template" ]] || \
    fail "falta la plantilla mangowm/$template"
done
[[ -x "$TARGET/.local/share/dotfiles/theme/reload.d/mangowm" ]] || \
  fail 'falta el hook de recarga reload.d/mangowm'

# mango-theme forwards to the shared engine: rendering is reproducible,
# immutable and only writes in XDG state.
theme_env=(env -u DOTFILES_THEME HOME="$TARGET" XDG_STATE_HOME="$STATE"
  XDG_DATA_HOME="$TARGET/.local/share" XDG_CONFIG_HOME="$TARGET/.config")
first_revision=$("${theme_env[@]}" "$TARGET/.local/bin/mango-theme" render)
first_link=$(readlink -- "$STATE/dotfiles/theme/current")
second_revision=$("${theme_env[@]}" "$TARGET/.local/bin/mango-theme")
second_link=$(readlink -- "$STATE/dotfiles/theme/current")
[[ "$first_revision" == "$second_revision" && "$first_link" == "$second_link" ]] || \
  fail 'el renderer no fue idempotente'
[[ ! -e "$STATE/mangowm/theme" ]] || fail 'se renderizó en la ruta antigua mangowm/theme'
[[ ! -e "$REPO_ROOT/.local/state" ]] || fail 'el renderer contaminó el checkout'
[[ "$(git -C "$REPO_ROOT" status --porcelain --ignored -- home)" == "$HOME_STATE_BEFORE" ]] || \
  fail 'el renderer escribió dentro del paquete Stow'
grep -Fxq 'accent_name=pink' "$first_revision/metadata" || \
  fail 'el tema activo no conserva Pink'
grep -Fxq 'ignore-empty-password' "$first_revision/mangowm/swaylock.conf" || \
  fail 'Swaylock permite passwords vacíos'
grep -Fq '#f5c2e7' "$first_revision/mangowm/waybar.css" || \
  fail 'Waybar no recibió el acento rosa'
if command -v foot >/dev/null 2>&1; then
  foot --config="$first_revision/mangowm/foot.ini" --check-config || \
    fail 'Foot rechazó el adaptador generado'
fi

jq empty "$TARGET/.config/waybar/config.json" || \
  fail 'Waybar no contiene JSON válido'
[[ $(sed -n '/[^[:space:]]/ { s/^[[:space:]]*//; s/\(.\).*/\1/; p; q; }' \
  "$TARGET/.config/wlogout/layout") == '{' ]] || \
  fail 'wlogout recibió un array en lugar de un stream de objetos JSON'
jq -s -e '
  length == 4 and
  all(.[];
    type == "object" and
    (.label as $label |
      ["logout", "suspend", "reboot", "shutdown"] | index($label)) != null and
    (.action | type == "string" and length > 0) and
    (.text | type == "string" and length > 0) and
    (.keybind | type == "string" and length == 1)
  )
' "$TARGET/.config/wlogout/layout" >/dev/null || \
  fail 'el stream JSON de wlogout no cumple su contrato'
grep -Fxq 'org.freedesktop.impl.portal.ScreenCast=wlr' \
  "$TARGET/.config/xdg-desktop-portal/mango-portals.conf" || \
  fail 'el routing de ScreenCast no selecciona wlr'
[[ $(grep -Rh '^bindl=SUPER,L,' "$TARGET/.config/mango/conf.d" | wc -l) == 1 ]] || \
  fail 'el binding de lock no es único'
[[ $(tail -n 1 "$TARGET/.config/mango/config.conf") == \
   'source-optional=./config.local.conf' ]] || \
  fail 'el override local no tiene la última precedencia'

mapfile -d '' shell_files < <(find \
  "$REPO_ROOT/hooks" "$REPO_ROOT/home" "$REPO_ROOT/tests" \
  -type f -perm -u+x -print0)
shellcheck -x "${shell_files[@]}"

# Todos los procesos y herramientas externas se reemplazan por dobles. La
# prueba inspecciona composición sin necesitar Wayland ni tocar el host.
for command_name in \
  blueman-manager bluetui brightnessctl dbus-update-activation-environment foot fuzzel gammastep grim magick mako \
  mango mmsg notify-send pgrep pkill playerctl powerprofilesctl satty slurp \
  swaybg swayidle systemctl systemd-run waybar wf-recorder wl-copy wlogout \
  overskride rfkill wpctl xdg-open xdg-user-dir; do
  case "$command_name" in
    systemctl|systemd-run|dbus-update-activation-environment)
      ln -s "$REPO_ROOT/tests/fakes/session-control" "$FAKE_BIN/$command_name"
      ;;
    *)
      ln -s "$REPO_ROOT/tests/fakes/desktop-command" "$FAKE_BIN/$command_name"
      ;;
  esac
done
ln -s "$REPO_ROOT/tests/fakes/swaylock" "$FAKE_BIN/swaylock"

export HOME="$TARGET"
export XDG_CONFIG_HOME="$TARGET/.config"
export XDG_STATE_HOME="$STATE"
export XDG_DATA_HOME="$TARGET/.local/share"
export XDG_RUNTIME_DIR="$RUNTIME"
export MANGOWM_TEST_LOG="$LOG"
export MANGOWM_TEST_SERVICE_STATE="$SERVICE_STATE"
export MANGOWM_TEST_MEDIA_ROOT="$MEDIA_ROOT"
export PATH="$FAKE_BIN:/usr/bin"

# The desktop layer the WM requires installs the base prefer-dark entrypoint.
# Swap it for a double so session-start never reaches the host's gsettings, and
# restore the managed link afterwards.
PREFERENCES="$TARGET/.local/lib/dotfiles/session-preferences"
[[ -L "$PREFERENCES" ]] || fail 'la capa desktop no enlazó session-preferences'
managed_preferences=$(readlink -- "$PREFERENCES")
ln -sfn "$REPO_ROOT/tests/fakes/desktop-command" "$PREFERENCES"

"$TARGET/.local/lib/mangowm/session-start"
for unit_name in mangowm-mako mangowm-swayidle mangowm-swaybg mangowm-waybar; do
  grep -q -- "--unit=$unit_name" "$LOG" || fail "session-start no inició $unit_name"
done
grep -q 'WAYLAND_DISPLAY.*XDG_CURRENT_DESKTOP' "$LOG" || \
  fail 'session-start no importó el entorno Wayland'

grep -q '^session-preferences apply ' "$LOG" || \
  fail 'session-start no consumió el contrato de preferencias de la capa desktop'
ln -sfn "$managed_preferences" "$PREFERENCES"

"$TARGET/.local/lib/mangowm/lock"
read -r LOCK_PID < "$RUNTIME/mangowm/swaylock.pid"
kill -0 "$LOCK_PID" 2>/dev/null || fail 'el lock salió antes de estar activo'
"$TARGET/.local/lib/mangowm/lock"
[[ $(grep -c '^swaylock ' "$LOG") == 1 ]] || fail 'el wrapper duplicó Swaylock'

"$TARGET/.local/lib/mangowm/screenshot" region
"$TARGET/.local/lib/mangowm/screenshot" clipboard
"$TARGET/.local/lib/mangowm/screenshot" annotate
[[ $(grep -c 'satty .*--output-filename' "$LOG") == 2 ]] || \
  fail 'las capturas region/annotate no llegaron a Satty'
grep -q '^wl-copy .*--type.*image/png' "$LOG" || fail 'la captura no llegó al clipboard'
grep -Fqx "bind=SUPER+SHIFT,S,spawn,\$HOME/.local/lib/mangowm/screenshot annotate" \
  "$TARGET/.config/mango/conf.d/50-desktop.conf" || \
  fail 'falta el atajo explícito Super+Shift+S para anotar'
grep -Fqx "bind=SUPER,R,spawn,\$HOME/.local/lib/mangowm/recording toggle" \
  "$TARGET/.config/mango/conf.d/50-desktop.conf" || \
  fail 'falta el atajo Super+R para grabar en 50-desktop.conf'
grep -Fqx "bind=NONE,XF86MonBrightnessUp,spawn,\$HOME/.local/lib/mangowm/brightness up" \
  "$TARGET/.config/mango/conf.d/50-desktop.conf" || \
  fail 'falta el atajo XF86MonBrightnessUp en 50-desktop.conf'
grep -Fqx "bind=SUPER,P,spawn,\$HOME/.local/lib/mangowm/color-picker" \
  "$TARGET/.config/mango/conf.d/50-desktop.conf" || \
  fail 'falta el atajo Super+P para color-picker en 50-desktop.conf'
"$TARGET/.local/lib/mangowm/color-picker"
grep -q '^wl-copy .*--type.*text/plain' "$LOG" || fail 'el color no llegó al clipboard'


"$TARGET/.local/lib/mangowm/night-light" on
"$TARGET/.local/lib/mangowm/night-light" off
grep -q '^pkill .*gammastep' "$LOG" || \
  fail 'night-light no invocó pkill para gammastep'
grep -q '^pkill .*waybar' "$LOG" || \
  fail 'night-light no refrescó waybar mediante señal'
# The Waybar bluetooth icon stays native; a click opens bluetui in the
# floating terminal through the terminal helper.
waybar_config="$TARGET/.config/waybar/config.json"
[[ $(jq -r '.bluetooth.format' "$waybar_config") == '󰂯' ]] || fail 'waybar perdió el icono de bluetooth'
bluetooth_click=$(jq -r '.bluetooth["on-click"]' "$waybar_config")
sh -c "$bluetooth_click"
grep -q '^foot --config=[^ ]*/mangowm/foot\.ini --app-id=floating-terminal bluetui $' "$LOG" || \
  fail "el clic de bluetooth no abrió bluetui en el terminal: $bluetooth_click"
"$TARGET/.local/lib/mangowm/brightness" up
"$TARGET/.local/lib/mangowm/media" play-pause
"$TARGET/.local/lib/mangowm/volume" mute
"$TARGET/.local/lib/mangowm/recording" start
[[ $("$TARGET/.local/lib/mangowm/recording" status) == recording ]] || \
  fail 'la grabación no cambió a activa'
recording_json=$("$TARGET/.local/lib/mangowm/recording" waybar)
jq empty <<< "$recording_json" || fail 'recording waybar no devolvió JSON válido al estar activo'
[[ "$recording_json" == *'󰻃 REC'* ]] || fail 'recording waybar no incluyó icono y texto REC'
"$TARGET/.local/lib/mangowm/recording" stop
[[ $("$TARGET/.local/lib/mangowm/recording" status) == stopped ]] || \
  fail 'la grabación no cambió a detenida'
stopped_recording_json=$("$TARGET/.local/lib/mangowm/recording" waybar)
jq empty <<< "$stopped_recording_json" || fail 'recording waybar no devolvió JSON válido al estar inactivo'
[[ "$stopped_recording_json" == *'"text":""'* ]] || fail 'recording waybar no ocultó el texto al detenerse'

[[ $("$TARGET/.local/lib/mangowm/keyboard" get) == "US" ]] || \
  fail 'keyboard get no devolvió el layout por defecto US'
jq empty < <("$TARGET/.local/lib/mangowm/keyboard" status) || \
  fail 'keyboard status no devolvió JSON válido'
grep -Fqx "xkb_rules_options=grp:alt_space_toggle" \
  "$TARGET/.config/mango/conf.d/20-input.conf" || \
  fail 'falta la opción xkb_rules_options=grp:alt_space_toggle para alternar layout'

mkdir -p "$TARGET/Pictures/Wallpapers"
touch "$TARGET/Pictures/Wallpapers/sample.png"
"$TARGET/.local/lib/mangowm/wallpaper" set "$TARGET/Pictures/Wallpapers/sample.png"
[[ -f "$STATE/mangowm/wallpaper" ]] || fail 'wallpaper set no guardó el estado'
"$TARGET/.local/lib/mangowm/wallpaper" restore
"$TARGET/.local/lib/mangowm/wallpaper" select
"$TARGET/.local/lib/mangowm/wallpaper" clear
[[ ! -f "$STATE/mangowm/wallpaper" ]] || fail 'wallpaper clear no eliminó el estado'
grep -Fqx "bind=SUPER,W,spawn,\$HOME/.local/lib/mangowm/wallpaper select" \
  "$TARGET/.config/mango/conf.d/50-desktop.conf" || \
  fail 'falta el atajo Super+W para seleccionar wallpaper'

HOME="$ORIGINAL_HOME" PATH="$ORIGINAL_PATH" "$DOTFILES" doctor --profile core --wm mangowm \
  --wm-profile desktop --stow-only --target "$TARGET" >/dev/null 2>&1 || fail 'doctor falló tras la sesión'
HOME="$ORIGINAL_HOME" PATH="$ORIGINAL_PATH" "$DOTFILES" unlink --profile core --wm mangowm \
  --wm-profile desktop --stow-only --target "$TARGET" --apply >/dev/null 2>&1
[[ ! -e "$TARGET/.config/mango/config.conf" ]] || fail 'unlink dejó enlaces de sesión'

printf 'OK: sesión, tema y wrappers MangoWM validados\n'
