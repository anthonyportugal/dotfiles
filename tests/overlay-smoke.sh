#!/usr/bin/env bash
# Overlays (--overlay DIR) driven through bin/dotfiles: a second layers root
# whose layers apply on their own once what they require is selected, whose
# path is recorded in the selection receipt, and which update pulls too.

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
# shellcheck source=SCRIPTDIR/lib/checkout-copy.sh
source "$SCRIPT_DIR/lib/checkout-copy.sh"
DOTFILES="$REPO_ROOT/bin/dotfiles"
export DOTFILES_LANG=es
TEST_ROOT=""
TEST_TMP_PARENT=${DOTFILES_TEST_TMPDIR:-/tmp}

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  [[ -n "$TEST_ROOT" && "$TEST_ROOT" == "$TEST_TMP_PARENT"/dotfiles-overlay-smoke.* ]] || return 0
  rm -rf -- "$TEST_ROOT"
}

trap cleanup EXIT

command -v stow >/dev/null 2>&1 || fail "GNU Stow es necesario para este smoke test"
[[ -d "$TEST_TMP_PARENT" ]] || fail "no existe el directorio temporal: $TEST_TMP_PARENT"
TEST_ROOT=$(mktemp -d "$TEST_TMP_PARENT/dotfiles-overlay-smoke.XXXXXX")
CHECKOUT_STATE=$(git -C "$REPO_ROOT" status --porcelain)

# Creates overlay layer $2 under overlay root $1 with layer.conf lines $3..
# and one Stow package named after the layer that owns .config/overlay/$2.
make_overlay_layer() {
  local root=$1 name=$2
  shift 2
  mkdir -p "$root/layers/$name/packages/stow" "$root/layers/$name/home/$name/.config/overlay"
  printf '%s\n' "$@" > "$root/layers/$name/layer.conf"
  printf '%s\n' "$name" > "$root/layers/$name/packages/stow/$name.txt"
  printf '%s\n' "$name" > "$root/layers/$name/home/$name/.config/overlay/$name"
  : > "$root/layers/$name/home/.stow"
}

# The fixture overlay: ident applies with core, devx only with the public dev
# layer, and the feature work adds its own Stow package to ident.
OVERLAY="$TEST_ROOT/overlay with spaces"
make_overlay_layer "$OVERLAY" ident requires=core profiles=ident features=work prune_dirs=.config/overlay
mkdir -p "$OVERLAY/layers/ident/home/work/.config/overlay"
printf 'work\n' > "$OVERLAY/layers/ident/packages/stow/work.txt"
printf 'work\n' > "$OVERLAY/layers/ident/home/work/.config/overlay/work"
make_overlay_layer "$OVERLAY" devx requires=dev profiles=devx prune_dirs=.config/overlay

H="$TEST_ROOT/home"
RECEIPT="$H/.local/state/dotfiles/dotfiles.receipt"
mkdir -p "$H"

run() {
  HOME="$H" "$DOTFILES" "$@"
}

apply() {
  run bootstrap --stow-only --apply --target "$H" "$@"
}

linked_to_overlay() {
  [[ -L "$H/.config/overlay/$1" && "$(realpath -m -- "$H/.config/overlay/$1")" == "$OVERLAY/layers/"*"/home/$1/.config/overlay/$1" ]]
}

# The help documents the selector and the old private flags are gone.
output=$(run help)
[[ "$output" == *'--overlay'* && "$output" == *'--no-overlay'* ]] || fail "la ayuda no documenta --overlay y --no-overlay"
[[ "$output" != *'--private'* ]] || fail "la ayuda sigue documentando --private"
for option in --private --private-path=x --private-profile=core --private-work=x; do
  status=0
  output=$(run bootstrap --profile core --target "$H" "$option" 2>&1) || status=$?
  (( status == 2 )) || fail "$option no fue rechazado como error de uso (salida $status)"
  [[ "$output" == *'--overlay'* ]] || fail "$option no indicó que se reemplazó por --overlay: $output"
done

# A layer applies when what it requires is selected, and only then.
output=$(apply --profile core --overlay "$OVERLAY" 2>&1) || fail "bootstrap con --overlay falló: $output"
[[ "$output" == *'Plan de la capa ident'* ]] || fail "el plan no incluyó la capa del overlay: $output"
linked_to_overlay ident || fail "la capa ident del overlay no se enlazó desde el overlay"
[[ ! -e "$H/.config/overlay/devx" ]] || fail "devx se aplicó sin la capa dev que requiere"
[[ ! -e "$H/.config/overlay/work" ]] || fail "la feature work se aplicó sin pedirla"
grep -Fxq "OVERLAY=\"$OVERLAY\"" "$RECEIPT" || fail "el recibo no guardó la ruta del overlay: $(<"$RECEIPT")"

# With the public layer it requires, the dependent overlay layer applies too,
# and a feature of an overlay layer adds its Stow packages.
apply --profile core --layer dev --feature work --overlay "$OVERLAY" >/dev/null 2>&1 || \
  fail "bootstrap con --layer dev y --feature work falló"
linked_to_overlay devx || fail "devx no se aplicó junto a la capa dev"
linked_to_overlay work || fail "la feature work no enlazó su paquete Stow"

# doctor labels overlay layers.
output=$(run doctor --stow-only --profile core --layer dev --feature work --overlay "$OVERLAY" --target "$H" 2>&1) || \
  fail "doctor con --overlay falló: $output"
[[ "$output" == *'Overlay (ident): OK'* ]] || fail "doctor no auditó la capa del overlay: $output"

# sync without flags re-applies the recorded overlay.
rm -f -- "$H/.config/overlay/ident"
output=$(run sync --stow-only --target "$H" 2>&1) || fail "sync falló: $output"
linked_to_overlay ident || fail "sync no volvió a aplicar el overlay del recibo"

# A recorded overlay that is gone stops sync instead of dropping it silently.
mv -- "$OVERLAY" "$OVERLAY.moved"
status=0
output=$(run sync --stow-only --target "$H" 2>&1) || status=$?
(( status != 0 )) || fail "sync siguió sin el overlay guardado"
[[ "$output" == *'--no-overlay'* ]] || fail "sync no explicó cómo continuar sin el overlay: $output"
mv -- "$OVERLAY.moved" "$OVERLAY"

# --no-overlay drops the overlay from the selection.
apply --profile core --no-overlay >/dev/null 2>&1 || fail "bootstrap --no-overlay falló"
grep -Fxq 'OVERLAY=""' "$RECEIPT" || fail "--no-overlay no limpió el overlay del recibo: $(<"$RECEIPT")"
status=0
run bootstrap --profile core --target "$H" --overlay "$OVERLAY" --no-overlay >/dev/null 2>&1 || status=$?
(( status == 2 )) || fail "--overlay junto a --no-overlay no fue rechazado (salida $status)"

# unlink removes the overlay layers' links.
apply --profile core --overlay "$OVERLAY" >/dev/null 2>&1 || fail "bootstrap con --overlay falló"
run unlink --apply --profile core --overlay "$OVERLAY" --target "$H" >/dev/null 2>&1 || fail "unlink con --overlay falló"
[[ ! -L "$H/.config/overlay/ident" ]] || fail "unlink no retiró los enlaces del overlay"

# Invalid overlays are refused before anything is touched.
expect_refused() {
  local label=$1 overlay=$2 status=0 output
  local target="$TEST_ROOT/refused-home"
  mkdir -p "$target"
  output=$(HOME="$target" "$DOTFILES" bootstrap --stow-only --apply --profile core --target "$target" \
    --overlay "$overlay" 2>&1) || status=$?
  (( status != 0 )) || fail "se aceptó un overlay inválido ($label)"
  [[ "$output" == *"$3"* ]] || fail "overlay inválido ($label) sin el mensaje esperado: $output"
  [[ -z "$(ls -A "$target")" ]] || fail "un overlay inválido ($label) modificó el target"
}
expect_refused missing "$TEST_ROOT/missing" 'no existe el overlay'
mkdir -p "$TEST_ROOT/no-layers"
expect_refused no-layers "$TEST_ROOT/no-layers" 'no contiene layers/'
expect_refused inside-repo "$REPO_ROOT/layers" 'fuera del repositorio'
CLASH="$TEST_ROOT/clash"
make_overlay_layer "$CLASH" cli requires=core profiles=cli
expect_refused clash "$CLASH" 'ya existe en el repositorio público'
SHADOW="$TEST_ROOT/shadow"
make_overlay_layer "$SHADOW" ident requires=core profiles=ident
make_overlay_layer "$SHADOW/layers/wm" bspwm requires=desktop profiles=desktop
mv -- "$SHADOW/layers/wm/layers/bspwm" "$SHADOW/layers/wm/bspwm" && rmdir -- "$SHADOW/layers/wm/layers"
expect_refused wm-shadow "$SHADOW" 'la capa wm del overlay ya existe en el repositorio público'
TYPO="$TEST_ROOT/typo"
make_overlay_layer "$TYPO" ident requires=coer profiles=ident
expect_refused typo "$TYPO" 'requiere una capa que no existe: coer'
RESERVED="$TEST_ROOT/reserved"
make_overlay_layer "$RESERVED" ident requires=core profiles=ident receipt=dotfiles
expect_refused reserved-receipt "$RESERVED" 'recibo reservado'

# update fast-forwards the recorded overlay too, then re-applies it.
UPSTREAM="$TEST_ROOT/upstream"
CHECKOUT="$TEST_ROOT/checkout"
OVERLAY_UPSTREAM="$TEST_ROOT/overlay-upstream"
OVERLAY_CHECKOUT="$TEST_ROOT/overlay-checkout"
commit_all() {
  git -C "$1" add -A
  git -C "$1" -c user.name=t -c user.email=t@t commit -qm "$2" --allow-empty --no-verify
}
copy_checkout "$REPO_ROOT" "$UPSTREAM"
# CI checks out a detached HEAD, and update can only pull on a branch.
git -C "$UPSTREAM" switch -qC upstream
commit_all "$UPSTREAM" wip
git clone -q "$UPSTREAM" "$CHECKOUT"
cp -a "$OVERLAY" "$OVERLAY_UPSTREAM"
git -C "$OVERLAY_UPSTREAM" init -q
commit_all "$OVERLAY_UPSTREAM" init
git clone -q "$OVERLAY_UPSTREAM" "$OVERLAY_CHECKOUT"
UH="$TEST_ROOT/update-home"
mkdir -p "$UH"
HOME="$UH" "$CHECKOUT/bin/dotfiles" bootstrap --stow-only --apply --profile core \
  --overlay "$OVERLAY_CHECKOUT" --target "$UH" >/dev/null 2>&1 || fail "bootstrap previo a update falló"
make_overlay_layer "$OVERLAY_UPSTREAM" extra requires=core profiles=extra prune_dirs=.config/overlay
commit_all "$OVERLAY_UPSTREAM" extra
output=$(HOME="$UH" "$CHECKOUT/bin/dotfiles" update -y --stow-only --target "$UH" 2>&1) || fail "update falló: $output"
[[ "$output" == *'overlay-checkout: actualizado'* ]] || fail "update no actualizó el overlay: $output"
[[ -L "$UH/.config/overlay/extra" ]] || fail "update no aplicó la capa nueva del overlay"

[[ "$(git -C "$REPO_ROOT" status --porcelain)" == "$CHECKOUT_STATE" ]] || fail "el overlay modificó el checkout"

printf 'OK: overlays validados\n'
