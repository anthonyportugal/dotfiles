#!/usr/bin/env bash
# Retiring a dropped selection: when an applied bootstrap or sync resolves a
# selection smaller than the selection receipt, the links of what was dropped
# (opt-in layers, a lower profile tier, WM layers, features, overlay layers)
# are removed, and the plan names them first. Only links into this checkout
# or the recorded overlay are removed. Every run uses a home in mktemp and
# --stow-only; never the network.

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
  [[ -n "$TEST_ROOT" && "$TEST_ROOT" == "$TEST_TMP_PARENT"/dotfiles-retire-smoke.* ]] || return 0
  rm -rf -- "$TEST_ROOT"
}

trap cleanup EXIT

command -v stow >/dev/null 2>&1 || fail "GNU Stow es necesario para este smoke test"
[[ -d "$TEST_TMP_PARENT" ]] || fail "no existe el directorio temporal: $TEST_TMP_PARENT"
TEST_ROOT=$(mktemp -d "$TEST_TMP_PARENT/dotfiles-retire-smoke.XXXXXX")
TEST_ROOT=$(realpath -e -- "$TEST_ROOT")
CHECKOUT_STATE=$(git -C "$REPO_ROOT" status --porcelain)

# Creates overlay layer $2 under overlay root $1 with layer.conf lines $3..
# and one Stow package named after the layer that owns .config/overlay/$2.
make_overlay_layer() {
  local root=$1 name=$2
  shift 2
  mkdir -p "$root/layers/$name/packages/stow" "$root/layers/$name/home/$name/.config/overlay"
  printf '%s\n' "$@" > "$root/layers/$name/layer.conf"
  printf '%s\n' "$name" > "$root/layers/$name/packages/stow/$name.txt"
  printf '%s\n' "$name" > "$root/layers/$name/home/$name/.config/overlay/$name"
  : > "$root/layers/$name/home/.stow"
}

# ident applies with core; its feature work adds a Stow package of its own.
OVERLAY="$TEST_ROOT/overlay"
make_overlay_layer "$OVERLAY" ident requires=core profiles=ident features=work prune_dirs=.config/overlay
mkdir -p "$OVERLAY/layers/ident/home/work/.config/overlay"
printf 'work\n' > "$OVERLAY/layers/ident/packages/stow/work.txt"
printf 'work\n' > "$OVERLAY/layers/ident/home/work/.config/overlay/work"
OTHER_OVERLAY="$TEST_ROOT/other-overlay"
make_overlay_layer "$OTHER_OVERLAY" other requires=core profiles=other prune_dirs=.config/overlay

H=""
RECEIPT=""
output=""
status=0

# Starts a fresh home named $1.
new_home() {
  H="$TEST_ROOT/$1"
  RECEIPT="$H/.local/state/dotfiles/dotfiles.receipt"
  mkdir -p "$H"
}

# Runs bin/dotfiles $1 on the current home; output in $output, exit in $status.
run() {
  local command=$1
  shift
  status=0
  output=$(HOME="$H" "$DOTFILES" "$command" --stow-only --target "$H" "$@" 2>&1) || status=$?
}

apply() {
  run bootstrap --apply "$@"
  (( status == 0 )) || fail "bootstrap --apply $* terminó con $status: $output"
}

# The plan names what is retired on one line, before any change.
retire_line() {
  grep -E '^  Se retiran: +' <<< "$output" || true
}

expect_retired() {
  local expected=$1 line
  line=$(retire_line)
  [[ "$line" =~ ^\ \ Se\ retiran:\ +(.*)$ ]] || fail "el plan no listó lo que se retira ($expected): $output"
  [[ "${BASH_REMATCH[1]}" == "$expected" ]] || fail "el plan retira '${BASH_REMATCH[1]}' en vez de '$expected': $output"
}

expect_nothing_retired() {
  [[ -z "$(retire_line)" ]] || fail "el plan retira algo sin que la selección se haya reducido: $output"
}

# 1. A dropped opt-in layer: the dry-run names it and changes nothing; the
# apply removes its links and its layer receipt, and keeps what stays.
new_home layer
apply --profile core --layer dev
dev_link="$H/.config/zsh/conf.d/50-dev.zsh"
[[ -L "$dev_link" ]] || fail "la capa dev no se enlazó"
receipt_before=$(<"$RECEIPT")
run bootstrap --profile cli
(( status == 0 )) || fail "el dry-run sin dev terminó con $status: $output"
expect_retired dev
[[ -L "$dev_link" ]] || fail "el dry-run retiró el enlace de dev"
[[ "$(<"$RECEIPT")" == "$receipt_before" ]] || fail "el dry-run cambió el recibo de selección"
apply --profile cli
expect_retired dev
# Prints the number of the first line of $output that contains $1 (0 if none).
first_line() {
  awk -v text="$1" 'index($0, text) { print NR; found = 1; exit } END { if (!found) print 0 }' <<< "$output"
}
plan_end=$(first_line 'Target:')
retire_at=$(first_line 'Se retiran:')
first_change=$(first_line 'Retirando enlaces GNU Stow')
(( first_change > 0 )) || fail "bootstrap no retiró ningún enlace: $output"
(( retire_at > plan_end && retire_at < first_change )) || fail "la línea 'Se retiran' no aparece en el plan antes del primer cambio: $output"
[[ ! -e "$dev_link" && ! -L "$dev_link" ]] || fail "bootstrap no retiró el enlace de la capa dev"
[[ ! -e "$H/.local/state/dotfiles/dev.receipt" ]] || fail "bootstrap no retiró el recibo de la capa dev"
[[ -L "$H/.zshrc" && -L "$H/.config/bat/config" ]] || fail "retirar dev retiró también core o cli"
grep -Fxq 'LAYERS=""' "$RECEIPT" || fail "el recibo conserva la capa retirada: $(<"$RECEIPT")"

# 2. A lower profile tier retires the desktop layer and keeps cli.
new_home tier
apply --profile desktop
[[ -L "$H/.config/alacritty/alacritty.toml" ]] || fail "desktop no enlazó alacritty"
apply --profile cli
expect_retired desktop
[[ ! -L "$H/.config/alacritty/alacritty.toml" ]] || fail "bajar a cli no retiró los enlaces de desktop"
[[ -L "$H/.config/bat/config" ]] || fail "bajar a cli retiró los enlaces de cli"
grep -Fxq 'PROFILE="cli"' "$RECEIPT" || fail "el recibo no guardó cli: $(<"$RECEIPT")"

# 3. A dropped WM layer is retired with its WM receipt.
new_home wm
apply --profile core --wm bspwm
[[ -L "$H/.config/bspwm/bspwmrc" ]] || fail "bspwm no se enlazó"
apply --profile desktop
expect_retired bspwm
[[ ! -L "$H/.config/bspwm/bspwmrc" ]] || fail "bootstrap sin --wm no retiró bspwm"
[[ ! -e "$H/.local/state/dotfiles/bspwm.receipt" ]] || fail "bootstrap no retiró el recibo de bspwm"
[[ -L "$H/.config/alacritty/alacritty.toml" ]] || fail "retirar bspwm retiró desktop"

# 4. A dropped feature removes its Stow packages only; its layer stays.
new_home feature
apply --profile core --overlay "$OVERLAY" --feature work
[[ -L "$H/.config/overlay/work" && -L "$H/.config/overlay/ident" ]] || fail "la feature work no se enlazó"
apply --profile core --overlay "$OVERLAY"
expect_retired work
[[ ! -L "$H/.config/overlay/work" ]] || fail "bootstrap sin --feature work no retiró su paquete Stow"
[[ -L "$H/.config/overlay/ident" ]] || fail "retirar la feature work retiró su capa ident"
[[ -f "$H/.local/state/dotfiles/ident.receipt" ]] || fail "retirar una feature borró el recibo de su capa"

# 5. A dropped overlay: --no-overlay and a changed overlay retire its layers.
apply --profile core --overlay "$OTHER_OVERLAY"
expect_retired ident
[[ ! -L "$H/.config/overlay/ident" ]] || fail "cambiar de overlay no retiró las capas del anterior"
[[ -L "$H/.config/overlay/other" ]] || fail "el overlay nuevo no se enlazó"
apply --profile core --no-overlay
expect_retired other
[[ ! -L "$H/.config/overlay/other" ]] || fail "--no-overlay no retiró las capas del overlay"
grep -Fxq 'OVERLAY=""' "$RECEIPT" || fail "--no-overlay no limpió el overlay del recibo: $(<"$RECEIPT")"
[[ -L "$H/.zshrc" ]] || fail "retirar el overlay retiró core"

# 6. sync retires a lower tier too, from the selection it actually applies.
new_home sync
apply --profile cli
run sync --profile core
(( status == 0 )) || fail "sync --profile core terminó con $status: $output"
expect_retired cli
[[ ! -L "$H/.config/bat/config" ]] || fail "sync --profile core no retiró cli"
[[ -L "$H/.zshrc" ]] || fail "sync --profile core retiró core"

# Regression: with nothing dropped, the plan is byte-identical to a plan
# without any receipt (bootstrap never read the selection receipt).
new_home unchanged
apply --profile cli --layer dev
run bootstrap --profile cli --layer dev
with_receipt=$output
expect_nothing_retired
mv -- "$RECEIPT" "$RECEIPT.saved"
run bootstrap --profile cli --layer dev
mv -- "$RECEIPT.saved" "$RECEIPT"
[[ "$with_receipt" == "$output" ]] || \
  fail "el plan cambió con un recibo sin nada que retirar: $(diff <(printf '%s\n' "$output") <(printf '%s\n' "$with_receipt") || true)"
run sync
(( status == 0 )) || fail "sync terminó con $status: $output"
expect_nothing_retired

# Regression: a foreign file and a foreign link where a dropped package links
# are never touched; only the links into this checkout go.
new_home foreign
apply --profile desktop
foreign_file="$H/.config/alacritty/alacritty.toml"
rm -f -- "$foreign_file"
printf 'mine\n' > "$foreign_file"
foreign_target="$TEST_ROOT/foreign-target"
printf 'theirs\n' > "$foreign_target"
foot_source=$(find "$REPO_ROOT/layers/desktop/home/foot" -type f -print -quit)
foreign_link="$H/${foot_source#"$REPO_ROOT/layers/desktop/home/foot/"}"
[[ -L "$foreign_link" ]] || fail "desktop no enlazó $foreign_link"
ln -sfn -- "$foreign_target" "$foreign_link"
apply --profile cli
expect_retired desktop
[[ -f "$foreign_file" && ! -L "$foreign_file" && "$(<"$foreign_file")" == mine ]] || fail "el retiro tocó un archivo ajeno"
[[ "$(readlink -- "$foreign_link")" == "$foreign_target" ]] || fail "el retiro tocó un enlace ajeno"
[[ "$(<"$foreign_target")" == theirs ]] || fail "el retiro modificó el destino de un enlace ajeno"

# The help documents the retire line in both languages.
[[ "$(DOTFILES_LANG=en "$DOTFILES" help)" == *"'Retiring:'"* ]] || fail "la ayuda (en) no documenta el retiro"
[[ "$(DOTFILES_LANG=es "$DOTFILES" help)" == *"'Se retiran:'"* ]] || fail "la ayuda (es) no documenta el retiro"

[[ "$(git -C "$REPO_ROOT" status --porcelain)" == "$CHECKOUT_STATE" ]] || fail "las pruebas modificaron el checkout"
printf 'OK: retiro de la selección descartada validado\n'
