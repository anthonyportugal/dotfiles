#!/usr/bin/env bash
# Exercises `dotfiles system`, the only entrypoint of the root-level system
# layer. sudo and pacman are replaced by doubles, so nothing under / is ever
# written and no package is installed.

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
# shellcheck source=SCRIPTDIR/lib/checkout-copy.sh
source "$SCRIPT_DIR/lib/checkout-copy.sh"
DOTFILES="$REPO_ROOT/bin/dotfiles"
INSTALLER="$REPO_ROOT/layers/system/install.sh"
TEST_ROOT=""
TEST_TMP_PARENT=${DOTFILES_TEST_TMPDIR:-/tmp}

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  [[ -n "$TEST_ROOT" && "$TEST_ROOT" == "$TEST_TMP_PARENT"/dotfiles-system-smoke.* ]] || return 0
  rm -rf -- "$TEST_ROOT"
}

trap cleanup EXIT

[[ -d "$TEST_TMP_PARENT" ]] || fail "no existe el directorio temporal: $TEST_TMP_PARENT"
TEST_ROOT=$(mktemp -d "$TEST_TMP_PARENT/dotfiles-system-smoke.XXXXXX")
CHECKOUT_STATE=$(git -C "$REPO_ROOT" status --porcelain)

FAKE_BIN="$TEST_ROOT/fake-bin"
SUDO_LOG="$TEST_ROOT/sudo.log"
mkdir -p "$FAKE_BIN"
# sudo records its arguments and exits with $FAKE_SUDO_EXIT without running
# anything; pacman reports no installed package.
# shellcheck disable=SC2016
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> "%s"\nexit "${FAKE_SUDO_EXIT:-0}"\n' "$SUDO_LOG" > "$FAKE_BIN/sudo"
printf '#!/usr/bin/env bash\nexit 0\n' > "$FAKE_BIN/pacman"
chmod +x "$FAKE_BIN/sudo" "$FAKE_BIN/pacman"

H="$TEST_ROOT/home"
RECEIPT="$H/.local/state/dotfiles/system.receipt"
mkdir -p "$H"

run_system() {
  PATH="$FAKE_BIN:/usr/bin:/bin" HOME="$H" "$DOTFILES" system "$@"
}

# help lists the subcommands and never escalates.
output=$(run_system help) || fail "system help falló"
[[ "$output" == *'dotfiles system'*'doctor'* ]] || fail "system help no describe los subcomandos: $output"
[[ ! -e "$SUDO_LOG" ]] || fail "system help usó sudo"

# doctor reaches the installer's audit (not its usage or an error) without sudo.
run_system doctor --target "$H" > "$TEST_ROOT/doctor.out" 2>&1 || \
  fail "system doctor falló: $(<"$TEST_ROOT/doctor.out")"
grep -q 'Running comprehensive system audit' "$TEST_ROOT/doctor.out" || \
  fail "system doctor no llegó a la auditoría del instalador: $(<"$TEST_ROOT/doctor.out")"
grep -q 'Performing configuration and service audit' "$TEST_ROOT/doctor.out" || \
  fail "system doctor no auditó Ly: $(<"$TEST_ROOT/doctor.out")"
[[ ! -e "$SUDO_LOG" ]] || fail "system doctor usó sudo"

# doctor rejects setup options instead of ignoring them.
status=0
run_system doctor --ly --target "$H" >/dev/null 2>&1 || status=$?
(( status == 2 )) || fail "system doctor aceptó una opción de setup (salida $status)"

# A dry run needs no root, never escalates and records nothing.
output=$(run_system setup --dns -p quad9 --dry-run --target "$H" 2>&1) || fail "system setup --dry-run falló: $output"
[[ "$output" == *DRY-RUN* ]] || fail "system setup --dry-run no simuló la instalación: $output"
[[ ! -e "$SUDO_LOG" ]] || fail "system setup --dry-run usó sudo"
[[ ! -e "$RECEIPT" ]] || fail "un dry run escribió el recibo de system"

# --install plans the Ly package through the monorepo backend engine.
output=$(run_system setup --ly --install --dry-run --platform arch --backend pacman --target "$H" 2>&1) || \
  fail "system setup --install --dry-run falló: $output"
[[ "$output" == *'pacman -S --needed ly'* ]] || fail "system no planificó ly con el motor de paquetes: $output"
[[ ! -e "$SUDO_LOG" ]] || fail "el plan de paquetes en dry run usó sudo"
if output=$(run_system setup --ly --install --dry-run --platform windows --target "$H" 2>&1); then
  fail "system aceptó una plataforma inválida"
fi
[[ "$output" == *windows* ]] || fail "system no nombró la plataforma inválida: $output"

# setup escalates with sudo explicitly, without forwarding --install, and
# records the applied selection in the user's receipt.
output=$(run_system setup --dns -p quad9 --install --target "$H" 2>&1) || fail "system setup falló: $output"
[[ "$(<"$SUDO_LOG")" == "$INSTALLER --dns -p quad9 --lang en" ]] || \
  fail "system no escaló con los argumentos esperados: $(<"$SUDO_LOG")"
[[ -f "$RECEIPT" ]] || fail "system setup no guardó el recibo"
grep -Fxq 'COMPONENT="system"' "$RECEIPT" || fail "recibo de system sin COMPONENT"
grep -Fxq 'SYSTEM_ARGS="--dns -p quad9"' "$RECEIPT" || fail "recibo de system sin la selección: $(<"$RECEIPT")"

# The saved selection is shown by doctor.
output=$(run_system doctor --target "$H" 2>&1) || true
[[ "$output" == *'--dns -p quad9'* ]] || fail "system doctor no mostró la selección guardada: $output"

# A failed escalation fails the command and keeps the previous receipt.
rm -f -- "$SUDO_LOG"
before=$(sha256sum < "$RECEIPT")
if FAKE_SUDO_EXIT=1 run_system setup --ly --target "$H" >/dev/null 2>&1; then
  fail "system setup informó éxito con un instalador fallido"
fi
[[ "$(sha256sum < "$RECEIPT")" == "$before" ]] || fail "un setup fallido cambió el recibo"

# Custom DoT endpoints may carry a private resolver id: never stored.
rm -f -- "$SUDO_LOG"
run_system setup --dns --custom '45.90.28.0#secret-id.dns.nextdns.io' --target "$H" >/dev/null 2>&1 || \
  fail "system setup --custom falló"
! grep -q 'secret-id' "$RECEIPT" || fail "el recibo guardó los endpoints DoT personalizados"
grep -Fxq 'SYSTEM_ARGS="--dns --custom"' "$RECEIPT" || fail "recibo inesperado con --custom: $(<"$RECEIPT")"

# The profile commands never run the system layer.
rm -f -- "$SUDO_LOG"
PATH="$FAKE_BIN:/usr/bin:/bin" HOME="$H" "$DOTFILES" bootstrap --profile core --stow-only --target "$H" >/dev/null 2>&1 || true
[[ ! -e "$SUDO_LOG" ]] || fail "bootstrap ejecutó la capa system"

# update never applies the system layer: when the pulled range changed it on
# a machine that applied it, it only says how to re-apply it.
UPSTREAM="$TEST_ROOT/upstream"
CHECKOUT="$TEST_ROOT/checkout"
copy_checkout "$REPO_ROOT" "$UPSTREAM"
# CI checks out a detached HEAD, and update can only pull on a branch.
git -C "$UPSTREAM" switch -qC upstream
git -C "$UPSTREAM" add -A
git -C "$UPSTREAM" -c user.name=t -c user.email=t@t commit -qm wip --allow-empty --no-verify
git clone -q "$UPSTREAM" "$CHECKOUT"
UH="$TEST_ROOT/update-home"
mkdir -p "$UH/.local/state/dotfiles"
printf 'RECEIPT_VERSION=1\nCOMPONENT="system"\nSYSTEM_ARGS="--dns -p quad9"\n' \
  > "$UH/.local/state/dotfiles/system.receipt"
run_update() {
  PATH="$FAKE_BIN:/usr/bin:/bin" HOME="$UH" "$CHECKOUT/bin/dotfiles" update -y \
    --profile core --stow-only --target "$UH" 2>&1
}
printf '\n' >> "$UPSTREAM/README.md"
git -C "$UPSTREAM" -c user.name=t -c user.email=t@t commit -qam docs --no-verify
rm -f -- "$SUDO_LOG"
output=$(run_update) || fail "update falló: $output"
[[ "$output" != *'La capa system cambió'* && "$output" != *'system layer changed'* ]] || \
  fail "update avisó de system sin cambios en layers/system"
printf '# change\n' >> "$UPSTREAM/layers/system/dns/providers/quad9.conf"
git -C "$UPSTREAM" -c user.name=t -c user.email=t@t commit -qam system --no-verify
output=$(run_update) || fail "update falló con cambios en system: $output"
[[ "$output" == *'dotfiles system setup --dns -p quad9'* ]] || fail "update no avisó del cambio en system: $output"
[[ ! -e "$SUDO_LOG" ]] || fail "update ejecutó la capa system"
printf 'RECEIPT_VERSION=1\nCOMPONENT="system"\nSYSTEM_ARGS="--dns --custom"\n' \
  > "$UH/.local/state/dotfiles/system.receipt"
printf '# change\n' >> "$UPSTREAM/layers/system/dns/providers/quad9.conf"
git -C "$UPSTREAM" -c user.name=t -c user.email=t@t commit -qam system2 --no-verify
output=$(run_update) || fail "update falló con --custom guardado: $output"
[[ "$output" == *'dotfiles system setup --dns --custom <endpoints>'* ]] || \
  fail "update no pidió de nuevo los endpoints personalizados: $output"

[[ "$(git -C "$REPO_ROOT" status --porcelain)" == "$CHECKOUT_STATE" ]] || fail "system modificó el checkout"

printf 'OK: comando dotfiles system validado\n'
