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

declare -A expected_keys=()

for key in \
  schema id family flavour accent_name \
  background_deep background_alt background surface surface_hover surface_strong \
  foreground foreground_muted foreground_subtle foreground_disabled border \
  accent accent_fg urgent warning success info \
  selection_bg selection_fg cursor cursor_fg \
  ansi_black ansi_red ansi_green ansi_yellow ansi_blue ansi_magenta ansi_cyan ansi_white \
  ansi_bright_black ansi_bright_red ansi_bright_green ansi_bright_yellow \
  ansi_bright_blue ansi_bright_magenta ansi_bright_cyan ansi_bright_white \
  syntax_keyword syntax_string syntax_number syntax_constant syntax_function \
  syntax_type syntax_property syntax_tag syntax_operator syntax_regex \
  syntax_variable syntax_punctuation syntax_comment \
  hue_red hue_orange hue_yellow hue_green hue_teal hue_cyan hue_blue hue_indigo \
  hue_purple hue_pink hue_rose hue_maroon \
  font_mono font_text font_display font_inscription cursor_theme cursor_size; do
  expected_keys[$key]=1
done

# Catppuccin Mocha accent colors; schema 2 has no per-name keys, so the
# semantic accent is checked against this table.
declare -A mocha_accents=(
  [rosewater]='#f5e0dc' [flamingo]='#f2cdcd' [pink]='#f5c2e7' [mauve]='#cba6f7'
  [red]='#f38ba8' [maroon]='#eba0ac' [peach]='#fab387' [yellow]='#f9e2af'
  [green]='#a6e3a1' [teal]='#94e2d5' [sky]='#89dceb' [sapphire]='#74c7ec'
  [blue]='#89b4fa' [lavender]='#b4befe'
)

check_palette() {
  local palette=$1
  local expected_id
  expected_id=$(basename -- "$palette" .conf)
  local expected_accent="${expected_id#catppuccin-mocha-}"

  declare -A seen_keys=()
  declare -A palette_values=()

  while IFS='=' read -r key value; do
    [[ -n "$key" && -n "$value" ]] || fail "línea inválida en $palette"
    [[ -v "expected_keys[$key]" ]] || fail "clave de paleta desconocida: $key en $palette"
    [[ ! -v "seen_keys[$key]" ]] || fail "clave de paleta duplicada: $key en $palette"
    seen_keys[$key]=1
    palette_values[$key]="$value"

    case "$key" in
      schema)
        [[ "$value" == 2 ]] || fail "schema de paleta no soportado en $palette"
        ;;
      id)
        [[ "$value" == "$expected_id" ]] || fail "id de paleta inesperado en $palette"
        ;;
      family)
        [[ "$value" == catppuccin ]] || fail "familia de paleta inesperada en $palette"
        ;;
      flavour)
        [[ "$value" == mocha ]] || fail "flavour de paleta inesperado en $palette"
        ;;
      accent_name)
        [[ "$value" == "$expected_accent" ]] || fail "acento de paleta inesperado en $palette"
        ;;
      font_*)
        [[ "$value" =~ ^[A-Za-z0-9][A-Za-z0-9\ ]*$ ]] || \
          fail "fuente inválida para $key en $palette"
        ;;
      cursor_theme)
        [[ "$value" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || \
          fail "cursor inválido en $palette"
        ;;
      cursor_size)
        [[ "$value" =~ ^[0-9]{2,3}$ ]] || fail "tamaño de cursor inválido en $palette"
        ;;
      *)
        [[ "$value" =~ ^#[0-9a-f]{6}$ ]] || \
          fail "color inválido para $key en $palette"
        ;;
    esac
  done < "$palette"

  for key in "${!expected_keys[@]}"; do
    [[ -v "seen_keys[$key]" ]] || fail "falta la clave de paleta $key en $palette"
  done

  [[ -v "mocha_accents[$expected_accent]" ]] || \
    fail "acento desconocido de Catppuccin Mocha: $expected_accent"
  [[ "${palette_values[accent]}" == "${mocha_accents[$expected_accent]}" ]] || \
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
