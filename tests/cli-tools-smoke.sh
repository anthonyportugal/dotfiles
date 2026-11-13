#!/usr/bin/env bash
# Modern CLI tools: the cli layer declares eza, zoxide, tealdeer, dust and duf
# from the official repositories; zsh lists files with eza when it is
# installed and adds zoxide's z/zi without replacing cd.

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
CLI_LAYER="$REPO_ROOT/layers/cli/packages"
ZSH_DIR="$REPO_ROOT/layers/core/home/zsh/.config/zsh"
ALIASES="$ZSH_DIR/conf.d/40-aliases.zsh"
ZOXIDE="$ZSH_DIR/init.d/95-zoxide.zsh"
TEST_ROOT=''

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  [[ -n "$TEST_ROOT" && "$TEST_ROOT" == /tmp/cli-tools-smoke.* ]] || return 0
  find "$TEST_ROOT" -mindepth 1 -delete
  find "$TEST_ROOT" -depth -type d -empty -delete
}
trap cleanup EXIT

# 1. Packages: official repositories only, never the AUR.
for package in eza zoxide tealdeer dust duf; do
  grep -qxF -- "$package" "$CLI_LAYER/repo/cli.txt" || \
    fail "la capa cli no declara $package"
  if found=$(grep -rlxF -- "$package" "$CLI_LAYER"/aur 2>/dev/null); then
    fail "$package viene del AUR: $found"
  fi
done

# 2. tealdeer never touches the network when a shell starts.
if found=$(grep -rnE '(^|[^[:alnum:]_-])tldr([[:space:]]|$)' "$ZSH_DIR" "$REPO_ROOT/layers/core/home/zsh/.zshrc"); then
  fail "zsh ejecuta tldr al iniciar:"$'\n'"$found"
fi

# 3. zoxide initializes after the plugins (90-plugins.zsh).
[[ -f "$ZOXIDE" ]] || fail "falta $ZOXIDE"
last=$(cd "$ZSH_DIR/init.d" && printf '%s\n' *.zsh | LC_ALL=C sort | tail -n 1)
[[ "$last" == "${ZOXIDE##*/}" ]] || fail "zoxide no se inicializa al final de init.d (último: $last)"

command -v zsh >/dev/null 2>&1 || {
  printf 'SKIP: zsh no está instalado; se omiten los alias y zoxide\n'
  exit 0
}
ZSH=$(command -v zsh)

TEST_ROOT=$(mktemp -d /tmp/cli-tools-smoke.XXXXXX)
mkdir -p "$TEST_ROOT/with/bin" "$TEST_ROOT/without/bin" "$TEST_ROOT/home"
for dir in with without; do
  printf '#!/bin/sh\nprintf "real-ls %%s\\n" "$*"\n' > "$TEST_ROOT/$dir/bin/ls"
  chmod +x "$TEST_ROOT/$dir/bin/ls"
done
printf '#!/bin/sh\nprintf "eza %%s\\n" "$*"\n' > "$TEST_ROOT/with/bin/eza"
# A zoxide double: `init zsh` prints the functions the real one defines.
cat > "$TEST_ROOT/with/bin/zoxide" <<'EOF'
#!/bin/sh
[ "$1 $2" = 'init zsh' ] || exit 64
printf 'z() { print -r -- "zoxide-z $*"; }\nzi() { print -r -- "zoxide-zi $*"; }\n'
EOF
chmod +x "$TEST_ROOT/with/bin/eza" "$TEST_ROOT/with/bin/zoxide"

run_zsh() {
  local bin=$1 code=$2
  # shellcheck disable=SC2016 # expanded by zsh
  env -i HOME="$TEST_ROOT/home" PATH="$bin" "$ZSH" -fc \
    'source "$1"; source "$2"; eval "$3"' zsh "$ALIASES" "$ZOXIDE" "$code" 2>&1
}

# 4. With eza: ls, ll, la and lt list with icons and directories first.
with="$TEST_ROOT/with/bin"
for name in ls ll la lt; do
  output=$(run_zsh "$with" "$name /data")
  [[ "$output" == 'eza '*'--icons'*'--group-directories-first'*'/data' ]] || \
    fail "$name con eza no lista con iconos y directorios primero: $output"
done
[[ "$(run_zsh "$with" 'll /data')" == *' -la'* || "$(run_zsh "$with" 'll /data')" == *' -l -a'* ]] || \
  fail "ll con eza no es un listado largo con ocultos: $(run_zsh "$with" 'll /data')"
[[ "$(run_zsh "$with" 'lt /data')" == *'--tree'* ]] || \
  fail "lt con eza no muestra un árbol: $(run_zsh "$with" 'lt /data')"
output=$(run_zsh "$with" 'command ls /data')
[[ "$output" == 'real-ls /data' ]] || fail "command ls no llega al ls real: $output"

# 5. Without eza: ls stays ls and the long listings keep using it.
without="$TEST_ROOT/without/bin"
output=$(run_zsh "$without" 'ls /data')
[[ "$output" == 'real-ls /data' ]] || fail "ls sin eza no es el ls real: $output"
output=$(run_zsh "$without" 'll /data')
[[ "$output" == 'real-ls --color=auto -lah /data' ]] || fail "ll sin eza cambió: $output"

# 6. zoxide adds z and zi; cd stays the builtin.
output=$(run_zsh "$with" 'z proj; zi; whence -w cd')
[[ "$output" == $'zoxide-z proj\nzoxide-zi \ncd: builtin' ]] || fail "zoxide no define z/zi o reemplaza cd: $output"
output=$(run_zsh "$without" 'whence -w z cd; true')
[[ "$output" == $'z: none\ncd: builtin' ]] || fail "sin zoxide aparece z o cambia cd: $output"

printf 'PASS: cli tools (eza, zoxide, tealdeer, dust, duf)\n'
