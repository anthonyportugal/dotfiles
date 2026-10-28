#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
DOTFILES="$REPO_ROOT/bin/dotfiles"
TEST_ROOT=""
TEST_TMP_PARENT=${DOTFILES_TEST_TMPDIR:-/tmp}

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  [[ -n "$TEST_ROOT" && "$TEST_ROOT" == "$TEST_TMP_PARENT"/dotfiles-wizard-smoke.* ]] || return 0
  find "$TEST_ROOT" -mindepth 1 -delete
  find "$TEST_ROOT" -depth -type d -empty -delete
}

trap cleanup EXIT

command -v stow >/dev/null 2>&1 || fail "GNU Stow es necesario para este smoke test"
[[ -x "$DOTFILES" ]] || fail "$DOTFILES no es ejecutable"

TEST_ROOT=$(mktemp -d "$TEST_TMP_PARENT/dotfiles-wizard-smoke.XXXXXX")
TARGET_DIR="$TEST_ROOT/home"
FAKE_BIN="$TEST_ROOT/bin"

mkdir -p "$TARGET_DIR" "$FAKE_BIN"

# agent-harness is an independent project: its options are refused.
for option in --agent-harness --harness --agent-harness-path=x --harness-path=x; do
  status=0
  output=$("$DOTFILES" bootstrap --profile core --target "$TARGET_DIR" "$option" 2>&1) || status=$?
  (( status == 2 )) || fail "$option no fue rechazado como error de uso (salida $status)"
  [[ "$output" == *'proyecto independiente'* ]] || fail "$option no explicó que agent-harness es independiente: $output"
done
"$DOTFILES" help | grep -q -- '--agent-harness' && fail "la ayuda sigue documentando --agent-harness"

# 1. Test multi-WM integration via bootstrap flags
"$DOTFILES" bootstrap --profile core --stow-only --target "$TARGET_DIR" \
  --wm mangowm --wm bspwm \
  --apply > "$TEST_ROOT/multi-bootstrap.out"

# Verify that both WM layers were linked
[[ -L "$TARGET_DIR/.config/mango/config.conf" ]] || fail "MangoWM no fue enlazado en multi-WM"
[[ -L "$TARGET_DIR/.config/bspwm/bspwmrc" ]] || fail "BSPWM no fue enlazado en multi-WM"

# 2. Test doctor on multi-WM
"$DOTFILES" doctor --profile core --stow-only --target "$TARGET_DIR" \
  --wm mangowm --wm bspwm > "$TEST_ROOT/multi-doctor.out"

grep -q 'Window Manager (mangowm): OK' "$TEST_ROOT/multi-doctor.out" || fail "Doctor no auditó MangoWM"
grep -q 'Window Manager (bspwm): OK' "$TEST_ROOT/multi-doctor.out" || fail "Doctor no auditó BSPWM"

# 3. Test unlink on multi-WM
"$DOTFILES" unlink --profile core --target "$TARGET_DIR" \
  --wm mangowm --wm bspwm --apply > "$TEST_ROOT/multi-unlink.out"

[[ ! -e "$TARGET_DIR/.config/mango/config.conf" ]] || fail "Unlink no retiró MangoWM"
[[ ! -e "$TARGET_DIR/.config/bspwm/bspwmrc" ]] || fail "Unlink no retiró BSPWM"

# 4. sync re-applies the saved selection without flags (other PCs, laptops, VPS)
CANON_HOME="$TEST_ROOT/canon-home"
mkdir -p "$CANON_HOME/.local/state/dotfiles"
cat > "$CANON_HOME/.local/state/dotfiles/dotfiles.receipt" <<'EOF'
RECEIPT_VERSION=1
COMPONENT="dotfiles"
PROFILE="desktop"
FEATURES=""
WMS="bspwm"
BACKEND=""
EOF

"$DOTFILES" sync --stow-only --target "$CANON_HOME" --apply > "$TEST_ROOT/sync.out"

grep -q 'Selección restaurada del recibo: perfil desktop, WMs bspwm' "$TEST_ROOT/sync.out" || \
  fail "Sync no restauró la selección guardada"
[[ -L "$CANON_HOME/.zshrc" ]] || fail "Sync no enlazó la base"
[[ -L "$CANON_HOME/.config/bspwm/bspwmrc" ]] || fail "Sync no re-aplicó el WM guardado"
[[ ! -e "$CANON_HOME/.config/mango" ]] || fail "Sync instaló un WM que no estaba seleccionado"

# A saved cli profile without WMs is restored without pulling in desktop, and an
# explicit --profile still wins over it.
CLI_HOME="$TEST_ROOT/cli-home"
mkdir -p "$CLI_HOME/.local/state/dotfiles"
printf 'RECEIPT_VERSION=1\nCOMPONENT="dotfiles"\nPROFILE="cli"\nWMS=""\n' \
  > "$CLI_HOME/.local/state/dotfiles/dotfiles.receipt"
"$DOTFILES" sync --stow-only --target "$CLI_HOME" > "$TEST_ROOT/sync-cli.out"
grep -q 'Selección restaurada del recibo: perfil cli$' "$TEST_ROOT/sync-cli.out" || \
  fail "Sync no restauró el perfil cli guardado"
[[ -L "$CLI_HOME/.config/bat/config" ]] || fail "Sync no aplicó el perfil cli guardado"
[[ ! -e "$CLI_HOME/.config/alacritty" ]] || fail "Sync aplicó un perfil más amplio que el cli guardado"

"$DOTFILES" sync --profile core --stow-only --target "$CLI_HOME" > "$TEST_ROOT/sync-explicit.out"
if grep -q 'Selección restaurada del recibo' "$TEST_ROOT/sync-explicit.out"; then
  fail "Sync atribuyó al recibo un perfil que vino de --profile"
fi
grep -qx 'PROFILE="core"' "$CLI_HOME/.local/state/dotfiles/dotfiles.receipt" || \
  fail "Sync no actualizó el recibo de selección con el perfil explícito"

# An invalid saved profile never installs more than core.
INVALID_HOME="$TEST_ROOT/invalid-profile-home"
mkdir -p "$INVALID_HOME/.local/state/dotfiles"
printf 'RECEIPT_VERSION=1\nCOMPONENT="dotfiles"\nPROFILE="everything"\n' \
  > "$INVALID_HOME/.local/state/dotfiles/dotfiles.receipt"
"$DOTFILES" sync --stow-only --target "$INVALID_HOME" > "$TEST_ROOT/sync-invalid.out" 2>&1
grep -q 'perfil inválido en el recibo de selección: everything; se usa core' "$TEST_ROOT/sync-invalid.out" || \
  fail "Sync no avisó del perfil inválido del recibo"
[[ -L "$INVALID_HOME/.zshrc" && ! -e "$INVALID_HOME/.config/bat" ]] || \
  fail "Sync no usó core ante un perfil inválido en el recibo"

# A tampered selection receipt can never reach a layer outside layers/wm/.
TAMPER_HOME="$TEST_ROOT/tamper-home"
OUTSIDE_LAYER="$TEST_ROOT/outside-layer"
mkdir -p "$TAMPER_HOME/.local/state/dotfiles" "$OUTSIDE_LAYER/home" "$OUTSIDE_LAYER/hooks"
printf 'profiles=core desktop\nreceipt=outside\n' > "$OUTSIDE_LAYER/layer.conf"
: > "$OUTSIDE_LAYER/home/.stow"
printf '#!/bin/sh\ntouch %q\n' "$TEST_ROOT/outside-hook-ran" > "$OUTSIDE_LAYER/hooks/validate"
chmod +x "$OUTSIDE_LAYER/hooks/validate"
outside_relative=$(realpath --relative-to="$REPO_ROOT/layers/wm" "$OUTSIDE_LAYER")
{
  printf 'RECEIPT_VERSION=1\n'
  printf 'COMPONENT="dotfiles"\n'
  printf 'PROFILE="core"\n'
  printf 'WMS="%s ../wm/mangowm bspwm"\n' "$outside_relative"
  printf 'FEATURES="yazi-extras ../evil"\n'
} > "$TAMPER_HOME/.local/state/dotfiles/dotfiles.receipt"
"$DOTFILES" sync --stow-only --target "$TAMPER_HOME" > "$TEST_ROOT/tamper.out" 2>&1 || \
  fail "Sync falló con un recibo manipulado en vez de ignorar las entradas inválidas"
[[ ! -e "$TEST_ROOT/outside-hook-ran" ]] || fail "Sync ejecutó un hook de fuera de layers/wm/ desde el recibo"
grep -q 'se ignora un WM inválido en el recibo de selección' "$TEST_ROOT/tamper.out" || \
  fail "Sync no avisó de las entradas inválidas del recibo"
grep -q 'se ignora una feature inválida en el recibo de selección: ../evil' "$TEST_ROOT/tamper.out" || \
  fail "Sync aceptó una feature inválida desde el recibo"
grep -q 'Selección restaurada del recibo: perfil core, features yazi-extras, WMs bspwm' "$TEST_ROOT/tamper.out" || \
  fail "Sync no restauró las entradas válidas del recibo manipulado"
[[ -L "$TAMPER_HOME/.config/bspwm/bspwmrc" ]] || fail "Sync descartó también el WM válido del recibo"
[[ ! -e "$TAMPER_HOME/.config/mango" ]] || fail "Sync aceptó un WM con ruta relativa desde el recibo"

# 5. Test update command (checks git repositories)
"$DOTFILES" update --profile core --stow-only --target "$CANON_HOME"

# 6. Test composite doctor command (auto-detects active components)
"$DOTFILES" doctor --profile core --stow-only --target "$CANON_HOME" > "$TEST_ROOT/auto-doctor.out"

grep -q 'Window Manager (bspwm): OK' "$TEST_ROOT/auto-doctor.out" || fail "Doctor no detectó BSPWM activo automáticamente"
if grep -q 'Window Manager (mangowm)' "$TEST_ROOT/auto-doctor.out"; then
  fail "Doctor detectó MangoWM cuando no estaba activo"
fi

# 6b. WM profile is restored from its receipt (default would be desktop),
# and a receipt without PROFILE falls back instead of aborting.
# Prints the "Perfil:" value of the plan of layer $2 in output file $1.
layer_profile() {
  awk -v header="Plan de la capa $2" '
    index($0, header) { in_layer = 1; next }
    in_layer && /Perfil:/ { print $NF; exit }
  ' "$1"
}
cat > "$CANON_HOME/.local/state/dotfiles/bspwm.receipt" <<'EOF'
RECEIPT_VERSION=1
COMPONENT="bspwm"
PROFILE='core'
EOF
cat > "$CANON_HOME/.local/state/dotfiles/mangowm.receipt" <<'EOF'
RECEIPT_VERSION=1
COMPONENT="mangowm"
EOF

"$DOTFILES" bootstrap --profile core --stow-only --target "$CANON_HOME" \
  --wm bspwm --wm mangowm > "$TEST_ROOT/receipt-profiles.out" ||
  fail "Bootstrap falló con un recibo de WM sin PROFILE"

[[ "$(layer_profile "$TEST_ROOT/receipt-profiles.out" wm/bspwm)" == core ]] || \
  fail "Bootstrap no reutilizó PROFILE=core desde el recibo de BSPWM"
[[ "$(layer_profile "$TEST_ROOT/receipt-profiles.out" wm/mangowm)" == desktop ]] || \
  fail "Bootstrap no usó el perfil por defecto para un recibo de MangoWM sin PROFILE"
rm -f "$CANON_HOME/.local/state/dotfiles/mangowm.receipt"

# 7. Test doctor with --base-only
"$DOTFILES" doctor --profile core --stow-only --target "$CANON_HOME" --base-only > "$TEST_ROOT/base-only.out"

if grep -q 'Plan de la capa wm/' "$TEST_ROOT/base-only.out"; then
  fail "Doctor con --base-only auditó una capa de WM"
fi

echo "OK: Pruebas de Multi-WM, Sync, Update y Composite Doctor validadas exitosamente."
