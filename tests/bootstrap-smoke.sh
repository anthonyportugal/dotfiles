#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
DOTFILES="$REPO_ROOT/bin/dotfiles"
TEST_ROOT=""

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  [[ -n "$TEST_ROOT" && "$TEST_ROOT" == /tmp/dotfiles-bootstrap-smoke.* ]] || return 0
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

TEST_ROOT=$(mktemp -d /tmp/dotfiles-bootstrap-smoke.XXXXXX)
TARGET_DIR="$TEST_ROOT/home with spaces"
CONFLICT_DIR="$TEST_ROOT/conflict"
PARENT_CONFLICT_DIR="$TEST_ROOT/parent-conflict"
PARENT_DESTINATION="$TEST_ROOT/parent-destination"
FAKE_BIN="$TEST_ROOT/fake-bin"
mkdir "$TARGET_DIR" "$CONFLICT_DIR" "$PARENT_CONFLICT_DIR" \
  "$PARENT_DESTINATION" "$FAKE_BIN"

# Dry-run, aplicación, doctor e idempotencia sobre un home desechable.
"$DOTFILES" bootstrap --profile desktop --stow-only --target "$TARGET_DIR"
"$DOTFILES" bootstrap --profile desktop --stow-only --target "$TARGET_DIR" --apply
"$DOTFILES" doctor --profile desktop --stow-only --target "$TARGET_DIR"
"$DOTFILES" bootstrap --profile desktop --stow-only --target "$TARGET_DIR" --apply

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
