#!/usr/bin/env bash
# Exercises the shared theme engine (dotfiles-theme) against a throwaway home.
# gsettings and notify-send are replaced by doubles so the host session is
# never touched.

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
ENGINE="$REPO_ROOT/layers/desktop/home/theme/.local/bin/dotfiles-theme"
TEST_ROOT=""
TEST_TMP_PARENT=${DOTFILES_TEST_TMPDIR:-/tmp}

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  [[ -n "$TEST_ROOT" && "$TEST_ROOT" == "$TEST_TMP_PARENT"/dotfiles-theme-smoke.* ]] || return 0
  rm -rf -- "$TEST_ROOT"
}

trap cleanup EXIT

[[ -x "$ENGINE" ]] || fail "falta el motor ejecutable layers/desktop/home/theme/.local/bin/dotfiles-theme"
[[ -d "$TEST_TMP_PARENT" ]] || fail "no existe el directorio temporal: $TEST_TMP_PARENT"
TEST_ROOT=$(mktemp -d "$TEST_TMP_PARENT/dotfiles-theme-smoke.XXXXXX")
CHECKOUT_STATE=$(git -C "$REPO_ROOT" status --porcelain)

STUBS="$TEST_ROOT/stubs"
mkdir -p "$STUBS"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> "%s/gsettings.log"\n' "$TEST_ROOT" > "$STUBS/gsettings"
printf '#!/usr/bin/env bash\nexit 0\n' > "$STUBS/notify-send"
chmod +x "$STUBS/gsettings" "$STUBS/notify-send"

# Runs the engine $1 with HOME and XDG dirs inside the throwaway home.
theme_in() {
  local home=$1
  shift
  env -u DOTFILES_THEME PATH="$STUBS:$PATH" HOME="$home" \
    XDG_STATE_HOME="$home/.local/state" XDG_DATA_HOME="$home/.local/share" \
    XDG_CONFIG_HOME="$home/.config" "$ENGINE_UNDER_TEST" "$@"
}

ENGINE_UNDER_TEST=$ENGINE
H="$TEST_ROOT/home"
STATE="$H/.local/state/dotfiles/theme"
TEMPLATES="$H/.local/share/dotfiles/theme/templates"
mkdir -p "$H/.config/yazi"

# list: one entry per palette in themes/palettes.
mapfile -t themes < <(theme_in "$H" list)
(( ${#themes[@]} == 14 )) || fail "list devolvió ${#themes[@]} temas en lugar de 14"
for theme in "${themes[@]}"; do
  [[ "$theme" == catppuccin-mocha-* ]] || fail "tema inesperado en list: $theme"
done

# render without a selection uses the pink default and the shared outputs.
theme_in "$H" render >/dev/null || fail "render falló en un home vacío"
[[ -L "$STATE/current" ]] || fail "render no publicó theme/current"
grep -Fq '@define-color accent_color #f5c2e7;' "$STATE/current/gtk.css" || \
  fail "gtk.css no recibió el acento rosa por defecto"
grep -Fq '#f5c2e7' "$STATE/current/yazi/flavor.toml" || fail "yazi no recibió el acento"
grep -Fxq 'id=catppuccin-mocha-pink' "$STATE/current/metadata" || fail "metadata sin id rosa"
grep -Fxq '#1e1e2e' "$STATE/current/background" || fail "background inesperado"
[[ "$(readlink -- "$H/.config/yazi/flavors/theme.yazi")" == "$STATE/current/yazi" ]] || \
  fail "render no enlazó el flavor de yazi"
first=$(readlink -- "$STATE/current")
theme_in "$H" render >/dev/null
[[ "$(readlink -- "$STATE/current")" == "$first" ]] || fail "render no es idempotente"

# Every installed WM template dir is rendered side by side, with {{key}} and
# {{key.raw}} markers; adding a template produces a new revision.
mkdir -p "$TEMPLATES/fakewm/nested" "$TEMPLATES/otherwm"
printf 'border={{accent}}\nraw=0x{{accent.raw}}ff\nbg={{background}}\n' > "$TEMPLATES/fakewm/fake.conf"
printf 'muted={{foreground_muted}}\n' > "$TEMPLATES/fakewm/nested/deep.ini"
printf 'accent={{accent}}\n' > "$TEMPLATES/otherwm/other.css"
theme_in "$H" render >/dev/null || fail "render falló con plantillas de WM"
[[ "$(readlink -- "$STATE/current")" != "$first" ]] || fail "añadir plantillas no cambió la revisión"
printf -v expected 'border=#f5c2e7\nraw=0xf5c2e7ff\nbg=#1e1e2e\n'
[[ "$(<"$STATE/current/fakewm/fake.conf")"$'\n' == "$expected" ]] || \
  fail "plantilla de fakewm mal renderizada: $(<"$STATE/current/fakewm/fake.conf")"
grep -Fxq 'muted=#a6adc8' "$STATE/current/fakewm/nested/deep.ini" || fail "plantilla anidada no renderizada"
grep -Fxq 'accent=#f5c2e7' "$STATE/current/otherwm/other.css" || fail "el segundo WM no se renderizó junto al primero"
[[ -f "$STATE/current/gtk.css" ]] || fail "las plantillas de WM desplazaron gtk.css"

# An unknown marker fails without touching the active revision.
before=$(readlink -- "$STATE/current")
printf 'x={{nope}}\n' > "$TEMPLATES/otherwm/broken.conf"
if output=$(theme_in "$H" render 2>&1); then
  fail "render aceptó un marcador desconocido"
fi
[[ "$output" == *'marcador desconocido {{nope}}'* ]] || fail "render falló por otra causa: $output"
[[ "$(readlink -- "$STATE/current")" == "$before" ]] || fail "un render fallido cambió theme/current"
compgen -G "$STATE/.render.*" >/dev/null && fail "un render fallido dejó directorios temporales"
rm -f -- "$TEMPLATES/otherwm/broken.conf"

# A WM template directory with an unsafe name fails the render.
mkdir -p "$TEMPLATES/Bad_WM"
printf 'x={{accent}}\n' > "$TEMPLATES/Bad_WM/x.conf"
if output=$(theme_in "$H" render 2>&1); then
  fail "render aceptó un directorio de plantillas con nombre inválido"
fi
[[ "$output" == *'nombre de plantillas de WM inválido: Bad_WM'* ]] || fail "render falló por otra causa: $output"
[[ "$(readlink -- "$STATE/current")" == "$before" ]] || fail "un nombre inválido cambió theme/current"
rm -rf -- "$TEMPLATES/Bad_WM"

# A WM template directory named like a shared output would overwrite it.
for shared in yazi foot; do
  mkdir -p "$TEMPLATES/$shared"
  printf 'x={{accent}}\n' > "$TEMPLATES/$shared/x.conf"
  if output=$(theme_in "$H" render 2>&1); then
    fail "render aceptó plantillas de WM llamadas $shared"
  fi
  [[ "$output" == *"nombre de plantillas de WM inválido: $shared"* ]] || fail "render falló por otra causa: $output"
  rm -rf -- "${TEMPLATES:?}/$shared"
done
[[ "$(readlink -- "$STATE/current")" == "$before" ]] || fail "un nombre reservado cambió theme/current"

# set renders, persists the selection, syncs the GNOME accent and runs every
# WM reload hook; a failing hook only warns.
mkdir -p "$H/.local/share/dotfiles/theme/reload.d"
# shellcheck disable=SC2016
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$DOTFILES_THEME_DIR" > "%s/reload.out"\n' "$TEST_ROOT" \
  > "$H/.local/share/dotfiles/theme/reload.d/fakewm"
printf '#!/usr/bin/env bash\nexit 3\n' > "$H/.local/share/dotfiles/theme/reload.d/otherwm"
chmod +x "$H/.local/share/dotfiles/theme/reload.d/"*
output=$(theme_in "$H" set catppuccin-mocha-mauve 2>&1) || fail "set mauve falló: $output"
[[ "$output" == *'la recarga otherwm falló'* ]] || fail "set no avisó del hook de recarga fallido"
[[ "$(<"$STATE/selected")" == catppuccin-mocha-mauve ]] || fail "set no guardó la selección"
grep -Fq '#cba6f7' "$STATE/current/gtk.css" || fail "set no aplicó el acento mauve a GTK"
grep -Fxq 'border=#cba6f7' "$STATE/current/fakewm/fake.conf" || fail "set no re-renderizó las plantillas de WM"
grep -Fxq 'set org.gnome.desktop.interface accent-color purple' "$TEST_ROOT/gsettings.log" || \
  fail "set no sincronizó el acento de GNOME"
[[ "$(<"$TEST_ROOT/reload.out")" == "$STATE/current" ]] || fail "set no ejecutó el hook de recarga del WM"
[[ "$(theme_in "$H" current)" == 'catppuccin-mocha-mauve (acento: mauve, #cba6f7)' ]] || \
  fail "current no informa del tema guardado"

# An unknown theme is rejected and the saved selection stays.
if output=$(theme_in "$H" set catppuccin-mocha-nope 2>&1); then
  fail "set aceptó un tema desconocido"
fi
[[ "$output" == *'tema desconocido: catppuccin-mocha-nope'* ]] || fail "set falló por otra causa: $output"
[[ "$(<"$STATE/selected")" == catppuccin-mocha-mauve ]] || fail "un set fallido cambió la selección"
theme_in "$H" set >/dev/null 2>&1 && fail "set sin id no devolvió error"
status=0
theme_in "$H" set >/dev/null 2>&1 || status=$?
(( status == 2 )) || fail "set sin id devolvió $status en lugar de 2"

# DOTFILES_THEME overrides the saved selection for one render.
env PATH="$STUBS:$PATH" HOME="$H" XDG_STATE_HOME="$H/.local/state" XDG_DATA_HOME="$H/.local/share" \
  XDG_CONFIG_HOME="$H/.config" DOTFILES_THEME=catppuccin-mocha-blue "$ENGINE" render >/dev/null
grep -Fq '#89b4fa' "$STATE/current/gtk.css" || fail "DOTFILES_THEME no se respetó"
[[ "$(<"$STATE/selected")" == catppuccin-mocha-mauve ]] || fail "DOTFILES_THEME cambió la selección guardada"

# A real yazi flavor directory is never replaced by the link.
H2="$TEST_ROOT/home-yazi"
mkdir -p "$H2/.config/yazi/flavors/theme.yazi"
output=$(theme_in "$H2" render 2>&1) || fail "render falló con un flavor real de yazi: $output"
[[ -d "$H2/.config/yazi/flavors/theme.yazi" && ! -L "$H2/.config/yazi/flavors/theme.yazi" ]] || \
  fail "render reemplazó un directorio real de yazi"
[[ "$output" == *'no es un enlace simbólico'* ]] || fail "render no avisó del flavor real de yazi"

# path renders on first use.
H3="$TEST_ROOT/home-path"
mkdir -p "$H3"
[[ "$(theme_in "$H3" path)" == "$H3/.local/state/dotfiles/theme/current" ]] || fail "path devolvió otra ruta"
[[ -f "$H3/.local/state/dotfiles/theme/current/gtk.css" ]] || fail "path no renderizó el tema"

# Palettes accept upper-case hex (the old MangoWM engine rejected it).
FAKE_REPO="$TEST_ROOT/repo"
mkdir -p "$FAKE_REPO/bin" "$FAKE_REPO/themes/palettes"
cp "$ENGINE" "$FAKE_REPO/bin/dotfiles-theme"
cp -r "$REPO_ROOT/themes/templates" "$FAKE_REPO/themes/"
sed 's/^accent=#f5c2e7$/accent=#F5C2E7/' "$REPO_ROOT/themes/palettes/catppuccin-mocha-pink.conf" \
  > "$FAKE_REPO/themes/palettes/catppuccin-mocha-pink.conf"
grep -Fxq 'accent=#F5C2E7' "$FAKE_REPO/themes/palettes/catppuccin-mocha-pink.conf" || fail "no se preparó la paleta en mayúsculas"
ENGINE_UNDER_TEST="$FAKE_REPO/bin/dotfiles-theme"
H4="$TEST_ROOT/home-upper"
theme_in "$H4" render >/dev/null || fail "render rechazó un color hexadecimal en mayúsculas"
grep -Fq '#F5C2E7' "$H4/.local/state/dotfiles/theme/current/gtk.css" || fail "el color en mayúsculas no llegó a GTK"
# Schema 2: {{key}} works for every key, {{key.raw}} only for colors, and the
# rendered metadata records the schema.
ENGINE_UNDER_TEST=$ENGINE
H5="$TEST_ROOT/home-schema"
ROLES="$H5/.local/share/dotfiles/theme/templates/fakewm"
mkdir -p "$ROLES"
printf 'mono={{font_mono}}\ncursor={{cursor_theme}}:{{cursor_size}}\nmagenta={{ansi_magenta.raw}}\n' \
  > "$ROLES/roles.conf"
theme_in "$H5" render >/dev/null || fail "render rechazó la paleta schema 2 por defecto"
grep -Fxq 'schema=2' "$H5/.local/state/dotfiles/theme/current/metadata" || fail "metadata sin schema=2"
grep -Fxq 'mono=JetBrainsMono Nerd Font' "$H5/.local/state/dotfiles/theme/current/fakewm/roles.conf" || \
  fail "{{font_mono}} no renderizó la familia de la fuente"
grep -Fxq 'cursor=Bibata-Modern-Classic:24' "$H5/.local/state/dotfiles/theme/current/fakewm/roles.conf" || \
  fail "los roles de cursor no se renderizaron"
grep -Fxq 'magenta=f5c2e7' "$H5/.local/state/dotfiles/theme/current/fakewm/roles.conf" || \
  fail "{{ansi_magenta.raw}} no renderizó el color sin #"
printf 'x={{font_mono.raw}}\n' > "$ROLES/raw.conf"
if output=$(theme_in "$H5" render 2>&1); then
  fail "render aceptó {{font_mono.raw}}"
fi
[[ "$output" == *'marcador desconocido {{font_mono.raw}}'* ]] || fail "render falló por otra causa: $output"
rm -f -- "$ROLES/raw.conf"

# Typed values and schema 1 are rejected by validate.
ENGINE_UNDER_TEST="$FAKE_REPO/bin/dotfiles-theme"
FAKE_PALETTE="$FAKE_REPO/themes/palettes/catppuccin-mocha-pink.conf"
for case in 'font_mono=Mono;rm' 'font_text= Sans' 'cursor_theme=../cursors' 'cursor_size=8' \
            'cursor_size=1000' 'foreground=cdd6f4'; do
  key=${case%%=*}
  sed "s|^$key=.*|$case|" "$REPO_ROOT/themes/palettes/catppuccin-mocha-pink.conf" > "$FAKE_PALETTE"
  grep -Fxq -- "$case" "$FAKE_PALETTE" || fail "no se preparó la paleta con $case"
  if output=$(theme_in "$H4" validate 2>&1); then
    fail "validate aceptó $case"
  fi
  [[ "$output" == *"inválido para $key"* ]] || fail "validate falló por otra causa con $case: $output"
done
printf 'schema=1\nid=catppuccin-mocha-pink\nrosewater=#f5e0dc\n' > "$FAKE_PALETTE"
if output=$(theme_in "$H4" validate 2>&1); then
  fail "validate aceptó una paleta schema 1"
fi
[[ "$output" == *'schema de paleta no soportado'* ]] || fail "schema 1 falló por otra causa: $output"
ENGINE_UNDER_TEST=$ENGINE

# The desktop post-link renders the theme into the target after linking.
TARGET="$TEST_ROOT/target"
mkdir -p "$TARGET"
stow --dir="$REPO_ROOT/layers/desktop/home" --target="$TARGET" --no-folding theme
# shellcheck disable=SC2016
PATH="$STUBS:$PATH" DOTFILES_LANG=es "$BASH" -c '
  set -Eeuo pipefail
  for module in colors core layers; do
    # shellcheck source=/dev/null
    source "$1/lib/$module.sh"
  done
  TARGET_DIR=$2 PROFILE=desktop APPLY=1 OPERATION=bootstrap
  run_layer_hook "$1/layers/desktop" post-link' _ "$REPO_ROOT" "$TARGET" >/dev/null || \
  fail "post-link de desktop falló"
grep -Fq '#f5c2e7' "$TARGET/.local/state/dotfiles/theme/current/gtk.css" || \
  fail "post-link de desktop no renderizó el tema en el target"
stow --dir="$REPO_ROOT/layers/desktop/home" --target="$TARGET" --no-folding --delete theme

[[ "$(git -C "$REPO_ROOT" status --porcelain)" == "$CHECKOUT_STATE" ]] || fail "el motor de temas modificó el checkout"

printf 'OK: motor de temas compartido validado\n'
