#!/usr/bin/env bash
# `dotfiles setup`: the short guided flow (profile, WMs, overlay, extras, then
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

# The desktop post-link applies prefer-dark through gsettings when the target
# is HOME; the fixture keeps it off the host dconf (as in bootstrap-smoke.sh).
FAKE_BIN="$TEST_ROOT/fake-bin"
mkdir -p "$FAKE_BIN"
ln -s "$SCRIPT_DIR/fakes/gsettings" "$FAKE_BIN/gsettings"
export PATH="$FAKE_BIN:$PATH"
export DOTFILES_TEST_GSETTINGS_STATE="$TEST_ROOT/gsettings.state"
export DOTFILES_TEST_GSETTINGS_LOG="$TEST_ROOT/gsettings.log"
: > "$DOTFILES_TEST_GSETTINGS_STATE"
: > "$DOTFILES_TEST_GSETTINGS_LOG"

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
[[ "$output" == *'Extras (optional, none selected by default)'* && "$output" == *'(Enter = none)'* ]] || \
  fail "sin recibo cambió la pregunta de extras: $output"
[[ "$output" != *'[x]'* && "$output" != *'[ ]'* && "$output" != *'Retiring:'* ]] || fail "sin recibo setup marcó o retiró algo: $output"

# 2. Desktop + bspwm + dev + dev-containers + walls, applied.
H="$TEST_ROOT/desktop"
setup_run "$H" 'desktop\nbspwm\n\ndev dev-containers walls\napply\n'
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
setup_run "$H" "server\nfile://$OVERLAY_SRC\n\napply\n"
(( status == 0 )) || fail "setup con URL de overlay terminó con $status: $output"
[[ -d "$H/.dotfiles-private/.git" ]] || fail "setup no clonó el overlay en ~/.dotfiles-private"
[[ -L "$H/.config/overlay/ident" ]] || fail "setup no aplicó el overlay clonado"
grep -Fxq "OVERLAY=\"$H/.dotfiles-private\"" "$(receipt "$H" dotfiles)" || fail "el recibo no guardó el overlay clonado"

# 3b. A target set up before starts from its receipt: Enter on every
# question keeps the whole selection, unchecking retires its links and the
# plan names them first.
retire_line() {
  grep -E "^  $1 +" <<< "$output" || true
}
expect_wizard_retired() {
  local label=$1 expected=$2 line count=0
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    [[ "$line" =~ ^\ \ $label\ +(.*)$ && "${BASH_REMATCH[1]}" == "$expected" ]] || \
      fail "el plan retira '$line' en vez de '$expected': $output"
    count=$(( count + 1 ))
  done <<< "$(retire_line "$label")"
  # Once in the setup plan and once in the bootstrap plan.
  (( count == 2 )) || fail "el plan no listó '$label $expected' en el plan de setup y en el del bootstrap: $output"
}
H="$TEST_ROOT/desktop"
R=$(receipt "$H" dotfiles)
selection_of() {
  grep -E '^(PROFILE|WMS|LAYERS|FEATURES|OVERLAY)=' "$1"
}
selection_before=$(selection_of "$R")
setup_run "$H" '\n\n\n\napply\n'
(( status == 0 )) || fail "setup con Enter sobre un recibo terminó con $status: $output"
[[ "$output" == *'Choose [desktop]'* ]] || fail "setup no propuso el perfil guardado: $output"
[[ "$output" == *'[x] bspwm'* && "$output" == *'[ ] mangowm'* ]] || fail "setup no marcó los WMs guardados: $output"
[[ "$output" == *'[x] dev '* && "$output" == *'[x] dev-containers'* && "$output" == *'[x] walls'* && "$output" == *'[ ] dev-js'* ]] || \
  fail "setup no marcó los extras guardados: $output"
[[ "$output" == *'Extras (optional, the current selection is marked)'* ]] || fail "la pregunta de extras no indica la preselección: $output"
[[ "$output" == *'Enter = keep the marked ones, - = none'* ]] || fail "setup no explica cómo conservar o vaciar la preselección: $output"
[[ -z "$(retire_line 'Retiring:')" ]] || fail "Enter en todas las preguntas retiró algo: $output"
[[ "$(selection_of "$R")" == "$selection_before" ]] || fail "Enter en todas las preguntas cambió la selección: $(<"$R")"
grep -qx 'COMPONENTS="walls"' "$(receipt "$H" components)" || fail "Enter en todas las preguntas perdió walls"
[[ -L "$H/.config/bspwm/bspwmrc" && -L "$H/.local/share/wallpapers" ]] || fail "Enter en todas las preguntas retiró enlaces"
dev_link="$H/.config/zsh/conf.d/50-dev.zsh"
[[ -L "$dev_link" ]] || fail "la capa dev no estaba enlazada"

# Unchecking dev and dev-containers: the dry-run names them and changes nothing.
setup_run "$H" '\n\n\nwalls\ndry-run\n'
(( status == 0 )) || fail "setup dry-run desmarcando dev terminó con $status: $output"
expect_wizard_retired 'Retiring:' 'dev dev-containers'
[[ -L "$dev_link" && "$(selection_of "$R")" == "$selection_before" ]] || fail "el dry-run de setup retiró algo"

# Applied (in Spanish), the links of dev go and the receipt forgets them.
SETUP_LANG=es_PE.UTF-8 setup_run "$H" '\n\n\nwalls\napply\n'
(( status == 0 )) || fail "setup desmarcando dev terminó con $status: $output"
expect_wizard_retired 'Se retiran:' 'dev dev-containers'
[[ ! -e "$dev_link" && ! -L "$dev_link" ]] || fail "setup no retiró los enlaces de la capa dev"
grep -qx 'LAYERS=""' "$R" || fail "el recibo conserva la capa dev: $(<"$R")"
grep -qx 'FEATURES=""' "$R" || fail "el recibo conserva dev-containers: $(<"$R")"
[[ -L "$H/.local/share/wallpapers" && -L "$H/.config/bspwm/bspwmrc" ]] || fail "desmarcar dev retiró walls o bspwm"

# "-" clears the extras: the component is unlinked and forgotten, its checkout kept.
setup_run "$H" '\n\n\n-\napply\n'
(( status == 0 )) || fail "setup vaciando los extras terminó con $status: $output"
expect_wizard_retired 'Retiring:' 'walls'
[[ ! -L "$H/.local/share/wallpapers" ]] || fail "setup no retiró el enlace de walls"
[[ ! -e "$(receipt "$H" components)" ]] || fail "el recibo de componentes conserva walls"
[[ -d "$H/.local/share/dotfiles/walls" ]] || fail "retirar walls borró su checkout"

# Unchecking the WM retires its layer.
setup_run "$H" '\n-\n\n\napply\n'
(( status == 0 )) || fail "setup desmarcando bspwm terminó con $status: $output"
expect_wizard_retired 'Retiring:' 'bspwm'
[[ ! -L "$H/.config/bspwm/bspwmrc" ]] || fail "setup no retiró bspwm"
grep -qx 'WMS=""' "$R" || fail "el recibo conserva bspwm: $(<"$R")"

# The recorded overlay: Enter keeps it, n drops it and retires its layers.
H="$TEST_ROOT/overlay-detected"
setup_run "$H" '\n\n\napply\n'
(( status == 0 )) || fail "setup con Enter sobre el overlay terminó con $status: $output"
[[ "$output" == *'Choose [server]'* ]] || fail "setup no propuso el perfil server guardado: $output"
[[ -z "$(retire_line 'Retiring:')" && -L "$H/.config/overlay/ident" ]] || fail "Enter no conservó el overlay: $output"
setup_run "$H" '\nn\n\napply\n'
(( status == 0 )) || fail "setup sin el overlay terminó con $status: $output"
expect_wizard_retired 'Retiring:' 'ident'
[[ ! -L "$H/.config/overlay/ident" ]] || fail "setup no retiró la capa del overlay descartado"
grep -qx 'OVERLAY=""' "$(receipt "$H" dotfiles)" || fail "el recibo conserva el overlay descartado"

# The recorded overlay's features are extras too: the overlay is asked before
# the extras, so Enter keeps them marked, and unchecking one retires only it.
H="$TEST_ROOT/overlay-features"
OVERLAY_FEAT="$TEST_ROOT/overlay-feat"
make_overlay "$OVERLAY_FEAT"
printf 'features=work play\ndescription.work=Fixture work identity\n' >> "$OVERLAY_FEAT/layers/ident/layer.conf"
for feature in work play; do
  mkdir -p "$OVERLAY_FEAT/layers/ident/home/$feature/.config/overlay"
  printf '%s\n' "$feature" > "$OVERLAY_FEAT/layers/ident/packages/stow/$feature.txt"
  printf '%s\n' "$feature" > "$OVERLAY_FEAT/layers/ident/home/$feature/.config/overlay/$feature"
done
mkdir -p "$H"
HOME="$H" "$DOTFILES" bootstrap --stow-only --target "$H" --profile cli --overlay "$OVERLAY_FEAT" \
  --feature work --feature play --apply >/dev/null 2>&1 || fail "no se pudo preparar el overlay con features"
R=$(receipt "$H" dotfiles)
grep -qx 'FEATURES="work play"' "$R" || fail "el recibo no guardó las features del overlay: $(<"$R")"
selection_before=$(selection_of "$R")
setup_run "$H" '\n\n\napply\n'
(( status == 0 )) || fail "setup con Enter sobre features del overlay terminó con $status: $output"
[[ "$output" == *'[x] work - Fixture work identity'* && "$output" == *'[x] play'* ]] || \
  fail "setup no ofreció marcadas las features del overlay: $output"
[[ -z "$(retire_line 'Retiring:')" ]] || fail "Enter en todas las preguntas retiró una feature del overlay: $output"
[[ -L "$H/.config/overlay/work" && -L "$H/.config/overlay/play" ]] || fail "Enter retiró el enlace de una feature del overlay"
[[ "$(selection_of "$R")" == "$selection_before" ]] || fail "Enter cambió la selección con features del overlay: $(<"$R")"
setup_run "$H" '\n\nplay\napply\n'
(( status == 0 )) || fail "setup desmarcando work terminó con $status: $output"
expect_wizard_retired 'Retiring:' 'work'
[[ ! -L "$H/.config/overlay/work" ]] || fail "setup no retiró el enlace de la feature work"
[[ -L "$H/.config/overlay/play" && -L "$H/.config/overlay/ident" ]] || fail "desmarcar work retiró play o la capa del overlay"
grep -qx 'FEATURES="play"' "$R" || fail "el recibo conserva la feature work: $(<"$R")"

# 4. Dry-run and cancel change nothing (not even the overlay clone).
for final in dry-run cancel; do
  H="$TEST_ROOT/$final"
  setup_run "$H" "desktop\nbspwm\nfile://$OVERLAY_SRC\ndev walls\n$final\n"
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

# 9. An old install on the target: setup offers to migrate it with the
# switch logic before the four questions. The checkout is a copy with the
# overlay next to it, so nothing comes from the real machine.
# shellcheck source=SCRIPTDIR/lib/legacy-home.sh
source "$SCRIPT_DIR/lib/legacy-home.sh"
MIG="$TEST_ROOT/mig/dotfiles"
copy_checkout "$MIG"
make_legacy_overlay "$TEST_ROOT/mig/dotfiles-private"
MIG_STATE=$(hash_tree "$MIG")

# Runs setup from the copy on a fresh legacy home $1 with stdin $2 and the
# remaining setup options; H, LEGACY and the hashes before the run
# ($home_before, $legacy_before) are left set.
migrate_run() {
  local name=$1 input=$2
  shift 2
  new_legacy_home "$name"
  home_before=$(hash_tree "$H")
  legacy_before=$(hash_tree "$LEGACY")
  SETUP_DOTFILES="${MIGRATE_DOTFILES:-$MIG/bin/dotfiles}" setup_run "$H" "$input" "$@"
}

# 9a. The summary names what was found and one question comes first;
# cancel changes nothing. In Spanish with a Spanish LANG.
migrate_run migrate-cancel 'cancel\n'
(( status == 0 )) || fail "setup con una instalación anterior y cancel terminó con $status: $output"
[[ "$(hash_tree "$H")" == "$home_before" ]] || fail "cancel en la migración modificó el target"
# shellcheck disable=SC2088 # the tilde is the literal text the summary prints
for expected in 'Previous install detected' '~/.dotfiles (previous ecosystem)' 'Profile:'*'desktop' \
  'WMs:'*'mangowm' 'Extras:'*'dev work-csti walls' 'Overlay:'*'dotfiles-private' 'Links to replace:      11' \
  'Not migrated:'*'agent-harness' 'migrate'*'continue'*'cancel' 'Setup cancelled'; do
  # shellcheck disable=SC2053 # the expectations are glob patterns
  [[ "$output" == *$expected* ]] || fail "el resumen de la migración no muestra '$expected': $output"
done
[[ "$output" != *'Choose a profile'* ]] || fail "cancel en la migración siguió con las preguntas: $output"
SETUP_LANG=es_ES.UTF-8 migrate_run migrate-es 'cancel\n'
[[ "$output" == *'Instalación anterior detectada'*'Enlaces a reemplazar:'*'Migrarla'* ]] || \
  fail "el resumen de la migración no sigue a LANG: $output"

# 9b. Migrate + apply: the switch moves the selection to this checkout, the
# wizard ends (no questions) and says how to undo it.
migrate_run migrate-apply 'migrate\napply\n'
(( status == 0 )) || fail "migrar + apply terminó con $status: $output"
[[ "$(hash_tree "$LEGACY")" == "$legacy_before" ]] || fail "la migración modificó el checkout anterior"
receipt_file=$(receipt "$H" dotfiles)
for line in 'PROFILE="desktop"' 'WMS="mangowm"' 'LAYERS="dev"' 'FEATURES="work-csti"' "OVERLAY=\"$TEST_ROOT/mig/dotfiles-private\""; do
  grep -Fxq "$line" "$receipt_file" || fail "la migración no registró $line: $(<"$receipt_file")"
done
[[ "$(realpath -- "$H/.config/mango/config.conf")" == "$MIG/layers/wm/mangowm/home/"* ]] || fail "la migración no enlazó MangoWM al checkout"
[[ "$(realpath -- "$H/.local/bin/dotfiles")" == "$MIG/bin/dotfiles" ]] || fail "el comando dotfiles no apunta al checkout migrado"
[[ "$(realpath -- "$H/.zshrc")" == "$MIG/"* ]] || fail "quedó un enlace de base hacia el checkout anterior"
[[ -f "$H/.local/state/dotfiles/transactions/switch-last/manifest" ]] || fail "la migración no dejó el manifiesto de reversión"
[[ "$output" == *'dotfiles switch --rollback --apply'* ]] || fail "la migración no explicó cómo deshacerla: $output"
[[ "$output" != *'Choose a profile'* ]] || fail "tras migrar el wizard repitió las preguntas: $output"
# The next setup starts from the migrated receipt and offers nothing.
SETUP_DOTFILES="$MIG/bin/dotfiles" setup_run "$H" 'cancel\n'
[[ "$output" != *'Previous install detected'* ]] || fail "setup volvió a ofrecer la migración ya hecha: $output"
[[ "$output" == *'[x] mangowm'* ]] || fail "tras migrar setup no partió del recibo: $output"

# 9c. Migrate + dry-run and migrate + cancel change nothing.
migrate_run migrate-dry 'migrate\ndry-run\n'
(( status == 0 )) || fail "migrar + dry-run terminó con $status: $output"
[[ "$(hash_tree "$H")" == "$home_before" ]] || fail "migrar + dry-run modificó el target"
[[ "$output" == *'Plan del cambio de checkout'*'sin colisiones'* ]] || fail "el dry-run de la migración no mostró el plan y el preflight: $output"
[[ "$output" == *'Dry-run: nothing changed'* ]] || fail "el dry-run de la migración no dijo que nada cambió: $output"
# Inside setup only the wizard's own hint: never the switch's --apply one.
[[ "$output" != *'use --apply'* && "$(grep -c 'Dry-run:' <<< "$output")" == 1 ]] || \
  fail "el dry-run de la migración mostró más de una indicación o la de --apply: $output"
migrate_run migrate-plan-cancel 'migrate\ncancel\n'
(( status == 0 )) || fail "migrar + cancel terminó con $status: $output"
[[ "$(hash_tree "$H")" == "$home_before" ]] || fail "migrar + cancel modificó el target"
[[ "$output" == *'Plan del cambio de checkout'*'apply'*'dry-run'*'cancel'*'Setup cancelled'* ]] || \
  fail "migrar no mostró el plan antes de apply / dry-run / cancel: $output"

# 9d. Continue without migrating: today's four questions, same output as on
# a home without an old install, after the summary.
migrate_run migrate-continue 'continue\nserver\n\n\ncancel\n'
continue_output=$output
(( status == 0 )) || fail "continuar sin migrar terminó con $status: $output"
[[ "$(hash_tree "$H")" == "$home_before" ]] || fail "continuar sin migrar + cancel modificó el target"
SETUP_DOTFILES="$MIG/bin/dotfiles" setup_run "$TEST_ROOT/migrate-fresh" 'server\n\n\ncancel\n'
[[ "${continue_output%%$'\n'*}" == "${output%%$'\n'*}" && "$continue_output" == *"${output#*$'\n'}" ]] || \
  fail "continuar sin migrar no siguió el flujo de siempre: $continue_output"

# 9e. Nothing foreign: no summary, the profile question comes right after
# the header (as before), on a fresh home and on one already on the checkout.
[[ "$output" != *'Previous install detected'* ]] || fail "un home nuevo mostró el resumen de migración: $output"
second=$(sed -n 2,3p <<< "$output")
[[ "$second" == $'\nChoose a profile' ]] || fail "un home nuevo no empieza por el perfil: $output"
SETUP_DOTFILES="$MIG/bin/dotfiles" setup_run "$TEST_ROOT/migrate-fresh" 'server\n\n\napply\n'
(( status == 0 )) || fail "setup server en el home nuevo terminó con $status: $output"
SETUP_DOTFILES="$MIG/bin/dotfiles" setup_run "$TEST_ROOT/migrate-fresh" 'cancel\n'
[[ "$output" != *'Previous install detected'* && "$(sed -n 3p <<< "$output")" == 'Choose a profile' ]] || \
  fail "un home ya en este checkout mostró el resumen de migración: $output"

# 9f. End of input on the question cancels and changes nothing.
migrate_run migrate-eof ''
(( status == 0 )) || fail "EOF en la migración terminó con $status: $output"
[[ "$(hash_tree "$H")" == "$home_before" ]] || fail "EOF en la migración modificó el target"
[[ "$output" == *'Setup cancelled'* && "$output" != *'Choose a profile'* ]] || fail "EOF en la migración no canceló: $output"

# 9g. A failed migration shows the switch's own rollback and setup fails.
BROKEN="$TEST_ROOT/broken/dotfiles"
copy_checkout "$BROKEN"
printf '#!/usr/bin/env bash\nexit 1\n' > "$BROKEN/layers/wm/mangowm/hooks/post-link"
MIGRATE_DOTFILES="$BROKEN/bin/dotfiles" migrate_run migrate-fail 'migrate\napply\n'
(( status != 0 )) || fail "una migración fallida no hizo fallar setup: $output"
[[ "$output" == *'se restauró el estado anterior'* ]] || fail "la migración fallida no mostró la reversión del switch: $output"
[[ "$(hash_tree "$H")" == "$home_before" ]] || fail "la migración fallida no dejó el target como estaba"
[[ "$(hash_tree "$MIG")" == "$MIG_STATE" ]] || fail "la migración modificó el checkout copiado"
[[ "$(DOTFILES_LANG=en "$DOTFILES" help)" == *'offers to migrate'*'switch logic'* ]] || fail "la ayuda (en) no documenta la migración de setup"
[[ "$(DOTFILES_LANG=es "$DOTFILES" help)" == *'ofrece antes migrarla'*'lógica de switch'* ]] || fail "la ayuda (es) no documenta la migración de setup"

# 9h. An explicit --overlay or --no-overlay of setup carries into the
# migration summary and the switch plan.
OTHER_OVERLAY="$TEST_ROOT/mig/other-private"
make_legacy_overlay "$OTHER_OVERLAY"
migrate_run migrate-overlay 'migrate\ncancel\n' --overlay "$OTHER_OVERLAY"
(( status == 0 )) || fail "migrar con --overlay + cancel terminó con $status: $output"
[[ "$output" == *'Overlay:'*'other-private'*"Overlay:                 $OTHER_OVERLAY (--overlay)"* ]] || \
  fail "el --overlay de setup no llegó al resumen y al plan de la migración: $output"
migrate_run migrate-no-overlay 'migrate\ncancel\n' --no-overlay
(( status == 0 )) || fail "migrar con --no-overlay + cancel terminó con $status: $output"
[[ "$output" == *'Overlay:'*'none'*'Overlay:                 ninguno (--no-overlay)'* ]] || \
  fail "el --no-overlay de setup no llegó al resumen y al plan de la migración: $output"

# 9i. An old install that cannot be prepared (here a bad --overlay) is not
# skipped silently: setup shows the switch's error and asks continue or
# cancel (the default); continue runs today's questions.
migrate_run migrate-bad-overlay 'cancel\n' --overlay "$TEST_ROOT/no-such-overlay"
(( status == 0 )) || fail "setup con un --overlay inválido y cancel terminó con $status: $output"
[[ "$(hash_tree "$H")" == "$home_before" ]] || fail "cancel tras el aviso de migración modificó el target"
[[ "$output" == *'cannot be migrated'*"el overlay no contiene layers/: $TEST_ROOT/no-such-overlay"*'continue'*'cancel'*'Setup cancelled'* ]] || \
  fail "setup no explicó por qué no puede migrar con un --overlay inválido: $output"
[[ "$output" != *'Choose a profile'* && "$output" != *'rollback'* ]] || fail "el aviso de migración siguió con las preguntas u ofreció rollback: $output"

# A home linked to another monorepo checkout without its selection receipt.
OLD_CO="$TEST_ROOT/mig/old-dotfiles"
copy_checkout "$OLD_CO"
H="$TEST_ROOT/migrate-no-receipt"
mkdir -p "$H"
HOME="$H" "$OLD_CO/bin/dotfiles" bootstrap --profile cli --stow-only --target "$H" --apply >/dev/null 2>&1 || \
  fail "el bootstrap del checkout viejo falló"
rm -f -- "$(receipt "$H" dotfiles)"
home_before=$(hash_tree "$H")
SETUP_DOTFILES="$MIG/bin/dotfiles" setup_run "$H" ''
(( status == 0 )) || fail "EOF tras el aviso de migración terminó con $status: $output"
[[ "$(hash_tree "$H")" == "$home_before" ]] || fail "EOF tras el aviso de migración modificó el target"
[[ "$output" == *'cannot be migrated'*'no hay recibo de selección'*'Setup cancelled'* && "$output" != *'Choose a profile'* ]] || \
  fail "setup no avisó del checkout sin recibo o no canceló con EOF: $output"
SETUP_DOTFILES="$MIG/bin/dotfiles" setup_run "$H" 'continue\nserver\n\n\ncancel\n'
(( status == 0 )) || fail "continuar tras el aviso de migración terminó con $status: $output"
[[ "$output" == *'no hay recibo de selección'*'Choose a profile'*'Setup cancelled'* ]] || \
  fail "continuar tras el aviso de migración no siguió con las preguntas: $output"

# 9j. A change left unfinished (its manifest written) is named before
# anything else, with rollback offered by setup itself: its plan first, then
# apply or cancel; applied, the home is back as before that change.
migrate_run migrate-pending 'migrate\napply\n'
(( status == 0 )) || fail "migrar + apply (para el cambio sin cerrar) terminó con $status: $output"
txns="$H/.local/state/dotfiles/transactions"
mv -T -- "$txns/switch-last" "$txns/switch.pending"
after_migration=$(hash_tree "$H")
SETUP_DOTFILES="$MIG/bin/dotfiles" setup_run "$H" 'cancel\n'
(( status == 0 )) || fail "cancel ante un cambio sin cerrar terminó con $status: $output"
[[ "$(hash_tree "$H")" == "$after_migration" ]] || fail "cancel ante un cambio sin cerrar modificó el target"
[[ "$output" == *'unfinished change'*"sin cerrar en $txns/switch.pending"*'rollback'*'continue'*'cancel'*'Setup cancelled'* ]] || \
  fail "setup no avisó del cambio sin cerrar ni ofreció rollback: $output"
[[ "$output" != *'Choose a profile'* ]] || fail "cancel ante un cambio sin cerrar siguió con las preguntas: $output"
SETUP_DOTFILES="$MIG/bin/dotfiles" setup_run "$H" 'rollback\ncancel\n'
(( status == 0 )) || fail "rollback + cancel terminó con $status: $output"
[[ "$(hash_tree "$H")" == "$after_migration" ]] || fail "rollback + cancel modificó el target"
[[ "$output" == *'Plan de la reversión'*"$txns/switch.pending/manifest"*'apply'*'cancel'*'Setup cancelled'* ]] || \
  fail "rollback no mostró su plan antes de apply / cancel: $output"
[[ "$output" != *'use --apply'* ]] || fail "el plan de rollback en setup mostró la indicación de --apply: $output"
SETUP_DOTFILES="$MIG/bin/dotfiles" setup_run "$H" 'rollback\napply\n'
(( status == 0 )) || fail "rollback + apply terminó con $status: $output"
[[ "$output" == *'Se restauró el estado anterior'*'Run setup again'* && "$output" != *'Choose a profile'* ]] || \
  fail "rollback + apply no restauró ni terminó setup: $output"
[[ "$(readlink -- "$H/.zshrc")" == *.dotfiles/base/home/zsh/.zshrc ]] || fail "rollback no devolvió los enlaces del checkout anterior"
[[ ! -e "$txns/switch.pending" ]] || fail "rollback dejó el cambio sin cerrar pendiente"
[[ "$(hash_tree "$LEGACY")" == "$legacy_before" ]] || fail "rollback modificó el checkout anterior"
# Afterwards setup offers the migration again.
SETUP_DOTFILES="$MIG/bin/dotfiles" setup_run "$H" 'cancel\n'
[[ "$output" == *'Previous install detected'* && "$output" != *'unfinished change'* ]] || \
  fail "tras el rollback setup no volvió a ofrecer la migración: $output"

# Migrate + apply discards a change stopped before its manifest (it changed
# nothing), as switch --apply does, and migrates.
new_legacy_home migrate-stale
mkdir -p "$H/.local/state/dotfiles/transactions/switch.pending/files"
SETUP_DOTFILES="$MIG/bin/dotfiles" setup_run "$H" 'migrate\napply\n'
(( status == 0 )) || fail "migrar con un cambio sin manifiesto terminó con $status: $output"
[[ "$output" == *'se descartó'* && ! -e "$H/.local/state/dotfiles/transactions/switch.pending" ]] || \
  fail "migrar no descartó el cambio sin manifiesto: $output"

[[ "$(git -C "$REPO_ROOT" status --porcelain)" == "$CHECKOUT_STATE" ]] || fail "las pruebas modificaron el checkout"
echo "OK: dotfiles setup (perfil, WMs, overlay, extras, plan) validado"
