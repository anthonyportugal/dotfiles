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
WM_MANGO="$TEST_ROOT/wm-mango"
WM_BSPWM="$TEST_ROOT/wm-bspwm"
WALLS_REPO="$TEST_ROOT/walls"
PRIVATE_REPO="$TEST_ROOT/private"
HARNESS_REPO="$TEST_ROOT/agent-harness"

WM_LOG="$TEST_ROOT/wm.log"
WALLS_LOG="$TEST_ROOT/walls.log"
PRIVATE_LOG="$TEST_ROOT/private.log"
HARNESS_LOG="$TEST_ROOT/harness.log"

mkdir -p "$TARGET_DIR" "$FAKE_BIN" "$WM_MANGO/bin" "$WM_BSPWM/bin" "$WALLS_REPO/bin" "$PRIVATE_REPO/bin" "$HARNESS_REPO/bin"
ln -s "$SCRIPT_DIR/fakes/wm-entrypoint" "$WM_MANGO/bin/mango"
ln -s "$SCRIPT_DIR/fakes/wm-entrypoint" "$WM_BSPWM/bin/bspwm"
ln -s "$SCRIPT_DIR/fakes/walls-entrypoint" "$WALLS_REPO/bin/walls"
ln -s "$SCRIPT_DIR/fakes/private-entrypoint" "$PRIVATE_REPO/bin/dotfiles-private"
ln -s "$SCRIPT_DIR/fakes/harness-entrypoint" "$HARNESS_REPO/bin/agent-harness"

: > "$WM_LOG"
: > "$WALLS_LOG"
: > "$PRIVATE_LOG"
: > "$HARNESS_LOG"

# 1. Test multi-WM, private, and agent-harness integration via bootstrap flags
DOTFILES_WM_TEST_LOG="$WM_LOG" \
DOTFILES_WALLS_TEST_LOG="$WALLS_LOG" \
DOTFILES_PRIVATE_TEST_LOG="$PRIVATE_LOG" \
DOTFILES_HARNESS_TEST_LOG="$HARNESS_LOG" \
"$DOTFILES" bootstrap --profile core --stow-only --target "$TARGET_DIR" \
  --wm mangowm --wm-path "$WM_MANGO" \
  --wm bspwm --wm-path "$WM_BSPWM" \
  --wallpapers --wallpapers-path "$WALLS_REPO" \
  --private --private-path "$PRIVATE_REPO" --private-profile development --private-work corp \
  --agent-harness --agent-harness-path "$HARNESS_REPO" \
  --apply

# Verify that both WMs, walls, private, and agent-harness were invoked
grep -q 'mango' "$WM_LOG" || fail "MangoWM no fue ejecutado en multi-WM"
grep -q 'bspwm' "$WM_LOG" || fail "BSPWM no fue ejecutado en multi-WM"
grep -q 'link' "$WALLS_LOG" || fail "Walls link no fue invocado"
grep -q 'corp' "$PRIVATE_LOG" || fail "Private work corp no fue invocado"
grep -q 'development' "$PRIVATE_LOG" || fail "Private profile development no fue invocado"
grep -q 'setup' "$HARNESS_LOG" || fail "Agent Harness setup no fue invocado"

# 2. Test doctor on multi-WM, private, and agent-harness
: > "$WM_LOG"
: > "$WALLS_LOG"
: > "$PRIVATE_LOG"
: > "$HARNESS_LOG"

DOTFILES_WM_TEST_LOG="$WM_LOG" \
DOTFILES_WALLS_TEST_LOG="$WALLS_LOG" \
DOTFILES_PRIVATE_TEST_LOG="$PRIVATE_LOG" \
DOTFILES_HARNESS_TEST_LOG="$HARNESS_LOG" \
"$DOTFILES" doctor --profile core --stow-only --target "$TARGET_DIR" \
  --wm mangowm --wm-path "$WM_MANGO" \
  --wm bspwm --wm-path "$WM_BSPWM" \
  --wallpapers --wallpapers-path "$WALLS_REPO" \
  --private --private-path "$PRIVATE_REPO" \
  --agent-harness --agent-harness-path "$HARNESS_REPO"

grep -q 'mango' "$WM_LOG" || fail "Doctor no invocó MangoWM"
grep -q 'bspwm' "$WM_LOG" || fail "Doctor no invocó BSPWM"
grep -q 'walls' "$WALLS_LOG" || fail "Doctor no invocó Walls"
grep -q 'private' "$PRIVATE_LOG" || fail "Doctor no invocó Private"
grep -q 'doctor' "$HARNESS_LOG" || fail "Doctor no invocó Agent Harness"

# 3. Test unlink on multi-WM, private, and agent-harness
: > "$WM_LOG"
: > "$WALLS_LOG"
: > "$PRIVATE_LOG"
: > "$HARNESS_LOG"

DOTFILES_WM_TEST_LOG="$WM_LOG" \
DOTFILES_WALLS_TEST_LOG="$WALLS_LOG" \
DOTFILES_PRIVATE_TEST_LOG="$PRIVATE_LOG" \
DOTFILES_HARNESS_TEST_LOG="$HARNESS_LOG" \
"$DOTFILES" unlink --profile core --target "$TARGET_DIR" \
  --wm mangowm --wm-path "$WM_MANGO" \
  --wm bspwm --wm-path "$WM_BSPWM" \
  --wallpapers --wallpapers-path "$WALLS_REPO" \
  --private --private-path "$PRIVATE_REPO" \
  --agent-harness --agent-harness-path "$HARNESS_REPO" --apply

grep -q 'unlink' "$WM_LOG" || fail "Unlink no invocó WM"
grep -q 'unlink' "$WALLS_LOG" || fail "Unlink no invocó Walls"
grep -q 'unlink' "$PRIVATE_LOG" || fail "Unlink no invocó Private"

# 4. Test sync command in canonical directory structure
CANON_HOME="$TEST_ROOT/canon-home"
mkdir -p "$CANON_HOME/.dotfiles/wm/mangowm/bin" \
         "$CANON_HOME/.dotfiles/wm/bspwm/bin" \
         "$CANON_HOME/.dotfiles/walls/bin" \
         "$CANON_HOME/.dotfiles/private/bin" \
         "$CANON_HOME/.dotfiles/agent-harness/bin"

ln -s "$SCRIPT_DIR/fakes/wm-entrypoint" "$CANON_HOME/.dotfiles/wm/mangowm/bin/mango"
ln -s "$SCRIPT_DIR/fakes/wm-entrypoint" "$CANON_HOME/.dotfiles/wm/bspwm/bin/bspwm"
ln -s "$SCRIPT_DIR/fakes/walls-entrypoint" "$CANON_HOME/.dotfiles/walls/bin/walls"
ln -s "$SCRIPT_DIR/fakes/private-entrypoint" "$CANON_HOME/.dotfiles/private/bin/dotfiles-private"
ln -s "$SCRIPT_DIR/fakes/harness-entrypoint" "$CANON_HOME/.dotfiles/agent-harness/bin/agent-harness"

: > "$WM_LOG"
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

DOTFILES_WM_TEST_LOG="$WM_LOG" \
DOTFILES_WALLS_TEST_LOG="$WALLS_LOG" \
DOTFILES_PRIVATE_TEST_LOG="$PRIVATE_LOG" \
DOTFILES_HARNESS_TEST_LOG="$HARNESS_LOG" \
"$DOTFILES" sync --profile core --stow-only --target "$CANON_HOME" --apply

grep -q 'mango' "$WM_LOG" || fail "Sync no detectó MangoWM automáticamente"
grep -q 'bspwm' "$WM_LOG" || fail "Sync no detectó BSPWM automáticamente"
grep -q 'walls' "$WALLS_LOG" || fail "Sync no detectó Walls automáticamente"
grep -q 'private' "$PRIVATE_LOG" || fail "Sync no detectó Private automáticamente"
grep -q 'development' "$PRIVATE_LOG" || fail "Sync no reutilizó PROFILE=development desde el recibo de private"
grep -q 'corp' "$PRIVATE_LOG" || fail "Sync no reutilizó WORK=corp desde el recibo de private"
grep -q 'setup' "$HARNESS_LOG" || fail "Sync no detectó Agent Harness automáticamente"

# 5. Test update command (checks git repositories)
mkdir -p "$CANON_HOME/.dotfiles/walls/.git"
git init -q "$CANON_HOME/.dotfiles/walls"
mkdir -p "$CANON_HOME/.dotfiles/agent-harness/.git"
git init -q "$CANON_HOME/.dotfiles/agent-harness"

DOTFILES_WM_TEST_LOG="$WM_LOG" \
DOTFILES_WALLS_TEST_LOG="$WALLS_LOG" \
DOTFILES_PRIVATE_TEST_LOG="$PRIVATE_LOG" \
DOTFILES_HARNESS_TEST_LOG="$HARNESS_LOG" \
"$DOTFILES" update --profile core --stow-only --target "$CANON_HOME"

echo "OK: Pruebas de Multi-WM, Private, Agent Harness, Sync y Update validadas exitosamente."
