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

for module in colors core packages links receipts layers; do
  [[ -f "$REPO_ROOT/lib/$module.sh" ]] || fail "falta el módulo lib/$module.sh"
done

# Runs a snippet in a clean bash that only knows the engine modules.
# The snippet is expanded by the inner shell, hence the single quotes.
# shellcheck disable=SC2016
run_engine() {
  env -i HOME="$TEST_ROOT" PATH="${ENGINE_PATH:-/usr/bin:/bin}" DOTFILES_LANG=es \
    REPO_LIB="$REPO_ROOT/lib" "$BASH" -c '
      set -Eeuo pipefail
      for module in colors core packages links receipts layers; do
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

# --- layers: layer.conf parsing --------------------------------------------
LAYERS="$TEST_ROOT/layers"
make_layer() {
  mkdir -p "$LAYERS/$1"
  printf '%b' "$2" > "$LAYERS/$1/layer.conf"
}
make_layer base '# comment\n\nprofiles = core desktop\n'
make_layer desktop 'requires=base\n'
make_layer wm/mango 'requires=desktop base\nprofiles=core desktop\nreceipt=mangowm\nprune_dirs=.config/mango .local/bin\n'

output=$(run_engine "
  declare -A conf=()
  read_layer_conf '$LAYERS/wm/mango' conf
  printf '%s|%s|%s|%s' \"\${conf[requires]}\" \"\${conf[profiles]}\" \"\${conf[receipt]}\" \"\${conf[prune_dirs]}\"")
[[ "$output" == "desktop base|core desktop|mangowm|.config/mango .local/bin" ]] || fail "read_layer_conf devolvió '$output'"

output=$(run_engine "declare -A conf=(); read_layer_conf '$LAYERS/base' conf; printf '%s' \"\${conf[profiles]}\"")
[[ "$output" == "core desktop" ]] || fail "read_layer_conf no recortó espacios: '$output'"

make_layer bad-key 'colour=red\n'
if run_engine "declare -A conf=(); read_layer_conf '$LAYERS/bad-key' conf" 2>/dev/null; then
  fail "read_layer_conf aceptó una clave desconocida"
fi
# shellcheck disable=SC2016
make_layer bad-value 'requires=$(touch pwned)\n'
if (cd "$TEST_ROOT" && run_engine "declare -A conf=(); read_layer_conf '$LAYERS/bad-value' conf") 2>/dev/null; then
  fail "read_layer_conf aceptó un valor inseguro"
fi
[[ ! -e "$TEST_ROOT/pwned" ]] || fail "read_layer_conf ejecutó contenido de layer.conf"
make_layer dup 'receipt=a\nreceipt=b\n'
if run_engine "declare -A conf=(); read_layer_conf '$LAYERS/dup' conf" 2>/dev/null; then
  fail "read_layer_conf aceptó una clave duplicada"
fi
if run_engine "declare -A conf=(); read_layer_conf '$LAYERS/missing' conf" 2>/dev/null; then
  fail "read_layer_conf aceptó una capa sin layer.conf"
fi

# --- layers: requires= resolution -------------------------------------------
output=$(run_engine "declare -a order=(); resolve_layers '$LAYERS' order wm/mango; printf '%s,' \"\${order[@]}\"")
[[ "$output" == "base,desktop,wm/mango," ]] || fail "resolve_layers devolvió '$output'"
output=$(run_engine "declare -a order=(); resolve_layers '$LAYERS' order desktop wm/mango base; printf '%s,' \"\${order[@]}\"")
[[ "$output" == "base,desktop,wm/mango," ]] || fail "resolve_layers no deduplicó: '$output'"

make_layer cycle-a 'requires=cycle-b\n'
make_layer cycle-b 'requires=cycle-a\n'
if run_engine "declare -a order=(); resolve_layers '$LAYERS' order cycle-a" 2>/dev/null; then
  fail "resolve_layers aceptó un ciclo"
fi
make_layer orphan 'requires=nowhere\n'
if run_engine "declare -a order=(); resolve_layers '$LAYERS' order orphan" 2>/dev/null; then
  fail "resolve_layers aceptó una dependencia inexistente"
fi
if run_engine "declare -a order=(); resolve_layers '$LAYERS' order ../escape" 2>/dev/null; then
  fail "resolve_layers aceptó un nombre de capa fuera de layers/"
fi

# --- layers: hooks ------------------------------------------------------------
HOOK_LOG="$TEST_ROOT/hook.log"
mkdir -p "$LAYERS/wm/mango/hooks"
{
  printf '#!/usr/bin/env bash\n'
  # shellcheck disable=SC2016
  printf 'printf "%%s|%%s|%%s|%%s|%%s\\n" "$LAYER_DIR" "$TARGET_DIR" "$PROFILE" "$APPLY" "${DOTFILES_LIB:+lib}" > %q\n' "$HOOK_LOG"
  # shellcheck disable=SC2016
  printf '[[ -z "${SECRET_ENGINE_STATE:-}" ]] || echo leaked >> %q\n' "$HOOK_LOG"
} > "$LAYERS/wm/mango/hooks/validate"
chmod +x "$LAYERS/wm/mango/hooks/validate"
run_engine "
  SECRET_ENGINE_STATE=1 TARGET_DIR='$TEST_ROOT/home' PROFILE=core APPLY=0
  run_layer_hook '$LAYERS/wm/mango' validate" >/dev/null
[[ "$(cat "$HOOK_LOG")" == "$LAYERS/wm/mango|$TEST_ROOT/home|core|0|lib" ]] || \
  fail "el hook recibió un entorno inesperado: $(cat "$HOOK_LOG")"

run_engine "TARGET_DIR=/x PROFILE=core APPLY=0; run_layer_hook '$LAYERS/base' validate" >/dev/null || \
  fail "run_layer_hook falló para un hook ausente"

printf '#!/usr/bin/env bash\nexit 7\n' > "$LAYERS/wm/mango/hooks/post-link"
chmod +x "$LAYERS/wm/mango/hooks/post-link"
if run_engine "TARGET_DIR=/x PROFILE=core APPLY=1; run_layer_hook '$LAYERS/wm/mango' post-link" >/dev/null 2>&1; then
  fail "run_layer_hook ocultó el fallo de un hook"
fi
chmod -x "$LAYERS/wm/mango/hooks/post-link"
if run_engine "TARGET_DIR=/x PROFILE=core APPLY=1; run_layer_hook '$LAYERS/wm/mango' post-link" >/dev/null 2>&1; then
  fail "run_layer_hook aceptó un hook no ejecutable"
fi
if run_engine "TARGET_DIR=/x PROFILE=core APPLY=1; run_layer_hook '$LAYERS/wm/mango' unknown-phase" >/dev/null 2>&1; then
  fail "run_layer_hook aceptó una fase desconocida"
fi

printf 'OK: motor compartido de lib/ validado (manifiestos, backends, recibos, prune y capas)\n'
