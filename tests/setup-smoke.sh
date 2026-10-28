#!/usr/bin/env bash
# `dotfiles setup`: the short guided flow (profile, WMs, extras, overlay, then
# plan and apply / dry-run / cancel) driven with piped input. Every run uses a
# home in mktemp, --stow-only and file:// fixtures; never the network. Also
# covers the help cleanup (bootstrap, completion, no install alias).

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
  [[ -n "$TEST_ROOT" && "$TEST_ROOT" == "$TEST_TMP_PARENT"/dotfiles-setup-smoke.* ]] || return 0
  rm -rf -- "$TEST_ROOT"
}

trap cleanup EXIT

command -v stow >/dev/null 2>&1 || fail "GNU Stow es necesario para este smoke test"
command -v git >/dev/null 2>&1 || fail "git es necesario para este smoke test"
[[ -d "$TEST_TMP_PARENT" ]] || fail "no existe el directorio temporal: $TEST_TMP_PARENT"
TEST_ROOT=$(mktemp -d "$TEST_TMP_PARENT/dotfiles-setup-smoke.XXXXXX")
TEST_ROOT=$(realpath -e -- "$TEST_ROOT")
CHECKOUT_STATE=$(git -C "$REPO_ROOT" status --porcelain)

# Git never reads the host configuration (signing, hooks, default branch).
export GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL="$TEST_ROOT/gitconfig"
git config --file "$GIT_CONFIG_GLOBAL" user.name test
git config --file "$GIT_CONFIG_GLOBAL" user.email test@example.invalid
git config --file "$GIT_CONFIG_GLOBAL" init.defaultBranch main
git config --file "$GIT_CONFIG_GLOBAL" commit.gpgsign false

commit_all() {
  git -C "$1" add -A
  git -C "$1" commit -qm "$2" --no-verify
}

# Fixture component (walls) declared in a components.conf of its own.
WALLS_SRC="$TEST_ROOT/walls-src"
mkdir -p "$WALLS_SRC/wallpapers"
printf 'one\n' > "$WALLS_SRC/wallpapers/w-001.webp"
git -C "$WALLS_SRC" init -q
commit_all "$WALLS_SRC" one
export DOTFILES_COMPONENTS_FILE="$TEST_ROOT/components.conf"
printf 'walls file://%s %s wallpapers=.local/share/wallpapers -- Wallpaper collection\n' \
  "$WALLS_SRC" "$(git -C "$WALLS_SRC" rev-parse HEAD)" > "$DOTFILES_COMPONENTS_FILE"

# Writes an overlay at $1 with one layer, ident, that applies with core.
make_overlay() {
  local root=$1
  mkdir -p "$root/layers/ident/packages/stow" "$root/layers/ident/home/ident/.config/overlay"
  printf 'requires=core\nprofiles=ident\nprune_dirs=.config/overlay\n' > "$root/layers/ident/layer.conf"
  printf 'ident\n' > "$root/layers/ident/packages/stow/ident.txt"
  printf 'ident\n' > "$root/layers/ident/home/ident/.config/overlay/ident"
  : > "$root/layers/ident/home/.stow"
}

# Runs `dotfiles setup` for home $1 with stdin $2 and the remaining options;
# leaves the output in $output and the exit status in $status. The language
# comes from LANG only, unless the caller exports it otherwise.
setup_run() {
  local home=$1 input=$2
  shift 2
  mkdir -p "$home"
  status=0
  output=$(printf '%b' "$input" | env -u LC_ALL -u LC_MESSAGES -u DOTFILES_LANG LANG="${SETUP_LANG:-C}" \
    HOME="$home" "${SETUP_DOTFILES:-$DOTFILES}" setup --stow-only --target "$home" "$@" 2>&1) || status=$?
}

receipt() {
  printf '%s/.local/state/dotfiles/%s.receipt' "$1" "$2"
}

# 1. Server: no WM question, no desktop-only extra, cli linked, receipt.
H="$TEST_ROOT/server"
setup_run "$H" 'server\n\n\napply\n'
(( status == 0 )) || fail "setup server terminó con $status: $output"
[[ "$output" != *'Window managers'* ]] || fail "el perfil server preguntó por los WMs: $output"
[[ "$output" == *'dev-containers'* && "$output" == *'walls'* ]] || fail "server no ofreció los extras compatibles: $output"
[[ "$output" == *'Wallpaper collection'* ]] || fail "el extra walls no mostró su descripción: $output"
[[ -L "$H/.zshrc" && -L "$H/.config/bat/config" ]] || fail "setup server no enlazó cli"
[[ ! -e "$H/.config/alacritty" ]] || fail "setup server aplicó desktop"
grep -qx 'PROFILE="cli"' "$(receipt "$H" dotfiles)" || fail "el recibo no guardó el perfil cli: $(<"$(receipt "$H" dotfiles)")"
grep -qx 'WMS=""' "$(receipt "$H" dotfiles)" || fail "el recibo de server guardó WMs"
grep -qx 'OVERLAY=""' "$(receipt "$H" dotfiles)" || fail "Enter no omitió el overlay"
[[ "$output" == *'fail-closed'* ]] || fail "sin overlay no avisó que Git queda fail-closed: $output"
[[ "$output" == *'dotfiles system'* ]] || fail "setup no indicó 'dotfiles system' al cerrar: $output"
[[ "$output" != *'user.name'* && "$output" != *'Git Name'* ]] || fail "setup sigue pidiendo la identidad Git: $output"

# 2. Desktop + bspwm + dev + dev-containers + walls, applied.
H="$TEST_ROOT/desktop"
setup_run "$H" 'desktop\nbspwm\ndev dev-containers walls\n\napply\n'
(( status == 0 )) || fail "setup desktop terminó con $status: $output"
[[ "$output" == *'Window managers'* && "$output" == *'mangowm'* ]] || fail "desktop no ofreció los WMs: $output"
[[ -L "$H/.config/bspwm/bspwmrc" ]] || fail "setup no enlazó bspwm"
[[ ! -e "$H/.config/mango" ]] || fail "setup enlazó un WM no elegido"
[[ -L "$H/.config/alacritty" || -e "$H/.config/alacritty/alacritty.toml" ]] || fail "setup no enlazó desktop"
R=$(receipt "$H" dotfiles)
grep -qx 'PROFILE="desktop"' "$R" || fail "el recibo no guardó desktop: $(<"$R")"
grep -qx 'WMS="bspwm"' "$R" || fail "el recibo no guardó bspwm: $(<"$R")"
grep -qx 'LAYERS="dev"' "$R" || fail "el recibo no guardó la capa dev: $(<"$R")"
grep -qx 'FEATURES="dev-containers"' "$R" || fail "el recibo no guardó dev-containers: $(<"$R")"
[[ -f "$(receipt "$H" bspwm)" ]] || fail "no se escribió el recibo de bspwm"
grep -qx 'COMPONENTS="walls"' "$(receipt "$H" components)" || fail "el recibo de componentes no guardó walls"
[[ -L "$H/.local/share/wallpapers" ]] || fail "setup no añadió el componente walls"

# 3. A detected overlay at the target's .dotfiles-private is applied and recorded.
H="$TEST_ROOT/overlay-detected"
make_overlay "$H/.dotfiles-private"
setup_run "$H" 'server\n\n\napply\n'
(( status == 0 )) || fail "setup con overlay detectado terminó con $status: $output"
[[ "$output" == *'Overlay detected'* ]] || fail "setup no detectó el overlay: $output"
[[ -L "$H/.config/overlay/ident" ]] || fail "setup no aplicó la capa del overlay detectado"
grep -Fxq "OVERLAY=\"$H/.dotfiles-private\"" "$(receipt "$H" dotfiles)" || \
  fail "el recibo no guardó el overlay detectado: $(<"$(receipt "$H" dotfiles)")"

# An overlay URL is cloned into ~/.dotfiles-private and applied.
OVERLAY_SRC="$TEST_ROOT/overlay-src"
make_overlay "$OVERLAY_SRC"
git -C "$OVERLAY_SRC" init -q
commit_all "$OVERLAY_SRC" overlay
H="$TEST_ROOT/overlay-url"
setup_run "$H" "server\n\nfile://$OVERLAY_SRC\napply\n"
(( status == 0 )) || fail "setup con URL de overlay terminó con $status: $output"
[[ -d "$H/.dotfiles-private/.git" ]] || fail "setup no clonó el overlay en ~/.dotfiles-private"
[[ -L "$H/.config/overlay/ident" ]] || fail "setup no aplicó el overlay clonado"
grep -Fxq "OVERLAY=\"$H/.dotfiles-private\"" "$(receipt "$H" dotfiles)" || fail "el recibo no guardó el overlay clonado"

# 4. Dry-run and cancel change nothing (not even the overlay clone).
for final in dry-run cancel; do
  H="$TEST_ROOT/$final"
  setup_run "$H" "desktop\nbspwm\ndev walls\nfile://$OVERLAY_SRC\n$final\n"
  (( status == 0 )) || fail "setup $final terminó con $status: $output"
  [[ -z "$(find "$H" -mindepth 1 -print -quit)" ]] || fail "setup $final modificó el home: $(find "$H" -mindepth 1)"
done
setup_run "$TEST_ROOT/dry-run-plan" 'server\n\n\ndry-run\n'
[[ "$output" == *'dry-run'* && "$output" == *'Plan de la capa cli'* ]] || fail "dry-run no mostró el plan del bootstrap: $output"

# 5. Language: from LANG, unless --lang or DOTFILES_LANG says otherwise.
SETUP_LANG=es_PE.UTF-8 setup_run "$TEST_ROOT/lang-es" ''
[[ "$output" == *'Elige un perfil'* ]] || fail "LANG=es_PE.UTF-8 no dio prompts en español: $output"
SETUP_LANG=C setup_run "$TEST_ROOT/lang-c" ''
[[ "$output" == *'Choose a profile'* ]] || fail "LANG=C no dio prompts en inglés: $output"
SETUP_LANG=es_PE.UTF-8 setup_run "$TEST_ROOT/lang-flag" '' --lang en
[[ "$output" == *'Choose a profile'* ]] || fail "--lang en no ganó sobre LANG: $output"
status=0
output=$(env -u LC_ALL LANG=C DOTFILES_LANG=es HOME="$TEST_ROOT/lang-env" "$DOTFILES" setup --stow-only \
  --target "$TEST_ROOT/lang-env" < /dev/null 2>&1) || status=$?
[[ "$output" == *'Elige un perfil'* ]] || fail "DOTFILES_LANG=es no ganó sobre LANG: $output"

# 6. EOF on stdin takes every default, ends, and changes nothing.
H="$TEST_ROOT/eof"
make_overlay "$H/.dotfiles-private"
before=$(find "$H" | sort)
status=0
output=$(timeout 20 env LANG=C HOME="$H" "$DOTFILES" setup --stow-only --target "$H" < /dev/null 2>&1) || status=$?
(( status == 0 )) || fail "setup con EOF terminó con $status: $output"
[[ "$(find "$H" | sort)" == "$before" ]] || fail "setup con EOF modificó el home"
# Invalid answers are asked again, and EOF still ends the flow.
setup_run "$TEST_ROOT/invalid" 'nope\n42\n'
(( status == 0 )) || fail "setup con respuestas inválidas terminó con $status: $output"
[[ "$output" == *'Invalid'* ]] || fail "setup no rechazó una respuesta inválida: $output"
[[ -z "$(find "$TEST_ROOT/invalid" -mindepth 1 -print -quit)" ]] || fail "setup con respuestas inválidas modificó el home"

# 7. Extras are discovered: a new opt-in layer appears with its description,
# only where its requirements fit the profile (scratch copy of the repo).
SCRATCH="$TEST_ROOT/repo"
mkdir -p "$SCRATCH"
cp -a "$REPO_ROOT/bin" "$REPO_ROOT/lib" "$REPO_ROOT/layers" "$REPO_ROOT/packages" "$REPO_ROOT/themes" "$SCRATCH/"
mkdir -p "$SCRATCH/layers/gui-extra/packages/stow"
printf 'requires=desktop\nprofiles=gui-extra\ndescription=Fixture graphical extra\n' > "$SCRATCH/layers/gui-extra/layer.conf"
mkdir -p "$SCRATCH/layers/cli-extra"
printf 'requires=cli\nprofiles=cli-extra\nfeatures=cli-extra-feat\ndescription=Fixture terminal extra\ndescription.cli-extra-feat=Fixture feature\n' \
  > "$SCRATCH/layers/cli-extra/layer.conf"
SETUP_DOTFILES="$SCRATCH/bin/dotfiles" setup_run "$TEST_ROOT/discover-desktop" 'desktop\n\n\n\ncancel\n'
[[ "$output" == *'gui-extra'*'Fixture graphical extra'* ]] || fail "desktop no ofreció la capa nueva con su descripción: $output"
[[ "$output" == *'cli-extra-feat'*'Fixture feature'* ]] || fail "desktop no ofreció la feature nueva con su descripción: $output"
SETUP_DOTFILES="$SCRATCH/bin/dotfiles" setup_run "$TEST_ROOT/discover-server" 'server\n\n\ncancel\n'
[[ "$output" != *'gui-extra'* ]] || fail "server ofreció un extra que requiere desktop: $output"
[[ "$output" == *'cli-extra'*'Fixture terminal extra'* ]] || fail "server no ofreció el extra de terminal: $output"

# Selection options are asked by setup itself, so passing them is refused
# instead of being dropped silently; bootstrap is the non-interactive path.
for option in '--feature dev-js' '--layer dev' '--profile cli' '--wm bspwm' '--feature=dev-js'; do
  refused_home="$TEST_ROOT/refused-$RANDOM"
  mkdir -p "$refused_home"
  # shellcheck disable=SC2086 # each option is one flag and its value
  setup_run "$refused_home" 'server\n\n\napply\n' $option
  (( status == 2 )) || fail "setup $option no fue rechazado como error de uso (salida $status): $output"
  [[ "$output" == *bootstrap* ]] || fail "setup $option no remitió a bootstrap: $output"
  [[ -z "$(ls -A "$refused_home")" ]] || fail "setup $option modificó el target"
done

# 8. Help cleanup: bootstrap and completion documented, install removed.
for lang in en es; do
  output=$(DOTFILES_LANG=$lang "$DOTFILES" help)
  [[ "$output" == *'  bootstrap '* && "$output" == *'  completion '* ]] || fail "la ayuda ($lang) no documenta bootstrap y completion: $output"
  [[ "$output" != *'install'*'alias'* ]] || fail "la ayuda ($lang) documenta el alias install"
done
status=0
output=$("$DOTFILES" install < /dev/null 2>&1) || status=$?
(( status == 2 )) || fail "'dotfiles install' terminó con $status en vez de 2: $output"
"$DOTFILES" completion zsh | grep -q "'bootstrap:" || fail "la completion zsh no ofrece bootstrap"
"$DOTFILES" completion zsh | grep -q "'completion:" || fail "la completion zsh no ofrece completion"
if "$DOTFILES" completion bash | grep -qw install; then
  fail "la completion bash ofrece install"
fi

[[ "$(git -C "$REPO_ROOT" status --porcelain)" == "$CHECKOUT_STATE" ]] || fail "las pruebas modificaron el checkout"
echo "OK: dotfiles setup (perfil, WMs, extras, overlay, plan) validado"
