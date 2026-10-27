#!/usr/bin/env bash
# Exercises the generated ~/.config/mimeapps.list through the desktop layer
# hooks: repo keys always win, other entries survive, a stow symlink in its
# place is replaced and doctor reports drift.

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
DEFAULTS="$REPO_ROOT/layers/desktop/mimeapps/defaults.list"
TEST_ROOT=""
TEST_TMP_PARENT=${DOTFILES_TEST_TMPDIR:-/tmp}

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  [[ -n "$TEST_ROOT" && "$TEST_ROOT" == "$TEST_TMP_PARENT"/dotfiles-mimeapps-smoke.* ]] || return 0
  rm -rf -- "$TEST_ROOT"
}

trap cleanup EXIT

[[ -f "$DEFAULTS" ]] || fail "faltan los valores por defecto: layers/desktop/mimeapps/defaults.list"
[[ ! -e "$REPO_ROOT/layers/desktop/home/xdg-defaults/.config/mimeapps.list" ]] || \
  fail "mimeapps.list sigue enlazándose con Stow"
[[ -d "$TEST_TMP_PARENT" ]] || fail "no existe el directorio temporal: $TEST_TMP_PARENT"
TEST_ROOT=$(mktemp -d "$TEST_TMP_PARENT/dotfiles-mimeapps-smoke.XXXXXX")
CHECKOUT_STATE=$(git -C "$REPO_ROOT" status --porcelain)

# Runs desktop hook $2 against target $1 with OPERATION $3 and PROFILE $4.
# The snippet is expanded by the inner shell, hence the single quotes.
# shellcheck disable=SC2016
run_hook() {
  local target=$1 phase=$2 operation=$3 profile=${4:-desktop}
  DOTFILES_LANG=es "$BASH" -c '
    set -Eeuo pipefail
    for module in colors core layers; do
      # shellcheck source=/dev/null
      source "$1/lib/$module.sh"
    done
    TARGET_DIR=$2 PROFILE=$3 APPLY=$4 OPERATION=$5
    run_layer_hook "$1/layers/desktop" "$6"' _ "$REPO_ROOT" "$target" "$profile" \
    "$([[ $phase == post-link ]] && echo 1 || echo 0)" "$operation" "$phase"
}

# Prints the value of key $2 in section $3 of mimeapps file $1.
value_of() {
  awk -v want_key="$2" -v want_section="[$3]" '
    /^\[/ { section = $0; next }
    section == want_section && index($0, want_key "=") == 1 {
      print substr($0, length(want_key) + 2); exit
    }' "$1"
}

new_target() {
  local target="$TEST_ROOT/$1"
  mkdir -p "$target/.config"
  printf '%s' "$target"
}

# A fresh target, even without ~/.config, gets a real file with every repo
# default.
target="$TEST_ROOT/fresh"
mkdir -p "$target"
run_hook "$target" post-link bootstrap >/dev/null || fail "post-link falló en un target vacío"
file="$target/.config/mimeapps.list"
[[ -f "$file" && ! -L "$file" ]] || fail "post-link no generó mimeapps.list como archivo real"
while IFS= read -r line; do
  [[ "$line" == *=* ]] || continue
  grep -Fxq -- "$line" "$file" || fail "falta la asociación del repo: $line"
done < "$DEFAULTS"

# Repo keys win, keys the repo does not declare and other sections survive.
target=$(new_target merge)
file="$target/.config/mimeapps.list"
printf '%s\n' '[Default Applications]' 'application/pdf=other-viewer.desktop;' \
  'x-scheme-handler/claude-cli=claude-code-url-handler.desktop' '' \
  '[Added Associations]' 'text/plain=micro.desktop;' > "$file"
run_hook "$target" post-link bootstrap >/dev/null || fail "post-link falló con un archivo existente"
expected_pdf=$(value_of "$DEFAULTS" application/pdf 'Default Applications')
[[ "$(value_of "$file" application/pdf 'Default Applications')" == "$expected_pdf" ]] || \
  fail "una clave del repo no ganó sobre el valor local"
[[ "$(value_of "$file" x-scheme-handler/claude-cli 'Default Applications')" == claude-code-url-handler.desktop ]] || \
  fail "se perdió una asociación registrada por una aplicación"
[[ "$(value_of "$file" text/plain 'Added Associations')" == 'micro.desktop;' ]] || \
  fail "se perdió una sección que el repo no declara"
(( $(grep -c '^application/pdf=' "$file") == 1 )) || fail "la clave del repo quedó duplicada"

# Applying twice leaves the file byte-for-byte and its mtime unchanged.
before_sum=$(sha256sum < "$file")
touch -d '2000-01-01' "$file"
before_mtime=$(stat -c %Y "$file")
run_hook "$target" post-link bootstrap >/dev/null
[[ "$(sha256sum < "$file")" == "$before_sum" ]] || fail "un segundo apply cambió mimeapps.list"
[[ "$(stat -c %Y "$file")" == "$before_mtime" ]] || fail "un segundo apply reescribió mimeapps.list sin cambios"

# A hand-edited key with spaces around '=' is still the repo key.
target=$(new_target spaces)
file="$target/.config/mimeapps.list"
printf '%s\n' '[Default Applications]' 'application/pdf = evince.desktop;' > "$file"
run_hook "$target" post-link bootstrap >/dev/null || fail "post-link falló con espacios alrededor de '='"
(( $(grep -c '^application/pdf' "$file") == 1 )) || fail "una clave con espacios quedó junto a la del repo"
[[ "$(value_of "$file" application/pdf 'Default Applications')" == "$expected_pdf" ]] || \
  fail "una clave con espacios no cedió ante la del repo"

# A file that cannot be replaced fails the apply and leaves no temporary file.
target=$(new_target blocked)
mkdir -p "$target/.config/mimeapps.list"
if run_hook "$target" post-link bootstrap >/dev/null 2>&1; then
  fail "post-link informó éxito sin poder escribir mimeapps.list"
fi
compgen -G "$target/.config/.mimeapps.list.*" >/dev/null && fail "un apply fallido dejó un archivo temporal"

# A stow symlink in its place is replaced by a real file that keeps its
# entries, and the file it pointed to is left untouched.
target=$(new_target symlink)
file="$target/.config/mimeapps.list"
old_checkout="$TEST_ROOT/old-checkout/mimeapps.list"
mkdir -p "${old_checkout%/*}"
printf '%s\n' '[Default Applications]' 'x-scheme-handler/claude-cli=claude-code-url-handler.desktop' > "$old_checkout"
old_sum=$(sha256sum < "$old_checkout")
ln -s "$old_checkout" "$file"
run_hook "$target" post-link bootstrap >/dev/null || fail "post-link falló con el symlink de Stow"
[[ -f "$file" && ! -L "$file" ]] || fail "post-link no reemplazó el symlink por un archivo real"
[[ "$(value_of "$file" x-scheme-handler/claude-cli 'Default Applications')" == claude-code-url-handler.desktop ]] || \
  fail "se perdieron las entradas del symlink reemplazado"
[[ "$(sha256sum < "$old_checkout")" == "$old_sum" ]] || fail "post-link modificó el archivo del checkout anterior"

# A dangling symlink is replaced by the repo defaults.
target=$(new_target dangling)
file="$target/.config/mimeapps.list"
ln -s "$TEST_ROOT/missing/mimeapps.list" "$file"
run_hook "$target" post-link bootstrap >/dev/null || fail "post-link falló con un symlink roto"
[[ -f "$file" && ! -L "$file" ]] || fail "post-link no reemplazó el symlink roto"
[[ "$(value_of "$file" application/pdf 'Default Applications')" == "$expected_pdf" ]] || \
  fail "el symlink roto no recibió los valores del repo"

# Non-desktop profiles never generate the file.
target=$(new_target cli)
run_hook "$target" post-link bootstrap cli >/dev/null || fail "post-link falló con el perfil cli"
[[ ! -e "$target/.config/mimeapps.list" ]] || fail "el perfil cli generó mimeapps.list"

# doctor is quiet when in sync, warns on a drifted repo key or a missing file,
# and the warning alone does not fail the layer.
target="$TEST_ROOT/fresh"
file="$target/.config/mimeapps.list"
output=$(run_hook "$target" validate doctor 2>&1) || fail "doctor falló con mimeapps.list sincronizado: $output"
[[ "$output" != *mimeapps* ]] || fail "doctor avisó con mimeapps.list sincronizado: $output"
sed -i 's|^application/pdf=.*|application/pdf=other-viewer.desktop;|' "$file"
output=$(run_hook "$target" validate doctor 2>&1) || fail "doctor falló por una desviación: $output"
[[ "$output" == *'mimeapps.list difiere del repo en application/pdf'* ]] || \
  fail "doctor no avisó de la desviación: $output"
rm -f -- "$file"
output=$(run_hook "$target" validate doctor 2>&1) || fail "doctor falló sin mimeapps.list: $output"
[[ "$output" == *"falta $file"* ]] || fail "doctor no avisó de la ausencia: $output"

[[ "$(git -C "$REPO_ROOT" status --porcelain)" == "$CHECKOUT_STATE" ]] || fail "los hooks modificaron el checkout"

printf 'OK: mimeapps.list generado y validado\n'
