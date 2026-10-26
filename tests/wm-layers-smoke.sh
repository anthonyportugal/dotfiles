#!/usr/bin/env bash
# WM layers driven through bin/dotfiles: receipts, profile reuse, collisions,
# unlink and the package commands of every backend. Ported from the former
# per-WM CLIs (layers/wm/*/bin/*).

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
DOTFILES="$REPO_ROOT/bin/dotfiles"
export DOTFILES_LANG=es
TEST_ROOT=""
TEST_TMP_PARENT=${DOTFILES_TEST_TMPDIR:-/tmp}

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  [[ -n "$TEST_ROOT" && "$TEST_ROOT" == "$TEST_TMP_PARENT"/dotfiles-wm-layers-smoke.* ]] || return 0
  find "$TEST_ROOT" -mindepth 1 -delete
  find "$TEST_ROOT" -depth -type d -empty -delete
}

trap cleanup EXIT

command -v stow >/dev/null 2>&1 || fail "GNU Stow es necesario para este smoke test"
[[ -d "$TEST_TMP_PARENT" ]] || fail "no existe el directorio temporal: $TEST_TMP_PARENT"
TEST_ROOT=$(mktemp -d "$TEST_TMP_PARENT/dotfiles-wm-layers-smoke.XXXXXX")

# WM layers require desktop, so they must not repeat what core, cli and desktop
# already install. Optional base features (yazi-extras) are not counted: a WM
# may need those packages without the feature.
manifest_entries() {
  cat -- "$@" | grep -v '^[[:space:]]*#' | grep -v '^[[:space:]]*$' | sort -u || true
}
mapfile -t base_manifests < <(find "$REPO_ROOT"/layers/{core,cli,desktop}/packages \
  \( -path '*/repo/*.txt' -o -path '*/cachyos/*.txt' -o -name '*-fallback.txt' \) ! -name 'yazi-extras.txt')
base_packages=$(manifest_entries "${base_manifests[@]}")
for manifest in "$REPO_ROOT"/layers/wm/*/packages/{repo,aur,cachyos,external}/*.txt; do
  [[ -f "$manifest" ]] || continue
  repeated=$(manifest_entries "$manifest" | comm -12 - <(printf '%s\n' "$base_packages"))
  [[ -z "$repeated" ]] || fail "${manifest#"$REPO_ROOT"/} repite paquetes de las capas base: ${repeated//$'\n'/ }"
done

# Prints the part of output file $1 that belongs to the plan of layer $2.
layer_section() {
  awk -v header="Plan de la capa $2" '
    index($0, header) { inside = 1; print; next }
    inside && /Plan de la capa / { exit }
    inside { print }
  ' "$1"
}

# Runs bin/dotfiles with base profile core, which keeps the base part small.
wm_run() {
  "$DOTFILES" "$1" --profile core "${@:2}"
}

# check_wm_lifecycle WM OWNED_PATH STOW_PACKAGE
check_wm_lifecycle() {
  local wm=$1 owned=$2 package=$3
  local target="$TEST_ROOT/$wm home with spaces"
  local conflict="$TEST_ROOT/$wm-conflict"
  local parent_conflict="$TEST_ROOT/$wm-parent-conflict"
  local receipt="$target/.local/state/dotfiles/$wm.receipt"
  local out="$TEST_ROOT/$wm"
  mkdir -p "$target" "$conflict" "$parent_conflict" "$TEST_ROOT/$wm-parent-destination"

  # A dry-run never touches the target.
  wm_run bootstrap --stow-only --target "$target" --wm "$wm" --wm-profile desktop > "$out-dry.out"
  [[ ! -e "$target/$owned" ]] || fail "$wm: el dry-run creó un enlace"
  [[ ! -e "$receipt" ]] || fail "$wm: el dry-run creó el recibo de estado"

  # Apply links the layer and writes its receipt.
  wm_run bootstrap --stow-only --target "$target" --wm "$wm" --wm-profile desktop --apply > "$out-apply.out"
  [[ -L "$target/$owned" ]] || fail "$wm: bootstrap no creó el enlace esperado"
  [[ "$(realpath -m -- "$target/$owned")" == "$REPO_ROOT/layers/wm/$wm/home/$package/$owned" ]] || \
    fail "$wm: el enlace no apunta al owner correcto"
  grep -qx 'RECEIPT_VERSION=1' "$receipt" || fail "$wm: el recibo no define RECEIPT_VERSION=1"
  grep -qx "COMPONENT=\"$wm\"" "$receipt" || fail "$wm: el recibo no define COMPONENT=\"$wm\""
  grep -qx 'PROFILE="desktop"' "$receipt" || fail "$wm: el recibo no guardó PROFILE=desktop"
  grep -q '^BACKEND=' "$receipt" || fail "$wm: el recibo no define BACKEND"
  grep -q '^UPDATED_AT=' "$receipt" || fail "$wm: el recibo no define UPDATED_AT"

  # Without --wm-profile the saved profile is reused; an explicit one wins. The
  # saved profile is core so it cannot be confused with the desktop default.
  wm_run bootstrap --stow-only --target "$target" --wm "$wm" --wm-profile core --apply > "$out-core.out"
  grep -qx 'PROFILE="core"' "$receipt" || fail "$wm: el recibo no guardó PROFILE=core"
  wm_run doctor --stow-only --target "$target" --wm "$wm" > "$out-doctor-receipt.out" || \
    fail "$wm: doctor sin --wm-profile falló al reutilizar el recibo"
  layer_section "$out-doctor-receipt.out" "wm/$wm" | grep -Eq 'Perfil:[[:space:]]+core' || \
    fail "$wm: doctor no reutilizó el perfil core del recibo"
  wm_run bootstrap --stow-only --target "$target" --wm "$wm" > "$out-bootstrap-receipt.out"
  layer_section "$out-bootstrap-receipt.out" "wm/$wm" | grep -Eq 'Perfil:[[:space:]]+core' || \
    fail "$wm: bootstrap no reutilizó el perfil core del recibo"
  wm_run bootstrap --stow-only --target "$target" --wm "$wm" --wm-profile desktop > "$out-bootstrap-desktop.out"
  layer_section "$out-bootstrap-desktop.out" "wm/$wm" | grep -Eq 'Perfil:[[:space:]]+desktop' || \
    fail "$wm: --wm-profile desktop no sobreescribió el recibo en bootstrap"

  # Idempotence.
  wm_run bootstrap --stow-only --target "$target" --wm "$wm" --wm-profile desktop --apply > "$out-again.out"
  wm_run doctor --stow-only --target "$target" --wm "$wm" --wm-profile desktop > "$out-doctor.out" || \
    fail "$wm: doctor falló después de un bootstrap idempotente"

  # A collision stops before the existing file is modified.
  mkdir -p "$conflict/${owned%/*}"
  printf 'local\n' > "$conflict/$owned"
  if wm_run bootstrap --stow-only --target "$conflict" --wm "$wm" > "$out-conflict.out" 2>&1; then
    fail "$wm: el dry-run aceptó una colisión"
  fi
  grep -q 'colisión' "$out-conflict.out" || fail "$wm: no se reportó la colisión"
  [[ -f "$conflict/$owned" && ! -L "$conflict/$owned" && "$(cat "$conflict/$owned")" == local ]] || \
    fail "$wm: el preflight modificó el archivo en conflicto"

  ln -s "$TEST_ROOT/$wm-parent-destination" "$parent_conflict/.config"
  if wm_run bootstrap --stow-only --target "$parent_conflict" --wm "$wm" > "$out-parent.out" 2>&1; then
    fail "$wm: el dry-run aceptó un directorio padre enlazado fuera del target"
  fi
  grep -q 'directorio padre es symlink' "$out-parent.out" || \
    fail "$wm: no se explicó la colisión del directorio padre"

  # Unlink simulates first and never removes system packages.
  wm_run unlink --target "$target" --wm "$wm" --wm-profile desktop > "$out-unlink-dry.out"
  [[ -L "$target/$owned" ]] || fail "$wm: el dry-run de unlink retiró el enlace"
  [[ -f "$receipt" ]] || fail "$wm: el dry-run de unlink eliminó el recibo"
  wm_run unlink --target "$target" --wm "$wm" --wm-profile desktop --apply > "$out-unlink.out"
  [[ ! -e "$target/$owned" ]] || fail "$wm: unlink dejó el enlace administrado"
  [[ ! -e "$receipt" ]] || fail "$wm: unlink --apply no eliminó el recibo"
  if wm_run doctor --stow-only --target "$target" --wm "$wm" --wm-profile desktop \
      > "$out-doctor-after-unlink.out" 2>&1; then
    fail "$wm: doctor debía detectar los enlaces ausentes después de unlink"
  fi
}

check_wm_lifecycle bspwm .config/bspwm/bspwmrc bspwm
check_wm_lifecycle mangowm .config/mango/config.conf mango

# Adapters: a fake pacman reports every package as missing without touching the
# host, and fake helpers expose the generated commands.
FAKE_BIN="$TEST_ROOT/fake-bin"
mkdir -p "$FAKE_BIN"
ln -s /usr/bin/false "$FAKE_BIN/pacman"
for backend in shelly paru yay; do
  ln -s /usr/bin/true "$FAKE_BIN/$backend"
done

# packages_plan WM WM_PROFILE OUTPUT [bin/dotfiles options...]
packages_plan() {
  local wm=$1 profile=$2 output=$3 status=0
  shift 3
  PATH="$FAKE_BIN:/usr/bin" wm_run bootstrap --packages-only --wm "$wm" --wm-profile "$profile" "$@" \
    > "$output.full" 2>&1 || status=$?
  layer_section "$output.full" "wm/$wm" > "$output"
  return "$status"
}

# check_wm_backends WM AUR_PATTERN DESKTOP_REPO_PATTERN CACHYOS_CORE_PATTERN
check_wm_backends() {
  local wm=$1 aur_pattern=$2 desktop_repo=$3 cachyos_core=$4
  local out="$TEST_ROOT/$wm-pkg"

  packages_plan "$wm" desktop "$out-shelly.out" --platform arch --backend shelly || \
    fail "$wm: el plan con Shelly falló"
  grep -q 'shelly install standard' "$out-shelly.out" || fail "$wm: falta el comando de repositorio para Shelly"
  grep -Eq "shelly install aur .*$aur_pattern" "$out-shelly.out" || fail "$wm: Shelly no conserva el lote AUR declarado"
  grep -Eq "Paquetes repo:[[:space:]].*$desktop_repo" "$out-shelly.out" || \
    fail "$wm: el perfil desktop no declaró los paquetes esperados"

  packages_plan "$wm" core "$out-cachyos.out" --platform cachyos || fail "$wm: el plan en CachyOS falló"
  grep -Eq 'Backend:[[:space:]]+shelly' "$out-cachyos.out" || fail "$wm: CachyOS no priorizó Shelly"
  grep -Eq "Paquetes repo:[[:space:]].*$cachyos_core" "$out-cachyos.out" || \
    fail "$wm: el perfil core no declaró los paquetes esperados en CachyOS"

  local backend
  for backend in paru yay; do
    packages_plan "$wm" desktop "$out-$backend.out" --platform arch --backend "$backend" || \
      fail "$wm: el plan con $backend falló"
    grep -q "$backend -S --needed --repo" "$out-$backend.out" || \
      fail "$wm: $backend no restringió el lote binario a repositorios"
    grep -Eq "$backend -S --needed --aur .*$aur_pattern" "$out-$backend.out" || \
      fail "$wm: $backend no restringió el lote AUR a su procedencia"
  done

  if packages_plan "$wm" desktop "$out-pacman.out" --platform arch --backend pacman; then
    fail "$wm: pacman aceptó un paquete AUR faltante"
  fi
  # The desktop layer the WM requires may already stop pacman, so check the whole run.
  grep -q 'pacman sólo gestiona repositorios' "$out-pacman.out.full" || fail "$wm: pacman no explicó su límite"
}

check_wm_backends bspwm 'i3lock-color' 'polybar' 'bspwm.*xorg-setxkbmap'
check_wm_backends mangowm 'swaylock-effects.*wlogout' 'mangowm.*brightnessctl.*wf-recorder' 'mangowm.*swaylock-effects'

# A feature pulls in the layer that declares it, like a WM pulls in desktop.
PATH="$FAKE_BIN:/usr/bin" "$DOTFILES" bootstrap --profile core --feature yazi-extras \
  --packages-only --platform arch > "$TEST_ROOT/feature-core.out" 2>&1 || fail "core + yazi-extras falló"
grep -q 'La feature yazi-extras requiere la capa cli; se aplica cli en lugar de core' "$TEST_ROOT/feature-core.out" || \
  fail "core + yazi-extras no explicó que sube el perfil a cli"
layer_section "$TEST_ROOT/feature-core.out" cli | grep -Eq 'Paquetes repo:.*ripgrep' || \
  fail "core + yazi-extras no instaló los paquetes de la feature"

printf 'OK: capas de WM validadas a través de bin/dotfiles (recibos, perfiles, colisiones, unlink y backends)\n'
