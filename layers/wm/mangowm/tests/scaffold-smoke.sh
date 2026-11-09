#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
# The layer lives at layers/wm/mangowm inside the monorepo.
MONOREPO_ROOT=$(cd -- "$REPO_ROOT/../../.." && pwd -P)
# Palettes are shared by every WM and live at the repository root.
PALETTE="$MONOREPO_ROOT/themes/palettes/catppuccin-mocha-pink.conf"
TEMPLATES="$REPO_ROOT/home/mango/.local/share/dotfiles/theme/templates/mangowm"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_manifest_line() {
  local file=$1
  local expected=$2

  grep -Fxq -- "$expected" "$file" || \
    fail "$file no declara $expected"
}

check_manifest() {
  local file=$1
  local duplicate

  [[ -f "$file" ]] || fail "falta el manifest $file"

  if ! awk '
    /^[[:space:]]*($|#)/ { next }
    /^[a-z0-9][a-z0-9@._+:-]*$/ { next }
    { exit 1 }
  ' "$file"; then
    fail "$file contiene una entrada inválida"
  fi

  duplicate=$(awk '!/^[[:space:]]*($|#)/ { print }' "$file" | \
    LC_ALL=C sort | uniq -d | head -n 1)
  [[ -z "$duplicate" ]] || fail "$file duplica $duplicate"

  awk '!/^[[:space:]]*($|#)/ { print }' "$file" | \
    LC_ALL=C sort -C || fail "$file no está ordenado"
}

check_backend_order() {
  local file=$1
  local actual
  local expected=$'shelly\nparu\nyay\npacman'

  [[ -f "$file" ]] || fail "falta el manifest $file"

  if ! awk '
    /^[[:space:]]*($|#)/ { next }
    /^[a-z0-9][a-z0-9@._+:-]*$/ { next }
    { exit 1 }
  ' "$file"; then
    fail "$file contiene una entrada inválida"
  fi

  actual=$(awk '!/^[[:space:]]*($|#)/ { print }' "$file")
  [[ "$actual" == "$expected" ]] || \
    fail "$file no conserva el orden shelly, paru, yay, pacman"
}

for manifest in \
  "$REPO_ROOT"/packages/{repo,aur,external,stow}/{core,desktop}.txt \
  "$REPO_ROOT"/packages/cachyos/{core,desktop}.txt \
  "$REPO_ROOT"/packages/aur/{core,desktop}-fallback.txt; do
  check_manifest "$manifest"
done
# The backend order is shared by every layer and lives at the repository root.
check_backend_order "$MONOREPO_ROOT/packages/package-backends.txt"

assert_manifest_line "$REPO_ROOT/packages/repo/core.txt" mangowm
assert_manifest_line "$REPO_ROOT/packages/cachyos/core.txt" swaylock-effects
assert_manifest_line "$REPO_ROOT/packages/cachyos/desktop.txt" wlogout
assert_manifest_line "$REPO_ROOT/packages/aur/core-fallback.txt" swaylock-effects
assert_manifest_line "$REPO_ROOT/packages/aur/desktop-fallback.txt" wlogout
# foot comes from the desktop layer every WM layer requires.
assert_manifest_line "$MONOREPO_ROOT/layers/desktop/packages/repo/desktop.txt" foot
assert_manifest_line "$REPO_ROOT/packages/repo/core.txt" fuzzel
assert_manifest_line "$REPO_ROOT/packages/repo/core.txt" swayidle
assert_manifest_line "$REPO_ROOT/packages/repo/desktop.txt" waybar
assert_manifest_line "$REPO_ROOT/packages/repo/desktop.txt" satty
assert_manifest_line "$REPO_ROOT/packages/repo/desktop.txt" xdg-user-dirs
assert_manifest_line "$REPO_ROOT/packages/repo/desktop.txt" brightnessctl
assert_manifest_line "$REPO_ROOT/packages/repo/desktop.txt" wf-recorder
# bluetui (TUI) replaces blueman; Waybar keeps its native bluetooth module.
assert_manifest_line "$REPO_ROOT/packages/repo/desktop.txt" bluetui
if found=$(grep -rn blueman "$MONOREPO_ROOT/layers" --exclude-dir=tests --exclude='*.md'); then
  fail "blueman sigue referenciado:"$'\n'"$found"
fi
assert_manifest_line "$REPO_ROOT/packages/stow/core.txt" mango

if grep -ERq '^(mangowc-git|mangowm-git|hyprlock|hypridle|rofi|wofi|cliphist|wl-clip-persist|python-pywal|pulsemixer|xdg-desktop-portal-gnome)$' \
    "$REPO_ROOT/packages"; then
  fail "los manifests seleccionan un componente excluido por D34"
fi

[[ -f "$REPO_ROOT/home/.stow" ]] || fail "falta el marcador home/.stow"
[[ -f "$REPO_ROOT/layer.conf" ]] || fail "falta layer.conf"
[[ -x "$REPO_ROOT/hooks/validate" ]] || fail "hooks/validate no es ejecutable"
[[ -x "$REPO_ROOT/hooks/post-link" ]] || fail "hooks/post-link no es ejecutable"
[[ -f "$REPO_ROOT/home/mango/.config/mango/config.conf" ]] || \
  fail "falta el entrypoint modular de MangoWM"
[[ -f "$REPO_ROOT/home/mango/.config/waybar/config.json" ]] || \
  fail "falta Waybar en el perfil desktop"
[[ -x "$REPO_ROOT/home/mango/.local/bin/mango-theme" ]] || \
  fail "falta el renderer de tema"
[[ -f "$MONOREPO_ROOT/THIRD_PARTY_NOTICES.md" ]] || \
  fail "falta la atribución de la paleta"
# MangoWM only contributes templates and a reload hook to the shared engine.
[[ ! -e "$REPO_ROOT/themes" ]] || \
  fail "layers/wm/mangowm/themes duplica las paletas compartidas"
for template in mango.conf foot.ini fuzzel.ini mako.conf swaylock.conf \
  waybar.css wlogout.css xdg-config/satty/config.toml \
  icons/{suspend,logout,reboot,shutdown}{,-dark}.svg; do
  [[ -s "$TEMPLATES/$template" ]] || fail "falta la plantilla mangowm/$template"
done
for shared_output in gtk.css yazi background metadata; do
  [[ ! -e "$TEMPLATES/$shared_output" ]] || \
    fail "mangowm/$shared_output es un output compartido del motor"
done
grep -Fxq 'ignore-empty-password' "$TEMPLATES/swaylock.conf" || \
  fail "la plantilla de Swaylock permite passwords vacíos"
[[ -x "$REPO_ROOT/home/mango/.local/share/dotfiles/theme/reload.d/mangowm" ]] || \
  fail "falta el hook de recarga ejecutable reload.d/mangowm"
if grep -Fq 'render_waybar' "$REPO_ROOT/home/mango/.local/bin/mango-theme"; then
  fail "mango-theme sigue renderizando en lugar de delegar en dotfiles-theme"
fi

# Catppuccin Mocha accent colors; schema 2 has no per-name keys, so the
# semantic accent is checked against this table.
declare -A mocha_accents=(
  [rosewater]='#f5e0dc' [flamingo]='#f2cdcd' [pink]='#f5c2e7' [mauve]='#cba6f7'
  [red]='#f38ba8' [maroon]='#eba0ac' [peach]='#fab387' [yellow]='#f9e2af'
  [green]='#a6e3a1' [teal]='#94e2d5' [sky]='#89dceb' [sapphire]='#74c7ec'
  [blue]='#89b4fa' [lavender]='#b4befe'
)
ENGINE="$MONOREPO_ROOT/layers/desktop/home/theme/.local/bin/dotfiles-theme"
[[ -x "$ENGINE" ]] || fail "falta el motor de temas: $ENGINE"
VALIDATE_HOME=$(mktemp -d "${TMPDIR:-/tmp}/mangowm-scaffold-smoke.XXXXXX")
trap 'rm -rf -- "$VALIDATE_HOME"' EXIT

# Value of key $2 in palette $1.
palette_value() {
  sed -n "s/^$2=//p" "$1"
}

# The engine owns the schema: it validates every key, its type and the id;
# this layer only checks that the palette is a Catppuccin Mocha accent.
check_palette() {
  local palette=$1 expected_id expected_accent output

  expected_id=$(basename -- "$palette" .conf)
  expected_accent="${expected_id#catppuccin-mocha-}"
  output=$(env -u DOTFILES_THEME HOME="$VALIDATE_HOME" XDG_STATE_HOME="$VALIDATE_HOME/state" \
    XDG_DATA_HOME="$VALIDATE_HOME/share" XDG_CONFIG_HOME="$VALIDATE_HOME/config" \
    "$ENGINE" validate "$expected_id" 2>&1) || fail "dotfiles-theme rechazó $palette: $output"
  [[ "$(palette_value "$palette" family)" == catppuccin ]] || fail "familia de paleta inesperada en $palette"
  [[ "$(palette_value "$palette" flavour)" == mocha ]] || fail "flavour de paleta inesperado en $palette"
  [[ "$(palette_value "$palette" accent_name)" == "$expected_accent" ]] || \
    fail "acento de paleta inesperado en $palette"
  [[ -v "mocha_accents[$expected_accent]" ]] || \
    fail "acento desconocido de Catppuccin Mocha: $expected_accent"
  [[ "$(palette_value "$palette" accent)" == "${mocha_accents[$expected_accent]}" ]] || \
    fail "el acento semántico en $palette no coincide con el color de $expected_accent"
}

found_palettes=0
for palette_file in "$MONOREPO_ROOT"/themes/palettes/*.conf; do
  [[ -f "$palette_file" ]] || continue
  check_palette "$palette_file"
  ((found_palettes++)) || true
done
[[ "$found_palettes" -ge 14 ]] || fail "se esperaban al menos 14 paletas Catppuccin Mocha, encontradas: $found_palettes"

grep -Fxq 'hue_pink=#f5c2e7' "$PALETTE" || fail "Pink no coincide con Catppuccin Mocha"
grep -Fxq 'accent=#f5c2e7' "$PALETTE" || fail "Pink no es el acento semántico"
grep -Fqx "bind=SUPER+ALT,T,spawn,\$HOME/.local/bin/mango-theme menu" \
  "$REPO_ROOT/home/mango/.config/mango/conf.d/50-desktop.conf" || \
  fail "falta el atajo Super+Alt+T para mango-theme menu en 50-desktop.conf"

grep -Fq 'MangoWM' "$REPO_ROOT/README.md" || \
  fail "README.md no describe MangoWM"
grep -Fq 'MangoWM' "$REPO_ROOT/README.es.md" || \
  fail "README.es.md no describe MangoWM"

printf 'OK: scaffold, manifests y paleta MangoWM validados\n'
