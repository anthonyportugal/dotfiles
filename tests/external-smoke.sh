#!/usr/bin/env bash
# External adapter: pinned downloads (fonts, cursor themes) installed under
# ~/.local through the package engine, checked against their sha256, never
# run, and replacing only what the adapter itself installed.
#
# shellcheck source-path=SCRIPTDIR

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
TEST_ROOT=''

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  [[ -n "$TEST_ROOT" && "$TEST_ROOT" == /tmp/external-smoke.* ]] || return 0
  chmod -R u+w -- "$TEST_ROOT" 2>/dev/null || true
  find "$TEST_ROOT" -mindepth 1 -delete
  find "$TEST_ROOT" -depth -type d -empty -delete
}
trap cleanup EXIT

TEST_ROOT=$(mktemp -d /tmp/external-smoke.XXXXXX)
FAKE_BIN="$TEST_ROOT/fake-bin"
DOWNLOADS="$TEST_ROOT/downloads"
CURL_LOG="$TEST_ROOT/curl.log"
FC_LOG="$TEST_ROOT/fc-cache.log"
mkdir -p "$FAKE_BIN" "$DOWNLOADS"
: > "$CURL_LOG"
: > "$FC_LOG"

# curl serves https://example.test/<name> from $DOWNLOADS/<name> and logs
# every call; fc-cache logs the directory it was asked to refresh.
cat > "$FAKE_BIN/curl" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> '$CURL_LOG.args'
output='' url=''
while (( \$# > 0 )); do
  case "\$1" in
    -o) output=\$2; shift ;;
    --proto|--retry) shift ;;
    -*) ;;
    *) url=\$1 ;;
  esac
  shift
done
printf '%s\n' "\$url" >> '$CURL_LOG'
if [[ "\$url" == */slow ]]; then
  : > '$TEST_ROOT/slow.started'
  sleep 30
fi
[[ "\$url" == https://example.test/* && -f '$DOWNLOADS'/"\${url##*/}" ]] || exit 22
cp -- '$DOWNLOADS'/"\${url##*/}" "\$output"
EOF
cat > "$FAKE_BIN/fc-cache" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\${!#}" >> '$FC_LOG'
EOF
ln -s /usr/bin/true "$FAKE_BIN/pacman"
chmod +x "$FAKE_BIN/curl" "$FAKE_BIN/fc-cache"
export PATH="$FAKE_BIN:/usr/bin"

# shellcheck source=../lib/colors.sh
source "$REPO_ROOT/lib/colors.sh"
# shellcheck source=../lib/core.sh
source "$REPO_ROOT/lib/core.sh"
# shellcheck source=../lib/receipts.sh
source "$REPO_ROOT/lib/receipts.sh"
# shellcheck source=../lib/external.sh
source "$REPO_ROOT/lib/external.sh"
# shellcheck source=../lib/packages.sh
source "$REPO_ROOT/lib/packages.sh"
setup_colors

# Downloads: two font files, a license and a cursor archive with one
# top-level directory; a second archive has two top-level entries.
printf 'font-regular\n' > "$DOWNLOADS/Sans[wght].ttf"
printf 'font-italic\n' > "$DOWNLOADS/Sans-Italic[wght].ttf"
printf 'license\n' > "$DOWNLOADS/OFL.txt"
printf 'readme\n' > "$DOWNLOADS/README.txt"
mkdir -p "$TEST_ROOT/archive/Cursor/cursors" "$TEST_ROOT/archive/Extra"
printf 'arrow\n' > "$TEST_ROOT/archive/Cursor/cursors/arrow"
ln -s arrow "$TEST_ROOT/archive/Cursor/cursors/default"
printf '[Icon Theme]\n' > "$TEST_ROOT/archive/Cursor/index.theme"
tar -C "$TEST_ROOT/archive" -cJf "$DOWNLOADS/Cursor.tar.xz" Cursor
tar -C "$TEST_ROOT/archive" -cJf "$DOWNLOADS/Two.tar.xz" Cursor Extra

sha() {
  sha256sum -- "$DOWNLOADS/$1" | cut -d' ' -f1
}

PACKAGES_DIR="$TEST_ROOT/packages"
mkdir -p "$PACKAGES_DIR/external"
write_fonts_recipe() {
  cat > "$PACKAGES_DIR/external/sans.conf" <<EOF
# A variable font and its license.
version=$1
dest=share/fonts/sans
file=Sans[wght].ttf $(sha 'Sans[wght].ttf') https://example.test/Sans[wght].ttf
file=$2 $(sha "$2") https://example.test/$2
file=OFL.txt $(sha OFL.txt) https://example.test/OFL.txt
refresh=fonts
EOF
}
write_fonts_recipe 1 'Sans-Italic[wght].ttf'
cat > "$PACKAGES_DIR/external/cursor.conf" <<EOF
version=2.0.7
dest=share/icons/Cursor
archive=$(sha Cursor.tar.xz) https://example.test/Cursor.tar.xz
EOF

new_target() {
  TARGET_DIR="$TEST_ROOT/target-$1"
  mkdir -p "$TARGET_DIR"
}

# Runs the engine the way a layer does: classify, plan, validate, install.
plan() {
  REPO_PACKAGES=() AUR_PACKAGES=() EXTERNAL_PACKAGES=("$@")
  BACKEND=pacman
  classify_packages
}

# 1. A dry run lists what it would download and downloads nothing.
new_target dry
plan sans cursor
[[ "${MISSING_EXTERNAL_PACKAGES[*]}" == 'sans cursor' ]] || \
  fail "faltantes inesperados: ${MISSING_EXTERNAL_PACKAGES[*]}"
output=$(show_package_commands 2>&1)
[[ "$output" == *'sans 1'*'share/fonts/sans'* ]] || fail "el plan no muestra la fuente: $output"
[[ "$output" == *'cursor 2.0.7'*'share/icons/Cursor'* ]] || fail "el plan no muestra el cursor: $output"
validate_package_plan || fail 'un plan con recetas válidas no pasó la validación'
[[ ! -s "$CURL_LOG" ]] || fail 'el dry-run descargó algo'

# 2. Install: files land in dest, the archive's top-level directory becomes
# dest, symlinks inside it survive, fonts refresh their cache, and a second
# classification sees both installed.
new_target install
plan sans cursor
execute_package_install >/dev/null 2>&1 || fail 'la instalación falló'
fonts="$TARGET_DIR/.local/share/fonts/sans"
cursor="$TARGET_DIR/.local/share/icons/Cursor"
[[ $(cat "$fonts/Sans[wght].ttf") == font-regular && -f "$fonts/OFL.txt" ]] || \
  fail 'las fuentes no se instalaron en dest'
[[ -f "$cursor/index.theme" && -L "$cursor/cursors/default" ]] || \
  fail 'el archivo no se extrajo como dest con sus symlinks'
grep -qxF "$fonts" "$FC_LOG" || fail 'no se refrescó la caché de fuentes'
[[ ! -x "$fonts/Sans[wght].ttf" ]] || fail 'una descarga quedó ejecutable'
plan sans cursor
[[ "${INSTALLED_EXTERNAL_PACKAGES[*]}" == 'sans cursor' && ${#MISSING_EXTERNAL_PACKAGES[@]} -eq 0 ]] || \
  fail 'la reclasificación no ve los paquetes instalados'
compgen -G "$TARGET_DIR/.local/.dotfiles-external.*" >/dev/null && fail 'quedó staging tras instalar'

# 3. Changing a recipe reinstalls it: dest is replaced whole.
write_fonts_recipe 2 README.txt
plan sans
[[ "${MISSING_EXTERNAL_PACKAGES[*]}" == sans ]] || fail 'un cambio de receta no pidió reinstalar'
execute_package_install >/dev/null 2>&1 || fail 'la reinstalación falló'
[[ ! -e "$fonts/Sans-Italic[wght].ttf" ]] || fail 'la reinstalación dejó un archivo de la versión anterior'
write_fonts_recipe 1 'Sans-Italic[wght].ttf'

# 4. A wrong checksum aborts before dest changes and leaves no staging.
new_target checksum
plan sans
execute_package_install >/dev/null 2>&1 || fail 'la instalación base falló'
printf 'tampered\n' > "$DOWNLOADS/OFL.txt"
write_fonts_recipe 3 'Sans-Italic[wght].ttf'
sed -i "s/^file=OFL.txt .* /file=OFL.txt $(printf '0%.0s' {1..64}) /" "$PACKAGES_DIR/external/sans.conf"
plan sans
if output=$(execute_package_install 2>&1); then
  fail 'una suma sha256 distinta no detuvo la instalación'
fi
[[ "$output" == *sha256* ]] || fail "el error no menciona sha256: $output"
[[ $(cat "$fonts/OFL.txt") == license ]] || fail 'una descarga inválida tocó dest'
compgen -G "$TARGET_DIR/.local/.dotfiles-external.*" >/dev/null && fail 'quedó staging tras fallar'
printf 'license\n' > "$DOWNLOADS/OFL.txt"
write_fonts_recipe 1 'Sans-Italic[wght].ttf'

# 5. A dest the adapter did not install is never replaced.
new_target foreign
mkdir -p "$TARGET_DIR/.local/share/icons/Cursor"
printf 'mine\n' > "$TARGET_DIR/.local/share/icons/Cursor/notes"
plan cursor
if output=$(execute_package_install 2>&1); then
  fail 'se reemplazó un directorio que no instaló dotfiles'
fi
[[ "$output" == *'no lo instaló dotfiles'* ]] || fail "el error no explica el conflicto: $output"
[[ $(cat "$TARGET_DIR/.local/share/icons/Cursor/notes") == mine ]] || fail 'se tocó el directorio ajeno'

# 6. An archive must hold exactly one top-level directory.
new_target two
cat > "$PACKAGES_DIR/external/two.conf" <<EOF
version=1
dest=share/icons/Two
archive=$(sha Two.tar.xz) https://example.test/Two.tar.xz
EOF
plan two
if execute_package_install >/dev/null 2>&1; then
  fail 'se aceptó un archivo con varias entradas de primer nivel'
fi
[[ ! -e "$TARGET_DIR/.local/share/icons/Two" ]] || fail 'un archivo inválido creó dest'

# 7. Invalid recipes fail validation, and so does a missing one.
invalid() {
  local label=$1
  shift
  printf '%s\n' "$@" > "$PACKAGES_DIR/external/bad.conf"
  plan bad
  if validate_package_plan >/dev/null 2>&1; then
    fail "receta inválida aceptada: $label"
  fi
}
good_sha=$(sha OFL.txt)
invalid 'http' 'version=1' 'dest=share/fonts/bad' "file=OFL.txt $good_sha http://example.test/OFL.txt"
invalid 'dest ..' 'version=1' 'dest=share/fonts/../../bin' "file=OFL.txt $good_sha https://example.test/OFL.txt"
invalid 'dest corto' 'version=1' 'dest=share' "file=OFL.txt $good_sha https://example.test/OFL.txt"
invalid 'dest fuera de share' 'version=1' 'dest=bin/bad' "file=OFL.txt $good_sha https://example.test/OFL.txt"
invalid 'sha corto' 'version=1' 'dest=share/fonts/bad' 'file=OFL.txt abc https://example.test/OFL.txt'
invalid 'archive y file' 'version=1' 'dest=share/fonts/bad' \
  "archive=$good_sha https://example.test/OFL.txt" "file=OFL.txt $good_sha https://example.test/OFL.txt"
invalid 'sin fuentes' 'version=1' 'dest=share/fonts/bad'
invalid 'clave desconocida' 'version=1' 'dest=share/fonts/bad' \
  "file=OFL.txt $good_sha https://example.test/OFL.txt" 'run=rm -rf ~'
invalid 'nombre con /' 'version=1' 'dest=share/fonts/bad' "file=../OFL.txt $good_sha https://example.test/OFL.txt"
invalid 'archivo repetido' 'version=1' 'dest=share/fonts/bad' \
  "file=OFL.txt $good_sha https://example.test/OFL.txt" "file=OFL.txt $good_sha https://example.test/OFL.txt"
invalid 'refresh desconocido' 'version=1' 'dest=share/fonts/bad' \
  "file=OFL.txt $good_sha https://example.test/OFL.txt" 'refresh=icons'
rm -f -- "$PACKAGES_DIR/external/bad.conf"
plan missing
if output=$(validate_package_plan 2>&1); then
  fail 'una receta inexistente pasó la validación'
fi
[[ "$output" == *missing* ]] || fail "el error no nombra la receta: $output"

# 8. Downloads cannot hang forever on a stalled server.
if ! grep -q -- '--connect-timeout' "$CURL_LOG.args" || ! grep -q -- '--speed-time' "$CURL_LOG.args"; then
  fail 'curl se llama sin límites de tiempo'
fi

# 9. A symlinked directory between ~/.local and dest is refused, so a
# download never lands in the symlink's target.
new_target symlink
mkdir -p "$TARGET_DIR/elsewhere" "$TARGET_DIR/.local/share"
ln -s "$TARGET_DIR/elsewhere" "$TARGET_DIR/.local/share/icons"
plan cursor
if output=$(execute_package_install 2>&1); then
  fail 'se instaló a través de un directorio symlink'
fi
[[ "$output" == *symlink* ]] || fail "el error no menciona el symlink: $output"
[[ -z $(ls -A "$TARGET_DIR/elsewhere") ]] || fail 'la descarga llegó al destino del symlink'

# 10-11 simulate unwritable directories, which root writes anyway.
if (( EUID != 0 )); then
# 10. When the receipt cannot be written, the install is undone: dest goes
# away and the next run installs instead of refusing a dest it does not own.
new_target receipt
mkdir -p "$TARGET_DIR/.local/state/dotfiles"
chmod 0555 "$TARGET_DIR/.local/state/dotfiles"
plan cursor
if (execute_package_install) >/dev/null 2>&1; then
  fail 'una instalación sin recibo se dio por buena'
fi
[[ ! -e "$TARGET_DIR/.local/share/icons/Cursor" ]] || fail 'dest quedó instalado sin recibo'
chmod 0755 "$TARGET_DIR/.local/state/dotfiles"
plan cursor
execute_package_install >/dev/null 2>&1 || fail 'no se pudo instalar después de arreglar el recibo'

# 11. A replace that cannot move the old dest fails and keeps it intact,
# without nesting the new payload inside it.
write_fonts_recipe 4 'Sans-Italic[wght].ttf'
new_target readonly
plan sans
execute_package_install >/dev/null 2>&1 || fail 'la instalación base falló'
fonts="$TARGET_DIR/.local/share/fonts/sans"
write_fonts_recipe 5 README.txt
chmod 0555 "$TARGET_DIR/.local/share/fonts"
plan sans
if execute_package_install >/dev/null 2>&1; then
  fail 'un reemplazo imposible se dio por bueno'
fi
chmod 0755 "$TARGET_DIR/.local/share/fonts"
[[ -f "$fonts/Sans-Italic[wght].ttf" && ! -e "$fonts/payload" && ! -e "$fonts/README.txt" ]] || \
  fail 'el reemplazo fallido alteró dest'
write_fonts_recipe 1 'Sans-Italic[wght].ttf'
fi

# 12. curl may be missing when the repository step of the same run installs it.
(
  command_exists() { [[ "$1" != curl ]] && command -v "$1" >/dev/null 2>&1; }
  plan sans
  MISSING_REPO_PACKAGES=(curl)
  validate_package_plan >/dev/null 2>&1 || fail 'se rechazó curl pendiente del paso de repositorio'
  MISSING_REPO_PACKAGES=()
  if validate_package_plan >/dev/null 2>&1; then
    fail 'se aceptó un plan sin curl'
  fi
)

# 13. An interrupted download leaves no staging behind.
new_target interrupt
cat > "$PACKAGES_DIR/external/slow.conf" <<EOF
version=1
dest=share/fonts/slow
file=slow $(sha OFL.txt) https://example.test/slow
EOF
rm -f -- "$TEST_ROOT/slow.started"
( plan slow; execute_package_install ) >/dev/null 2>&1 &
installer=$!
for _ in {1..100}; do
  [[ -e "$TEST_ROOT/slow.started" ]] && break
  sleep 0.1
done
kill -TERM "$installer"
wait "$installer" 2>/dev/null || true
compgen -G "$TARGET_DIR/.local/.dotfiles-external.*" >/dev/null && fail 'una interrupción dejó staging'
rm -f -- "$PACKAGES_DIR/external/slow.conf"

# 14. A signal right after the swap, before the receipt, undoes the swap:
# the previous version and its receipt are back.
new_target swap
write_fonts_recipe 6 'Sans-Italic[wght].ttf'
plan sans
execute_package_install >/dev/null 2>&1 || fail 'la instalación base falló'
fonts="$TARGET_DIR/.local/share/fonts/sans"
write_fonts_recipe 7 README.txt
(
  _external_record() { kill -TERM "$BASHPID"; sleep 5; }
  plan sans
  execute_package_install
) >/dev/null 2>&1 || true
[[ -f "$fonts/Sans-Italic[wght].ttf" && ! -e "$fonts/README.txt" ]] || \
  fail 'una interrupción tras el reemplazo no restauró la versión anterior'
write_fonts_recipe 6 'Sans-Italic[wght].ttf'
plan sans
[[ "${INSTALLED_EXTERNAL_PACKAGES[*]}" == sans ]] || fail 'el recibo anterior no volvió con la versión anterior'
# A first install interrupted the same way leaves neither dest nor receipt.
new_target swap-fresh
(
  _external_record() { kill -TERM "$BASHPID"; sleep 5; }
  plan sans
  execute_package_install
) >/dev/null 2>&1 || true
[[ ! -e "$TARGET_DIR/.local/share/fonts/sans" ]] || fail 'una primera instalación interrumpida dejó dest'
[[ ! -e "$(receipt_path external-sans)" ]] || fail 'una primera instalación interrumpida dejó recibo'
write_fonts_recipe 1 'Sans-Italic[wght].ttf'

# 15. One refused recipe does not skip the others, and the caller's own
# signal traps are back afterwards.
new_target partial
mkdir -p "$TARGET_DIR/elsewhere" "$TARGET_DIR/.local/share"
ln -s "$TARGET_DIR/elsewhere" "$TARGET_DIR/.local/share/icons"
trap 'printf outer' INT
plan cursor sans
if execute_package_install >/dev/null 2>&1; then
  fail 'una receta rechazada no hizo fallar la instalación'
fi
[[ -f "$TARGET_DIR/.local/share/fonts/sans/OFL.txt" ]] || fail 'una receta rechazada saltó las siguientes'
[[ $(trap -p INT) == *outer* ]] || fail 'no se restauró el trap INT del llamador'
trap - INT

# 16. Repository recipes are valid and pin https downloads.
names=()
shopt -s nullglob
for manifest in "$REPO_ROOT"/layers/*/packages/external/*.txt "$REPO_ROOT"/layers/wm/*/packages/external/*.txt; do
  PACKAGES_DIR=${manifest%/external/*}
  read_manifest "$manifest" names
  (( ${#names[@]} == 0 )) && continue
  plan "${names[@]}"
  validate_package_plan >/dev/null || fail "receta inválida en $manifest"
done

printf 'OK: external-smoke\n'
