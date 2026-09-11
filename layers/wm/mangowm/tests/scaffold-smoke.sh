#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
PALETTE="$REPO_ROOT/themes/catppuccin-mocha-pink/palette.conf"

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
  "$REPO_ROOT"/packages/{repo,aur,external,stow}/{core,desktop}.txt; do
  check_manifest "$manifest"
done
check_backend_order "$REPO_ROOT/packages/package-backends.txt"

assert_manifest_line "$REPO_ROOT/packages/aur/core.txt" mangowm
assert_manifest_line "$REPO_ROOT/packages/aur/desktop.txt" wlogout
assert_manifest_line "$REPO_ROOT/packages/repo/core.txt" foot
assert_manifest_line "$REPO_ROOT/packages/repo/core.txt" fuzzel
assert_manifest_line "$REPO_ROOT/packages/aur/core.txt" swaylock-effects-git
assert_manifest_line "$REPO_ROOT/packages/repo/core.txt" swayidle
assert_manifest_line "$REPO_ROOT/packages/repo/desktop.txt" waybar
assert_manifest_line "$REPO_ROOT/packages/repo/desktop.txt" satty
assert_manifest_line "$REPO_ROOT/packages/repo/desktop.txt" xdg-user-dirs
assert_manifest_line "$REPO_ROOT/packages/repo/desktop.txt" brightnessctl
assert_manifest_line "$REPO_ROOT/packages/repo/desktop.txt" wf-recorder
assert_manifest_line "$REPO_ROOT/packages/stow/core.txt" mango

if grep -ERq '^(mangowc-git|mangowm-git|hyprlock|hypridle|rofi|wofi|cliphist|wl-clip-persist|python-pywal|pulsemixer|xdg-desktop-portal-gnome)$' \
    "$REPO_ROOT/packages"/{repo,aur}; then
  fail "los manifests seleccionan un componente excluido por D34"
fi

[[ -f "$REPO_ROOT/home/.stow" ]] || fail "falta el marcador home/.stow"
[[ -x "$REPO_ROOT/bin/mango" ]] || fail "bin/mango no es ejecutable"
[[ -f "$REPO_ROOT/home/mango/.config/mango/config.conf" ]] || \
  fail "falta el entrypoint modular de MangoWM"
[[ -f "$REPO_ROOT/home/mango/.config/waybar/config.json" ]] || \
  fail "falta Waybar en el perfil desktop"
[[ -x "$REPO_ROOT/home/mango/.local/bin/mango-theme" ]] || \
  fail "falta el renderer de tema"
[[ -f "$REPO_ROOT/THIRD_PARTY_NOTICES.md" ]] || \
  fail "falta la atribución de la paleta"
[[ -f "$REPO_ROOT/themes/templates/yazi-flavor.toml" ]] || \
  fail "falta el template de tema para yazi"

declare -A expected_keys=()

for key in \
  schema id family flavour accent_name \
  rosewater flamingo pink mauve red maroon peach yellow green teal sky \
  sapphire blue lavender text subtext1 subtext0 overlay2 overlay1 overlay0 \
  surface2 surface1 surface0 base mantle crust \
  background background_alt background_deep surface surface_hover foreground \
  foreground_muted accent urgent warning success; do
  expected_keys[$key]=1
done

check_palette() {
  local palette=$1
  local expected_id
  expected_id=$(basename -- "$(dirname -- "$palette")")
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
        [[ "$value" == 1 ]] || fail "schema de paleta no soportado en $palette"
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
      *)
        [[ "$value" =~ ^#[0-9a-f]{6}$ ]] || \
          fail "color inválido para $key en $palette"
        ;;
    esac
  done < "$palette"

  for key in "${!expected_keys[@]}"; do
    [[ -v "seen_keys[$key]" ]] || fail "falta la clave de paleta $key en $palette"
  done

  local expected_color="${palette_values[$expected_accent]}"
  [[ "${palette_values[accent]}" == "$expected_color" ]] || \
    fail "el acento semántico en $palette no coincide con el color de $expected_accent"
}

found_palettes=0
for palette_file in "$REPO_ROOT"/themes/*/palette.conf; do
  [[ -f "$palette_file" ]] || continue
  check_palette "$palette_file"
  ((found_palettes++)) || true
done
[[ "$found_palettes" -ge 14 ]] || fail "se esperaban al menos 14 paletas Catppuccin Mocha, encontradas: $found_palettes"

grep -Fxq 'pink=#f5c2e7' "$PALETTE" || fail "Pink no coincide con Catppuccin Mocha"
grep -Fxq 'accent=#f5c2e7' "$PALETTE" || fail "Pink no es el acento semántico"
grep -Fqx "bind=SUPER+ALT,T,spawn,\$HOME/.local/bin/mango-theme menu" \
  "$REPO_ROOT/home/mango/.config/mango/conf.d/50-desktop.conf" || \
  fail "falta el atajo Super+Alt+T para mango-theme menu en 50-desktop.conf"

grep -Fq 'MangoWM' "$REPO_ROOT/README.md" || \
  fail "README.md no describe MangoWM"
grep -Fq 'MangoWM' "$REPO_ROOT/README.es.md" || \
  fail "README.es.md no describe MangoWM"

printf 'OK: scaffold, manifests y paleta MangoWM validados\n'
