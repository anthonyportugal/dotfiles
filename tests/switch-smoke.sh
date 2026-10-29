#!/usr/bin/env bash
# dotfiles switch: moving a home from the pre-monorepo ecosystem under
# ~/.dotfiles (base, wm/<x>, private, walls, agent-harness, system) or from
# another monorepo checkout to a new checkout, with a collision check before
# anything changes, a manifest and a rollback that leaves the target
# byte-identical. Every run uses homes and checkouts in mktemp, --stow-only,
# a local walls fixture and the gsettings fake; never the network or the
# real home.

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
export DOTFILES_LANG=es
TEST_ROOT=""
TEST_TMP_PARENT=${DOTFILES_TEST_TMPDIR:-/tmp}

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  [[ -n "$TEST_ROOT" && "$TEST_ROOT" == "$TEST_TMP_PARENT"/dotfiles-switch-smoke.* ]] || return 0
  rm -rf -- "$TEST_ROOT"
}

trap cleanup EXIT

command -v stow >/dev/null 2>&1 || fail "GNU Stow es necesario para este smoke test"
command -v git >/dev/null 2>&1 || fail "git es necesario para este smoke test"
TEST_ROOT=$(mktemp -d "$TEST_TMP_PARENT/dotfiles-switch-smoke.XXXXXX")
TEST_ROOT=$(realpath -e -- "$TEST_ROOT")
CHECKOUT_STATE=$(git -C "$REPO_ROOT" status --porcelain)

# The desktop post-link applies prefer-dark through gsettings when the target
# is HOME; the fixture keeps it off the host dconf.
FAKE_BIN="$TEST_ROOT/fake-bin"
mkdir -p "$FAKE_BIN"
ln -s "$SCRIPT_DIR/fakes/gsettings" "$FAKE_BIN/gsettings"
export PATH="$FAKE_BIN:$PATH"
export DOTFILES_TEST_GSETTINGS_STATE="$TEST_ROOT/gsettings.state"
export DOTFILES_TEST_GSETTINGS_LOG="$TEST_ROOT/gsettings.log"
: > "$DOTFILES_TEST_GSETTINGS_STATE"
: > "$DOTFILES_TEST_GSETTINGS_LOG"

# Copies the engine and layers of this checkout to $1, so a sibling overlay
# never comes from the real machine and a checkout can be broken on purpose.
copy_checkout() {
  mkdir -p "$1"
  cp -a "$REPO_ROOT"/{bin,lib,layers,themes,packages,components.conf} "$1/"
}

NEW="$TEST_ROOT/new/dotfiles"
copy_checkout "$NEW"
NEW_STATE=$(cd "$NEW" && find . -printf '%y %p %l\n' | LC_ALL=C sort; find "$NEW" -type f -exec sha256sum {} + | LC_ALL=C sort)

# The overlay next to the new checkout: identity (requires core, feature
# work-csti) and dev-personal (requires the public dev layer).
OVERLAY="$TEST_ROOT/new/dotfiles-private"
make_overlay_package() {
  local layer=$1 package=$2 rel=$3
  mkdir -p "$OVERLAY/layers/$layer/home/$package/${rel%/*}"
  printf '%s\n' "$package" > "$OVERLAY/layers/$layer/home/$package/$rel"
  : > "$OVERLAY/layers/$layer/home/.stow"
}
make_overlay_package identity git-private .config/git/private.conf
make_overlay_package identity work-csti .config/git/work-csti.conf
make_overlay_package dev-personal gh .config/gh/hosts.yml
mkdir -p "$OVERLAY/layers/identity/packages/stow" "$OVERLAY/layers/dev-personal/packages/stow"
printf '%s\n' requires=core profiles=identity features=work-csti > "$OVERLAY/layers/identity/layer.conf"
printf 'git-private\n' > "$OVERLAY/layers/identity/packages/stow/identity.txt"
printf 'work-csti\n' > "$OVERLAY/layers/identity/packages/stow/work-csti.txt"
printf '%s\n' requires=dev profiles=dev-personal > "$OVERLAY/layers/dev-personal/layer.conf"
printf 'gh\n' > "$OVERLAY/layers/dev-personal/packages/stow/dev-personal.txt"

# walls: a local component repository pinned in a components.conf of its own.
WALLS_REPO="$TEST_ROOT/walls-upstream"
mkdir -p "$WALLS_REPO/wallpapers" "$WALLS_REPO/bin"
printf 'jpg\n' > "$WALLS_REPO/wallpapers/a.jpg"
printf '#!/bin/sh\n' > "$WALLS_REPO/bin/walls"
git -C "$WALLS_REPO" init -q
git -C "$WALLS_REPO" add -A
git -C "$WALLS_REPO" -c user.name=t -c user.email=t@t -c commit.gpgsign=false commit -qm walls
WALLS_REF=$(git -C "$WALLS_REPO" rev-parse HEAD)
export DOTFILES_COMPONENTS_FILE="$TEST_ROOT/components.conf"
printf 'walls file://%s %s wallpapers=.local/share/wallpapers bin/walls=.local/bin/walls -- Wallpapers\n' \
  "$WALLS_REPO" "$WALLS_REF" > "$DOTFILES_COMPONENTS_FILE"

H=""
LEGACY=""
output=""
status=0

# Prints every entry of $1 (type, path, link value) and the hash of every
# regular file, so two calls differ when anything under $1 changed.
hash_tree() {
  (cd "$1" && find . -printf '%y %p %l\n' | LC_ALL=C sort
   find . -type f -exec sha256sum {} + | LC_ALL=C sort) | sha256sum
}

# Old Stow package $2 of old repository $1 (under $LEGACY) owning $3.
old_package() {
  mkdir -p "$LEGACY/$1/home/$2/$(dirname -- "$3")"
  printf 'old %s\n' "$2" > "$LEGACY/$1/home/$2/$3"
}

# A home with the pre-monorepo ecosystem as this machine has it: base, a
# MangoWM install with its theme, private (development + csti), walls and
# the independent agent-harness, all applied with GNU Stow or absolute links.
new_legacy_home() {
  H="$TEST_ROOT/$1"
  LEGACY="$H/.dotfiles"
  mkdir -p "$H"
  old_package base zsh .zshrc
  old_package base bat .config/bat/config
  old_package base bat .config/bat/themes/old-only.tmTheme
  old_package base xdg-defaults .config/gtk-3.0/settings.ini
  old_package base xdg-defaults .config/mimeapps.list
  printf '[Default Applications]\nx-scheme-handler/foo=foo.desktop\n' > "$LEGACY/base/home/xdg-defaults/.config/mimeapps.list"
  mkdir -p "$LEGACY/base/bin"
  printf '#!/bin/sh\n' > "$LEGACY/base/bin/dotfiles"
  chmod +x "$LEGACY/base/bin/dotfiles"
  old_package wm/mangowm mango .config/mango/config.conf
  old_package wm/bspwm bspwm .config/bspwm/bspwmrc
  old_package private git-private .config/git/private.conf
  old_package private zsh-development .config/zsh/conf.d/90-development.zsh
  mkdir -p "$LEGACY/walls/wallpapers" "$LEGACY/walls/bin" "$LEGACY/agent-harness/bin" "$LEGACY/system"
  printf 'jpg\n' > "$LEGACY/walls/wallpapers/a.jpg"
  printf '#!/bin/sh\n' > "$LEGACY/walls/bin/walls"
  printf '#!/bin/sh\n' > "$LEGACY/agent-harness/bin/agent"
  printf '#!/bin/sh\n' > "$LEGACY/system/install.sh"

  stow -d "$LEGACY/base/home" -t "$H" --no-folding zsh bat xdg-defaults
  stow -d "$LEGACY/wm/mangowm/home" -t "$H" --no-folding mango
  stow -d "$LEGACY/private/home" -t "$H" --no-folding git-private zsh-development
  mkdir -p "$H/.local/bin" "$H/.local/share"
  ln -s "$LEGACY/base/bin/dotfiles" "$H/.local/bin/dotfiles"
  ln -s "$LEGACY/walls/bin/walls" "$H/.local/bin/walls"
  ln -s "$LEGACY/walls/wallpapers" "$H/.local/share/wallpapers"
  ln -s "$LEGACY/agent-harness/bin/agent" "$H/.local/bin/agent"

  local state="$H/.local/state"
  mkdir -p "$state/dotfiles/theme" "$state/mangowm/theme"
  printf 'RECEIPT_VERSION=1\nCOMPONENT="mangowm"\nPROFILE="desktop"\nBACKEND="pacman"\n' > "$state/dotfiles/mangowm.receipt"
  printf 'RECEIPT_VERSION=1\nCOMPONENT="private"\nPROFILE="development"\nWORK="csti"\nBACKEND="pacman"\n' > "$state/dotfiles/private.receipt"
  printf 'RECEIPT_VERSION=1\nCOMPONENT="agent-harness"\nTARGET="all"\n' > "$state/dotfiles/agent-harness.receipt"
  printf 'catppuccin-mocha-mauve\n' > "$state/mangowm/theme/selected"
  ln -s ../../mangowm/theme/current "$state/dotfiles/theme/current"
}

# Runs `switch $@` with checkout bin/dotfiles $DOTFILES_BIN on the current
# home; output in $output, exit status in $status.
DOTFILES_BIN="$REPO_ROOT/bin/dotfiles"
run_switch() {
  status=0
  output=$(HOME="$H" "$DOTFILES_BIN" switch --target "$H" "$@" 2>&1) || status=$?
}

# Prints the links under $H that resolve into directory $1.
links_into() {
  local link
  while IFS= read -r -d '' link; do
    [[ "$(realpath -m -- "$link")" == "$1"/* ]] && printf '%s\n' "${link#"$H"/}"
  done < <(find "$H" -path "$LEGACY" -prune -o -type l -print0)
  return 0
}

# 1. Plan only: the plan translates the old selection and nothing changes.
new_legacy_home plan
before=$(hash_tree "$H")
run_switch "$NEW"
(( status == 0 )) || fail "el plan de switch terminó con $status: $output"
[[ "$(hash_tree "$H")" == "$before" ]] || fail "switch sin --apply modificó el target"
for expected in 'Perfil: +desktop' 'WMs: +mangowm' 'Capas opcionales: +dev' 'Features: +work-csti' \
  "Overlay: +$OVERLAY \\(checkout hermano\\)" 'Componentes nuevos: +walls' 'Tema: +catppuccin-mocha-mauve \(de mangowm\)' \
  'mimeapps.list: +se conservan' 'Recibos migrados: +private' 'No migrado: +agent-harness' 'No migrado: +system' \
  'Preflight del checkout nuevo: sin colisiones' 'Dry-run: nada cambió'; do
  grep -Eq "$expected" <<< "$output" || fail "el plan no muestra '$expected': $output"
done
grep -q 'bspwm' <<< "$(grep -E '^  WMs:' <<< "$output")" && fail "el plan migra bspwm, que no estaba instalado: $output"

# 2. Apply migrates profile, WMs, overlay, walls, theme and mimeapps; the old
# checkout is never modified and only its replaced repositories lose links.
new_legacy_home apply
legacy_before=$(hash_tree "$LEGACY")
home_before=$(hash_tree "$H")
run_switch "$NEW" --apply
(( status == 0 )) || fail "switch --apply terminó con $status: $output"
[[ "$(hash_tree "$LEGACY")" == "$legacy_before" ]] || fail "switch modificó el checkout anterior"
for repo in base private walls wm/mangowm; do
  leftover=$(links_into "$LEGACY/$repo")
  [[ -z "$leftover" ]] || fail "quedaron enlaces hacia $repo: $leftover"
done
[[ "$(readlink -- "$H/.local/bin/agent")" == "$LEGACY/agent-harness/bin/agent" ]] || fail "switch tocó el enlace de agent-harness"
receipt="$H/.local/state/dotfiles/dotfiles.receipt"
for line in 'PROFILE="desktop"' 'WMS="mangowm"' 'LAYERS="dev"' 'FEATURES="work-csti"' "OVERLAY=\"$OVERLAY\""; do
  grep -Fxq "$line" "$receipt" || fail "el recibo de selección no tiene $line: $(<"$receipt")"
done
[[ "$(realpath -- "$H/.local/bin/dotfiles")" == "$NEW/bin/dotfiles" ]] || fail "el comando dotfiles no apunta al checkout nuevo"
[[ "$(realpath -- "$H/.config/mango/config.conf")" == "$NEW/layers/wm/mangowm/home/"* ]] || fail "MangoWM no quedó enlazado al checkout nuevo"
[[ "$(realpath -- "$H/.config/git/work-csti.conf")" == "$OVERLAY/"* ]] || fail "la feature work-csti del overlay no se aplicó"
[[ "$(realpath -- "$H/.config/gh/hosts.yml")" == "$OVERLAY/"* ]] || fail "la capa dev-personal del overlay no se aplicó"
[[ -L "$H/.config/zsh/conf.d/50-dev.zsh" ]] || fail "el perfil privado development no aplicó la capa dev"
grep -Fxq 'COMPONENTS="walls"' "$H/.local/state/dotfiles/components.receipt" || fail "walls no quedó registrado como componente"
[[ "$(readlink -- "$H/.local/share/wallpapers")" == "$H/.local/share/dotfiles/walls/wallpapers" ]] || fail "los wallpapers no apuntan al componente walls"
[[ "$(<"$H/.local/state/dotfiles/theme/selected")" == catppuccin-mocha-mauve ]] || fail "el tema de MangoWM no se migró"
grep -Fxq 'id=catppuccin-mocha-mauve' "$H/.local/state/dotfiles/theme/current/metadata" || fail "el tema migrado no se renderizó"
mimeapps="$H/.config/mimeapps.list"
[[ -f "$mimeapps" && ! -L "$mimeapps" ]] || fail "mimeapps.list no quedó como archivo"
grep -Fxq 'x-scheme-handler/foo=foo.desktop' "$mimeapps" || fail "se perdió una entrada escrita a través del enlace viejo: $(<"$mimeapps")"
[[ ! -e "$H/.local/state/dotfiles/private.receipt" ]] || fail "el recibo private migrado sigue en el target"
[[ -f "$H/.local/state/dotfiles/agent-harness.receipt" ]] || fail "switch borró el recibo de agent-harness"
manifest="$H/.local/state/dotfiles/transactions/switch-last/manifest"
grep -Fq "link	.config/bat/config	" "$manifest" || fail "el manifiesto no registra un enlace reemplazado: $(<"$manifest")"

# 3. --rollback: the plan changes nothing; --apply restores every old link,
# file and receipt (files that appeared since are set aside, never deleted).
after_switch=$(hash_tree "$H")
run_switch --rollback
(( status == 0 )) || fail "el plan de --rollback terminó con $status: $output"
[[ "$(hash_tree "$H")" == "$after_switch" ]] || fail "--rollback sin --apply modificó el target"
# State written after the switch by something else (dotfiles system setup)
# stays in place; state the switch owned that changed since is set aside.
printf 'COMPONENTS="ly"\n' > "$H/.local/state/dotfiles/system.receipt"
printf 'catppuccin-mocha-pink\n' > "$H/.local/state/dotfiles/theme/selected"
run_switch --rollback --apply
(( status == 0 )) || fail "switch --rollback --apply terminó con $status: $output"
displaced=$(find "$H/.local/state/dotfiles/transactions" -mindepth 1 -maxdepth 1 -name 'displaced-*' -print -quit)
[[ -f "$displaced/.config/mimeapps.list" ]] || fail "--rollback no apartó el mimeapps.list generado: $output"
[[ "$(<"$H/.local/state/dotfiles/system.receipt")" == 'COMPONENTS="ly"' ]] || \
  fail "--rollback borró un recibo que el switch no creó: $output"
[[ "$(<"$displaced/.local/state/dotfiles/theme/selected")" == catppuccin-mocha-pink ]] || \
  fail "--rollback no apartó el estado del switch que cambió después: $output"
rm -f -- "$H/.local/state/dotfiles/system.receipt"
rm -rf -- "$H/.local/state/dotfiles/transactions"
[[ "$(hash_tree "$H")" == "$home_before" ]] || fail "--rollback no dejó el target como antes del switch"
run_switch --rollback
(( status == 1 )) || fail "--rollback sin manifiesto debería fallar: $status $output"

# Switches home $1 to the new checkout; the hashes of both checkouts before
# it are in $legacy_before and $new_before.
switch_for_rollback() {
  new_legacy_home "$1"
  legacy_before=$(hash_tree "$LEGACY")
  new_before=$(hash_tree "$NEW")
  run_switch "$NEW" --apply
  (( status == 0 )) || fail "switch --apply ($1) terminó con $status: $output"
}

# Checks that the rollback of scenario $1 succeeded and wrote into neither
# checkout; the set-aside directory is left in $displaced.
check_rollback() {
  (( status == 0 )) || fail "switch --rollback --apply ($1) terminó con $status: $output"
  [[ "$(hash_tree "$LEGACY")" == "$legacy_before" ]] || fail "--rollback ($1) escribió en el checkout anterior"
  [[ "$(hash_tree "$NEW")" == "$new_before" ]] || fail "--rollback ($1) escribió en el checkout nuevo"
  displaced=$(find "$H/.local/state/dotfiles/transactions" -mindepth 1 -maxdepth 1 -name 'displaced-*' -print -quit 2>/dev/null)
}

# 3b. A later rollback never deletes a file written inside a directory the
# switch created (the walls clone): it is set aside, the directory goes.
switch_for_rollback rollback-tree
walls_dir="$H/.local/share/dotfiles/walls"
[[ -d "$walls_dir/.git" ]] || fail "el switch no clonó walls en $walls_dir"
printf 'mine\n' > "$walls_dir/wallpapers/mine.jpg"
run_switch --rollback --apply
check_rollback rollback-tree
[[ "$(<"$displaced/.local/share/dotfiles/walls/wallpapers/mine.jpg")" == mine ]] 2>/dev/null || \
  fail "--rollback borró un archivo escrito en el clon de walls: $output"
grep -Fq "se apartó el contenido de $walls_dir" <<< "$output" || fail "--rollback no avisó del contenido apartado: $output"
[[ ! -e "$walls_dir" ]] || fail "--rollback dejó el clon de walls que no estaba antes"
[[ "$(readlink -- "$H/.local/share/wallpapers")" == "$LEGACY/walls/wallpapers" ]] || fail "--rollback no restauró el enlace de wallpapers"

# 3c. A directory folded into a link to the checkout after the switch is put
# back as the directory it was; the rollback never writes through it.
switch_for_rollback rollback-folded
rm -rf -- "$H/.config/mango"
ln -s "$NEW/layers/wm/mangowm/home/mango/.config/mango" "$H/.config/mango"
run_switch --rollback --apply
check_rollback rollback-folded
[[ -d "$H/.config/mango" && ! -L "$H/.config/mango" ]] || fail "--rollback no devolvió .config/mango como directorio: $output"
[[ -L "$H/.config/mango/config.conf" && "$(realpath -- "$H/.config/mango/config.conf")" == "$LEGACY/wm/mangowm/home/mango/.config/mango/config.conf" ]] || \
  fail "--rollback no restauró el enlace de MangoWM: $output"

# 3d. A non-empty directory where the snapshot had a link: its content is set
# aside and the link comes back.
switch_for_rollback rollback-dir
rm -f -- "$H/.local/share/wallpapers"
mkdir -p "$H/.local/share/wallpapers"
printf 'mine\n' > "$H/.local/share/wallpapers/mine.jpg"
run_switch --rollback --apply
check_rollback rollback-dir
[[ "$(<"$displaced/.local/share/wallpapers/mine.jpg")" == mine ]] 2>/dev/null || \
  fail "--rollback no apartó el contenido del directorio que ocupaba un enlace: $output"
grep -Fq "se reemplazó el directorio $H/.local/share/wallpapers" <<< "$output" || \
  fail "--rollback no avisó del directorio reemplazado: $output"
[[ "$(readlink -- "$H/.local/share/wallpapers")" == "$LEGACY/walls/wallpapers" ]] || \
  fail "--rollback no restauró el enlace sobre el directorio: $output"

# 4. A foreign file or link where the new checkout links aborts before any
# change and names every colliding path.
new_legacy_home collision
mkdir -p "$H/.config/alacritty"
printf 'mine\n' > "$H/.config/alacritty/alacritty.toml"
foot_source=$(find "$NEW/layers/desktop/home/foot" -type f -print -quit)
foot_rel=${foot_source#"$NEW/layers/desktop/home/foot/"}
mkdir -p "$H/$(dirname -- "$foot_rel")"
ln -s "$TEST_ROOT/elsewhere" "$H/$foot_rel"
before=$(hash_tree "$H")
run_switch "$NEW" --apply
(( status != 0 )) || fail "switch con colisiones no falló: $output"
[[ "$(hash_tree "$H")" == "$before" ]] || fail "switch con colisiones modificó el target"
grep -Fq "$H/.config/alacritty/alacritty.toml" <<< "$output" || fail "no se listó la colisión con un archivo: $output"
grep -Fq "$H/$foot_rel" <<< "$output" || fail "no se listó la colisión con un enlace ajeno: $output"
grep -Fq 'no se modificó nada' <<< "$output" || fail "el aborto no lo dijo claramente: $output"

# 4b. Links of an old repository that is not migrated (private without an
# overlay) are foreign too: one where the new checkout links aborts.
new_legacy_home kept
starship_source=$(find "$NEW/layers/cli/home/starship" -type f -print -quit)
starship_rel=${starship_source#"$NEW/layers/cli/home/starship/"}
old_package private starship-private "$starship_rel"
stow -d "$LEGACY/private/home" -t "$H" --no-folding starship-private
before=$(hash_tree "$H")
run_switch "$NEW" --no-overlay --apply
(( status != 0 )) || fail "switch sin overlay pisó un enlace de private, que no migra: $output"
[[ "$(hash_tree "$H")" == "$before" ]] || fail "switch sin overlay modificó el target"
grep -Fq "$H/$starship_rel" <<< "$output" || fail "no se listó la colisión con el enlace de private: $output"
grep -Fq 'No migrado:              private (--no-overlay' <<< "$output" || fail "el plan no dice que private no migra: $output"

# 5. A failure after the old links are gone rolls back to a byte-identical
# target: here the new checkout's MangoWM post-link fails after linking.
BROKEN="$TEST_ROOT/broken/dotfiles"
copy_checkout "$BROKEN"
printf '#!/usr/bin/env bash\nexit 1\n' > "$BROKEN/layers/wm/mangowm/hooks/post-link"
new_legacy_home failure
before=$(hash_tree "$H")
run_switch "$BROKEN" --overlay "$OVERLAY" --apply
(( status != 0 )) || fail "switch con un post-link roto no falló: $output"
grep -Fq 'Enlaces del checkout anterior retirados' <<< "$output" || fail "el fallo no ocurrió después de retirar los enlaces: $output"
grep -Fq 'se restauró el estado anterior' <<< "$output" || fail "el fallo no anunció la reversión: $output"
[[ "$(hash_tree "$H")" == "$before" ]] || fail "la reversión no dejó el target idéntico"

# 5b. Parents that were already links before the switch (state and cache on
# another disk) are used as recorded: the failed switch still rolls back to
# an identical target, through them.
new_legacy_home failure-linked
EXTERNAL="$TEST_ROOT/external-disk"
mkdir -p "$EXTERNAL/cache" "$H/.local"
mv -- "$H/.local/state" "$EXTERNAL/state"
ln -s -- "$EXTERNAL/state" "$H/.local/state"
ln -s -- "$EXTERNAL/cache" "$H/.cache"
before=$(hash_tree "$H")
before_external=$(hash_tree "$EXTERNAL")
run_switch "$BROKEN" --overlay "$OVERLAY" --apply
(( status != 0 )) || fail "switch con un post-link roto no falló (padres enlazados): $output"
grep -Fq 'se restauró el estado anterior' <<< "$output" || \
  fail "la reversión con padres ya enlazados no terminó: $output"
[[ "$(hash_tree "$H")" == "$before" ]] || fail "la reversión con padres ya enlazados cambió el target"
[[ "$(hash_tree "$EXTERNAL")" == "$before_external" ]] || \
  fail "la reversión dejó restos detrás de los padres ya enlazados: $(find "$EXTERNAL" -newer "$H/.cache")"

# 6. Monorepo to monorepo: the selection receipt moves to the new checkout.
OLD_CO="$TEST_ROOT/old/dotfiles"
copy_checkout "$OLD_CO"
H="$TEST_ROOT/mono"
LEGACY="$H/.none"
mkdir -p "$H"
status=0
output=$(HOME="$H" "$OLD_CO/bin/dotfiles" bootstrap --profile cli --layer dev --stow-only --target "$H" --apply 2>&1) || status=$?
(( status == 0 )) || fail "el bootstrap del checkout viejo falló: $output"
# A change killed before its manifest was written changed nothing: it is
# discarded with a warning instead of blocking every later switch.
stale="$H/.local/state/dotfiles/transactions/switch.pending"
mkdir -p "$stale/files"
run_switch "$NEW" --apply
(( status == 0 )) || fail "switch entre monorepos terminó con $status: $output"
grep -Fq "se descartó $stale" <<< "$output" || fail "switch no avisó del cambio sin manifiesto descartado: $output"
[[ ! -e "$stale" ]] || fail "switch dejó el cambio sin manifiesto en $stale"
grep -Fq 'Overlay:                 ninguno (recibo de selección)' <<< "$output" || fail "switch añadió un overlay que el recibo no tenía: $output"
[[ -z "$(links_into "$OLD_CO")" ]] || fail "quedaron enlaces hacia el checkout viejo: $(links_into "$OLD_CO")"
[[ "$(realpath -- "$H/.config/bat/config")" == "$NEW/"* ]] || fail "cli no quedó enlazado al checkout nuevo"
[[ "$(realpath -- "$H/.config/zsh/conf.d/50-dev.zsh")" == "$NEW/"* ]] || fail "dev no quedó enlazado al checkout nuevo"
grep -Fxq 'LAYERS="dev"' "$H/.local/state/dotfiles/dotfiles.receipt" || fail "el recibo perdió la capa dev"
run_switch "$NEW"
grep -Fq 'ya es el checkout activo' <<< "$output" || fail "switch al checkout activo no lo detectó: $output"

# Usage: a path is required and --rollback takes no selection.
run_switch
(( status == 2 )) || fail "switch sin ruta debería ser un error de uso: $status $output"
run_switch --rollback "$NEW"
(( status == 2 )) || fail "--rollback con una ruta debería ser un error de uso: $status $output"
[[ "$(DOTFILES_LANG=en "$REPO_ROOT/bin/dotfiles" help)" == *"switch DIR"* ]] || fail "la ayuda (en) no documenta switch"
[[ "$(DOTFILES_LANG=es "$REPO_ROOT/bin/dotfiles" help)" == *"switch RUTA"* ]] || fail "la ayuda (es) no documenta switch"
[[ "$("$REPO_ROOT/bin/dotfiles" completion bash)" == *"switch"* ]] || fail "el autocompletado no ofrece switch"

[[ "$(cd "$NEW" && find . -printf '%y %p %l\n' | LC_ALL=C sort; find "$NEW" -type f -exec sha256sum {} + | LC_ALL=C sort)" == "$NEW_STATE" ]] || \
  fail "switch modificó archivos del checkout nuevo"
[[ "$(git -C "$REPO_ROOT" status --porcelain)" == "$CHECKOUT_STATE" ]] || fail "las pruebas modificaron el checkout"
printf 'OK: switch de checkout validado\n'
