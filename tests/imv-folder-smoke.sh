#!/usr/bin/env bash
# imv-folder: opening one image loads every image of its directory, starting
# at that image, and the desktop layer associates images with it.

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
HOME_PACKAGE="$REPO_ROOT/layers/desktop/home/xdg-defaults"
WRAPPER="$HOME_PACKAGE/.local/bin/imv-folder"
DESKTOP_ENTRY="$HOME_PACKAGE/.local/share/applications/imv-folder.desktop"
DEFAULTS="$REPO_ROOT/layers/desktop/mimeapps/defaults.list"
TEST_ROOT=''

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  [[ -n "$TEST_ROOT" && "$TEST_ROOT" == /tmp/imv-folder-smoke.* ]] || return 0
  find "$TEST_ROOT" -mindepth 1 -delete
  find "$TEST_ROOT" -depth -type d -empty -delete
}
trap cleanup EXIT

[[ -x "$WRAPPER" ]] || fail "falta el ejecutable $WRAPPER"

TEST_ROOT=$(mktemp -d /tmp/imv-folder-smoke.XXXXXX)
mkdir -p -- "$TEST_ROOT/bin" "$TEST_ROOT/photos with spaces/nested"
ARGS_LOG="$TEST_ROOT/imv.args"
printf '#!/usr/bin/env bash\n: > %q\n(( $# == 0 )) || printf "%%s\\n" "$@" > %q\n' \
  "$ARGS_LOG" "$ARGS_LOG" > "$TEST_ROOT/bin/imv"
chmod +x "$TEST_ROOT/bin/imv"
export PATH="$TEST_ROOT/bin:$PATH"

dir="$TEST_ROOT/photos with spaces"
touch -- "$dir/a.png" "$dir/b2.JPG" "$dir/b10.jpeg" "$dir/c.webp" \
  "$dir/notes.txt" "$dir/raw.unknown" "$dir/nested/d.png"

run() {
  : > "$ARGS_LOG"
  "$WRAPPER" "$@"
  mapfile -t args < "$ARGS_LOG"
}

# 1. One image: every image of its directory in natural order, starting at it;
# other files and subdirectories are left out.
cd -- "$dir"
run b2.JPG
cd -- "$REPO_ROOT"
expected=(-n "$dir/b2.JPG" "$dir/a.png" "$dir/b2.JPG" "$dir/b10.jpeg" "$dir/c.webp")
[[ "${args[*]}" == "${expected[*]}" ]] || \
  fail "argumentos inesperados para una imagen: ${args[*]}"

# 2. A file with an unknown extension is still opened, at its position.
run "$dir/raw.unknown"
[[ "${args[0]}" == -n && "${args[1]}" == "$dir/raw.unknown" ]] || \
  fail "no empezó en el archivo abierto: ${args[*]}"
printf '%s\n' "${args[@]:2}" | grep -qxF -- "$dir/raw.unknown" || \
  fail 'el archivo abierto no está en la lista'

# 3. Several paths, or none, reach imv unchanged.
run "$dir/a.png" "$dir/c.webp"
[[ "${args[*]}" == "$dir/a.png $dir/c.webp" ]] || \
  fail "no pasó varias rutas tal cual: ${args[*]}"
run
(( ${#args[@]} == 0 )) || fail "sin argumentos agregó: ${args[*]}"

# 4. A symlinked image keeps the folder it was opened from, and symlinks to
# images in that folder are listed.
mkdir -p -- "$TEST_ROOT/library"
touch -- "$TEST_ROOT/library/z.png"
ln -s -- "$TEST_ROOT/library/z.png" "$dir/link.png"
run "$dir/link.png"
expected=(-n "$dir/link.png" "$dir/a.png" "$dir/b2.JPG" "$dir/b10.jpeg" "$dir/c.webp" "$dir/link.png")
[[ "${args[*]}" == "${expected[*]}" ]] || \
  fail "un symlink no conservó su carpeta: ${args[*]}"
rm -- "$dir/link.png"

# 5. A folder too large for one command line is handed over as a directory.
IMV_FOLDER_MAX_ARGS_BYTES=10 run "$dir/a.png"
[[ "${args[*]}" == "-n $dir/a.png $dir" ]] || \
  fail "una carpeta enorme no se pasó como directorio: ${args[*]}"

# 6. Desktop entry and associations: every image type opens through it, and
# the entry, the associations and the wrapper name the same formats.
grep -qx 'Exec=imv-folder %F' "$DESKTOP_ENTRY" || fail 'la entrada no ejecuta imv-folder %F'
grep -qx 'NoDisplay=true' "$DESKTOP_ENTRY" || fail 'la entrada aparecería en los lanzadores'
if grep -n '^image/.*=imv\.desktop' "$DEFAULTS"; then
  fail 'quedan tipos de imagen asociados a imv.desktop'
fi
grep -q '^image/png=imv-folder.desktop;$' "$DEFAULTS" || fail 'image/png no usa imv-folder'
entry_types=$(sed -n 's/^MimeType=//p' "$DESKTOP_ENTRY" | tr ';' '\n' | sed '/^$/d' | sort)
associated=$(sed -n 's/^\(image\/[^=]*\)=imv-folder\.desktop;$/\1/p' "$DEFAULTS" | sort)
[[ "$entry_types" == "$associated" ]] || \
  fail "MimeType y defaults.list difieren:"$'\n'"$(diff <(printf '%s\n' "$entry_types") <(printf '%s\n' "$associated"))"
for type in $entry_types; do
  extension=${type#image/}
  extension=${extension%+xml}
  touch -- "$dir/format.$extension"
  run "$dir/a.png"
  printf '%s\n' "${args[@]}" | grep -qxF -- "$dir/format.$extension" || \
    fail "imv-folder no lista archivos .$extension ($type)"
  rm -- "$dir/format.$extension"
done

printf 'OK: imv-folder-smoke\n'
