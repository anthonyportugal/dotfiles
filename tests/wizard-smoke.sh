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
WALLS_REPO="$TEST_ROOT/walls"
PRIVATE_REPO="$TEST_ROOT/private"
HARNESS_REPO="$TEST_ROOT/agent-harness"

WALLS_LOG="$TEST_ROOT/walls.log"
PRIVATE_LOG="$TEST_ROOT/private.log"
HARNESS_LOG="$TEST_ROOT/harness.log"

mkdir -p "$TARGET_DIR" "$FAKE_BIN" "$WALLS_REPO/bin" "$PRIVATE_REPO/bin" "$HARNESS_REPO/bin"
ln -s "$SCRIPT_DIR/fakes/walls-entrypoint" "$WALLS_REPO/bin/walls"
ln -s "$SCRIPT_DIR/fakes/private-entrypoint" "$PRIVATE_REPO/bin/dotfiles-private"
ln -s "$SCRIPT_DIR/fakes/harness-entrypoint" "$HARNESS_REPO/bin/agent-harness"

: > "$WALLS_LOG"
: > "$PRIVATE_LOG"
: > "$HARNESS_LOG"

# 1. Test multi-WM, private, and agent-harness integration via bootstrap flags
DOTFILES_WALLS_TEST_LOG="$WALLS_LOG" \
DOTFILES_PRIVATE_TEST_LOG="$PRIVATE_LOG" \
DOTFILES_HARNESS_TEST_LOG="$HARNESS_LOG" \
"$DOTFILES" bootstrap --profile core --stow-only --target "$TARGET_DIR" \
  --wm mangowm --wm bspwm \
  --wallpapers --wallpapers-path "$WALLS_REPO" \
  --private --private-path "$PRIVATE_REPO" --private-profile development --private-work corp \
  --agent-harness --agent-harness-path "$HARNESS_REPO" \
  --apply > "$TEST_ROOT/multi-bootstrap.out"

# Verify that both WM layers were linked and walls, private, and agent-harness invoked
[[ -L "$TARGET_DIR/.config/mango/config.conf" ]] || fail "MangoWM no fue enlazado en multi-WM"
[[ -L "$TARGET_DIR/.config/bspwm/bspwmrc" ]] || fail "BSPWM no fue enlazado en multi-WM"
grep -q 'link' "$WALLS_LOG" || fail "Walls link no fue invocado"
grep -q 'corp' "$PRIVATE_LOG" || fail "Private work corp no fue invocado"
grep -q 'development' "$PRIVATE_LOG" || fail "Private profile development no fue invocado"
grep -q 'setup' "$HARNESS_LOG" || fail "Agent Harness setup no fue invocado"

# 2. Test doctor on multi-WM, private, and agent-harness
: > "$WALLS_LOG"
: > "$PRIVATE_LOG"
: > "$HARNESS_LOG"

DOTFILES_WALLS_TEST_LOG="$WALLS_LOG" \
DOTFILES_PRIVATE_TEST_LOG="$PRIVATE_LOG" \
DOTFILES_HARNESS_TEST_LOG="$HARNESS_LOG" \
"$DOTFILES" doctor --profile core --stow-only --target "$TARGET_DIR" \
  --wm mangowm --wm bspwm \
  --wallpapers --wallpapers-path "$WALLS_REPO" \
  --private --private-path "$PRIVATE_REPO" \
  --agent-harness --agent-harness-path "$HARNESS_REPO" > "$TEST_ROOT/multi-doctor.out"

grep -q 'Window Manager (mangowm): OK' "$TEST_ROOT/multi-doctor.out" || fail "Doctor no auditó MangoWM"
grep -q 'Window Manager (bspwm): OK' "$TEST_ROOT/multi-doctor.out" || fail "Doctor no auditó BSPWM"
grep -q 'walls' "$WALLS_LOG" || fail "Doctor no invocó Walls"
grep -q 'private' "$PRIVATE_LOG" || fail "Doctor no invocó Private"
grep -q 'doctor' "$HARNESS_LOG" || fail "Doctor no invocó Agent Harness"

# 3. Test unlink on multi-WM, private, and agent-harness
: > "$WALLS_LOG"
: > "$PRIVATE_LOG"
: > "$HARNESS_LOG"

DOTFILES_WALLS_TEST_LOG="$WALLS_LOG" \
DOTFILES_PRIVATE_TEST_LOG="$PRIVATE_LOG" \
DOTFILES_HARNESS_TEST_LOG="$HARNESS_LOG" \
"$DOTFILES" unlink --profile core --target "$TARGET_DIR" \
  --wm mangowm --wm bspwm \
  --wallpapers --wallpapers-path "$WALLS_REPO" \
  --private --private-path "$PRIVATE_REPO" \
  --agent-harness --agent-harness-path "$HARNESS_REPO" --apply > "$TEST_ROOT/multi-unlink.out"

[[ ! -e "$TARGET_DIR/.config/mango/config.conf" ]] || fail "Unlink no retiró MangoWM"
[[ ! -e "$TARGET_DIR/.config/bspwm/bspwmrc" ]] || fail "Unlink no retiró BSPWM"
grep -q 'unlink' "$WALLS_LOG" || fail "Unlink no invocó Walls"
grep -q 'unlink' "$PRIVATE_LOG" || fail "Unlink no invocó Private"

# 4. sync re-applies the saved selection without flags (other PCs, laptops, VPS)
CANON_HOME="$TEST_ROOT/canon-home"
mkdir -p "$CANON_HOME/.dotfiles/walls/bin" \
         "$CANON_HOME/.dotfiles/private/bin" \
         "$CANON_HOME/.dotfiles/agent-harness/bin"

ln -s "$SCRIPT_DIR/fakes/walls-entrypoint" "$CANON_HOME/.dotfiles/walls/bin/walls"
ln -s "$SCRIPT_DIR/fakes/private-entrypoint" "$CANON_HOME/.dotfiles/private/bin/dotfiles-private"
ln -s "$SCRIPT_DIR/fakes/harness-entrypoint" "$CANON_HOME/.dotfiles/agent-harness/bin/agent-harness"

: > "$WALLS_LOG"
: > "$PRIVATE_LOG"
: > "$HARNESS_LOG"

mkdir -p "$CANON_HOME/.local/state/dotfiles"
cat > "$CANON_HOME/.local/state/dotfiles/private.receipt" <<'EOF'
RECEIPT_VERSION=1
COMPONENT="private"
PROFILE="development"
WORK="corp"
EOF
cat > "$CANON_HOME/.local/state/dotfiles/dotfiles.receipt" <<'EOF'
RECEIPT_VERSION=1
COMPONENT="dotfiles"
PROFILE="core"
FEATURES=""
WMS="bspwm"
BACKEND=""
EOF

DOTFILES_WALLS_TEST_LOG="$WALLS_LOG" \
DOTFILES_PRIVATE_TEST_LOG="$PRIVATE_LOG" \
DOTFILES_HARNESS_TEST_LOG="$HARNESS_LOG" \
"$DOTFILES" sync --stow-only --target "$CANON_HOME" --apply > "$TEST_ROOT/sync.out"

grep -q 'Selección restaurada del recibo: perfil core, WMs bspwm' "$TEST_ROOT/sync.out" || \
  fail "Sync no restauró la selección guardada"
[[ -L "$CANON_HOME/.zshrc" ]] || fail "Sync no enlazó la base"
[[ ! -e "$CANON_HOME/.config/bat" ]] || fail "Sync aplicó un perfil más amplio que el core guardado"
[[ -L "$CANON_HOME/.config/bspwm/bspwmrc" ]] || fail "Sync no re-aplicó el WM guardado"
[[ ! -e "$CANON_HOME/.config/mango" ]] || fail "Sync instaló un WM que no estaba seleccionado"
grep -q 'walls' "$WALLS_LOG" || fail "Sync no detectó Walls automáticamente"
grep -q 'private' "$PRIVATE_LOG" || fail "Sync no detectó Private automáticamente"
grep -q 'development' "$PRIVATE_LOG" || fail "Sync no reutilizó PROFILE=development desde el recibo de private"
grep -q 'corp' "$PRIVATE_LOG" || fail "Sync no reutilizó WORK=corp desde el recibo de private"
grep -q 'setup' "$HARNESS_LOG" || fail "Sync no detectó Agent Harness automáticamente"

# An explicit --profile still wins over the saved selection.
DOTFILES_WALLS_TEST_LOG="$WALLS_LOG" \
DOTFILES_PRIVATE_TEST_LOG="$PRIVATE_LOG" \
DOTFILES_HARNESS_TEST_LOG="$HARNESS_LOG" \
"$DOTFILES" sync --profile cli --stow-only --target "$CANON_HOME" > "$TEST_ROOT/sync-explicit.out"
grep -q 'Selección restaurada del recibo: WMs bspwm$' "$TEST_ROOT/sync-explicit.out" || \
  fail "Sync no informó sólo los valores tomados del recibo"
[[ -L "$CANON_HOME/.config/bat/config" ]] || fail "Sync no aplicó el perfil cli explícito"
grep -qx 'PROFILE="cli"' "$CANON_HOME/.local/state/dotfiles/dotfiles.receipt" || \
  fail "Sync no actualizó el recibo de selección con el perfil aplicado"

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
mkdir -p "$CANON_HOME/.dotfiles/walls/.git"
git init -q "$CANON_HOME/.dotfiles/walls"
mkdir -p "$CANON_HOME/.dotfiles/agent-harness/.git"
git init -q "$CANON_HOME/.dotfiles/agent-harness"

DOTFILES_WALLS_TEST_LOG="$WALLS_LOG" \
DOTFILES_PRIVATE_TEST_LOG="$PRIVATE_LOG" \
DOTFILES_HARNESS_TEST_LOG="$HARNESS_LOG" \
"$DOTFILES" update --profile core --stow-only --target "$CANON_HOME"

# 6. Test composite doctor command (auto-detects active components)
: > "$WALLS_LOG"
: > "$PRIVATE_LOG"
: > "$HARNESS_LOG"

cat > "$CANON_HOME/.local/state/dotfiles/agent-harness.receipt" <<'EOF'
RECEIPT_VERSION=1
COMPONENT="agent-harness"
EOF

mkdir -p "$CANON_HOME/.local/share"
ln -s "$CANON_HOME/.dotfiles/walls/wallpapers" "$CANON_HOME/.local/share/wallpapers"

DOTFILES_WALLS_TEST_LOG="$WALLS_LOG" \
DOTFILES_PRIVATE_TEST_LOG="$PRIVATE_LOG" \
DOTFILES_HARNESS_TEST_LOG="$HARNESS_LOG" \
"$DOTFILES" doctor --profile core --stow-only --target "$CANON_HOME" > "$TEST_ROOT/auto-doctor.out"

grep -q 'Window Manager (bspwm): OK' "$TEST_ROOT/auto-doctor.out" || fail "Doctor no detectó BSPWM activo automáticamente"
if grep -q 'Window Manager (mangowm)' "$TEST_ROOT/auto-doctor.out"; then
  fail "Doctor detectó MangoWM cuando no estaba activo"
fi
grep -q 'walls' "$WALLS_LOG" || fail "Doctor no detectó Walls activo automáticamente"
grep -q 'private' "$PRIVATE_LOG" || fail "Doctor no detectó Private activo automáticamente"
grep -q 'agent-harness' "$HARNESS_LOG" || fail "Doctor no detectó Agent Harness activo automáticamente"

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

DOTFILES_WALLS_TEST_LOG="$WALLS_LOG" \
DOTFILES_PRIVATE_TEST_LOG="$PRIVATE_LOG" \
DOTFILES_HARNESS_TEST_LOG="$HARNESS_LOG" \
"$DOTFILES" bootstrap --profile core --stow-only --target "$CANON_HOME" \
  --wm bspwm --wm mangowm > "$TEST_ROOT/receipt-profiles.out" ||
  fail "Bootstrap falló con un recibo de WM sin PROFILE"

[[ "$(layer_profile "$TEST_ROOT/receipt-profiles.out" wm/bspwm)" == core ]] || \
  fail "Bootstrap no reutilizó PROFILE=core desde el recibo de BSPWM"
[[ "$(layer_profile "$TEST_ROOT/receipt-profiles.out" wm/mangowm)" == desktop ]] || \
  fail "Bootstrap no usó el perfil por defecto para un recibo de MangoWM sin PROFILE"
rm -f "$CANON_HOME/.local/state/dotfiles/mangowm.receipt"

# 7. Test doctor with --base-only
: > "$WALLS_LOG"
: > "$PRIVATE_LOG"
: > "$HARNESS_LOG"

DOTFILES_WALLS_TEST_LOG="$WALLS_LOG" \
DOTFILES_PRIVATE_TEST_LOG="$PRIVATE_LOG" \
DOTFILES_HARNESS_TEST_LOG="$HARNESS_LOG" \
"$DOTFILES" doctor --profile core --stow-only --target "$CANON_HOME" --base-only > "$TEST_ROOT/base-only.out"

if grep -q 'Plan de la capa' "$TEST_ROOT/base-only.out"; then
  fail "Doctor con --base-only auditó una capa de WM"
fi
[[ ! -s "$WALLS_LOG" ]] || fail "Doctor con --base-only delegó a Walls"
[[ ! -s "$PRIVATE_LOG" ]] || fail "Doctor con --base-only delegó a Private"
[[ ! -s "$HARNESS_LOG" ]] || fail "Doctor con --base-only delegó a Agent Harness"

echo "OK: Pruebas de Multi-WM, Private, Agent Harness, Sync, Update y Composite Doctor validadas exitosamente."
