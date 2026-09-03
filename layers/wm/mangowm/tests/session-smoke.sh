#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
MANGO="$REPO_ROOT/bin/mango"
TEST_ROOT=''
LOCK_PID=''

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

"$MANGO" bootstrap --profile desktop --feature laptop --feature recording \
  --stow-only --target "$TARGET" --apply >/dev/null 2>&1

for managed_path in \
  .config/mango/config.conf \
  .config/mango/conf.d/50-desktop.conf \
  .config/mango/conf.d/60-laptop.conf \
  .config/mango/conf.d/60-recording.conf \
  .config/waybar/config.json \
  .config/wlogout/layout \
  .config/swayidle/config \
  .config/xdg-desktop-portal/mango-portals.conf \
  .local/bin/mango-theme \
  .local/bin/mangowm-session \
  .local/lib/mangowm/brightness \
  .local/lib/mangowm/recording \
  .local/lib/mangowm/wallpaper; do
  [[ -L "$TARGET/$managed_path" ]] || fail "falta el enlace $managed_path"
done

# El renderer es reproducible, inmutable y sólo escribe en XDG state.
first_revision=$(HOME="$TARGET" XDG_STATE_HOME="$STATE" \
  "$TARGET/.local/bin/mango-theme" render)
first_link=$(readlink -- "$STATE/mangowm/theme/current")
second_revision=$(HOME="$TARGET" XDG_STATE_HOME="$STATE" \
  "$TARGET/.local/bin/mango-theme" render)
second_link=$(readlink -- "$STATE/mangowm/theme/current")
[[ "$first_revision" == "$second_revision" && "$first_link" == "$second_link" ]] || \
  fail 'el renderer no fue idempotente'
[[ ! -e "$REPO_ROOT/.local/state" ]] || fail 'el renderer contaminó el checkout'
grep -Fxq 'accent_name=pink' "$first_revision/metadata" || \
  fail 'el tema activo no conserva Pink'
grep -Fxq 'ignore-empty-password' "$first_revision/swaylock.conf" || \
  fail 'Swaylock permite passwords vacíos'
if command -v foot >/dev/null 2>&1; then
  foot --config="$first_revision/foot.ini" --check-config || \
    fail 'Foot rechazó el adaptador generado'
fi

jq empty "$TARGET/.config/waybar/config.json" || \
  fail 'Waybar no contiene JSON válido'
[[ $(sed -n '/[^[:space:]]/ { s/^[[:space:]]*//; s/\(.\).*/\1/; p; q; }' \
  "$TARGET/.config/wlogout/layout") == '{' ]] || \
  fail 'wlogout recibió un array en lugar de un stream de objetos JSON'
jq -s -e '
  length == 5 and
  all(.[];
    type == "object" and
    (.label as $label |
      ["lock", "logout", "suspend", "reboot", "shutdown"] | index($label)) != null and
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
  "$REPO_ROOT/bin" "$REPO_ROOT/home" "$REPO_ROOT/tests" \
  -type f -perm -u+x -print0)
shellcheck "${shell_files[@]}"

# Todos los procesos y herramientas externas se reemplazan por dobles. La
# prueba inspecciona composición sin necesitar Wayland ni tocar el host.
for command_name in \
  brightnessctl dbus-update-activation-environment fuzzel grim mako \
  mango notify-send playerctl satty slurp swaybg swayidle systemctl systemd-run \
  waybar wf-recorder wl-copy wlogout wlsunset wpctl xdg-open xdg-user-dir; do
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
export XDG_RUNTIME_DIR="$RUNTIME"
export MANGOWM_TEST_LOG="$LOG"
export MANGOWM_TEST_SERVICE_STATE="$SERVICE_STATE"
export MANGOWM_TEST_MEDIA_ROOT="$MEDIA_ROOT"
export PATH="$FAKE_BIN:/usr/bin"

"$TARGET/.local/lib/mangowm/session-start"
for unit_name in mangowm-mako mangowm-swayidle mangowm-swaybg mangowm-waybar; do
  grep -q -- "--unit=$unit_name" "$LOG" || fail "session-start no inició $unit_name"
done
grep -q 'WAYLAND_DISPLAY.*XDG_CURRENT_DESKTOP' "$LOG" || \
  fail 'session-start no importó el entorno Wayland'

# MangoWM inicia sin la base y consume su entrypoint público cuando aparece.
mkdir -p "$TARGET/.local/lib/dotfiles"
ln -s "$REPO_ROOT/tests/fakes/desktop-command" \
  "$TARGET/.local/lib/dotfiles/session-preferences"
"$TARGET/.local/lib/mangowm/session-start"
grep -q '^session-preferences apply ' "$LOG" || \
  fail 'session-start no consumió el contrato opcional de preferencias de base'

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
grep -Fqx "bind=SUPER,Print,spawn,\$HOME/.local/lib/mangowm/screenshot annotate" \
  "$TARGET/.config/mango/conf.d/50-desktop.conf" || \
  fail 'falta el atajo explícito Super+Print para anotar'

"$TARGET/.local/lib/mangowm/night-light" on
"$TARGET/.local/lib/mangowm/night-light" off
"$TARGET/.local/lib/mangowm/brightness" up
"$TARGET/.local/lib/mangowm/media" play-pause
"$TARGET/.local/lib/mangowm/volume" mute
"$TARGET/.local/lib/mangowm/recording" start
[[ $("$TARGET/.local/lib/mangowm/recording" status) == recording ]] || \
  fail 'la grabación no cambió a activa'
"$TARGET/.local/lib/mangowm/recording" stop
[[ $("$TARGET/.local/lib/mangowm/recording" status) == stopped ]] || \
  fail 'la grabación no cambió a detenida'

mkdir -p "$TARGET/Pictures/Wallpapers"
touch "$TARGET/Pictures/Wallpapers/sample.png"
"$TARGET/.local/lib/mangowm/wallpaper" set "$TARGET/Pictures/Wallpapers/sample.png"
[[ -f "$STATE/mangowm/wallpaper" ]] || fail 'wallpaper set no guardó el estado'
"$TARGET/.local/lib/mangowm/wallpaper" restore
"$TARGET/.local/lib/mangowm/wallpaper" select
"$TARGET/.local/lib/mangowm/wallpaper" clear
[[ ! -f "$STATE/mangowm/wallpaper" ]] || fail 'wallpaper clear no eliminó el estado'
grep -Fqx "bind=SUPER+CTRL,W,spawn,\$HOME/.local/lib/mangowm/wallpaper select" \
  "$TARGET/.config/mango/conf.d/50-desktop.conf" || \
  fail 'falta el atajo Super+Ctrl+W para seleccionar wallpaper'

"$MANGO" doctor --profile desktop --feature laptop --feature recording \
  --stow-only --target "$TARGET" >/dev/null 2>&1
"$MANGO" unlink --profile desktop --feature laptop --feature recording \
  --stow-only --target "$TARGET" --apply >/dev/null 2>&1
[[ ! -e "$TARGET/.config/mango/config.conf" ]] || fail 'unlink dejó enlaces de sesión'

printf 'OK: sesión, tema, wrappers y features MangoWM validados\n'
