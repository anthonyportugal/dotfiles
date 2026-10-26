#!/usr/bin/env bash
# Exercises the shared engine in lib/ without going through bin/dotfiles,
# the way layer scripts are expected to consume it.

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
  [[ -n "$TEST_ROOT" && "$TEST_ROOT" == "$TEST_TMP_PARENT"/dotfiles-lib-smoke.* ]] || return 0
  find "$TEST_ROOT" -mindepth 1 -delete
  find "$TEST_ROOT" -depth -type d -empty -delete
}

trap cleanup EXIT

[[ -d "$TEST_TMP_PARENT" ]] || fail "no existe el directorio temporal: $TEST_TMP_PARENT"
TEST_ROOT=$(mktemp -d "$TEST_TMP_PARENT/dotfiles-lib-smoke.XXXXXX")

for module in colors core packages links receipts; do
  [[ -f "$REPO_ROOT/lib/$module.sh" ]] || fail "falta el módulo lib/$module.sh"
done

# Runs a snippet in a clean bash that only knows the engine modules.
# The snippet is expanded by the inner shell, hence the single quotes.
# shellcheck disable=SC2016
run_engine() {
  env -i HOME="$TEST_ROOT" PATH="${ENGINE_PATH:-/usr/bin:/bin}" DOTFILES_LANG=es \
    REPO_LIB="$REPO_ROOT/lib" "$BASH" -c '
      set -Eeuo pipefail
      for module in colors core packages links receipts; do
        # shellcheck source=/dev/null
        source "$REPO_LIB/$module.sh"
      done
      '"$1"
}

# --- core: manifests -------------------------------------------------------
MANIFEST="$TEST_ROOT/manifest.txt"
printf '# comment\n\n  zsh  \ngit\n' > "$MANIFEST"
output=$(run_engine "declare -a out=(); read_manifest '$MANIFEST' out; printf '%s,' \"\${out[@]}\"")
[[ "$output" == "zsh,git," ]] || fail "read_manifest devolvió '$output'"

printf 'zsh\nzsh\n' > "$MANIFEST"
if run_engine "declare -a out=(); read_manifest '$MANIFEST' out" 2>/dev/null; then
  fail "read_manifest aceptó una entrada duplicada"
fi
printf 'zsh # inline\n' > "$MANIFEST"
if run_engine "declare -a out=(); read_manifest '$MANIFEST' out" 2>/dev/null; then
  fail "read_manifest aceptó un comentario inline"
fi

# --- packages: backend order shelly (cachyos only) > paru > yay > pacman ----
FAKE_BIN="$TEST_ROOT/fake-bin"
mkdir -p "$FAKE_BIN"
for helper in shelly paru yay pacman; do
  printf '#!/bin/sh\nexit 0\n' > "$FAKE_BIN/$helper"
  chmod +x "$FAKE_BIN/$helper"
done
printf 'shelly\nparu\nyay\npacman\n' > "$TEST_ROOT/package-backends.txt"

# PATH holds only the fake helpers so host paru/yay/pacman cannot leak in.
detect() {
  ENGINE_PATH="$FAKE_BIN" run_engine "
    PACKAGES_DIR='$TEST_ROOT'; BACKEND_REQUEST=auto; PLATFORM=$1; BACKEND=''
    detect_backend; printf '%s' \"\$BACKEND\""
}
[[ "$(detect cachyos)" == "shelly" ]] || fail "CachyOS debe preferir shelly"
[[ "$(detect arch)" == "paru" ]] || fail "Arch debe saltar shelly y elegir paru"
rm -f "$FAKE_BIN/paru"
[[ "$(detect arch)" == "yay" ]] || fail "sin paru debe elegirse yay"
rm -f "$FAKE_BIN/yay"
[[ "$(detect arch)" == "pacman" ]] || fail "sin helpers debe elegirse pacman"

# --- receipts: atomic write and round-trip ---------------------------------
output=$(run_engine "
  TARGET_DIR='$TEST_ROOT/home'
  write_receipt mangowm PROFILE=desktop BACKEND=paru >/dev/null
  declare -A r=()
  read_receipt mangowm r
  printf '%s|%s|%s|%s|%s' \"\${r[RECEIPT_VERSION]}\" \"\${r[COMPONENT]}\" \"\${r[PROFILE]}\" \"\${r[BACKEND]}\" \"\${r[UPDATED_AT]:+set}\"")
[[ "$output" == "1|mangowm|desktop|paru|set" ]] || fail "round-trip de recibo devolvió '$output'"
receipt_dir="$TEST_ROOT/home/.local/state/dotfiles"
[[ "$(find "$receipt_dir" -name 'mangowm.receipt.*' | wc -l)" == 0 ]] || fail "quedó un recibo temporal"

if run_engine "TARGET_DIR='$TEST_ROOT/home'; declare -A r=(); read_receipt missing r"; then
  fail "read_receipt debe fallar si el recibo no existe"
fi
if run_engine "TARGET_DIR='$TEST_ROOT/home'; write_receipt bad 'PROFILE=a\"b'" 2>/dev/null; then
  fail "write_receipt aceptó un valor con comillas"
fi

# --- links: prune only reaches the configured directories ------------------
PRUNE_HOME="$TEST_ROOT/prune-home"
FAKE_REPO="$TEST_ROOT/repo"
mkdir -p "$PRUNE_HOME/.config/app" "$PRUNE_HOME/.config/other" "$FAKE_REPO/home"
ln -s "$FAKE_REPO/home/app/gone.conf" "$PRUNE_HOME/.config/app/gone.conf"
ln -s "$FAKE_REPO/home/other/gone.conf" "$PRUNE_HOME/.config/other/gone.conf"
ln -s "/nonexistent/foreign.conf" "$PRUNE_HOME/.config/app/foreign.conf"
ln -s "$FAKE_REPO/home/zsh/.zshrc" "$PRUNE_HOME/.zshrc"
run_engine "
  REPO_ROOT='$FAKE_REPO'; STOW_DIR='$FAKE_REPO/home'; TARGET_DIR='$PRUNE_HOME'
  PRUNE_SEARCH_DIRS=(.config/app); PRUNE_ROOT_LINKS=(.zshrc)
  prune_dangling_dotfiles_links 1" >/dev/null 2>&1
[[ ! -L "$PRUNE_HOME/.config/app/gone.conf" ]] || fail "prune no eliminó el enlace huérfano del repo"
[[ ! -L "$PRUNE_HOME/.zshrc" ]] || fail "prune no eliminó el enlace raíz huérfano"
[[ -L "$PRUNE_HOME/.config/app/foreign.conf" ]] || fail "prune eliminó un enlace ajeno al repo"
[[ -L "$PRUNE_HOME/.config/other/gone.conf" ]] || fail "prune salió de los directorios configurados"

printf 'OK: motor compartido de lib/ validado (manifiestos, backends, recibos y prune)\n'
