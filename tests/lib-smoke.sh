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

for module in colors core packages links receipts layers layer_ops; do
  [[ -f "$REPO_ROOT/lib/$module.sh" ]] || fail "falta el módulo lib/$module.sh"
done

# Runs a snippet in a clean bash that only knows the engine modules.
# The snippet is expanded by the inner shell, hence the single quotes.
# shellcheck disable=SC2016
run_engine() {
  env -i HOME="$TEST_ROOT" PATH="${ENGINE_PATH:-/usr/bin:/bin}" DOTFILES_LANG=es \
    REPO_LIB="$REPO_ROOT/lib" "$BASH" -c '
      set -Eeuo pipefail
      for module in colors core packages links receipts layers layer_ops; do
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

# --- layers ------------------------------------------------------------------
# Runs a failing engine snippet and checks that the expected guard fired.
expect_fail() {
  local expected=$1
  local snippet=$2
  local stderr_output
  if stderr_output=$(run_engine "$snippet" 2>&1 >/dev/null); then
    fail "se esperaba un fallo con '$expected' y el snippet terminó bien: $snippet"
  fi
  [[ "$stderr_output" == *"$expected"* ]] || \
    fail "se esperaba '$expected' pero el error fue: $stderr_output"
}

LAYERS="$TEST_ROOT/layers"
make_layer() {
  mkdir -p "$LAYERS/$1"
  printf '%b' "$2" > "$LAYERS/$1/layer.conf"
}
make_layer base '# comment\n\nprofiles = core desktop\n'
make_layer desktop 'requires=base\n'
make_layer wm/mango 'requires=desktop base\nprofiles=core desktop\nreceipt=mangowm\nprune_dirs=.config/mango .local/bin\n'

# layer.conf parsing
output=$(run_engine "
  declare -A conf=()
  read_layer_conf '$LAYERS/wm/mango' conf
  printf '%s|%s|%s|%s' \"\${conf[requires]}\" \"\${conf[profiles]}\" \"\${conf[receipt]}\" \"\${conf[prune_dirs]}\"")
[[ "$output" == "desktop base|core desktop|mangowm|.config/mango .local/bin" ]] || fail "read_layer_conf devolvió '$output'"

output=$(run_engine "declare -A conf=(); read_layer_conf '$LAYERS/base' conf; printf '%s' \"\${conf[profiles]}\"")
[[ "$output" == "core desktop" ]] || fail "read_layer_conf no recortó espacios: '$output'"

output=$(run_engine "IFS=\$'\\n\\t'; declare -A conf=(); read_layer_conf '$LAYERS/wm/mango' conf; printf '%s' \"\${conf[profiles]}\"")
[[ "$output" == "core desktop" ]] || fail "read_layer_conf depende del IFS del caller: '$output'"

make_layer bad-key 'colour=red\n'
expect_fail "clave desconocida" "declare -A conf=(); read_layer_conf '$LAYERS/bad-key' conf"
# shellcheck disable=SC2016
make_layer bad-value 'requires=$(touch pwned)\n'
(cd "$TEST_ROOT" && expect_fail "valor inválido para requires" "declare -A conf=(); read_layer_conf '$LAYERS/bad-value' conf")
[[ ! -e "$TEST_ROOT/pwned" ]] || fail "read_layer_conf ejecutó contenido de layer.conf"
make_layer dup 'receipt=a\nreceipt=b\n'
expect_fail "clave duplicada" "declare -A conf=(); read_layer_conf '$LAYERS/dup' conf"
make_layer two-receipts 'receipt=a b\n'
expect_fail "receipt debe tener exactamente un valor" "declare -A conf=(); read_layer_conf '$LAYERS/two-receipts' conf"
for escaping in ../etc /etc .config/../../etc ./x; do
  make_layer prune-escape "prune_dirs=.config/ok $escaping\n"
  expect_fail "valor inválido para prune_dirs" "declare -A conf=(); read_layer_conf '$LAYERS/prune-escape' conf"
done
expect_fail "no existe el manifiesto de capa" "declare -A conf=(); read_layer_conf '$LAYERS/missing' conf"

# requires= resolution
output=$(run_engine "declare -a order=(); resolve_layers '$LAYERS' order wm/mango; printf '%s,' \"\${order[@]}\"")
[[ "$output" == "base,desktop,wm/mango," ]] || fail "resolve_layers devolvió '$output'"
output=$(run_engine "declare -a order=(); resolve_layers '$LAYERS' order desktop wm/mango base; printf '%s,' \"\${order[@]}\"")
[[ "$output" == "base,desktop,wm/mango," ]] || fail "resolve_layers no deduplicó: '$output'"
# Caller array names that used to be internal locals must still receive results.
for array_name in dependencies resolve_state chain layer_name output_name; do
  output=$(run_engine "declare -a $array_name=(); resolve_layers '$LAYERS' $array_name wm/mango; printf '%s,' \"\${${array_name}[@]}\"")
  [[ "$output" == "base,desktop,wm/mango," ]] || fail "resolve_layers perdió el resultado en el array '$array_name': '$output'"
done

make_layer cycle-a 'requires=cycle-b\n'
make_layer cycle-b 'requires=cycle-a\n'
expect_fail "dependencia circular entre capas: cycle-a -> cycle-b -> cycle-a" \
  "declare -a order=(); resolve_layers '$LAYERS' order cycle-a"
make_layer orphan 'requires=nowhere\n'
expect_fail "la capa 'nowhere' no existe" "declare -a order=(); resolve_layers '$LAYERS' order orphan"
expect_fail "nombre de capa inválido" "declare -a order=(); resolve_layers '$LAYERS' order ../escape"

# profile tiers and Stow packages
mkdir -p "$LAYERS/wm/mango/packages/stow" "$LAYERS/wm/mango/home/mango" "$LAYERS/wm/mango/home/extra"
printf 'mango\n' > "$LAYERS/wm/mango/packages/stow/core.txt"
printf 'extra\n' > "$LAYERS/wm/mango/packages/stow/desktop.txt"
output=$(run_engine "declare -a tiers=(); layer_profile_tiers '$LAYERS/wm/mango' desktop tiers; printf '%s,' \"\${tiers[@]}\"")
[[ "$output" == "core,desktop," ]] || fail "layer_profile_tiers devolvió '$output'"
output=$(run_engine "declare -a tiers=(); layer_profile_tiers '$LAYERS/wm/mango' core tiers; printf '%s,' \"\${tiers[@]}\"")
[[ "$output" == "core," ]] || fail "layer_profile_tiers no cortó en el perfil pedido: '$output'"
expect_fail "no declara el perfil 'server'" "declare -a tiers=(); layer_profile_tiers '$LAYERS/wm/mango' server tiers"
output=$(run_engine "declare -a pkgs=(); read_layer_stow_packages '$LAYERS/wm/mango' desktop pkgs; printf '%s,' \"\${pkgs[@]}\"")
[[ "$output" == "mango,extra," ]] || fail "read_layer_stow_packages devolvió '$output'"
output=$(run_engine "declare -a pkgs=(); read_layer_stow_packages '$LAYERS/wm/mango' core pkgs; printf '%s,' \"\${pkgs[@]}\"")
[[ "$output" == "mango," ]] || fail "read_layer_stow_packages no respetó el perfil core: '$output'"
printf 'ghost\n' > "$LAYERS/wm/mango/packages/stow/desktop.txt"
expect_fail "el paquete Stow 'ghost' no existe" "declare -a pkgs=(); read_layer_stow_packages '$LAYERS/wm/mango' desktop pkgs"
printf 'extra\n' > "$LAYERS/wm/mango/packages/stow/desktop.txt"

# hooks
HOOK_LOG="$TEST_ROOT/hook.log"
mkdir -p "$LAYERS/wm/mango/hooks"
{
  printf '#!/usr/bin/env bash\n'
  # shellcheck disable=SC2016
  printf 'printf "%%s|%%s|%%s|%%s|%%s|%%s\\n" "$LAYER_DIR" "$TARGET_DIR" "$PROFILE" "$APPLY" "$OPERATION" "${DOTFILES_LIB:+lib}" > %q\n' "$HOOK_LOG"
} > "$LAYERS/wm/mango/hooks/validate"
chmod +x "$LAYERS/wm/mango/hooks/validate"
run_engine "TARGET_DIR='$TEST_ROOT/home' PROFILE=core APPLY=0 OPERATION=unlink
  run_layer_hook '$LAYERS/wm/mango' validate" >/dev/null
[[ "$(cat "$HOOK_LOG")" == "$LAYERS/wm/mango|$TEST_ROOT/home|core|0|unlink|lib" ]] || \
  fail "el hook recibió un entorno inesperado: $(cat "$HOOK_LOG")"
run_engine "run_layer_hook '$LAYERS/wm/mango' validate" >/dev/null || \
  fail "run_layer_hook falló con PROFILE/APPLY sin definir"
[[ "$(cat "$HOOK_LOG")" == "$LAYERS/wm/mango|||0||lib" ]] || \
  fail "run_layer_hook no aplicó valores por defecto: $(cat "$HOOK_LOG")"

run_engine "TARGET_DIR=/x PROFILE=core APPLY=0; run_layer_hook '$LAYERS/base' validate" >/dev/null || \
  fail "run_layer_hook falló para un hook ausente"

printf '#!/usr/bin/env bash\nexit 7\n' > "$LAYERS/wm/mango/hooks/post-link"
chmod +x "$LAYERS/wm/mango/hooks/post-link"
set +e
run_engine "TARGET_DIR=/x PROFILE=core APPLY=1; run_layer_hook '$LAYERS/wm/mango' post-link" >/dev/null 2>&1
hook_status=$?
set -e
(( hook_status == 7 )) || fail "run_layer_hook no propagó el código del hook (obtuvo $hook_status)"
chmod -x "$LAYERS/wm/mango/hooks/post-link"
expect_fail "no es un archivo ejecutable" "run_layer_hook '$LAYERS/wm/mango' post-link"
expect_fail "fase de hook desconocida" "run_layer_hook '$LAYERS/wm/mango' unknown-phase"

# --- layers: features= and prune_links= ---------------------------------------
make_layer feat 'profiles=core\nfeatures=extra-feat\nprune_links=.rcfile .config/app.conf\n'
output=$(run_engine "declare -A conf=(); read_layer_conf '$LAYERS/feat' conf; printf '%s|%s' \"\${conf[features]}\" \"\${conf[prune_links]}\"")
[[ "$output" == "extra-feat|.rcfile .config/app.conf" ]] || fail "read_layer_conf no leyó features/prune_links: '$output'"
for escaping in ../.bashrc /etc/passwd; do
  make_layer prune-link-escape "prune_links=$escaping\n"
  expect_fail "valor inválido para prune_links" "declare -A conf=(); read_layer_conf '$LAYERS/prune-link-escape' conf"
done
make_layer bad-feature 'features=Bad_Feature\n'
expect_fail "valor inválido para features" "declare -A conf=(); read_layer_conf '$LAYERS/bad-feature' conf"

# --- layer operations: feature manifests, root links and target checks ---------
OPS_ROOT="$TEST_ROOT/ops-layers"
OPS_LAYER="$OPS_ROOT/feat"
OPS_TARGET="$TEST_ROOT/ops-home"
mkdir -p "$OPS_LAYER/packages/repo" "$OPS_LAYER/packages/stow" "$OPS_LAYER/home/app/.config" "$OPS_TARGET" "$TEST_ROOT/ops-bin"
printf 'profiles=core\nfeatures=extra-feat\nprune_links=.rcfile .foreign\n' > "$OPS_LAYER/layer.conf"
printf 'pkg-core\n' > "$OPS_LAYER/packages/repo/core.txt"
printf 'pkg-extra\n' > "$OPS_LAYER/packages/repo/extra-feat.txt"
mkdir -p "$OPS_LAYER/packages/aur"
printf 'pkg-extra-aur\n' > "$OPS_LAYER/packages/aur/extra-feat.txt"
printf 'app\n' > "$OPS_LAYER/packages/stow/core.txt"
: > "$OPS_LAYER/home/.stow"
printf 'x\n' > "$OPS_LAYER/home/app/.config/app.conf"
printf 'paru\n' > "$TEST_ROOT/ops-backends.txt"
ln -s /usr/bin/false "$TEST_ROOT/ops-bin/pacman"
ln -s /usr/bin/true "$TEST_ROOT/ops-bin/paru"

# layer_run OPERATION APPLY [VAR=value...]: runs the fixture layer through run_layer.
layer_run() {
  local operation=$1 apply=$2
  shift 2
  ENGINE_PATH="$TEST_ROOT/ops-bin:/usr/bin:/bin" run_engine "
    TARGET_DIR='$OPS_TARGET' PLATFORM_REQUEST=arch BACKEND_REQUEST=auto
    SYSTEM_ENABLED=1 STOW_ENABLED=0 FEATURES='' PACKAGE_BACKENDS_FILE='$TEST_ROOT/ops-backends.txt'
    REPO_ROOT='$OPS_ROOT' PROGRAM_NAME=test
    $*
    run_layer '$OPS_ROOT' feat $operation core $apply"
}

output=$(layer_run bootstrap 0 2>&1)
[[ "$output" == *"pkg-core"* && "$output" != *"pkg-extra"* ]] || \
  fail "el plan incluyó una feature no seleccionada: $output"
output=$(layer_run bootstrap 0 "FEATURES='extra-feat other-feat'" 2>&1)
[[ "$output" =~ Paquetes\ repo:\ +pkg-core\ pkg-extra ]] || \
  fail "el plan no incluyó la feature seleccionada: $output"
[[ "$output" =~ Paquetes\ AUR:\ +pkg-extra-aur ]] || \
  fail "el plan no incluyó el manifiesto AUR de la feature: $output"

# A dangling root link into the repository is pruned on apply; a listed link
# that points outside the repository stays.
ln -s "$OPS_ROOT/feat/home/app/.rcfile" "$OPS_TARGET/.rcfile"
ln -s /nonexistent/elsewhere "$OPS_TARGET/.foreign"
layer_run bootstrap 1 "SYSTEM_ENABLED=0 STOW_ENABLED=1" >/dev/null 2>&1 || fail "el bootstrap de la capa de prueba falló"
[[ ! -L "$OPS_TARGET/.rcfile" ]] || fail "prune_links no eliminó el enlace raíz huérfano"
[[ -L "$OPS_TARGET/.foreign" ]] || fail "prune_links eliminó un enlace listado pero ajeno al repositorio"
[[ -L "$OPS_TARGET/.config/app.conf" ]] || fail "la capa de prueba no enlazó su paquete"

# Target sanity checks are shared by every layer.
output=$(layer_run bootstrap 0 "STOW_ENABLED=1 SYSTEM_ENABLED=0 TARGET_DIR=/" 2>&1) && fail "una capa aceptó / como target"
[[ "$output" == *"se rechaza usar / como target"* ]] || fail "el rechazo de / no fue accionable: $output"
output=$(layer_run bootstrap 0 "STOW_ENABLED=1 SYSTEM_ENABLED=0 TARGET_DIR='$TEST_ROOT/missing'" 2>&1) && \
  fail "una capa aceptó un target inexistente"
[[ "$output" == *"no es un directorio existente"* ]] || fail "el rechazo del target inexistente no fue accionable: $output"

printf 'OK: motor compartido de lib/ validado (manifiestos, backends, recibos, prune y capas)\n'
