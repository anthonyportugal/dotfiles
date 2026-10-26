#!/usr/bin/env bash
# Runs the WM layer hooks directly against copies of the real layers.

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
TEST_ROOT=""
TEST_TMP_PARENT=${DOTFILES_TEST_TMPDIR:-/tmp}

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  [[ -n "$TEST_ROOT" && "$TEST_ROOT" == "$TEST_TMP_PARENT"/dotfiles-layer-hooks-smoke.* ]] || return 0
  find "$TEST_ROOT" -mindepth 1 -delete
  find "$TEST_ROOT" -depth -type d -empty -delete
}

trap cleanup EXIT

command -v stow >/dev/null 2>&1 || fail "GNU Stow es necesario para este smoke test"
[[ -d "$TEST_TMP_PARENT" ]] || fail "no existe el directorio temporal: $TEST_TMP_PARENT"
TEST_ROOT=$(mktemp -d "$TEST_TMP_PARENT/dotfiles-layer-hooks-smoke.XXXXXX")

# Runs hook $2 of the layer copy $1 the way bin/dotfiles does. The snippet is
# expanded by the inner shell, hence the single quotes.
# shellcheck disable=SC2016
run_hook() {
  local layer_dir=$1
  local phase=$2
  local operation=$3
  local profile=${4:-desktop}
  DOTFILES_LANG=es "$BASH" -c '
    set -Eeuo pipefail
    for module in colors core layers; do
      # shellcheck source=/dev/null
      source "$1/lib/$module.sh"
    done
    TARGET_DIR=$2 PROFILE=$3 APPLY=$4 OPERATION=$5
    run_layer_hook "$6" "$7"' _ "$REPO_ROOT" "$TARGET" "$profile" "$([[ $phase == post-link ]] && echo 1 || echo 0)" \
    "$operation" "$layer_dir" "$phase"
}

# Copies layer $1 to a fresh directory and prints its path.
copy_layer() {
  local copy="$TEST_ROOT/copies/$1-$RANDOM"
  mkdir -p "$copy"
  cp -a "$REPO_ROOT/layers/wm/$1/." "$copy/"
  printf '%s' "$copy"
}

TARGET="$TEST_ROOT/home"
mkdir -p "$TARGET"
CHECKOUT_STATE=$(git -C "$REPO_ROOT" status --porcelain -- layers)

for wm in bspwm mangowm; do
  layer="$REPO_ROOT/layers/wm/$wm"
  [[ -f "$layer/layer.conf" ]] || fail "falta layers/wm/$wm/layer.conf"
  [[ -x "$layer/hooks/validate" ]] || fail "falta el hook ejecutable layers/wm/$wm/hooks/validate"

  for profile in core desktop; do
    run_hook "$layer" validate bootstrap "$profile" >/dev/null || fail "validate de $wm falló con el perfil $profile"
  done

  # Content outside the layer's ownership is rejected in every operation.
  copy=$(copy_layer "$wm")
  stow_package=$(head -n 1 "$copy/packages/stow/core.txt")
  mkdir -p "$copy/home/$stow_package/.config/pulse"
  printf 'x\n' > "$copy/home/$stow_package/.config/pulse/client.conf"
  for operation in bootstrap doctor unlink; do
    if output=$(run_hook "$copy" validate "$operation" 2>&1); then
      fail "validate de $wm aceptó contenido fuera de su ownership ($operation)"
    fi
    [[ "$output" == *"fuera del ownership"* ]] || fail "validate de $wm falló por otra causa ($operation): $output"
  done
done

# bspwm: a broken session script blocks bootstrap and doctor, not unlink.
copy=$(copy_layer bspwm)
printf 'if then\n' >> "$copy/home/bspwm/.config/bspwm/bspwmrc"
run_hook "$copy" validate bootstrap >/dev/null 2>&1 && fail "validate de bspwm aceptó un bspwmrc con sintaxis inválida"
run_hook "$copy" validate doctor >/dev/null 2>&1 && fail "doctor de bspwm aceptó un bspwmrc con sintaxis inválida"
run_hook "$copy" validate unlink >/dev/null 2>&1 || fail "unlink de bspwm quedó bloqueado por un bspwmrc inválido"

# bspwm: hardcoded hardware names are rejected.
copy=$(copy_layer bspwm)
printf '# xrandr --output HDMI-1\n' >> "$copy/home/bspwm/.config/bspwm/sxhkdrc"
output=$(run_hook "$copy" validate bootstrap 2>&1) && fail "validate de bspwm aceptó un nombre de hardware fijo"
[[ "$output" == *"hardware fijos"* ]] || fail "validate de bspwm falló por otra causa: $output"

# mangowm: the modular config contract is enforced.
copy=$(copy_layer mangowm)
sed -i '/^blur=0$/d' "$copy/home/mango/.config/mango/conf.d/30-layout.conf"
output=$(run_hook "$copy" validate bootstrap 2>&1) && fail "validate de mangowm aceptó un layout sin blur=0"
[[ "$output" == *"desactivar blur"* ]] || fail "validate de mangowm falló por otra causa: $output"
run_hook "$copy" validate unlink >/dev/null 2>&1 || fail "unlink de mangowm quedó bloqueado por la configuración"

copy=$(copy_layer mangowm)
printf 'unexpected=1\n' >> "$copy/home/mango/.config/mango/config.conf"
output=$(run_hook "$copy" validate bootstrap 2>&1) && fail "validate de mangowm aceptó una directiva fuera del entrypoint"
[[ "$output" == *"directiva fuera del entrypoint modular"* ]] || fail "validate de mangowm falló por otra causa: $output"

# mangowm: post-link renders the theme under the target's XDG state.
layer="$REPO_ROOT/layers/wm/mangowm"
[[ -x "$layer/hooks/post-link" ]] || fail "falta el hook ejecutable layers/wm/mangowm/hooks/post-link"
stow --dir="$layer/home" --target="$TARGET" --no-folding mango
run_hook "$layer" post-link bootstrap >/dev/null || fail "post-link de mangowm falló"
[[ -L "$TARGET/.local/state/dotfiles/theme/current" ]] || fail "post-link no publicó theme/current"
[[ -f "$TARGET/.local/state/dotfiles/theme/current/gtk.css" ]] || fail "post-link no renderizó gtk.css"
stow --dir="$layer/home" --target="$TARGET" --no-folding --delete mango
[[ "$(git -C "$REPO_ROOT" status --porcelain -- layers)" == "$CHECKOUT_STATE" ]] || fail "los hooks modificaron el checkout"

printf 'OK: hooks de capa de bspwm y mangowm validados\n'
