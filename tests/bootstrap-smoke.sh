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
  [[ -n "$TEST_ROOT" && "$TEST_ROOT" == "$TEST_TMP_PARENT"/dotfiles-bootstrap-smoke.* ]] || return 0
  find "$TEST_ROOT" -mindepth 1 -delete
  find "$TEST_ROOT" -depth -type d -empty -delete
}

trap cleanup EXIT

command -v stow >/dev/null 2>&1 || fail "GNU Stow es necesario para este smoke test"
[[ -x "$DOTFILES" ]] || fail "$DOTFILES no es ejecutable"

if command -v alacritty >/dev/null 2>&1; then
  alacritty migrate --dry-run --skip-imports \
    --config-file "$REPO_ROOT/home/alacritty/.config/alacritty/alacritty.toml" \
    >/dev/null || fail "la configuración de Alacritty no es válida"
fi

[[ -d "$TEST_TMP_PARENT" ]] || fail "no existe el directorio temporal: $TEST_TMP_PARENT"
TEST_ROOT=$(mktemp -d "$TEST_TMP_PARENT/dotfiles-bootstrap-smoke.XXXXXX")
TARGET_DIR="$TEST_ROOT/home with spaces"
CONFLICT_DIR="$TEST_ROOT/conflict"
PARENT_CONFLICT_DIR="$TEST_ROOT/parent-conflict"
PARENT_DESTINATION="$TEST_ROOT/parent-destination"
FAKE_BIN="$TEST_ROOT/fake-bin"
WM_REPO="$TEST_ROOT/external bspwm"
WM_TARGET="$TEST_ROOT/wm target"
WM_FAILURE_TARGET="$TEST_ROOT/wm failure target"
WM_LOG="$TEST_ROOT/wm.log"
mkdir "$TARGET_DIR" "$CONFLICT_DIR" "$PARENT_CONFLICT_DIR" \
  "$PARENT_DESTINATION" "$FAKE_BIN" "$WM_REPO" "$WM_TARGET" \
  "$WM_FAILURE_TARGET" "$WM_REPO/bin"
ln -s "$SCRIPT_DIR/fakes/wm-entrypoint" "$WM_REPO/bin/bspwm"

# Dry-run, aplicación, doctor e idempotencia sobre un home desechable.
"$DOTFILES" bootstrap --profile desktop --stow-only --target "$TARGET_DIR"
"$DOTFILES" bootstrap --profile desktop --stow-only --target "$TARGET_DIR" --apply
"$DOTFILES" doctor --profile desktop --stow-only --target "$TARGET_DIR"
"$DOTFILES" bootstrap --profile desktop --stow-only --target "$TARGET_DIR" --apply

# Git público funciona sin includes opcionales y respeta la precedencia
# pública → privada → local sin introducir una identidad.
PUBLIC_GIT_CONFIG="$TARGET_DIR/.config/git/config"
[[ -L "$PUBLIC_GIT_CONFIG" ]] || fail "core no instaló la configuración Git"
HOME="$TARGET_DIR" XDG_CONFIG_HOME="$TARGET_DIR/.config" \
  git config --global --get init.defaultBranch | grep -qx main || \
  fail "Git no cargó el default público"
HOME="$TARGET_DIR" XDG_CONFIG_HOME="$TARGET_DIR/.config" \
  git config --global --get user.useConfigOnly | grep -qx true || \
  fail "Git público no activó el modo fail-closed"
if HOME="$TARGET_DIR" XDG_CONFIG_HOME="$TARGET_DIR/.config" \
    git config --global --get user.email >/dev/null 2>&1; then
  fail "la base pública definió una identidad Git"
fi
printf '%s\n' '[dotfiles-test]' '    precedence = private' \
  > "$TARGET_DIR/.config/git/private.gitconfig"
printf '%s\n' '[dotfiles-test]' '    precedence = local' \
  > "$TARGET_DIR/.config/git/local.gitconfig"
git_precedence=$(HOME="$TARGET_DIR" XDG_CONFIG_HOME="$TARGET_DIR/.config" \
  git config --global --includes --get dotfiles-test.precedence)
[[ "$git_precedence" == local ]] || \
  fail "Git no respetó la precedencia público → privado → local"

# ~/.gitconfig tiene precedencia posterior al archivo XDG. El preflight debe
# bloquear ese estado legacy en lugar de instalar una configuración ambigua.
LEGACY_TARGET="$TEST_ROOT/legacy git home"
mkdir "$LEGACY_TARGET"
printf '%s\n' '[user]' '    email = legacy@example.invalid' \
  > "$LEGACY_TARGET/.gitconfig"
if "$DOTFILES" bootstrap --profile core --stow-only --target "$LEGACY_TARGET" \
    > "$TEST_ROOT/legacy-git.out" 2>&1; then
  fail "el bootstrap aceptó ~/.gitconfig con precedencia posterior"
fi
grep -q 'configuración Git legacy' "$TEST_ROOT/legacy-git.out" || \
  fail "el conflicto de precedencia Git no fue accionable"

# Cuando el target es el home actual, doctor debe explicar por qué Bash no
# activaría los plugins aunque los enlaces de Zsh sean correctos.
ln -s "$SCRIPT_DIR/fakes/getent" "$FAKE_BIN/getent"
ln -s "$SCRIPT_DIR/fakes/chsh" "$FAKE_BIN/chsh"
HOME="$TARGET_DIR" SHELL=/bin/bash PATH="$FAKE_BIN:/usr/bin" \
  "$DOTFILES" doctor --profile core --stow-only --target "$TARGET_DIR" \
  > "$TEST_ROOT/zsh-activation.out" 2>&1
grep -q "shell de login.*'/bin/bash'" "$TEST_ROOT/zsh-activation.out" ||
  fail "doctor no detectó que la cuenta seguía usando Bash"
grep -q 'chsh -s /bin/zsh' "$TEST_ROOT/zsh-activation.out" ||
  fail "doctor no eligió una ruta Zsh registrada"

for alias_name in l la ll lg; do
  alias_definition=$(zsh -dfc 'source "$1"; alias "$2"' \
    dotfiles-alias-check \
    "$REPO_ROOT/home/zsh/.config/zsh/conf.d/40-aliases.zsh" "$alias_name")
  [[ "$alias_definition" == *'ls --color=auto '* ]] ||
    fail "el alias $alias_name no activa colores sólo para terminal"
done

# La integración de WM consume únicamente un checkout externo y su entrypoint
# público. Un apply ejecuta primero el dry-run del WM y propaga después las
# opciones compartidas sin mezclar perfiles ni manifests.
DOTFILES_WM_TEST_LOG="$WM_LOG" "$DOTFILES" bootstrap \
  --profile core --stow-only --target "$WM_TARGET" \
  --wm bspwm --wm-path "$WM_REPO" --wm-profile core --apply
[[ $(wc -l < "$WM_LOG") == 2 ]] || \
  fail "bootstrap no ejecutó preflight y apply del WM"
sed -n '1p' "$WM_LOG" | grep -qv -- '--apply' || \
  fail "el preflight del WM recibió --apply"
sed -n '2p' "$WM_LOG" | grep -q -- '--apply' || \
  fail "el apply del WM no recibió --apply"
grep -q -- 'bootstrap --profile=core --backend=auto --platform=auto' "$WM_LOG" || \
  fail "bootstrap no propagó operación, perfil o detección al WM"
wm_target_argument=$(printf '%q' "--target=$WM_TARGET")
grep -Fq -- "$wm_target_argument --stow-only" "$WM_LOG" || \
  fail "bootstrap no propagó target o alcance Stow al WM"

: > "$WM_LOG"
DOTFILES_WM_TEST_LOG="$WM_LOG" "$DOTFILES" doctor \
  --profile core --stow-only --target "$WM_TARGET" \
  --wm bspwm --wm-path "$WM_REPO" --wm-profile desktop
[[ $(wc -l < "$WM_LOG") == 1 ]] || fail "doctor no delegó una sola vez en el WM"
grep -q -- 'doctor --profile=desktop' "$WM_LOG" || \
  fail "doctor mezcló el perfil base con el perfil independiente del WM"

: > "$WM_LOG"
DOTFILES_WM_TEST_LOG="$WM_LOG" "$DOTFILES" unlink \
  --profile core --target "$WM_TARGET" \
  --wm bspwm --wm-path "$WM_REPO" --wm-profile core --apply
[[ $(wc -l < "$WM_LOG") == 2 ]] || \
  fail "unlink no ejecutó preflight y apply del WM"
sed -n '1p' "$WM_LOG" | grep -qv -- '--apply' || \
  fail "el preflight de unlink del WM recibió --apply"
sed -n '2p' "$WM_LOG" | grep -q -- '--apply' || \
  fail "el apply de unlink del WM no recibió --apply"

# Si el dry-run externo falla, la base no debe llegar a crear ningún enlace.
: > "$WM_LOG"
if DOTFILES_WM_TEST_LOG="$WM_LOG" DOTFILES_WM_TEST_FAILURE=always \
    "$DOTFILES" bootstrap --profile core --stow-only \
    --target "$WM_FAILURE_TARGET" --wm bspwm --wm-path "$WM_REPO" \
    --wm-profile core --apply > "$TEST_ROOT/wm-failure.out" 2>&1; then
  fail "bootstrap ignoró un preflight fallido del WM"
fi
[[ ! -e "$WM_FAILURE_TARGET/.zshrc" ]] || \
  fail "la base se modificó después de fallar el preflight del WM"
grep -q 'no se modificó la base' "$TEST_ROOT/wm-failure.out" || \
  fail "el fallo del preflight externo no fue accionable"

# La interfaz rechaza opciones incompletas y checkouts anidados en la base.
if "$DOTFILES" bootstrap --profile core --stow-only --target "$WM_TARGET" \
    --wm bspwm > "$TEST_ROOT/wm-no-path.out" 2>&1; then
  fail "--wm fue aceptado sin --wm-path"
fi
if "$DOTFILES" bootstrap --profile core --stow-only --target "$WM_TARGET" \
    --wm-path "$WM_REPO" > "$TEST_ROOT/wm-no-name.out" 2>&1; then
  fail "--wm-path fue aceptado sin --wm"
fi
if "$DOTFILES" bootstrap --profile core --stow-only --target "$WM_TARGET" \
    --wm bspwm --wm-path "$REPO_ROOT" > "$TEST_ROOT/wm-nested.out" 2>&1; then
  fail "se aceptó un checkout WM dentro del repositorio base"
fi
grep -q 'debe estar fuera del repositorio base' "$TEST_ROOT/wm-nested.out" || \
  fail "no se explicó el límite de independencia del checkout WM"

# Una colisión debe detenerse antes de modificar el archivo existente.
touch "$CONFLICT_DIR/.zshrc"
if "$DOTFILES" bootstrap --profile core --stow-only --target "$CONFLICT_DIR" \
    > "$TEST_ROOT/conflict.out" 2>&1; then
  fail "el dry-run aceptó una colisión"
fi
grep -q 'colisión' "$TEST_ROOT/conflict.out" || fail "no se reportó la colisión"
[[ -f "$CONFLICT_DIR/.zshrc" && ! -L "$CONFLICT_DIR/.zshrc" ]] || \
  fail "el preflight modificó el archivo en conflicto"

ln -s "$PARENT_DESTINATION" "$PARENT_CONFLICT_DIR/.config"
if "$DOTFILES" bootstrap --profile core --stow-only \
    --target "$PARENT_CONFLICT_DIR" > "$TEST_ROOT/parent-conflict.out" 2>&1; then
  fail "el dry-run aceptó un directorio padre enlazado fuera del target"
fi
grep -q 'directorio padre es symlink' "$TEST_ROOT/parent-conflict.out" || \
  fail "no se explicó la colisión del directorio padre"

# Unlink también simula primero y nunca retira paquetes del sistema.
"$DOTFILES" unlink --profile desktop --target "$TARGET_DIR"
"$DOTFILES" unlink --profile desktop --target "$TARGET_DIR" --apply
if "$DOTFILES" doctor --profile desktop --stow-only --target "$TARGET_DIR" \
    > "$TEST_ROOT/doctor-after-unlink.out" 2>&1; then
  fail "doctor debía detectar los enlaces ausentes después de unlink"
fi

# Adaptadores: pacman falso marca todos los paquetes como faltantes sin tocar
# el sistema; los helpers falsos permiten inspeccionar los comandos generados.
ln -s /usr/bin/false "$FAKE_BIN/pacman"
for backend in shelly paru yay; do
  ln -s /usr/bin/true "$FAKE_BIN/$backend"
done

PATH="$FAKE_BIN:/usr/bin" "$DOTFILES" bootstrap \
  --profile desktop --packages-only --platform arch --backend shelly \
  > "$TEST_ROOT/shelly.out"
grep -q 'shelly install standard' "$TEST_ROOT/shelly.out" || \
  fail "falta el comando de repositorio para Shelly"
grep -q 'zsh-completions' "$TEST_ROOT/shelly.out" || \
  fail "el perfil core no resolvió zsh-completions"
grep -q 'zsh-history-substring-search' "$TEST_ROOT/shelly.out" || \
  fail "el perfil core no resolvió zsh-history-substring-search"
grep -q 'shelly install aur brave-bin' "$TEST_ROOT/shelly.out" || \
  fail "falta el comando AUR para Shelly"

PATH="$FAKE_BIN:/usr/bin" "$DOTFILES" bootstrap \
  --profile core --packages-only --platform cachyos \
  > "$TEST_ROOT/auto-cachyos.out"
grep -Eq 'Backend:[[:space:]]+shelly' "$TEST_ROOT/auto-cachyos.out" || \
  fail "la detección automática de CachyOS no priorizó Shelly"

for backend in paru yay; do
  PATH="$FAKE_BIN:/usr/bin" "$DOTFILES" bootstrap \
    --profile desktop --packages-only --platform arch --backend "$backend" \
    > "$TEST_ROOT/$backend.out"
  grep -q "$backend -S --needed --repo" "$TEST_ROOT/$backend.out" || \
    fail "$backend no restringió el lote binario a repositorios"
  grep -q "$backend -S --needed --aur brave-bin" "$TEST_ROOT/$backend.out" || \
    fail "$backend no restringió el fallback brave-bin a AUR"
done

if PATH="$FAKE_BIN:/usr/bin" "$DOTFILES" bootstrap \
    --profile desktop --packages-only --platform arch --backend pacman \
    > "$TEST_ROOT/pacman.out" 2>&1; then
  fail "pacman intentó aceptar un paquete AUR faltante"
fi
grep -q 'pacman sólo gestiona repositorios' "$TEST_ROOT/pacman.out" || \
  fail "pacman no explicó su límite de capacidad"

printf 'OK: bootstrap, doctor, unlink y adaptadores validados\n'
