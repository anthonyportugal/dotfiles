#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
MANGO="$REPO_ROOT/bin/mango"
TEST_ROOT=""

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  [[ -n "$TEST_ROOT" && "$TEST_ROOT" == /tmp/mangowm-bootstrap-smoke.* ]] || \
    return 0
  find "$TEST_ROOT" -mindepth 1 -delete
  find "$TEST_ROOT" -depth -type d -empty -delete
}

trap cleanup EXIT

command -v stow >/dev/null 2>&1 || \
  fail "GNU Stow es necesario para este smoke test"
[[ -x "$MANGO" ]] || fail "$MANGO no es ejecutable"

TEST_ROOT=$(mktemp -d /tmp/mangowm-bootstrap-smoke.XXXXXX)
TARGET_DIR="$TEST_ROOT/home with spaces"
CONFLICT_DIR="$TEST_ROOT/conflict"
PARENT_CONFLICT_DIR="$TEST_ROOT/parent-conflict"
PARENT_DESTINATION="$TEST_ROOT/parent-destination"
SCOPE_REPO="$TEST_ROOT/scope-repo"
SCOPE_TARGET="$TEST_ROOT/scope-target"
CONFIG_REPO="$TEST_ROOT/config-repo"
CONFIG_TARGET="$TEST_ROOT/config-target"
FAKE_BIN="$TEST_ROOT/fake-bin"

mkdir "$TARGET_DIR" "$CONFLICT_DIR" "$PARENT_CONFLICT_DIR" \
  "$PARENT_DESTINATION" "$SCOPE_REPO" "$SCOPE_TARGET" \
  "$CONFIG_REPO" "$CONFIG_TARGET" "$FAKE_BIN"

# El dry-run no debe tocar el target. Apply, doctor e idempotencia operan sobre
# un home desechable y sólo administran el archivo del paquete mango.
"$MANGO" bootstrap --profile desktop --stow-only --target "$TARGET_DIR"
[[ ! -e "$TARGET_DIR/.config/mango/config.conf" ]] || \
  fail "el dry-run creó un archivo"
[[ ! -e "$TARGET_DIR/.local/state/dotfiles/mangowm.receipt" ]] || \
  fail "el dry-run de bootstrap creó el recibo de estado"

"$MANGO" bootstrap --profile desktop --stow-only \
  --target "$TARGET_DIR" --apply
[[ -L "$TARGET_DIR/.config/mango/config.conf" ]] || \
  fail "bootstrap no creó el enlace esperado"
[[ "$(realpath -m -- "$TARGET_DIR/.config/mango/config.conf")" == \
   "$(realpath -m -- "$REPO_ROOT/home/mango/.config/mango/config.conf")" ]] || \
  fail "el enlace no apunta al owner correcto"

RECEIPT_FILE="$TARGET_DIR/.local/state/dotfiles/mangowm.receipt"
[[ -f "$RECEIPT_FILE" ]] || \
  fail "bootstrap --apply no generó el recibo de estado"
grep -qx 'RECEIPT_VERSION=1' "$RECEIPT_FILE" || \
  fail "el recibo no define RECEIPT_VERSION=1"
grep -qx 'COMPONENT="mangowm"' "$RECEIPT_FILE" || \
  fail "el recibo no define COMPONENT=mangowm"
grep -qx 'PROFILE="desktop"' "$RECEIPT_FILE" || \
  fail "el recibo no guardó PROFILE=desktop"

# Switch to core to test profile reuse and override
"$MANGO" bootstrap --profile core --stow-only \
  --target "$TARGET_DIR" --apply
grep -qx 'PROFILE="core"' "$RECEIPT_FILE" || \
  fail "el recibo no guardó PROFILE=core tras bootstrap"

# doctor y bootstrap sin --profile deben reutilizar el perfil guardado en el recibo (core)
"$MANGO" doctor --stow-only --target "$TARGET_DIR" \
  > "$TEST_ROOT/receipt-doctor.out" 2>&1 || \
  fail "doctor sin --profile falló al reutilizar el recibo"
grep -q 'Perfil:[[:space:]]*core' "$TEST_ROOT/receipt-doctor.out" || \
  fail "doctor no reutilizó PROFILE=core desde el recibo"

"$MANGO" bootstrap --stow-only --target "$TARGET_DIR" \
  > "$TEST_ROOT/receipt-bootstrap.out" 2>&1 || \
  fail "bootstrap sin --profile falló al reutilizar el recibo"
grep -q 'Perfil:[[:space:]]*core' "$TEST_ROOT/receipt-bootstrap.out" || \
  fail "bootstrap no reutilizó PROFILE=core desde el recibo"

# Switch back to desktop and test that explicit --profile core overrides receipt
"$MANGO" bootstrap --profile desktop --stow-only --target "$TARGET_DIR" --apply
grep -qx 'PROFILE="desktop"' "$RECEIPT_FILE" || \
  fail "el recibo no guardó PROFILE=desktop tras bootstrap"

"$MANGO" bootstrap --profile core --stow-only --target "$TARGET_DIR" \
  > "$TEST_ROOT/receipt-override-core.out" 2>&1 || \
  fail "bootstrap con --profile explícito falló"
grep -q 'Perfil:[[:space:]]*core' "$TEST_ROOT/receipt-override-core.out" || \
  fail "bootstrap no respetó el override explícito --profile core"

"$MANGO" doctor --profile desktop --stow-only --target "$TARGET_DIR"
"$MANGO" bootstrap --profile desktop --stow-only \
  --target "$TARGET_DIR" --apply

# Un archivo existente o un directorio padre enlazado fuera del target deben
# detenerse antes de modificar el home.
mkdir -p "$CONFLICT_DIR/.config/mango"
touch "$CONFLICT_DIR/.config/mango/config.conf"
if "$MANGO" bootstrap --profile core --stow-only --target "$CONFLICT_DIR" \
    > "$TEST_ROOT/conflict.out" 2>&1; then
  fail "el dry-run aceptó una colisión"
fi
grep -q 'colisión' "$TEST_ROOT/conflict.out" || \
  fail "no se reportó la colisión"
[[ -f "$CONFLICT_DIR/.config/mango/config.conf" && \
   ! -L "$CONFLICT_DIR/.config/mango/config.conf" ]] || \
  fail "el preflight modificó el archivo en conflicto"

ln -s "$PARENT_DESTINATION" "$PARENT_CONFLICT_DIR/.config"
if "$MANGO" bootstrap --profile core --stow-only \
    --target "$PARENT_CONFLICT_DIR" \
    > "$TEST_ROOT/parent-conflict.out" 2>&1; then
  fail "el dry-run aceptó un directorio padre enlazado fuera del target"
fi
grep -q 'directorio padre es symlink' "$TEST_ROOT/parent-conflict.out" || \
  fail "no se explicó la colisión del directorio padre"

# Fixtures contaminados validan ownership y configuración sin tocar el source.
cp -a "$REPO_ROOT/bin" "$REPO_ROOT/home" "$REPO_ROOT/packages" "$SCOPE_REPO/"
mkdir -p "$SCOPE_REPO/home/mango/.config/foot"
touch "$SCOPE_REPO/home/mango/.config/foot/foot.ini"
if "$SCOPE_REPO/bin/mango" bootstrap --profile core --stow-only \
    --target "$SCOPE_TARGET" > "$TEST_ROOT/scope.out" 2>&1; then
  fail "el bootstrap aceptó contenido fuera del ownership de MangoWM"
fi
grep -q 'contenido fuera del ownership de MangoWM: .config/foot' \
  "$TEST_ROOT/scope.out" || fail "no se explicó la contaminación del paquete"
if grep -q 'Simulación nativa de GNU Stow' "$TEST_ROOT/scope.out"; then
  fail "Stow se ejecutó pese a contenido ajeno dentro del paquete"
fi

cp -a "$REPO_ROOT/bin" "$REPO_ROOT/home" "$REPO_ROOT/packages" "$CONFIG_REPO/"
printf 'unexpected=1\n' >> \
  "$CONFIG_REPO/home/mango/.config/mango/config.conf"
if "$CONFIG_REPO/bin/mango" bootstrap --profile core --stow-only \
    --target "$CONFIG_TARGET" > "$TEST_ROOT/config.out" 2>&1; then
  fail "el bootstrap aceptó una directiva duplicada"
fi
grep -q 'directiva fuera del entrypoint modular' "$TEST_ROOT/config.out" || \
  fail "no se explicó la configuración inválida"
if grep -q 'Simulación nativa de GNU Stow' "$TEST_ROOT/config.out"; then
  fail "Stow se ejecutó pese a configuración inválida"
fi

# Unlink también simula primero y no retira paquetes del sistema.
"$MANGO" unlink --profile desktop --target "$TARGET_DIR"
[[ -L "$TARGET_DIR/.config/mango/config.conf" ]] || \
  fail "el dry-run de unlink retiró el enlace"
[[ -f "$RECEIPT_FILE" ]] || \
  fail "el dry-run de unlink eliminó el recibo de estado"
"$MANGO" unlink --profile desktop --target "$TARGET_DIR" --apply
[[ ! -e "$TARGET_DIR/.config/mango/config.conf" ]] || \
  fail "unlink dejó el enlace administrado"
[[ ! -e "$RECEIPT_FILE" ]] || \
  fail "unlink --apply no eliminó el recibo de estado"
if "$MANGO" doctor --profile desktop --stow-only --target "$TARGET_DIR" \
    > "$TEST_ROOT/doctor-after-unlink.out" 2>&1; then
  fail "doctor debía detectar el enlace ausente después de unlink"
fi

# Adaptadores: pacman falso marca paquetes faltantes y los helpers falsos dejan
# inspeccionar comandos sin instalar nada en el host.
ln -s /usr/bin/false "$FAKE_BIN/pacman"
for backend in shelly paru yay; do
  ln -s /usr/bin/true "$FAKE_BIN/$backend"
done

PATH="$FAKE_BIN:/usr/bin" "$MANGO" bootstrap \
  --profile desktop \
  --packages-only --platform arch --backend shelly \
  > "$TEST_ROOT/shelly.out"
grep -q 'shelly install standard' "$TEST_ROOT/shelly.out" || \
  fail "falta el comando de repositorio para Shelly"
grep -Eq 'shelly install aur .*mangowm.*wlogout' "$TEST_ROOT/shelly.out" || \
  fail "Shelly no conserva el lote AUR declarado"
grep -Eq 'Paquetes repo:[[:space:]].*brightnessctl.*wf-recorder' \
  "$TEST_ROOT/shelly.out" || fail "el perfil desktop no añadió brightnessctl y wf-recorder"

PATH="$FAKE_BIN:/usr/bin" "$MANGO" bootstrap \
  --profile core --packages-only --platform cachyos \
  > "$TEST_ROOT/auto-cachyos.out"
grep -Eq 'Backend:[[:space:]]+shelly' "$TEST_ROOT/auto-cachyos.out" || \
  fail "la detección automática de CachyOS no priorizó Shelly"
grep -Eq 'Paquetes AUR:[[:space:]].*mangowm.*swaylock-effects-git' \
  "$TEST_ROOT/auto-cachyos.out" || fail "el perfil core no declaró MangoWM y swaylock-effects-git"

for backend in paru yay; do
  PATH="$FAKE_BIN:/usr/bin" "$MANGO" bootstrap \
    --profile desktop --packages-only --platform arch --backend "$backend" \
    > "$TEST_ROOT/$backend.out"
  grep -q "$backend -S --needed --repo" "$TEST_ROOT/$backend.out" || \
    fail "$backend no restringió el lote binario a repositorios"
  grep -Eq "$backend -S --needed --aur .*mangowm.*wlogout" \
    "$TEST_ROOT/$backend.out" || \
    fail "$backend no restringió el lote AUR a su procedencia"
done

if PATH="$FAKE_BIN:/usr/bin" "$MANGO" bootstrap \
    --profile core --packages-only --platform arch --backend pacman \
    > "$TEST_ROOT/pacman.out" 2>&1; then
  fail "pacman intentó aceptar un paquete AUR faltante"
fi
grep -q 'pacman sólo gestiona repositorios' "$TEST_ROOT/pacman.out" || \
  fail "pacman no explicó su límite de capacidad"

"$MANGO" bootstrap --profile core --feature laptop --stow-only \
  --target "$TARGET_DIR" > "$TEST_ROOT/feature.out" 2>&1 || true
grep -q 'deprecado' "$TEST_ROOT/feature.out" || \
  fail "el flag --feature no emitió advertencia de deprecación"

printf 'OK: bootstrap, doctor, unlink y adaptadores validados\n'
