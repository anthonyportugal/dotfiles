#!/usr/bin/env bash
# Opt-in layers (--layer) driven through bin/dotfiles: they are never part of
# a profile, pull in what they require, are pulled in by their own features,
# are recorded in the selection receipt and come back on sync.

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
  [[ -n "$TEST_ROOT" && "$TEST_ROOT" == "$TEST_TMP_PARENT"/dotfiles-optional-layers-smoke.* ]] || return 0
  rm -rf -- "$TEST_ROOT"
}

trap cleanup EXIT

command -v stow >/dev/null 2>&1 || fail "GNU Stow es necesario para este smoke test"
[[ -d "$TEST_TMP_PARENT" ]] || fail "no existe el directorio temporal: $TEST_TMP_PARENT"
TEST_ROOT=$(mktemp -d "$TEST_TMP_PARENT/dotfiles-optional-layers-smoke.XXXXXX")
CHECKOUT_STATE=$(git -C "$REPO_ROOT" status --porcelain)

# pacman reports nothing installed, so every manifest entry is planned.
FAKE_BIN="$TEST_ROOT/fake-bin"
mkdir -p "$FAKE_BIN"
printf '#!/usr/bin/env bash\nexit 0\n' > "$FAKE_BIN/pacman"
chmod +x "$FAKE_BIN/pacman"

H="$TEST_ROOT/home"
RECEIPT="$H/.local/state/dotfiles/dotfiles.receipt"
mkdir -p "$H"

run() {
  PATH="$FAKE_BIN:$PATH" HOME="$H" "$DOTFILES" "$@"
}

# Prints the part of output $1 that belongs to the plan of layer $2.
layer_section() {
  awk -v header="Plan de la capa $2" '
    index($0, header) { inside = 1; print; next }
    inside && /Plan de la capa / { exit }
    inside { print }
  ' <<< "$1"
}

plan_packages() {
  run bootstrap --packages-only --backend pacman --platform arch --target "$H" "$@" 2>&1
}

# The help documents the selector.
output=$(run help)
[[ "$output" == *'--layer'* ]] || fail "la ayuda no documenta --layer"

# A profile never includes an opt-in layer.
output=$(plan_packages --profile desktop) || fail "el plan desktop falló: $output"
[[ "$output" != *'Plan de la capa dev'* ]] || fail "el perfil desktop incluyó la capa opcional dev"
[[ "$output" != *'Capas opcionales'* ]] || fail "el plan sin --layer cambió su salida con una línea de capas opcionales"

# --layer dev pulls in cli and plans its base tools, not its features.
output=$(plan_packages --profile core --layer dev) || fail "el plan con --layer dev falló: $output"
[[ "$output" == *'Plan de la capa cli'* ]] || fail "--layer dev no aplicó la capa cli que requiere"
[[ "$output" == *'Las capas elegidas requieren la capa cli; se aplica cli en lugar de core'* ]] || \
  fail "--layer dev no explicó por qué subió el perfil a cli"
dev_plan=$(layer_section "$output" dev)
[[ -n "$dev_plan" ]] || fail "--layer dev no planificó la capa dev: $output"
[[ "$dev_plan" == *shellcheck* ]] || fail "la capa dev no planificó sus herramientas base: $dev_plan"
[[ "$dev_plan" != *docker* && "$dev_plan" != *pnpm* ]] || fail "la capa dev planificó features no pedidas: $dev_plan"

# A feature of an opt-in layer pulls the layer in and adds its packages.
output=$(plan_packages --profile core --feature dev-containers) || fail "el plan con dev-containers falló: $output"
dev_plan=$(layer_section "$output" dev)
[[ "$dev_plan" == *docker* ]] || fail "dev-containers no añadió docker a la capa dev: $output"
output=$(plan_packages --profile core --feature dev-js) || fail "el plan con dev-js falló: $output"
[[ "$(layer_section "$output" dev)" == *pnpm* ]] || fail "dev-js no añadió pnpm a la capa dev: $output"

# --feature dev-containers alone raises the profile to cli too.
output=$(plan_packages --profile core --feature dev-containers) || fail "el plan con dev-containers falló: $output"
[[ "$output" == *'Plan de la capa cli'* ]] || fail "dev-containers no aplicó la capa cli que requiere dev"

# A base feature still raises the profile to the layer declaring it.
output=$(plan_packages --profile core --feature yazi-extras) || fail "el plan con yazi-extras falló: $output"
[[ "$output" == *'Plan de la capa cli'* && "$output" != *'Plan de la capa dev'* ]] || \
  fail "yazi-extras dejó de aplicar solo la capa cli: $output"

# Only opt-in layers are accepted, with a usage error (exit 2) otherwise.
for name in nope core cli desktop system wm/bspwm ../core; do
  status=0
  run bootstrap --profile core --target "$H" --layer "$name" >/dev/null 2>&1 || status=$?
  (( status == 2 )) || fail "--layer $name no fue rechazado como error de uso (salida $status)"
done
status=0
run bootstrap --profile core --target "$H" --feature nope >/dev/null 2>&1 || status=$?
(( status == 2 )) || fail "una feature desconocida no fue rechazada (salida $status)"

# Applying links the layer and records it in the selection receipt.
run bootstrap --stow-only --apply --profile core --layer dev --target "$H" >/dev/null 2>&1 || \
  fail "bootstrap --apply con --layer dev falló"
dev_link="$H/.config/zsh/conf.d/50-dev.zsh"
[[ -L "$dev_link" ]] || fail "la capa dev no enlazó su configuración de zsh"
[[ "$(realpath -m -- "$dev_link")" == "$REPO_ROOT/layers/dev/home/"*/.config/zsh/conf.d/50-dev.zsh ]] || \
  fail "el enlace de la capa dev no apunta a layers/dev"
grep -Fxq 'LAYERS="dev"' "$RECEIPT" || fail "el recibo no guardó la capa opcional: $(<"$RECEIPT")"

# sync without flags restores the recorded opt-in layer.
rm -f -- "$dev_link"
output=$(run sync --stow-only --target "$H" 2>&1) || fail "sync falló: $output"
[[ "$output" == *'Plan de la capa dev'* ]] || fail "sync no restauró la capa dev del recibo: $output"
[[ -L "$dev_link" ]] || fail "sync no volvió a enlazar la capa dev"

# An explicit --layer on sync overrides the receipt; an empty selection is
# recorded as such.
output=$(run sync --stow-only --profile core --target "$H" 2>&1) || fail "sync --profile core falló: $output"
grep -Fxq 'LAYERS="dev"' "$RECEIPT" || fail "sync sin --layer perdió la capa del recibo: $(<"$RECEIPT")"

# An unknown layer in the receipt is ignored with a warning.
sed -i 's/^LAYERS=.*/LAYERS="dev nope"/' "$RECEIPT"
output=$(run sync --stow-only --target "$H" 2>&1) || fail "sync falló con una capa inválida en el recibo: $output"
[[ "$output" == *'se ignora una capa inválida en el recibo de selección: nope'* ]] || \
  fail "sync no avisó de la capa inválida del recibo: $output"

# unlink removes the opt-in layer's links too.
run unlink --apply --profile core --layer dev --target "$H" >/dev/null 2>&1 || fail "unlink con --layer dev falló"
[[ ! -e "$dev_link" && ! -L "$dev_link" ]] || fail "unlink no retiró el enlace de la capa dev"

[[ "$(git -C "$REPO_ROOT" status --porcelain)" == "$CHECKOUT_STATE" ]] || fail "las capas opcionales modificaron el checkout"

printf 'OK: capas opcionales validadas\n'
