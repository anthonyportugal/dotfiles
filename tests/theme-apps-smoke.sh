#!/usr/bin/env bash
# Renders every palette with the shared and MangoWM templates into a
# throwaway home and checks the application outputs: each one exists, has no
# leftover marker and carries the palette values, and the stowed configs read
# it from the rendered theme.

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
ENGINE="$REPO_ROOT/layers/desktop/home/theme/.local/bin/dotfiles-theme"
SHARED_TEMPLATES="$REPO_ROOT/themes/templates"
MANGO_TEMPLATES="$REPO_ROOT/layers/wm/mangowm/home/mango/.local/share/dotfiles/theme/templates/mangowm"
DESKTOP_HOME="$REPO_ROOT/layers/desktop/home"
# The literal path the stowed configs write; their apps expand the tilde.
# shellcheck disable=SC2088
CURRENT_PATH='~/.local/state/dotfiles/theme/current'
TEST_ROOT=""
TEST_TMP_PARENT=${DOTFILES_TEST_TMPDIR:-/tmp}

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  [[ -n "$TEST_ROOT" && "$TEST_ROOT" == "$TEST_TMP_PARENT"/dotfiles-theme-apps-smoke.* ]] || return 0
  rm -rf -- "$TEST_ROOT"
}

trap cleanup EXIT

[[ -x "$ENGINE" ]] || fail "falta el motor de temas: $ENGINE"
[[ -d "$TEST_TMP_PARENT" ]] || fail "no existe el directorio temporal: $TEST_TMP_PARENT"
TEST_ROOT=$(mktemp -d "$TEST_TMP_PARENT/dotfiles-theme-apps-smoke.XXXXXX")

# Value of key $2 in palette $1, and the same color without its '#'.
palette_value() {
  sed -n "s/^$2=//p" "$1"
}

raw_value() {
  local value
  value=$(palette_value "$1" "$2")
  printf '%s\n' "${value#\#}"
}

# Fails unless file $1 holds the exact line $2.
expect_line() {
  grep -Fxq -- "$2" "$1" || fail "falta '$2' en ${1#"$TEST_ROOT"/}"
}

# Fails unless file $1 exists, is not empty and has no {{ marker left; a grep
# error (exit 2) fails too instead of passing as "no match".
expect_rendered() {
  local status=0

  [[ -s "$1" ]] || fail "output vacío o ausente: ${1#"$TEST_ROOT"/}"
  grep -Fq '{{' "$1" || status=$?
  case "$status" in
    0) fail "marcadores sin renderizar en ${1#"$TEST_ROOT"/}" ;;
    1) ;;
    *) fail "grep falló ($status) en ${1#"$TEST_ROOT"/}" ;;
  esac
}

# Fails when template $1 still holds a literal #rrggbb color.
expect_no_hex() {
  local status=0

  grep -Eq '#[0-9a-fA-F]{6}\b' "$1" || status=$?
  case "$status" in
    0) fail "${1#"$REPO_ROOT"/} conserva colores hexadecimales fijos" ;;
    1) ;;
    *) fail "grep falló ($status) en ${1#"$REPO_ROOT"/}" ;;
  esac
}

# Section [colors-dark] of foot config $1, up to the end of the file.
foot_colors() {
  sed -n '/^\[colors-dark\]$/,$p' "$1"
}

# Renders palette $1 into the throwaway home $2 and prints the revision.
render_in() {
  local id=$1 home=$2

  mkdir -p "$home/.local/share/dotfiles/theme/templates"
  cp -R -- "$MANGO_TEMPLATES" "$home/.local/share/dotfiles/theme/templates/"
  env -u DOTFILES_THEME HOME="$home" XDG_STATE_HOME="$home/.local/state" \
    XDG_DATA_HOME="$home/.local/share" XDG_CONFIG_HOME="$home/.config" XDG_CACHE_HOME="$home/.cache" \
    "$ENGINE" render "$id" || fail "no se pudo renderizar $id"
}

# Terminals: alacritty imports and foot includes the rendered file; both
# follow the palette, and foot shares its color block with MangoWM.
check_terminals() {
  local palette=$1 revision=$2 index color
  local -a ansi=(black red green yellow blue magenta cyan white)

  expect_rendered "$revision/alacritty/theme.toml"
  expect_line "$revision/alacritty/theme.toml" "background = \"$(palette_value "$palette" background)\""
  expect_line "$revision/alacritty/theme.toml" "foreground = \"$(palette_value "$palette" foreground)\""
  expect_line "$revision/alacritty/theme.toml" "cursor = \"$(palette_value "$palette" cursor)\""
  expect_line "$revision/alacritty/theme.toml" "family = \"$(palette_value "$palette" font_mono)\""
  for index in "${!ansi[@]}"; do
    color=${ansi[$index]}
    expect_line "$revision/alacritty/theme.toml" "$color = \"$(palette_value "$palette" "ansi_$color")\""
  done
  python3 -c 'import sys, tomllib; tomllib.load(open(sys.argv[1], "rb"))' \
    "$revision/alacritty/theme.toml" || fail "alacritty/theme.toml no es TOML válido"

  expect_rendered "$revision/foot/theme.ini"
  expect_line "$revision/foot/theme.ini" "font=$(palette_value "$palette" font_mono):size=11"
  expect_line "$revision/foot/theme.ini" "background=$(raw_value "$palette" background)"
  expect_line "$revision/foot/theme.ini" "cursor=$(raw_value "$palette" cursor_fg) $(raw_value "$palette" cursor)"
  expect_line "$revision/foot/theme.ini" "urls=$(raw_value "$palette" accent)"
  for index in "${!ansi[@]}"; do
    color=${ansi[$index]}
    expect_line "$revision/foot/theme.ini" "regular$index=$(raw_value "$palette" "ansi_$color")"
    expect_line "$revision/foot/theme.ini" "bright$index=$(raw_value "$palette" "ansi_bright_$color")"
  done
  [[ "$(foot_colors "$revision/foot/theme.ini")" == "$(foot_colors "$revision/mangowm/foot.ini")" ]] || \
    fail "foot y MangoWM renderizan bloques de color distintos"
}

# CLI tools: every output carries the palette and parses.
check_cli() {
  local palette=$1 revision=$2 output

  for output in bat/dotfiles.tmTheme btop/dotfiles.theme lazygit/theme.yml \
                micro/default.micro fzf/options; do
    expect_rendered "$revision/$output"
  done
  python3 - "$revision/bat/dotfiles.tmTheme" "$palette" <<'PY' || fail "bat/dotfiles.tmTheme no lleva la paleta"
import plistlib, sys
theme = plistlib.load(open(sys.argv[1], "rb"))
palette = dict(line.rstrip("\n").split("=", 1) for line in open(sys.argv[2]) if "=" in line)
main = theme["settings"][0]["settings"]
scopes = {entry.get("scope"): entry["settings"] for entry in theme["settings"][1:]}
assert theme["name"] == palette["id"]
assert main["background"] == palette["background"]
assert main["foreground"] == palette["foreground"]
assert scopes["string"]["foreground"] == palette["syntax_string"]
assert scopes["entity.name.function, variable.function"]["foreground"] == palette["syntax_function"]
PY
  expect_line "$revision/btop/dotfiles.theme" "theme[main_bg]=\"$(palette_value "$palette" background)\""
  expect_line "$revision/btop/dotfiles.theme" "theme[main_fg]=\"$(palette_value "$palette" foreground)\""
  expect_line "$revision/lazygit/theme.yml" "      - '$(palette_value "$palette" accent)'"
  expect_line "$revision/micro/default.micro" \
    "color-link default \"$(palette_value "$palette" foreground),$(palette_value "$palette" background)\""
  expect_line "$revision/micro/default.micro" \
    "color-link current-line-number \"$(palette_value "$palette" accent)\""
  output=$(cat "$revision/fzf/options")
  [[ "$output" == *"bg:$(palette_value "$palette" background),"* ]] || fail "fzf/options no lleva el fondo"
  expect_rendered "$revision/nvim/palette.lua"
  expect_line "$revision/nvim/palette.lua" "    base00 = \"$(palette_value "$palette" background)\","
  expect_line "$revision/nvim/palette.lua" "    base0D = \"$(palette_value "$palette" syntax_function)\","
  expect_line "$revision/nvim/palette.lua" "  accent = \"$(palette_value "$palette" accent)\","
  if command -v luac >/dev/null; then
    luac -p -- "$revision/nvim/palette.lua" || fail "nvim/palette.lua no es Lua válido"
  fi
  check_nvim_colorscheme "$revision"
}

# Loads Neovim's dotfiles colorscheme against revision $1 under a stub `vim`
# and mini.base16 (LuaJIT, as Neovim): it must name itself and set only hex
# colors. Skipped without luajit.
check_nvim_colorscheme() {
  local state

  command -v luajit >/dev/null || return 0
  state=$(mktemp -d -p "$TEST_ROOT")
  mkdir -p "$state/dotfiles/theme"
  ln -s "$1" "$state/dotfiles/theme/current"
  XDG_STATE_HOME="$state" luajit - "$REPO_ROOT/layers/dev/home/nvim/.config/nvim/colors/dotfiles.lua" <<'LUA' || \
    fail "el colorscheme dotfiles de Neovim falló con ${1#"$TEST_ROOT"/}"
local function hex(group, value)
  assert(type(value) ~= "string" or value:match("^#%x%x%x%x%x%x$"), group .. ": " .. tostring(value))
end
vim = {
  env = { XDG_STATE_HOME = os.getenv("XDG_STATE_HOME") }, o = {}, g = {}, cmd = function() end,
  api = { nvim_set_hl = function(_, group, spec) for _, v in pairs(spec) do hex(group, v) end end },
}
package.preload["mini.base16"] = function()
  return { setup = function(config) for k, v in pairs(config.palette) do hex(k, v) end end }
end
package.path = arg[1]:gsub("/colors/dotfiles.lua$", "/lua/?.lua;") .. package.path
dofile(arg[1])
assert(vim.g.colors_name == "dotfiles", "colors_name")
assert(vim.o.background == "dark" or vim.o.background == "light", "background")
LUA
}

# Fails when rendered file $2 holds a #rrggbb color that is not a value of
# palette $1, so every color in it comes from the palette.
expect_palette_colors() {
  local palette=$1 file=$2 foreign

  foreign=$(comm -23 \
    <(grep -oE '#[0-9a-fA-F]{6}\b' "$file" | tr 'A-F' 'a-f' | LC_ALL=C sort -u) \
    <(sed -n 's/^[a-z_]*=\(#[0-9a-fA-F]\{6\}\)$/\1/p' "$palette" | tr 'A-F' 'a-f' | LC_ALL=C sort -u))
  [[ -z "$foreign" ]] || fail "${file#"$TEST_ROOT"/} usa colores ajenos a la paleta: ${foreign//$'\n'/ }"
}

# Yazi: the flavor parses, takes every color from the palette and highlights
# previews with the rendered bat theme.
check_yazi() {
  local palette=$1 revision=$2 flavor="$2/yazi/flavor.toml"

  expect_rendered "$flavor"
  python3 -c 'import sys, tomllib; tomllib.load(open(sys.argv[1], "rb"))' "$flavor" || \
    fail "yazi/flavor.toml no es TOML válido"
  expect_palette_colors "$palette" "$flavor"
  expect_line "$flavor" "overall = { bg = \"$(palette_value "$palette" background)\" }"
  expect_line "$flavor" 'syntect_theme = "~/.config/bat/themes/dotfiles.tmTheme"'
}

# GTK: the rendered stylesheet defines the named colors from the palette;
# the stowed gtk-3.0/gtk-4.0 files only import it.
check_gtk() {
  local palette=$1 css="$2/gtk.css"

  expect_rendered "$css"
  expect_palette_colors "$palette" "$css"
  expect_line "$css" "@define-color accent_color $(palette_value "$palette" accent);"
  expect_line "$css" "@define-color window_bg_color $(palette_value "$palette" background);"
  expect_line "$css" "@define-color view_bg_color $(palette_value "$palette" background_alt);"
  expect_line "$css" "@define-color error_color $(palette_value "$palette" urgent);"
  expect_line "$css" '@define-color shade_color rgba(0, 0, 0, 0.36);'
  [[ "$(tr -cd '{' < "$css" | wc -c)" == "$(tr -cd '}' < "$css" | wc -c)" ]] || \
    fail "gtk.css tiene llaves desbalanceadas"
}

rendered=0
for palette in "$REPO_ROOT"/themes/palettes/*.conf; do
  [[ -f "$palette" ]] || continue
  id=$(basename -- "$palette" .conf)
  revision=$(render_in "$id" "$TEST_ROOT/$id")
  check_terminals "$palette" "$revision"
  check_cli "$palette" "$revision"
  check_yazi "$palette" "$revision"
  check_gtk "$palette" "$revision"
  ((rendered++)) || true
done
(( rendered >= 50 )) || fail "se esperaban al menos 50 paletas, renderizadas: $rendered"

# One color definition for foot: the MangoWM template carries the same
# [colors-dark] block as the shared template.
[[ -n "$(foot_colors "$SHARED_TEMPLATES/foot/theme.ini")" ]] || \
  fail "la plantilla compartida de foot no define [colors-dark]"
[[ "$(foot_colors "$SHARED_TEMPLATES/foot/theme.ini")" == "$(foot_colors "$MANGO_TEMPLATES/foot.ini")" ]] || \
  fail "la plantilla de foot de MangoWM diverge del bloque de color compartido"
grep -Fxq 'font={{font_mono}}:size=10' "$MANGO_TEMPLATES/foot.ini" || \
  fail "la plantilla de foot de MangoWM no toma la fuente de font_mono"

# The stowed terminal configs read the rendered files and keep no colors.
ALACRITTY="$DESKTOP_HOME/alacritty/.config/alacritty/alacritty.toml"
FOOT="$DESKTOP_HOME/foot/.config/foot/foot.ini"
expect_line "$ALACRITTY" "import = [\"$CURRENT_PATH/alacritty/theme.toml\"]"
expect_no_hex "$ALACRITTY"
grep -Eq '^family' "$ALACRITTY" && fail "alacritty.toml fija la familia de la fuente"
python3 -c 'import sys, tomllib; tomllib.load(open(sys.argv[1], "rb"))' "$ALACRITTY" || \
  fail "alacritty.toml no es TOML válido"
expect_line "$FOOT" "include=$CURRENT_PATH/foot/theme.ini"
grep -Eq '^(\[colors|font=|regular[0-7]=)' "$FOOT" && fail "foot.ini define colores o fuentes propios"
for template in alacritty/theme.toml foot/theme.ini; do
  expect_no_hex "$SHARED_TEMPLATES/$template"
done

# foot accepts the stowed config with the rendered include, read through ~.
if command -v foot >/dev/null 2>&1; then
  home="$TEST_ROOT/catppuccin-mocha-pink"
  HOME="$home" foot --check-config --config="$FOOT" || fail "foot rechazó foot.ini con el tema renderizado"
  HOME="$home" foot --check-config --config="$home/.local/state/dotfiles/theme/current/mangowm/foot.ini" || \
    fail "foot rechazó la plantilla de MangoWM"
fi

# CLI configs select the rendered outputs by name or through the environment.
CLI_HOME="$REPO_ROOT/layers/cli/home"
ENVIRONMENT="$REPO_ROOT/layers/core/home/zsh/.config/zsh/conf.d/10-environment.zsh"
BAT_HOOK="$CLI_HOME/bat/.local/share/dotfiles/theme/render.d/bat"
expect_line "$CLI_HOME/bat/.config/bat/config" '--theme="dotfiles"'
expect_line "$CLI_HOME/btop/.config/btop/btop.conf" 'color_theme = "dotfiles"'
grep -Fq '"colorscheme": "default",' "$CLI_HOME/micro/.config/micro/settings.json" || \
  fail "micro no selecciona el colorscheme renderizado"
grep -Fq 'theme:' "$CLI_HOME/lazygit/.config/lazygit/config.yml" && fail "lazygit fija su propio tema"
# Neovim (dev layer) reads the rendered palette from the state path and falls
# back to a bundled colorscheme without one.
NVIM_CONFIG="$REPO_ROOT/layers/dev/home/nvim/.config/nvim"
grep -Fq '/dotfiles/theme/current/nvim/palette.lua' "$NVIM_CONFIG/lua/dotfiles/theme.lua" || \
  fail "Neovim no ubica la paleta renderizada en el estado del tema"
# The colorscheme option picks "dotfiles" with a rendered palette that loads,
# and tokyonight without a palette or when "dotfiles" fails (LuaJIT, stub vim).
nvim_picks() {
  command -v luajit >/dev/null || { printf '%s\n' "$2"; return; }
  XDG_STATE_HOME="$1" luajit - "$NVIM_CONFIG" "${3:-}" <<'LUA'
package.path = arg[1] .. "/lua/?.lua;" .. package.path
local picked
vim = {
  env = { XDG_STATE_HOME = os.getenv("XDG_STATE_HOME"), HOME = os.getenv("HOME") },
  uv = { fs_stat = function(path) local f = io.open(path) if f then f:close() return {} end end },
  cmd = { colorscheme = function(name)
    if name == "dotfiles" and arg[2] == "broken" then error("broken palette") end
    picked = name
  end },
}
local specs = dofile(arg[1] .. "/lua/plugins/colorscheme.lua")
for _, spec in ipairs(specs) do
  if spec.opts and spec.opts.colorscheme then spec.opts.colorscheme() end
end
print(picked)
LUA
}
NVIM_STATE=$(mktemp -d -p "$TEST_ROOT")
[[ "$(nvim_picks "$NVIM_STATE" tokyonight)" == tokyonight ]] || fail "sin paleta Neovim no usó tokyonight"
mkdir -p "$NVIM_STATE/dotfiles/theme/current/nvim"
printf 'return {}\n' > "$NVIM_STATE/dotfiles/theme/current/nvim/palette.lua"
[[ "$(nvim_picks "$NVIM_STATE" dotfiles)" == dotfiles ]] || fail "con paleta Neovim no eligió el colorscheme dotfiles"
[[ "$(nvim_picks "$NVIM_STATE" tokyonight broken)" == tokyonight ]] || \
  fail "con el colorscheme dotfiles roto Neovim no volvió a tokyonight"
for config in "$NVIM_CONFIG/colors/dotfiles.lua" "$NVIM_CONFIG/lua/plugins/colorscheme.lua" \
              "$NVIM_CONFIG/lua/dotfiles/theme.lua"; do
  expect_no_hex "$config"
done
for config in "$CLI_HOME/lazygit/.config/lazygit/config.yml" "$CLI_HOME/fastfetch/.config/fastfetch/config.jsonc" \
              "$ENVIRONMENT"; do
  expect_no_hex "$config"
done
for template in bat/dotfiles.tmTheme btop/dotfiles.theme lazygit/theme.yml micro/default.micro fzf/options \
                yazi/flavor.toml nvim/palette.lua; do
  expect_no_hex "$SHARED_TEMPLATES/$template"
done
for version in 3.0 4.0; do
  GTK_CSS="$DESKTOP_HOME/xdg-defaults/.config/gtk-$version/gtk.css"
  expect_line "$GTK_CSS" '@import url("../../.local/state/dotfiles/theme/current/gtk.css");'
  expect_no_hex "$GTK_CSS"
  grep -Fq '@define-color' "$GTK_CSS" && fail "gtk-$version/gtk.css define colores propios"
done
expect_no_hex "$SHARED_TEMPLATES/gtk.css"

# The stowed yazi theme only selects the flavor, so the flavor's syntect
# theme applies.
YAZI_THEME="$CLI_HOME/yazi/.config/yazi/theme.toml"
expect_no_hex "$YAZI_THEME"
grep -Fq 'syntect_theme' "$YAZI_THEME" && fail "theme.toml de yazi fija su propio syntect_theme"

# The engine links the outputs an application only reads from its own config
# directory, and only for the applications that are configured.
LINKS="$TEST_ROOT/home-links"
mkdir -p "$LINKS/.config/bat/themes" "$LINKS/.config/btop" "$LINKS/.config/micro"
render_in catppuccin-mocha-pink "$LINKS" >/dev/null
for link in bat/themes/dotfiles.tmTheme:bat/dotfiles.tmTheme btop/themes/dotfiles.theme:btop/dotfiles.theme \
            micro/colorschemes/default.micro:micro/default.micro; do
  [[ "$(readlink -- "$LINKS/.config/${link%%:*}")" == "$LINKS/.local/state/dotfiles/theme/current/${link#*:}" ]] || \
    fail "render no enlazó ${link%%:*}"
done
[[ ! -e "$LINKS/.config/yazi" ]] || fail "render creó la configuración de una aplicación ausente"

# zsh selects the rendered theme for bat once its cache is fresh, and points
# lazygit and fzf at the rendered files only when they exist.
# shellcheck disable=SC2016
zsh_env() {
  env -i HOME="$1" PATH="$PATH" zsh -fc 'source "$1"; print -r -- "$BAT_THEME|${LG_CONFIG_FILE-}|${FZF_DEFAULT_OPTS_FILE-}"' \
    _ "$ENVIRONMENT"
}
if command -v zsh >/dev/null 2>&1; then
  EMPTY="$TEST_ROOT/home-empty"
  mkdir -p "$EMPTY"
  [[ "$(zsh_env "$EMPTY")" == 'Catppuccin-mocha||' ]] || fail "zsh sin tema renderizado: $(zsh_env "$EMPTY")"
  mkdir -p "$LINKS/.config/lazygit" "$LINKS/.cache/bat"
  : > "$LINKS/.config/lazygit/config.yml"
  [[ "$(zsh_env "$LINKS")" == "Catppuccin-mocha|$LINKS/.config/lazygit/config.yml,$LINKS/.local/state/dotfiles/theme/current/lazygit/theme.yml|$LINKS/.local/state/dotfiles/theme/current/fzf/options" ]] || \
    fail "zsh con tema renderizado y sin caché de bat: $(zsh_env "$LINKS")"
  : > "$LINKS/.cache/bat/themes.bin"
  [[ "$(zsh_env "$LINKS")" == dotfiles\|* ]] || fail "zsh no seleccionó el tema de bat con la caché al día"
fi

# fzf parses the rendered options file.
if command -v fzf >/dev/null 2>&1; then
  status=0
  printf 'x\n' | FZF_DEFAULT_OPTS_FILE="$LINKS/.local/state/dotfiles/theme/current/fzf/options" \
    fzf --filter=x >/dev/null || status=$?
  (( status == 0 )) || fail "fzf rechazó fzf/options ($status)"
fi

# bat builds its cache from the linked theme and lists it by name.
if command -v bat >/dev/null 2>&1; then
  BAT_CONFIG_DIR="$LINKS/.config/bat" BAT_CACHE_PATH="$TEST_ROOT/bat-cache" bat cache --build >/dev/null || \
    fail "bat no pudo construir la caché con el tema renderizado"
  BAT_CONFIG_DIR="$LINKS/.config/bat" BAT_CACHE_PATH="$TEST_ROOT/bat-cache" bat --list-themes --color=never | \
    grep -Fxq dotfiles || fail "bat no lista el tema dotfiles"
fi

# The bat render hook rebuilds the cache whenever a revision is promoted
# (render-only paths like a desktop apply or DOTFILES_THEME included) and on
# every `set`, never on a render that changes nothing, and never fails it.
[[ -x "$BAT_HOOK" ]] || fail "falta el hook de render ejecutable de bat"
STUBS="$TEST_ROOT/stubs"
mkdir -p "$STUBS"
cat > "$STUBS/bat" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$TEST_ROOT/bat.args"
mkdir -p "\$BAT_CACHE_PATH" && : > "\$BAT_CACHE_PATH/themes.bin"
EOF
printf '#!/usr/bin/env bash\nexit 0\n' > "$STUBS/gsettings"
cp -- "$STUBS/gsettings" "$STUBS/notify-send"
chmod +x "$STUBS/bat" "$STUBS/gsettings" "$STUBS/notify-send"
bat_builds() {
  [[ -e "$TEST_ROOT/bat.args" ]] || { printf '0\n'; return 0; }
  grep -cFx 'cache --build' "$TEST_ROOT/bat.args" || true
}
HOOKS="$TEST_ROOT/home-hooks"
mkdir -p "$HOOKS/.config/bat/themes" "$HOOKS/.local/share/dotfiles/theme/render.d"
cp -- "$BAT_HOOK" "$HOOKS/.local/share/dotfiles/theme/render.d/bat"
TM_THEME="$HOOKS/.config/bat/themes/dotfiles.tmTheme"
BAT_CACHE="$HOOKS/.cache/bat/themes.bin"
PATH="$STUBS:$PATH" render_in catppuccin-mocha-pink "$HOOKS" >/dev/null
[[ "$(bat_builds)" == 1 && -e "$BAT_CACHE" && ! "$TM_THEME" -nt "$BAT_CACHE" ]] || \
  fail "render no reconstruyó la caché de bat ($(bat_builds))"
if command -v zsh >/dev/null 2>&1; then
  [[ "$(zsh_env "$HOOKS")" == dotfiles\|* ]] || fail "zsh no seleccionó bat tras un render: $(zsh_env "$HOOKS")"
fi
PATH="$STUBS:$PATH" render_in catppuccin-mocha-blue "$HOOKS" >/dev/null
# Back to a revision rendered before: its tmTheme is older than the cache of
# the blue theme, so only a rebuild makes the cache match it again.
PATH="$STUBS:$PATH" render_in catppuccin-mocha-pink "$HOOKS" >/dev/null
[[ "$(bat_builds)" == 3 ]] || fail "volver a una revisión existente no reconstruyó la caché de bat ($(bat_builds))"
PATH="$STUBS:$PATH" render_in catppuccin-mocha-pink "$HOOKS" >/dev/null
[[ "$(bat_builds)" == 3 ]] || fail "un render sin cambios reconstruyó la caché de bat ($(bat_builds))"
env -u DOTFILES_THEME PATH="$STUBS:$PATH" HOME="$HOOKS" XDG_STATE_HOME="$HOOKS/.local/state" \
  XDG_DATA_HOME="$HOOKS/.local/share" XDG_CONFIG_HOME="$HOOKS/.config" XDG_CACHE_HOME="$HOOKS/.cache" \
  "$ENGINE" set catppuccin-mocha-pink >/dev/null || fail "set falló con el hook de bat"
[[ "$(bat_builds)" == 4 ]] || fail "set no reconstruyó la caché de bat ($(bat_builds))"
[[ ! -e "$CLI_HOME/bat/.local/share/dotfiles/theme/reload.d/bat" ]] || fail "bat sigue como hook de recarga"
# A failing or chatty hook only warns: the render succeeds and its stdout is
# still the revision path alone.
printf '#!/usr/bin/env bash\necho ruido\nexit 3\n' > "$HOOKS/.local/share/dotfiles/theme/render.d/falla"
chmod +x "$HOOKS/.local/share/dotfiles/theme/render.d/falla"
output=$(PATH="$STUBS:$PATH" render_in catppuccin-mocha-blue "$HOOKS" 2>"$TEST_ROOT/hooks.err") || \
  fail "un hook de render fallido hizo fallar el render"
[[ "$output" == "$HOOKS/.local/state/dotfiles/theme/catppuccin-mocha-blue-"* && "$output" != *$'\n'* ]] || \
  fail "la salida de un hook de render se mezcló con la ruta: $output"
grep -Fq 'falla' "$TEST_ROOT/hooks.err" || fail "no se avisó del hook de render fallido"
[[ "$(bat_builds)" == 5 ]] || fail "un hook fallido impidió reconstruir la caché de bat ($(bat_builds))"

# Without bat the hook reports it and succeeds; a cache outside HOME (an
# inherited XDG_CACHE_HOME while rendering into another target) is skipped.
NO_BAT="$TEST_ROOT/no-bat"
mkdir -p "$NO_BAT"
ln -s "$(command -v bash)" "$NO_BAT/bash"
output=$(env HOME="$HOOKS" PATH="$NO_BAT" "$BAT_HOOK" 2>&1) || fail "el hook de bat falló sin bat instalado"
[[ "$output" == *'bat no está instalado'* ]] || fail "el hook de bat no informó que falta bat: $output"
output=$(env -u BAT_CACHE_PATH -u BAT_CONFIG_DIR HOME="$HOOKS" XDG_CONFIG_HOME="$HOOKS/.config" \
  XDG_CACHE_HOME="$TEST_ROOT/outside-cache" PATH="$STUBS:$PATH" "$BAT_HOOK" 2>&1) || \
  fail "el hook de bat falló con la caché fuera de HOME"
[[ ! -e "$TEST_ROOT/outside-cache" && "$(bat_builds)" == 5 && "$output" == *'fuera de'* ]] || \
  fail "el hook de bat escribió una caché fuera de HOME: $output"

# The Neovim reload hook (dev layer) asks every Neovim server socket to
# re-apply the dotfiles colorscheme, skips non-sockets, and does nothing
# without Neovim.
NVIM_HOOK="$REPO_ROOT/layers/dev/home/nvim/.local/share/dotfiles/theme/reload.d/nvim"
[[ -x "$NVIM_HOOK" ]] || fail "falta el hook de recarga ejecutable de Neovim"
NVIM_RUNTIME=$(mktemp -d -p "$TEST_ROOT")
NVIM_STUBS="$TEST_ROOT/nvim-stubs"
mkdir -p "$NVIM_STUBS"
# shellcheck disable=SC2016  # expanded by the stub
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s/nvim-calls"\n' "$TEST_ROOT" > "$NVIM_STUBS/nvim"
chmod +x "$NVIM_STUBS/nvim"
python3 -c 'import socket, sys; socket.socket(socket.AF_UNIX).bind(sys.argv[1])' "$NVIM_RUNTIME/nvim.42.0"
touch -- "$NVIM_RUNTIME/nvim.43.0"
env XDG_RUNTIME_DIR="$NVIM_RUNTIME" PATH="$NVIM_STUBS:$PATH" "$NVIM_HOOK" || fail "el hook de Neovim falló"
[[ "$(wc -l < "$TEST_ROOT/nvim-calls")" == 1 ]] || fail "el hook de Neovim no habló solo con el socket: $(<"$TEST_ROOT/nvim-calls")"
grep -Fq -- "--server $NVIM_RUNTIME/nvim.42.0 --remote-expr" "$TEST_ROOT/nvim-calls" || \
  fail "el hook de Neovim no pidió recargar el colorscheme: $(<"$TEST_ROOT/nvim-calls")"
grep -Fq 'colorscheme dotfiles' "$TEST_ROOT/nvim-calls" || fail "el hook de Neovim no reaplica el colorscheme dotfiles"
env XDG_RUNTIME_DIR="$NVIM_RUNTIME" PATH="$NO_BAT" "$NVIM_HOOK" || fail "el hook de Neovim falló sin Neovim instalado"
# Without XDG_RUNTIME_DIR Neovim keeps its sockets under $TMPDIR/nvim.<user>/<random>/.
NVIM_TMP=$(mktemp -d -p "$TEST_ROOT")
mkdir -p "$NVIM_TMP/nvim.$(id -un)/abc123"
python3 -c 'import socket, sys; socket.socket(socket.AF_UNIX).bind(sys.argv[1])' "$NVIM_TMP/nvim.$(id -un)/abc123/nvim.7.0"
rm -f -- "$TEST_ROOT/nvim-calls"
env -u XDG_RUNTIME_DIR TMPDIR="$NVIM_TMP" PATH="$NVIM_STUBS:$PATH" "$NVIM_HOOK" || fail "el hook de Neovim falló sin XDG_RUNTIME_DIR"
grep -Fq -- "--server $NVIM_TMP/nvim.$(id -un)/abc123/nvim.7.0 --remote-expr" "$TEST_ROOT/nvim-calls" 2>/dev/null || \
  fail "sin XDG_RUNTIME_DIR el hook de Neovim no encontró el servidor en TMPDIR"

# The real bat lists the rendered theme after a render-only path, with its
# cache newer than the tmTheme.
if command -v bat >/dev/null 2>&1; then
  REAL="$TEST_ROOT/home-real-bat"
  mkdir -p "$REAL/.config/bat/themes" "$REAL/.local/share/dotfiles/theme/render.d"
  cp -- "$BAT_HOOK" "$REAL/.local/share/dotfiles/theme/render.d/bat"
  render_in catppuccin-mocha-mauve "$REAL" >/dev/null
  [[ -e "$REAL/.cache/bat/themes.bin" && ! "$REAL/.config/bat/themes/dotfiles.tmTheme" -nt "$REAL/.cache/bat/themes.bin" ]] || \
    fail "render dejó la caché real de bat más vieja que el tmTheme"
  BAT_CONFIG_DIR="$REAL/.config/bat" BAT_CACHE_PATH="$REAL/.cache/bat" bat --list-themes --color=never | \
    grep -Fxq dotfiles || fail "bat no lista el tema dotfiles tras un render"
fi

printf 'OK: %d paletas renderizadas para las aplicaciones\n' "$rendered"
