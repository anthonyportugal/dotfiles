#!/usr/bin/env bash
# tests/smoke.sh: argument errors exit 2 before any stage runs, every stage is
# in exactly one group, and the CI matrix runs exactly the runner's groups.

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
RUNNER="$SCRIPT_DIR/smoke.sh"
WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

# Runs the runner with arguments $@ and prints "<exit> <output>".
runner() {
  local status=0 output

  output=$("$RUNNER" "$@" 2>&1) || status=$?
  printf '%s %s' "$status" "$output"
}

output=$(runner nope)
[[ "$output" == 2\ *'unknown smoke test group: nope'* ]] || fail "un grupo desconocido no fue error de uso: $output"
[[ "$output" != *'-->'* ]] || fail "un grupo desconocido ejecutó etapas: $output"
output=$(runner themes layers)
[[ "$output" == 2\ *'Usage:'* ]] || fail "dos grupos no fueron error de uso: $output"

# The group table covers stages 1..STAGE_COUNT exactly once.
groups=$(sed -n "s/^  \[\([a-z]*\)\]='\([0-9 ]*\)'$/\1 \2/p" "$RUNNER")
stage_count=$(sed -n 's/^STAGE_COUNT=\([0-9]*\)$/\1/p' "$RUNNER")
[[ -n "$groups" && -n "$stage_count" ]] || fail 'no se pudo leer la tabla de grupos de smoke.sh'
stages=$(cut -d' ' -f2- <<< "$groups" | tr ' ' '\n' | sort -n | tr '\n' ' ')
[[ "$stages" == "$(seq -s ' ' 1 "$stage_count") " ]] || fail "los grupos no cubren cada etapa una vez: $stages"
for (( stage = 1; stage <= stage_count; stage++ )); do
  grep -q "^stage_$stage() {" "$RUNNER" || fail "falta la etapa $stage en smoke.sh"
done

# CI runs the same groups (matrix) and keeps the required check name.
runner_groups=$(cut -d' ' -f1 <<< "$groups" | sort | tr '\n' ' ')
ci_groups=$(sed -n 's/^ *group: \[\(.*\)\]$/\1/p' "$WORKFLOW" | tr -d ' ' | tr ',' '\n' | sort | tr '\n' ' ')
[[ "$ci_groups" == "$runner_groups" ]] || fail "la matriz de CI ($ci_groups) no coincide con smoke.sh ($runner_groups)"
grep -Fq 'name: Bootstrap & Smoke Tests' "$WORKFLOW" || fail 'CI perdió el check requerido Bootstrap & Smoke Tests'
# shellcheck disable=SC2016  # GitHub Actions expression, matched literally
grep -Fq './tests/smoke.sh "${{ matrix.group }}"' "$WORKFLOW" || fail 'CI no ejecuta cada grupo de la matriz'

printf 'OK: grupos del runner de smoke tests validados\n'
