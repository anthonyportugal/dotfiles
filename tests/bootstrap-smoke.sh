#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
DOTFILES="$REPO_ROOT/bin/dotfiles"
export DOTFILES_LANG=es
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
    --config-file "$REPO_ROOT/layers/desktop/home/alacritty/.config/alacritty/alacritty.toml" \
    >/dev/null || fail "la configuración de Alacritty no es válida"
fi

[[ -d "$TEST_TMP_PARENT" ]] || fail "no existe el directorio temporal: $TEST_TMP_PARENT"
TEST_ROOT=$(mktemp -d "$TEST_TMP_PARENT/dotfiles-bootstrap-smoke.XXXXXX")
TARGET_DIR="$TEST_ROOT/home with spaces"
CONFLICT_DIR="$TEST_ROOT/conflict"
PARENT_CONFLICT_DIR="$TEST_ROOT/parent-conflict"
PARENT_DESTINATION="$TEST_ROOT/parent-destination"
FAKE_BIN="$TEST_ROOT/fake-bin"
WM_TARGET="$TEST_ROOT/wm target"
WM_FAILURE_TARGET="$TEST_ROOT/wm failure target"
WALLS_REPO="$TEST_ROOT/external walls"
WALLS_LOG="$TEST_ROOT/walls.log"
mkdir "$TARGET_DIR" "$CONFLICT_DIR" "$PARENT_CONFLICT_DIR" \
  "$PARENT_DESTINATION" "$FAKE_BIN" "$WM_TARGET" \
  "$WM_FAILURE_TARGET" "$WALLS_REPO" "$WALLS_REPO/bin"
ln -s "$SCRIPT_DIR/fakes/walls-entrypoint" "$WALLS_REPO/bin/walls"

# Dry-run, aplicación, doctor e idempotencia sobre un home desechable.
"$DOTFILES" bootstrap --profile desktop --stow-only --target "$TARGET_DIR"
"$DOTFILES" bootstrap --profile desktop --stow-only --target "$TARGET_DIR" --apply
"$DOTFILES" doctor --profile desktop --stow-only --target "$TARGET_DIR"
"$DOTFILES" bootstrap --profile desktop --stow-only --target "$TARGET_DIR" --apply

# El default GTK se aplica sólo cuando el target coincide con HOME y es
# idempotente; el fixture evita tocar dconf o preferencias del host.
PREFERENCE_STATE="$TEST_ROOT/gsettings.state"
PREFERENCE_LOG="$TEST_ROOT/gsettings.log"
: > "$PREFERENCE_STATE"
: > "$PREFERENCE_LOG"
ln -s "$SCRIPT_DIR/fakes/gsettings" "$FAKE_BIN/gsettings"
for _ in 1 2; do
  HOME="$TARGET_DIR" PATH="$FAKE_BIN:/usr/bin" \
    DOTFILES_TEST_GSETTINGS_STATE="$PREFERENCE_STATE" \
    DOTFILES_TEST_GSETTINGS_LOG="$PREFERENCE_LOG" \
    "$DOTFILES" bootstrap --profile desktop --stow-only \
      --target "$TARGET_DIR" --apply >/dev/null
done
grep -Fxq "'prefer-dark'" "$PREFERENCE_STATE" || \
  fail 'el bootstrap no aplicó prefer-dark'
[[ $(grep -c '^set prefer-dark$' "$PREFERENCE_LOG") == 1 ]] || \
  fail 'prefer-dark no fue idempotente'
HOME="$TARGET_DIR" PATH="$FAKE_BIN:/usr/bin" \
  DOTFILES_TEST_GSETTINGS_STATE="$PREFERENCE_STATE" \
  DOTFILES_TEST_GSETTINGS_LOG="$PREFERENCE_LOG" \
  "$DOTFILES" doctor --profile desktop --stow-only \
    --target "$TARGET_DIR" >/dev/null

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

for alias_name in l la ll ld; do
  alias_definition=$(zsh -dfc 'source "$1"; alias "$2"' \
    dotfiles-alias-check \
    "$REPO_ROOT/layers/core/home/zsh/.config/zsh/conf.d/40-aliases.zsh" "$alias_name")
  [[ "$alias_definition" == *'ls --color=auto '* ]] ||
    fail "el alias $alias_name no activa colores sólo para terminal"
done

lg_definition=$(zsh -dfc 'source "$1"; alias "$2"' \
  dotfiles-alias-check \
  "$REPO_ROOT/layers/core/home/zsh/.config/zsh/conf.d/40-aliases.zsh" "lg")
[[ "$lg_definition" == *'lazygit'* ]] ||
  fail "el alias lg no apunta a lazygit"

# Los WMs son capas de layers/wm/ que la base enlaza con el mismo motor. Un
# apply ejecuta primero el preflight de la capa y no mezcla perfiles.
"$DOTFILES" bootstrap --profile core --stow-only --target "$WM_TARGET" \
  --wm bspwm --wm-profile core --apply > "$TEST_ROOT/wm-apply.out"
grep -q 'Dry-run de la capa wm/bspwm completado' "$TEST_ROOT/wm-apply.out" || \
  fail "bootstrap no ejecutó el preflight de la capa antes de aplicar"
[[ -L "$WM_TARGET/.zshrc" ]] || fail "bootstrap con WM no enlazó la base"
[[ -L "$WM_TARGET/.config/bspwm/bspwmrc" ]] || fail "bootstrap no enlazó la capa bspwm"
[[ "$(realpath "$WM_TARGET/.config/bspwm/bspwmrc")" == "$REPO_ROOT/layers/wm/bspwm/home/bspwm/.config/bspwm/bspwmrc" ]] || \
  fail "el enlace de bspwm no apunta a layers/wm/bspwm"
WM_STATE="$WM_TARGET/.local/state/dotfiles"
grep -qx 'PROFILE="core"' "$WM_STATE/bspwm.receipt" || fail "el recibo de bspwm no guardó el perfil core"
# A WM pulls in the desktop layer, so the recorded base profile is desktop.
grep -qx 'PROFILE="desktop"' "$WM_STATE/dotfiles.receipt" || fail "el recibo de selección no guardó el perfil desktop que exige el WM"
grep -q 'Los WMs requieren el perfil desktop; se aplica desktop en lugar de core' "$TEST_ROOT/wm-apply.out" || \
  fail "bootstrap no explicó por qué subió el perfil a desktop"
[[ -L "$WM_TARGET/.config/alacritty/alacritty.toml" ]] || fail "el WM no arrastró la capa desktop"
grep -qx 'WMS="bspwm"' "$WM_STATE/dotfiles.receipt" || fail "el recibo de selección no guardó los WMs"

"$DOTFILES" bootstrap --profile core --stow-only --target "$WM_TARGET" \
  --wm mangowm --wm-profile desktop > "$TEST_ROOT/wm-dry.out"
grep -q 'Plan de la capa wm/mangowm' "$TEST_ROOT/wm-dry.out" || fail "la base no resolvió la capa de MangoWM"
grep -Eq 'Perfil: +desktop' "$TEST_ROOT/wm-dry.out" || fail "la capa no recibió su perfil independiente"
[[ ! -e "$WM_TARGET/.config/mango" ]] || fail "un dry-run de MangoWM creó enlaces"

"$DOTFILES" doctor --profile core --stow-only --target "$WM_TARGET" \
  --wm bspwm > "$TEST_ROOT/wm-doctor.out" || fail "doctor falló sobre una capa bspwm enlazada"
grep -q 'Window Manager (bspwm): OK' "$TEST_ROOT/wm-doctor.out" || fail "doctor no auditó la capa bspwm"
grep -Eq 'Perfil: +core' "$TEST_ROOT/wm-doctor.out" || fail "doctor no restauró el perfil del recibo de bspwm"

"$DOTFILES" unlink --profile core --target "$WM_TARGET" --wm bspwm --apply > "$TEST_ROOT/wm-unlink.out"
grep -q 'Dry-run de unlink de la capa wm/bspwm completado' "$TEST_ROOT/wm-unlink.out" || \
  fail "unlink no ejecutó el preflight de la capa antes de aplicar"
[[ ! -e "$WM_TARGET/.config/bspwm/bspwmrc" ]] || fail "unlink no retiró el enlace de bspwm"
[[ ! -e "$WM_STATE/bspwm.receipt" ]] || fail "unlink no eliminó el recibo de bspwm"
[[ ! -e "$WM_STATE/dotfiles.receipt" ]] || fail "unlink no eliminó el recibo de selección"

"$DOTFILES" bootstrap --profile core --stow-only --target "$WM_TARGET" \
  --wm both > "$TEST_ROOT/wm-both.out" || fail "--wm both fue rechazado"
grep -q 'Plan de la capa wm/mangowm' "$TEST_ROOT/wm-both.out" || fail "--wm both no incluyó MangoWM"
grep -q 'Plan de la capa wm/bspwm' "$TEST_ROOT/wm-both.out" || fail "--wm both no incluyó BSPWM"

# A failure inside a layer operation must stop it, even when nothing checks
# that command explicitly (here the WM receipt cannot be written). Root ignores
# directory permissions, so the check only runs as a regular user.
if (( EUID != 0 )); then
  ERREXIT_TARGET="$TEST_ROOT/errexit target"
  mkdir -p "$ERREXIT_TARGET/.local/state/dotfiles"
  chmod 555 "$ERREXIT_TARGET/.local/state/dotfiles"
  if "$DOTFILES" bootstrap --profile core --stow-only --target "$ERREXIT_TARGET" \
      --wm bspwm --apply > "$TEST_ROOT/wm-errexit.out" 2>&1; then
    chmod 755 "$ERREXIT_TARGET/.local/state/dotfiles"
    fail "bootstrap terminó bien aunque no pudo escribir el recibo de la capa"
  fi
  chmod 755 "$ERREXIT_TARGET/.local/state/dotfiles"
  # The layer must have reached its apply step, so the failure came from it.
  grep -q 'Aplicando enlaces GNU Stow' "$TEST_ROOT/wm-errexit.out" || \
    fail "el bootstrap falló antes de que la capa llegara a aplicar"
  # core is the first layer to write its receipt, so it is the one that stops.
  [[ -L "$ERREXIT_TARGET/.zshrc" ]] || fail "la capa core no enlazó antes del fallo del recibo"
  if grep -q 'Bootstrap de la capa core completado' "$TEST_ROOT/wm-errexit.out"; then
    fail "la capa informó éxito después de un fallo no comprobado"
  fi
  [[ ! -e "$ERREXIT_TARGET/.config/bspwm" ]] || fail "las capas siguientes se ejecutaron tras el fallo de core"
else
  printf 'SKIP: la prueba de errexit de capas necesita un usuario sin privilegios de root\n'
fi

# Si el preflight de la capa falla, la base no debe llegar a crear ningún enlace.
mkdir -p "$WM_FAILURE_TARGET/.config/bspwm"
printf 'local\n' > "$WM_FAILURE_TARGET/.config/bspwm/bspwmrc"
if "$DOTFILES" bootstrap --profile core --stow-only --target "$WM_FAILURE_TARGET" \
    --wm bspwm --wm-profile core --apply > "$TEST_ROOT/wm-failure.out" 2>&1; then
  fail "bootstrap ignoró un preflight fallido del WM"
fi
[[ ! -e "$WM_FAILURE_TARGET/.zshrc" ]] || \
  fail "la base se modificó después de fallar el preflight del WM"
grep -q 'no se modificó la base' "$TEST_ROOT/wm-failure.out" || \
  fail "el fallo del preflight de la capa no fue accionable"
[[ "$(cat "$WM_FAILURE_TARGET/.config/bspwm/bspwmrc")" == local ]] || \
  fail "el preflight fallido tocó el archivo local del usuario"

# La interfaz rechaza opciones retiradas, incompletas o WMs inexistentes.
if "$DOTFILES" bootstrap --profile core --stow-only --target "$WM_TARGET" \
    --wm bspwm --wm-path "$REPO_ROOT" > "$TEST_ROOT/wm-path.out" 2>&1; then
  fail "--wm-path fue aceptado"
fi
grep -q -- '--wm-path ya no existe' "$TEST_ROOT/wm-path.out" || fail "el rechazo de --wm-path no fue accionable"
if "$DOTFILES" bootstrap --profile core --stow-only --target "$WM_TARGET" \
    --wm-profile core > "$TEST_ROOT/wm-no-name.out" 2>&1; then
  fail "--wm-profile fue aceptado sin --wm"
fi
if "$DOTFILES" bootstrap --profile core --stow-only --target "$WM_TARGET" \
    --wm openbox > "$TEST_ROOT/wm-unknown.out" 2>&1; then
  fail "se aceptó un WM sin capa"
fi
grep -q 'no soportado' "$TEST_ROOT/wm-unknown.out" || fail "el rechazo de un WM desconocido no fue accionable"
"$DOTFILES" bootstrap --profile core --stow-only --target "$WM_TARGET" \
  --wm mangowm --wm-feature laptop \
  > "$TEST_ROOT/wm-feature-deprecate.out" 2>&1 || true
grep -q 'deprecado' "$TEST_ROOT/wm-feature-deprecate.out" || \
  fail "la opción --wm-feature no produjo advertencia de deprecación"

# A failing optional component after the layers were linked must still leave the
# selection recorded, so a later sync can restore what is on disk. The walls
# double fails when its log variable is missing.
RECEIPT_ORDER_TARGET="$TEST_ROOT/receipt order target"
mkdir -p "$RECEIPT_ORDER_TARGET"
if env -u DOTFILES_WALLS_TEST_LOG "$DOTFILES" bootstrap --profile core --stow-only \
    --target "$RECEIPT_ORDER_TARGET" --wallpapers --wallpapers-path "$WALLS_REPO" --apply \
    > "$TEST_ROOT/receipt-order.out" 2>&1; then
  fail "bootstrap ignoró el fallo del componente de wallpapers"
fi
[[ -L "$RECEIPT_ORDER_TARGET/.zshrc" ]] || fail "las capas no se enlazaron antes del componente opcional"
grep -qx 'PROFILE="core"' "$RECEIPT_ORDER_TARGET/.local/state/dotfiles/dotfiles.receipt" 2>/dev/null || \
  fail "un componente opcional fallido impidió guardar la selección ya aplicada"

# Integración con repositorio de wallpapers (anthonyportugal/walls)
: > "$WALLS_LOG"
DOTFILES_WALLS_TEST_LOG="$WALLS_LOG" "$DOTFILES" bootstrap \
  --profile core --stow-only --target "$TARGET_DIR" \
  --wallpapers --wallpapers-path "$WALLS_REPO"
[[ ! -s "$WALLS_LOG" ]] || fail "bootstrap dry-run no debió ejecutar la vinculación de wallpapers"

DOTFILES_WALLS_TEST_LOG="$WALLS_LOG" "$DOTFILES" bootstrap \
  --profile core --stow-only --target "$TARGET_DIR" \
  --wallpapers --wallpapers-path "$WALLS_REPO" --apply
grep -q -- 'link --target' "$WALLS_LOG" || \
  fail "bootstrap --wallpapers --apply no invocó el comando link"

: > "$WALLS_LOG"
DOTFILES_WALLS_TEST_LOG="$WALLS_LOG" "$DOTFILES" doctor \
  --profile core --stow-only --target "$TARGET_DIR" \
  --wallpapers --wallpapers-path "$WALLS_REPO"
grep -q -- 'doctor --target' "$WALLS_LOG" || \
  fail "doctor --wallpapers no invocó el comando doctor"

: > "$WALLS_LOG"
DOTFILES_WALLS_TEST_LOG="$WALLS_LOG" "$DOTFILES" unlink \
  --profile core --target "$TARGET_DIR" \
  --wallpapers --wallpapers-path "$WALLS_REPO"
[[ ! -s "$WALLS_LOG" ]] || fail "unlink dry-run no debió ejecutar el desvinculado de wallpapers"

DOTFILES_WALLS_TEST_LOG="$WALLS_LOG" "$DOTFILES" unlink \
  --profile core --target "$TARGET_DIR" \
  --wallpapers --wallpapers-path "$WALLS_REPO" --apply
grep -q -- 'unlink --target' "$WALLS_LOG" || \
  fail "unlink --wallpapers --apply no invocó el comando unlink"

# Validaciones de límites para wallpapers
if "$DOTFILES" bootstrap --profile core --stow-only --target "$TARGET_DIR" \
    --wallpapers --wallpapers-path "$REPO_ROOT" > "$TEST_ROOT/walls-nested.out" 2>&1; then
  fail "se aceptó un checkout de wallpapers dentro del repositorio base"
fi
grep -q 'debe estar fuera del repositorio base' "$TEST_ROOT/walls-nested.out" || \
  fail "no se explicó el límite de independencia del checkout de wallpapers"

BAD_WALLS="$TEST_ROOT/bad walls"
mkdir "$BAD_WALLS"
if "$DOTFILES" bootstrap --profile core --stow-only --target "$TARGET_DIR" \
    --wallpapers --wallpapers-path "$BAD_WALLS" > "$TEST_ROOT/walls-bad-entrypoint.out" 2>&1; then
  fail "se aceptó un checkout de wallpapers sin bin/walls ejecutable"
fi
grep -q 'no expone el entrypoint ejecutable esperado' "$TEST_ROOT/walls-bad-entrypoint.out" || \
  fail "no se explicó la falta del bin/walls en el checkout de wallpapers"

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
