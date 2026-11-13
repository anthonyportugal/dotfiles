#!/usr/bin/env bash
# Opt-in layers (--layer) driven through bin/dotfiles: they are never part of
# a profile, pull in what they require, are pulled in by their own features,
# are recorded in the selection receipt and come back on sync.

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
  [[ -n "$TEST_ROOT" && "$TEST_ROOT" == "$TEST_TMP_PARENT"/dotfiles-optional-layers-smoke.* ]] || return 0
  rm -rf -- "$TEST_ROOT"
}

trap cleanup EXIT

command -v stow >/dev/null 2>&1 || fail "GNU Stow es necesario para este smoke test"
[[ -d "$TEST_TMP_PARENT" ]] || fail "no existe el directorio temporal: $TEST_TMP_PARENT"
TEST_ROOT=$(mktemp -d "$TEST_TMP_PARENT/dotfiles-optional-layers-smoke.XXXXXX")
CHECKOUT_STATE=$(git -C "$REPO_ROOT" status --porcelain)

# pacman reports nothing installed, so every manifest entry is planned.
FAKE_BIN="$TEST_ROOT/fake-bin"
mkdir -p "$FAKE_BIN"
printf '#!/usr/bin/env bash\nexit 0\n' > "$FAKE_BIN/pacman"
chmod +x "$FAKE_BIN/pacman"
# A fake AUR helper, so plans that need AUR do not depend on the host having one.
ln -s /usr/bin/true "$FAKE_BIN/shelly"

H="$TEST_ROOT/home"
RECEIPT="$H/.local/state/dotfiles/dotfiles.receipt"
mkdir -p "$H"

run() {
  PATH="$FAKE_BIN:$PATH" HOME="$H" "$DOTFILES" "$@"
}

# Prints the part of output $1 that belongs to the plan of layer $2.
layer_section() {
  awk -v header="Plan de la capa $2" '
    index($0, header) { inside = 1; print; next }
    inside && /Plan de la capa / { exit }
    inside { print }
  ' <<< "$1"
}

plan_packages() {
  run bootstrap --packages-only --backend pacman --platform arch --target "$H" "$@" 2>&1
}

# Whether the repo packages of a plan section $1 include the exact name $2
# (a substring test would let `go` pass on golangci-lint or "Features: dev-go").
plans_repo_package() {
  local packages
  packages=$(awk '/Paquetes repo:/ { sub(/.*Paquetes repo: */, ""); print; exit }' <<< "$1")
  [[ " $packages " == *" $2 "* ]]
}

# Same as plans_repo_package, for the AUR packages of a plan section.
plans_aur_package() {
  local packages
  packages=$(awk '/Paquetes AUR:/ { sub(/.*Paquetes AUR: */, ""); print; exit }' <<< "$1")
  [[ " $packages " == *" $2 "* ]]
}

# The help documents the selector.
output=$(run help)
[[ "$output" == *'--layer'* ]] || fail "la ayuda no documenta --layer"

# A profile never includes an opt-in layer.
output=$(plan_packages --profile desktop) || fail "el plan desktop falló: $output"
[[ "$output" != *'Plan de la capa dev'* ]] || fail "el perfil desktop incluyó la capa opcional dev"
[[ "$output" != *'Capas opcionales'* ]] || fail "el plan sin --layer cambió su salida con una línea de capas opcionales"

# --layer dev pulls in cli and plans its base tools, not its features.
output=$(plan_packages --profile core --layer dev) || fail "el plan con --layer dev falló: $output"
[[ "$output" == *'Plan de la capa cli'* ]] || fail "--layer dev no aplicó la capa cli que requiere"
[[ "$output" == *'Las capas elegidas requieren la capa cli; se aplica cli en lugar de core'* ]] || \
  fail "--layer dev no explicó por qué subió el perfil a cli"
dev_plan=$(layer_section "$output" dev)
[[ -n "$dev_plan" ]] || fail "--layer dev no planificó la capa dev: $output"
[[ "$dev_plan" == *shellcheck* ]] || fail "la capa dev no planificó sus herramientas base: $dev_plan"
plans_repo_package "$dev_plan" direnv || fail "la capa dev no planificó direnv: $dev_plan"
plans_repo_package "$dev_plan" xh || fail "la capa dev no planificó xh: $dev_plan"
for package in hyperfine oha; do
  plans_repo_package "$dev_plan" "$package" || fail "la capa dev no planificó $package: $dev_plan"
done
# Neovim with LazyVim: the editor, the tree-sitter CLI and C compiler for its
# parsers, and the search tools of its picker.
for package in neovim tree-sitter-cli gcc ripgrep fd unzip; do
  plans_repo_package "$dev_plan" "$package" || fail "la capa dev no planificó $package para Neovim: $dev_plan"
done
! plans_aur_package "$dev_plan" herdr-bin || fail "la capa dev base planificó herdr-bin de AUR: $dev_plan"
[[ "$dev_plan" != *docker* && "$dev_plan" != *pnpm* ]] || fail "la capa dev planificó features no pedidas: $dev_plan"

# A feature of an opt-in layer pulls the layer in and adds its packages.
output=$(plan_packages --profile core --feature dev-containers) || fail "el plan con dev-containers falló: $output"
dev_plan=$(layer_section "$output" dev)
[[ "$dev_plan" == *docker* ]] || fail "dev-containers no añadió docker a la capa dev: $output"
output=$(plan_packages --profile core --feature dev-js) || fail "el plan con dev-js falló: $output"
[[ "$(layer_section "$output" dev)" == *pnpm* ]] || fail "dev-js no añadió pnpm a la capa dev: $output"
output=$(plan_packages --profile core --feature dev-go) || fail "el plan con dev-go falló: $output"
dev_plan=$(layer_section "$output" dev)
for package in go golangci-lint delve; do
  plans_repo_package "$dev_plan" "$package" || fail "dev-go no añadió $package a la capa dev: $output"
done
output=$(plan_packages --profile core --feature dev-tauri) || fail "el plan con dev-tauri falló: $output"
dev_plan=$(layer_section "$output" dev)
for package in rustup webkit2gtk-4.1 base-devel libayatana-appindicator librsvg xdotool; do
  plans_repo_package "$dev_plan" "$package" || fail "dev-tauri no añadió $package a la capa dev: $output"
done
! plans_repo_package "$dev_plan" golangci-lint || fail "dev-tauri planificó paquetes de dev-go: $dev_plan"
# dev-herdr adds an AUR package, so it plans with an AUR backend.
output=$(plan_packages --profile core --feature dev-herdr --backend shelly) || \
  fail "el plan con dev-herdr falló: $output"
dev_plan=$(layer_section "$output" dev)
plans_aur_package "$dev_plan" herdr-bin || fail "dev-herdr no añadió herdr-bin desde AUR: $output"

# --feature dev-containers alone raises the profile to cli too.
output=$(plan_packages --profile core --feature dev-containers) || fail "el plan con dev-containers falló: $output"
[[ "$output" == *'Plan de la capa cli'* ]] || fail "dev-containers no aplicó la capa cli que requiere dev"

# A base feature still raises the profile to the layer declaring it.
output=$(plan_packages --profile core --feature yazi-extras) || fail "el plan con yazi-extras falló: $output"
[[ "$output" == *'Plan de la capa cli'* && "$output" != *'Plan de la capa dev'* ]] || \
  fail "yazi-extras dejó de aplicar solo la capa cli: $output"

# Only opt-in layers are accepted, with a usage error (exit 2) otherwise.
for name in nope core cli desktop system wm/bspwm ../core; do
  status=0
  run bootstrap --profile core --target "$H" --layer "$name" >/dev/null 2>&1 || status=$?
  (( status == 2 )) || fail "--layer $name no fue rechazado como error de uso (salida $status)"
done
status=0
run bootstrap --profile core --target "$H" --feature nope >/dev/null 2>&1 || status=$?
(( status == 2 )) || fail "una feature desconocida no fue rechazada (salida $status)"

# Applying links the layer and records it in the selection receipt.
run bootstrap --stow-only --apply --profile core --layer dev --target "$H" >/dev/null 2>&1 || \
  fail "bootstrap --apply con --layer dev falló"
dev_link="$H/.config/zsh/conf.d/50-dev.zsh"
[[ -L "$dev_link" ]] || fail "la capa dev no enlazó su configuración de zsh"
[[ "$(realpath -m -- "$dev_link")" == "$REPO_ROOT/layers/dev/home/"*/.config/zsh/conf.d/50-dev.zsh ]] || \
  fail "el enlace de la capa dev no apunta a layers/dev"
grep -Fxq 'LAYERS="dev"' "$RECEIPT" || fail "el recibo no guardó la capa opcional: $(<"$RECEIPT")"
nvim_link="$H/.config/nvim/init.lua"
[[ -L "$nvim_link" ]] || fail "la capa dev no enlazó la configuración de Neovim"
[[ "$(realpath -m -- "$nvim_link")" == "$REPO_ROOT/layers/dev/home/nvim/.config/nvim/init.lua" ]] || \
  fail "el enlace de Neovim no apunta a layers/dev"
# LazyVim loads the extras of the user's stack.
LAZY_SPEC="$REPO_ROOT/layers/dev/home/nvim/.config/nvim/lua/config/lazy.lua"
for extra in lang.typescript lang.vue lang.angular lang.astro lang.tailwind lang.go lang.rust lang.json \
             lang.yaml lang.toml lang.docker lang.markdown formatting.prettier linting.eslint dap.core test.core; do
  grep -Fq "{ import = \"lazyvim.plugins.extras.$extra\" }" "$LAZY_SPEC" || \
    fail "la configuración de LazyVim no importa el extra $extra"
done
# Every Lua file of the Neovim configuration parses.
if command -v luac >/dev/null; then
  while IFS= read -r -d '' lua_file; do
    luac -p -- "$lua_file" 2>/dev/null || fail "la configuración de Neovim no compila: $lua_file"
  done < <(find "$REPO_ROOT/layers/dev/home/nvim" -name '*.lua' -print0)
else
  printf 'SKIP: sintaxis Lua de Neovim (falta luac)\n'
fi

# The layer's zsh file puts pnpm and its binaries on PATH, for a pnpm installed
# standalone under PNPM_HOME as well as for a packaged one; without pnpm it
# changes nothing. Prints PNPM_HOME and PATH for home $1 and PATH $2.
dev_env() {
  # shellcheck disable=SC2016  # expanded by the zsh it runs
  env -u PNPM_HOME -u XDG_DATA_HOME HOME="$1" PATH="$2" "$ZSH_BIN" -dfc \
    'source "$1"; print -r -- "${PNPM_HOME:-unset} $PATH"' _ "$dev_link"
}
ZSH_BIN=$(command -v zsh)
PNPM_NONE="$TEST_ROOT/pnpm-none"
PNPM_PACKAGED="$TEST_ROOT/pnpm-packaged"
mkdir -p "$PNPM_NONE" "$PNPM_PACKAGED/bin" "$PNPM_PACKAGED/home"
printf '#!/bin/sh\n' > "$PNPM_PACKAGED/bin/pnpm"
chmod +x "$PNPM_PACKAGED/bin/pnpm"
pnpm_home="$H/.local/share/pnpm"
output=$(dev_env "$H" "$PNPM_NONE")
[[ "$output" == "unset $PNPM_NONE" ]] || fail "sin pnpm la capa dev cambió el entorno: $output"
output=$(dev_env "$PNPM_PACKAGED/home" "$PNPM_PACKAGED/bin")
packaged_home="$PNPM_PACKAGED/home/.local/share/pnpm"
[[ "$output" == "$packaged_home $packaged_home:$packaged_home/bin:$PNPM_PACKAGED/bin" ]] || \
  fail "con un pnpm empaquetado la capa dev no preparó el PATH: $output"

# With direnv installed the layer's zsh file loads its shell hook; without it,
# it does nothing.
direnv_hooked() {
  # shellcheck disable=SC2016  # expanded by the zsh it runs
  env HOME="$H" PATH="$1" "$ZSH_BIN" -dfc \
    'source "$1"; print -r -- "${DIRENV_HOOKED:-no}"' _ "$dev_link"
}
DIRENV_BIN="$TEST_ROOT/direnv-bin"
mkdir -p "$DIRENV_BIN"
# shellcheck disable=SC2016  # expanded by the fake direnv
printf '#!/bin/sh\n[ "$1 $2" = "hook zsh" ] && echo DIRENV_HOOKED=yes\n' > "$DIRENV_BIN/direnv"
chmod +x "$DIRENV_BIN/direnv"
[[ $(direnv_hooked "$DIRENV_BIN") == yes ]] || fail 'con direnv la capa dev no cargó su hook de zsh'
[[ $(direnv_hooked "$PNPM_NONE") == no ]] || fail 'sin direnv la capa dev intentó cargar su hook'

# With Neovim installed the layer makes it the editor (EDITOR, VISUAL and git's
# GIT_EDITOR, over core's micro default); without it, micro stays.
dev_editor() {
  # shellcheck disable=SC2016  # expanded by the zsh it runs
  env -u GIT_EDITOR EDITOR="${2:-micro}" VISUAL="${2:-micro}" HOME="$H" PATH="$1" "$ZSH_BIN" -dfc \
    'source "$1"; print -r -- "$EDITOR $VISUAL ${GIT_EDITOR:-unset}"' _ "$dev_link"
}
NVIM_BIN="$TEST_ROOT/nvim-bin"
mkdir -p "$NVIM_BIN"
printf '#!/bin/sh\n' > "$NVIM_BIN/nvim"
chmod +x "$NVIM_BIN/nvim"
output=$(dev_editor "$NVIM_BIN")
[[ "$output" == 'nvim nvim nvim' ]] || fail "con Neovim la capa dev no lo hizo el editor: $output"
output=$(dev_editor "$PNPM_NONE")
[[ "$output" == 'micro micro unset' ]] || fail "sin Neovim la capa dev cambió el editor: $output"
# An editor the user chose (exported before core's micro default) is kept, and
# git follows it instead of core.editor (micro).
output=$(dev_editor "$NVIM_BIN" helix)
[[ "$output" == 'helix helix helix' ]] || fail "con Neovim la capa dev pisó el editor elegido o git no lo sigue: $output"
mkdir -p "$pnpm_home/bin"
printf '#!/bin/sh\n' > "$pnpm_home/pnpm"
chmod +x "$pnpm_home/pnpm"
output=$(dev_env "$H" "$PNPM_NONE")
[[ "$output" == "$pnpm_home $pnpm_home:$pnpm_home/bin:$PNPM_NONE" ]] || \
  fail "con un pnpm independiente la capa dev no preparó el PATH: $output"
rm -rf -- "$pnpm_home"

# sync without flags restores the recorded opt-in layer.
rm -f -- "$dev_link"
output=$(run sync --stow-only --target "$H" 2>&1) || fail "sync falló: $output"
[[ "$output" == *'Plan de la capa dev'* ]] || fail "sync no restauró la capa dev del recibo: $output"
[[ -L "$dev_link" ]] || fail "sync no volvió a enlazar la capa dev"

# Overriding another selection field on sync keeps the recorded layers.
output=$(run sync --stow-only --profile core --target "$H" 2>&1) || fail "sync --profile core falló: $output"
grep -Fxq 'LAYERS="dev"' "$RECEIPT" || fail "sync sin --layer perdió la capa del recibo: $(<"$RECEIPT")"
[[ "$output" != *'Se retiran:'* ]] || fail "sync --profile core retiró parte de la selección guardada: $output"
[[ -L "$dev_link" ]] || fail "sync --profile core retiró la capa dev guardada"

# An unknown layer in the receipt is ignored with a warning.
sed -i 's/^LAYERS=.*/LAYERS="dev nope"/' "$RECEIPT"
output=$(run sync --stow-only --target "$H" 2>&1) || fail "sync falló con una capa inválida en el recibo: $output"
[[ "$output" == *'se ignora una capa inválida en el recibo de selección: nope'* ]] || \
  fail "sync no avisó de la capa inválida del recibo: $output"

# unlink removes the opt-in layer's links too.
run unlink --apply --profile core --layer dev --target "$H" >/dev/null 2>&1 || fail "unlink con --layer dev falló"
[[ ! -e "$dev_link" && ! -L "$dev_link" ]] || fail "unlink no retiró el enlace de la capa dev"

[[ "$(git -C "$REPO_ROOT" status --porcelain)" == "$CHECKOUT_STATE" ]] || fail "las capas opcionales modificaron el checkout"

printf 'OK: capas opcionales validadas\n'
