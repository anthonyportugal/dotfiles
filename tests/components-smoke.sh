#!/usr/bin/env bash
# External components (components.conf + `dotfiles add <name>`) driven through
# bin/dotfiles with a local fixture repository: clone at the pinned ref, links,
# receipt, sync/update moving the pin, doctor, unlink and the removed
# --wallpapers flags. Never uses the network.

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
  [[ -n "$TEST_ROOT" && "$TEST_ROOT" == "$TEST_TMP_PARENT"/dotfiles-components-smoke.* ]] || return 0
  rm -rf -- "$TEST_ROOT"
}

trap cleanup EXIT

command -v stow >/dev/null 2>&1 || fail "GNU Stow es necesario para este smoke test"
command -v git >/dev/null 2>&1 || fail "git es necesario para este smoke test"
[[ -d "$TEST_TMP_PARENT" ]] || fail "no existe el directorio temporal: $TEST_TMP_PARENT"
TEST_ROOT=$(mktemp -d "$TEST_TMP_PARENT/dotfiles-components-smoke.XXXXXX")
# setup looks for the overlay next to the checkout; keep the real
# dotfiles-private out of these runs.
export DOTFILES_OVERLAY_DIR="$TEST_ROOT/no-overlay"
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

# The fixture component: two commits, the second adds a wallpaper.
FIXTURE="$TEST_ROOT/walls-src"
mkdir -p "$FIXTURE/wallpapers" "$FIXTURE/bin"
printf 'one\n' > "$FIXTURE/wallpapers/w-001.webp"
printf '#!/bin/sh\necho walls\n' > "$FIXTURE/bin/walls"
chmod +x "$FIXTURE/bin/walls"
git -C "$FIXTURE" init -q
commit_all "$FIXTURE" one
REF1=$(git -C "$FIXTURE" rev-parse HEAD)
printf 'two\n' > "$FIXTURE/wallpapers/w-002.webp"
commit_all "$FIXTURE" two
REF2=$(git -C "$FIXTURE" rev-parse HEAD)
URL="file://$FIXTURE"

CONF="$TEST_ROOT/components.conf"
export DOTFILES_COMPONENTS_FILE="$CONF"
write_conf() {
  {
    printf '# name url ref [src=dst ...]\n\n'
    printf 'walls %s %s wallpapers=.local/share/wallpapers bin/walls=.local/bin/walls\n' "$URL" "$1"
  } > "$CONF"
}
write_conf "$REF1"

H="$TEST_ROOT/home dir"
CO="$H/.local/share/dotfiles/walls"
COMPONENTS_RECEIPT="$H/.local/state/dotfiles/components.receipt"
mkdir -p "$H"

run() {
  HOME="$H" "$DOTFILES" "$@"
}

# Runs the CLI expecting exit status $1; the output is left in $output.
expect_status() {
  local expected=$1
  shift
  status=0
  output=$(run "$@" 2>&1) || status=$?
  (( status == expected )) || fail "'$*' terminó con $status en vez de $expected: $output"
}

linked_to_checkout() {
  [[ -L "$H/$1" && "$(readlink -- "$H/$1")" == "$CO/$2" ]]
}

# The help documents add and no longer the wallpapers flags.
output=$(run help)
[[ "$output" == *'dotfiles add NOMBRE'* ]] || fail "la ayuda (es) no documenta add: $output"
[[ "$output" != *'--wallpapers'* ]] || fail "la ayuda sigue documentando --wallpapers"
output=$(DOTFILES_LANG=en run help)
[[ "$output" == *'dotfiles add NAME'* && "$output" == *'components.conf'* ]] || fail "la ayuda (en) no documenta add: $output"

# The wallpapers flags are gone and point to the component.
for option in --wallpapers --wallpapers-path=x; do
  expect_status 2 bootstrap --profile core --target "$H" "$option"
  [[ "$output" == *"use 'dotfiles add walls'"* ]] || fail "$option no indicó 'dotfiles add walls': $output"
done
expect_status 2 doctor --target "$H" --wallpapers-path "$TEST_ROOT"
[[ "$output" == *'dotfiles add walls'* ]] || fail "--wallpapers-path DIR no indicó 'dotfiles add walls': $output"

# Unknown or missing names are usage errors that list the components.
expect_status 2 add nope --target "$H"
[[ "$output" == *'componente desconocido: nope'* && "$output" == *'disponibles: walls'* ]] || \
  fail "un componente desconocido no listó los disponibles: $output"
expect_status 2 add --target "$H"
[[ "$output" == *'disponibles: walls'* ]] || fail "add sin nombre no listó los disponibles: $output"

# An invalid components.conf is refused before touching anything.
expect_invalid_conf() {
  local label=$1 expected=$2 line=$3
  printf '%s\n' "$line" > "$TEST_ROOT/invalid.conf"
  status=0
  output=$(DOTFILES_COMPONENTS_FILE="$TEST_ROOT/invalid.conf" HOME="$H" "$DOTFILES" add walls --target "$H" 2>&1) || status=$?
  (( status == 1 )) || fail "conf inválido ($label) terminó con $status: $output"
  [[ "$output" == *"$expected"* ]] || fail "conf inválido ($label) no explicó '$expected': $output"
  [[ ! -e "$H/.local" ]] || fail "conf inválido ($label) modificó el home"
}
expect_invalid_conf short-ref 'ref fijada inválida' "walls $URL ${REF1:0:12} wallpapers=.local/share/wallpapers"
expect_invalid_conf branch-ref 'ref fijada inválida' "walls $URL main wallpapers=.local/share/wallpapers"
expect_invalid_conf dotdot-src 'ruta inválida' "walls $URL $REF1 ../wallpapers=.local/share/wallpapers"
expect_invalid_conf dotdot-dst 'ruta inválida' "walls $URL $REF1 wallpapers=.local/../../etc"
expect_invalid_conf dot-dst 'ruta inválida' "walls $URL $REF1 wallpapers=./.local/share/wallpapers"
expect_invalid_conf absolute-dst 'ruta inválida' "walls $URL $REF1 wallpapers=/etc/wallpapers"
expect_invalid_conf absolute-src 'ruta inválida' "walls $URL $REF1 /wallpapers=.local/share/wallpapers"
expect_invalid_conf bad-name 'nombre de componente inválido' "Walls $URL $REF1"
expect_invalid_conf incomplete 'entrada incompleta' "walls $URL"
printf 'walls %s %s\nwalls %s %s\n' "$URL" "$REF1" "$URL" "$REF1" > "$TEST_ROOT/dup.conf"
status=0
output=$(DOTFILES_COMPONENTS_FILE="$TEST_ROOT/dup.conf" HOME="$H" "$DOTFILES" add walls --target "$H" 2>&1) || status=$?
(( status == 1 )) || fail "un nombre duplicado terminó con $status: $output"
[[ "$output" == *'componente duplicado: walls'* ]] || fail "un nombre duplicado no fue explicado: $output"

# The base core layer is applied first so doctor can pass.
run bootstrap --profile core --stow-only --apply --target "$H" > /dev/null || fail "bootstrap core falló"

# Without components, the bootstrap plan, doctor and sync stay as before.
output=$(run bootstrap --profile core --stow-only --target "$H" 2>&1) || fail "bootstrap dry-run falló: $output"
[[ "$output" != *'Componente'* ]] || fail "el plan sin componentes cambió: $output"
output=$(run doctor --profile core --stow-only --target "$H" 2>&1) || fail "doctor sin componentes falló: $output"
[[ "$output" != *'Component'* ]] || fail "doctor sin componentes auditó componentes: $output"
output=$(run sync --stow-only --target "$H" 2>&1) || fail "sync sin componentes falló: $output"
[[ "$output" != *'Componente'* && ! -e "$H/.local/share/dotfiles" ]] || fail "sync sin componentes aplicó componentes: $output"
[[ ! -e "$COMPONENTS_RECEIPT" ]] || fail "sync sin componentes creó el recibo de componentes"

# --dry-run prints the plan and changes nothing.
expect_status 0 add walls --target "$H" --dry-run
[[ "$output" == *"$URL"* && "$output" == *"$REF1"* && "$output" == *"$H/.local/share/wallpapers"* ]] || \
  fail "add --dry-run no mostró el plan: $output"
[[ ! -e "$CO" && ! -e "$H/.local/share/wallpapers" && ! -e "$COMPONENTS_RECEIPT" ]] || fail "add --dry-run modificó el home"

# A real directory at a destination is refused and nothing changes.
mkdir -p "$H/.local/share/wallpapers"
printf 'mine\n' > "$H/.local/share/wallpapers/keep.webp"
expect_status 1 add walls --target "$H"
[[ "$output" == *"$H/.local/share/wallpapers ya existe y no es un enlace simbólico"* ]] || \
  fail "un directorio real en el destino no fue explicado: $output"
[[ -f "$H/.local/share/wallpapers/keep.webp" && ! -L "$H/.local/share/wallpapers" ]] || fail "add tocó el directorio real"
[[ ! -e "$CO" && ! -e "$H/.local/bin/walls" && ! -e "$COMPONENTS_RECEIPT" ]] || fail "add cambió algo tras rechazar el destino"
[[ -z "$(find "$H/.local/share" -maxdepth 2 -name '.walls.clone.*')" ]] || fail "add dejó un clon temporal"
rm -rf -- "$H/.local/share/wallpapers"

# A foreign symlink (the old ~/.dotfiles/walls link) is replaced.
ln -s "$TEST_ROOT/old-dotfiles/walls/wallpapers" "$H/.local/share/wallpapers"
expect_status 0 add walls --target "$H"
[[ "$(git -C "$CO" rev-parse HEAD)" == "$REF1" ]] || fail "add no fijó la ref"
git -C "$CO" symbolic-ref -q HEAD >/dev/null && fail "add no dejó el checkout en HEAD separado"
[[ "$(git -C "$CO" remote get-url origin)" == "$URL" ]] || fail "add no clonó desde la URL declarada"
linked_to_checkout .local/share/wallpapers wallpapers || fail "add no reemplazó el enlace ajeno"
linked_to_checkout .local/bin/walls bin/walls || fail "add no enlazó bin/walls"
[[ -f "$H/.local/share/wallpapers/w-001.webp" && ! -e "$H/.local/share/wallpapers/w-002.webp" ]] || \
  fail "el contenido enlazado no corresponde a la ref fijada"
grep -Fxq 'COMPONENTS="walls"' "$COMPONENTS_RECEIPT" || fail "add no registró el componente: $(<"$COMPONENTS_RECEIPT")"

# Re-adding is idempotent.
expect_status 0 add walls --target "$H"
[[ "$(git -C "$CO" rev-parse HEAD)" == "$REF1" ]] || fail "re-add movió la ref"
linked_to_checkout .local/share/wallpapers wallpapers || fail "re-add cambió el enlace de wallpapers"
linked_to_checkout .local/bin/walls bin/walls || fail "re-add cambió el enlace de bin/walls"
grep -Fxq 'COMPONENTS="walls"' "$COMPONENTS_RECEIPT" || fail "re-add duplicó el componente en el recibo"
[[ "$(grep -c '^COMPONENTS=' "$COMPONENTS_RECEIPT")" == 1 ]] || fail "re-add repitió la clave COMPONENTS"

# The bootstrap plan and doctor include the recorded component.
output=$(run bootstrap --profile core --stow-only --target "$H" 2>&1) || fail "bootstrap dry-run con componentes falló: $output"
[[ "$output" == *'Componentes:'*'walls'* ]] || fail "el plan no mostró el componente registrado: $output"
expect_status 0 doctor --profile core --stow-only --target "$H"
[[ "$output" == *'Component (walls): OK'* ]] || fail "doctor no auditó el componente: $output"

# A broken link makes doctor fail with the hint.
rm -f -- "$H/.local/bin/walls"
expect_status 1 doctor --profile core --stow-only --target "$H"
[[ "$output" == *'Component (walls): FAIL'* && "$output" == *"dotfiles add walls"* ]] || \
  fail "doctor no detectó el enlace roto: $output"
expect_status 0 add walls --target "$H"
linked_to_checkout .local/bin/walls bin/walls || fail "re-add no reparó el enlace"

# A new pinned ref the checkout has not fetched yet: doctor reports the wrong
# ref, sync fetches it and moves the checkout.
printf 'three\n' > "$FIXTURE/wallpapers/w-003.webp"
commit_all "$FIXTURE" three
REF3=$(git -C "$FIXTURE" rev-parse HEAD)
write_conf "$REF3"
expect_status 1 doctor --profile core --stow-only --target "$H"
[[ "$output" == *'Component (walls): FAIL'* && "$output" == *"$REF3"* && "$output" == *"dotfiles add walls"* ]] || \
  fail "doctor no detectó la ref distinta: $output"
expect_status 0 sync --stow-only --target "$H"
[[ "$(git -C "$CO" rev-parse HEAD)" == "$REF3" ]] || fail "sync no movió el checkout a la nueva ref"
linked_to_checkout .local/share/wallpapers wallpapers || fail "sync no conservó el enlace de wallpapers"
linked_to_checkout .local/bin/walls bin/walls || fail "sync no conservó el enlace de bin/walls"
[[ -f "$H/.local/share/wallpapers/w-003.webp" ]] || fail "el enlace no muestra el contenido de la nueva ref"

# A missing checkout is a doctor FAIL with the hint.
mv -- "$CO" "$TEST_ROOT/moved-checkout"
expect_status 1 doctor --profile core --stow-only --target "$H"
[[ "$output" == *'Component (walls): FAIL'* && "$output" == *"dotfiles add walls"* ]] || \
  fail "doctor no detectó el checkout ausente: $output"
mv -- "$TEST_ROOT/moved-checkout" "$CO"

# A dirty checkout or a different origin is refused without changes.
printf 'local\n' > "$CO/untracked"
write_conf "$REF1"
expect_status 1 add walls --target "$H"
[[ "$output" == *'tiene cambios locales'* ]] || fail "un checkout sucio no fue rechazado: $output"
[[ "$(git -C "$CO" rev-parse HEAD)" == "$REF3" ]] || fail "add movió un checkout sucio"
rm -f -- "$CO/untracked"
git -C "$CO" remote set-url origin "file://$TEST_ROOT/other"
expect_status 1 add walls --target "$H"
[[ "$output" == *'usa otro origin'* ]] || fail "un origin distinto no fue rechazado: $output"
[[ "$(git -C "$CO" rev-parse HEAD)" == "$REF3" ]] || fail "add movió un checkout de otro origin"
git -C "$CO" remote set-url origin "$URL"

# A recorded component that fails on sync still leaves the selection recorded.
RO="$TEST_ROOT/receipt-order"
mkdir -p "$RO"
HOME="$RO" "$DOTFILES" bootstrap --profile core --stow-only --apply --target "$RO" > /dev/null
HOME="$RO" "$DOTFILES" add walls --target "$RO" > /dev/null
printf 'local\n' > "$RO/.local/share/dotfiles/walls/untracked"
rm -f -- "$RO/.local/state/dotfiles/dotfiles.receipt"
if HOME="$RO" "$DOTFILES" bootstrap --profile core --stow-only --apply --target "$RO" > "$TEST_ROOT/order.out" 2>&1; then
  fail "bootstrap ignoró el fallo de un componente registrado"
fi
grep -q 'tiene cambios locales' "$TEST_ROOT/order.out" || fail "bootstrap no explicó el fallo del componente"
grep -Fxq 'PROFILE="core"' "$RO/.local/state/dotfiles/dotfiles.receipt" || \
  fail "un componente fallido impidió guardar la selección ya aplicada"

# An applied unlink that filters components out keeps their links and the
# receipt that tracks them: --packages-only is refused, and a recorded
# component no longer declared in components.conf is neither unlinked nor
# forgotten.
F="$TEST_ROOT/filtered-unlink"
mkdir -p "$F"
HOME="$F" "$DOTFILES" bootstrap --profile core --stow-only --apply --target "$F" > /dev/null || fail "bootstrap (filtrado) falló"
HOME="$F" "$DOTFILES" add walls --target "$F" > /dev/null || fail "add (filtrado) falló"
filtered_kept() {
  [[ -L "$F/.local/share/wallpapers" && -L "$F/.local/bin/walls" ]] || fail "$1 retiró los enlaces del componente: $output"
  grep -Fxq 'COMPONENTS="walls"' "$F/.local/state/dotfiles/components.receipt" 2>/dev/null || \
    fail "$1 borró el recibo de componentes: $output"
}
status=0
output=$(HOME="$F" "$DOTFILES" unlink --profile core --target "$F" --apply --packages-only 2>&1) || status=$?
(( status == 2 )) || fail "unlink --packages-only terminó con $status: $output"
filtered_kept "unlink --apply --packages-only"
printf '# empty\n' > "$TEST_ROOT/empty.conf"
output=$(DOTFILES_COMPONENTS_FILE="$TEST_ROOT/empty.conf" HOME="$F" "$DOTFILES" unlink --profile core --target "$F" --apply 2>&1) || \
  fail "unlink con el componente filtrado falló: $output"
[[ ! -L "$F/.zshrc" ]] || fail "unlink con el componente filtrado no retiró la base: $output"
filtered_kept "un unlink con el componente filtrado"

# A target reached through symlinked directories (the home itself and its
# .local/share) still finds the checkout: sync, doctor and unlink neither
# re-clone, refuse nor fail.
SR="$TEST_ROOT/symlinked-real"
SL="$TEST_ROOT/symlinked-home"
mkdir -p "$SR/.local" "$TEST_ROOT/symlinked-share"
ln -s "$SR" "$SL"
ln -s "$TEST_ROOT/symlinked-share" "$SR/.local/share"
HOME="$SR" "$DOTFILES" bootstrap --profile core --stow-only --apply --target "$SR" > /dev/null || fail "bootstrap (symlink) falló"
HOME="$SR" "$DOTFILES" add walls --target "$SR" > /dev/null || fail "add (symlink) falló"
SYM_INODE=$(stat -c %i -- "$SR/.local/share/dotfiles/walls/.git")
output=$(HOME="$SL" "$DOTFILES" sync --stow-only --target "$SL" 2>&1) || fail "sync con --target enlazado falló: $output"
[[ "$(stat -c %i -- "$SR/.local/share/dotfiles/walls/.git")" == "$SYM_INODE" ]] || fail "sync con --target enlazado re-clonó: $output"
output=$(HOME="$SL" "$DOTFILES" doctor --profile core --stow-only --target "$SL" 2>&1) || \
  fail "doctor con --target enlazado falló: $output"
[[ "$output" == *'Component (walls): OK'* && "$output" != *'FAIL'* ]] || fail "doctor con --target enlazado no validó el componente: $output"
output=$(HOME="$SL" "$DOTFILES" unlink --profile core --target "$SL" --apply 2>&1) || \
  fail "unlink con --target enlazado falló: $output"
[[ ! -L "$SR/.local/share/wallpapers" && ! -L "$SR/.local/bin/walls" ]] || fail "unlink con --target enlazado conservó los enlaces: $output"
[[ ! -e "$SR/.local/state/dotfiles/components.receipt" && -d "$SR/.local/share/dotfiles/walls/.git" ]] || \
  fail "unlink con --target enlazado no limpió el recibo o borró el checkout: $output"

# unlink: the dry run keeps everything; --apply removes only links into the
# checkout, keeps the checkout and clears the components receipt.
ln -sfn "$TEST_ROOT/elsewhere/walls" "$H/.local/bin/walls"
expect_status 0 unlink --profile core --target "$H"
[[ -L "$H/.local/share/wallpapers" && -e "$COMPONENTS_RECEIPT" ]] || fail "unlink sin --apply modificó los componentes"
expect_status 0 unlink --profile core --target "$H" --apply
[[ ! -e "$H/.local/share/wallpapers" && ! -L "$H/.local/share/wallpapers" ]] || fail "unlink no retiró el enlace del componente"
[[ -L "$H/.local/bin/walls" && "$(readlink -- "$H/.local/bin/walls")" == "$TEST_ROOT/elsewhere/walls" ]] || \
  fail "unlink retiró un enlace que no apunta al checkout"
[[ -d "$CO/.git" ]] || fail "unlink borró el checkout"
[[ ! -e "$COMPONENTS_RECEIPT" ]] || fail "unlink no limpió el recibo de componentes"
[[ ! -L "$H/.zshrc" ]] || fail "unlink no retiró la base"

# unlink without components keeps its previous behaviour.
N="$TEST_ROOT/no-components"
mkdir -p "$N"
HOME="$N" "$DOTFILES" bootstrap --profile core --stow-only --apply --target "$N" > /dev/null
output=$(HOME="$N" "$DOTFILES" unlink --profile core --target "$N" --apply 2>&1) || fail "unlink sin componentes falló: $output"
[[ "$output" != *'componente'* && ! -L "$N/.zshrc" && ! -e "$N/.local/state/dotfiles/dotfiles.receipt" ]] || \
  fail "unlink sin componentes cambió de comportamiento: $output"

# A component chosen among the setup extras is added at its pinned ref.
W="$TEST_ROOT/wizard-home"
mkdir -p "$W"
output=$(printf 'server\n\nwalls\napply\n' | HOME="$W" "$DOTFILES" setup --stow-only --target "$W" 2>&1) || \
  fail "el asistente falló: $output"
[[ -L "$W/.local/share/wallpapers" && "$(git -C "$W/.local/share/dotfiles/walls" rev-parse HEAD)" == "$REF1" ]] || \
  fail "el extra walls del asistente no añadió el componente: $output"

# update pulls the public repository (never a walls checkout) and its sync
# moves recorded components to the newly pinned ref.
UPSTREAM="$TEST_ROOT/upstream"
PUBLIC="$TEST_ROOT/public"
UH="$TEST_ROOT/update-home"
cp -a "$REPO_ROOT/." "$UPSTREAM"
# CI checks out a detached HEAD, and update can only pull on a branch.
git -C "$UPSTREAM" switch -qC upstream
{
  printf '# test\n'
  printf 'walls %s %s wallpapers=.local/share/wallpapers bin/walls=.local/bin/walls\n' "$URL" "$REF1"
} > "$UPSTREAM/components.conf"
commit_all "$UPSTREAM" wip
git clone -q "$UPSTREAM" "$PUBLIC"
mkdir -p "$UH/.dotfiles/walls"
git -C "$UH/.dotfiles/walls" init -q
run_public() {
  env -u DOTFILES_COMPONENTS_FILE HOME="$UH" "$PUBLIC/bin/dotfiles" "$@" 2>&1
}
run_public bootstrap --profile core --stow-only --apply --target "$UH" > /dev/null || fail "bootstrap previo a update falló"
output=$(run_public update -y --stow-only --target "$UH") || fail "update sin componentes falló: $output"
[[ "$output" != *'walls'* ]] || fail "update sigue tratando un checkout de walls: $output"
run_public add walls --target "$UH" > /dev/null || fail "add previo a update falló"
sed -i "s/$REF1/$REF2/" "$UPSTREAM/components.conf"
commit_all "$UPSTREAM" pin
output=$(run_public update -y --stow-only --target "$UH") || fail "update falló: $output"
[[ "$output" == *'public: actualizado'* ]] || fail "update no actualizó el repositorio público: $output"
[[ "$(git -C "$UH/.local/share/dotfiles/walls" rev-parse HEAD)" == "$REF2" ]] || \
  fail "update no movió el componente a la nueva ref: $output"
[[ -f "$UH/.local/share/wallpapers/w-002.webp" ]] || fail "update no conservó los enlaces del componente"

[[ "$(git -C "$REPO_ROOT" status --porcelain)" == "$CHECKOUT_STATE" ]] || fail "los componentes modificaron el checkout"

printf 'OK: componentes externos validados\n'
