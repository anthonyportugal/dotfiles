#!/usr/bin/env bash
# Canonical smoke tests. Without arguments every stage runs, in order; with a
# group name only that group's stages run, so CI can run the groups in
# parallel jobs. Every stage belongs to exactly one group.

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
STAGE_COUNT=13

# Groups balanced by their CI duration; .github/workflows/ci.yml lists the same names.
declare -A SMOKE_GROUPS=(
  [themes]='3'
  [layers]='1 2 4 5 6 7'
  [setup]='8 9 10 11'
  [lifecycle]='12 13'
)
GROUP_NAMES=(themes layers setup lifecycle)

usage() {
  printf 'Usage: %s [%s]\n' "${0##*/}" "$(IFS='|'; printf '%s' "${GROUP_NAMES[*]}")" >&2
}

stage_1() {
  printf '\n--> 1/13: Executing shared engine (lib/), smoke runner and external download smoke tests...\n'
  "$SCRIPT_DIR/lib-smoke.sh"
  "$SCRIPT_DIR/smoke-runner-smoke.sh"
  "$SCRIPT_DIR/external-smoke.sh"
}

stage_2() {
  printf '\n--> 2/13: Executing layer hook smoke tests...\n'
  "$SCRIPT_DIR/layer-hooks-smoke.sh"
}

stage_3() {
  printf '\n--> 3/13: Executing shared theme engine, Sanctuary palette, theme picker, mimeapps, font and image viewer smoke tests...\n'
  "$SCRIPT_DIR/theme-smoke.sh"
  "$SCRIPT_DIR/theme-schema-smoke.sh"
  "$SCRIPT_DIR/theme-apps-smoke.sh"
  "$SCRIPT_DIR/sanctuary-smoke.sh"
  "$SCRIPT_DIR/theme-picker-smoke.sh"
  "$SCRIPT_DIR/mimeapps-smoke.sh"
  "$SCRIPT_DIR/fonts-smoke.sh"
  "$SCRIPT_DIR/cli-tools-smoke.sh"
  "$SCRIPT_DIR/cursor-smoke.sh"
  "$SCRIPT_DIR/imv-folder-smoke.sh"
  "$SCRIPT_DIR/checkout-copy-smoke.sh"
}

stage_4() {
  printf '\n--> 4/13: Executing WM, opt-in layer and overlay smoke tests...\n'
  "$SCRIPT_DIR/wm-layers-smoke.sh"
  "$SCRIPT_DIR/optional-layers-smoke.sh"
  "$SCRIPT_DIR/overlay-smoke.sh"
}

stage_5() {
  printf '\n--> 5/13: Executing MangoWM scaffold and menu smoke tests...\n'
  "$REPO_ROOT/layers/wm/mangowm/tests/scaffold-smoke.sh"
  "$REPO_ROOT/layers/wm/mangowm/tests/menu-smoke.sh"
}

stage_6() {
  printf '\n--> 6/13: Executing WM session smoke tests...\n'
  "$REPO_ROOT/layers/wm/bspwm/tests/session-smoke.sh"
  "$REPO_ROOT/layers/wm/mangowm/tests/session-smoke.sh"
}

stage_7() {
  printf '\n--> 7/13: Executing system layer smoke tests...\n'
  "$REPO_ROOT/layers/system/tests/smoke.sh"
  "$SCRIPT_DIR/system-smoke.sh"
}

stage_8() {
  printf '\n--> 8/13: Executing bootstrap smoke tests...\n'
  "$SCRIPT_DIR/bootstrap-smoke.sh"
}

stage_9() {
  printf '\n--> 9/13: Executing wizard orchestrator smoke tests...\n'
  "$SCRIPT_DIR/wizard-smoke.sh"
}

stage_10() {
  printf '\n--> 10/13: Executing external component smoke tests...\n'
  "$SCRIPT_DIR/components-smoke.sh"
}

stage_11() {
  printf '\n--> 11/13: Executing guided setup smoke tests...\n'
  "$SCRIPT_DIR/setup-smoke.sh"
}

stage_12() {
  printf '\n--> 12/13: Executing dropped selection retire smoke tests...\n'
  "$SCRIPT_DIR/retire-smoke.sh"
}

stage_13() {
  printf '\n--> 13/13: Executing checkout switch smoke tests...\n'
  "$SCRIPT_DIR/switch-smoke.sh"
}

# A stage left out of every group, or listed twice, would silently skip or
# repeat it in CI.
check_groups() {
  local group stage
  local -A seen=()

  for group in "${GROUP_NAMES[@]}"; do
    for stage in ${SMOKE_GROUPS[$group]}; do
      [[ -z "${seen[$stage]-}" ]] || { printf 'ERROR: stage %s is in groups %s and %s\n' "$stage" "${seen[$stage]}" "$group" >&2; return 1; }
      seen[$stage]=$group
    done
  done
  for (( stage = 1; stage <= STAGE_COUNT; stage++ )); do
    [[ -n "${seen[$stage]-}" ]] || { printf 'ERROR: stage %s belongs to no group\n' "$stage" >&2; return 1; }
  done
  (( ${#seen[@]} == STAGE_COUNT )) || { printf 'ERROR: groups name stages beyond %s\n' "$STAGE_COUNT" >&2; return 1; }
}

check_groups

(( $# <= 1 )) || { usage; exit 2; }
group=${1-}
if [[ -z "$group" ]]; then
  stages=$(seq 1 "$STAGE_COUNT")
  label='base'
elif [[ -n "${SMOKE_GROUPS[$group]-}" ]]; then
  stages=${SMOKE_GROUPS[$group]}
  label="group $group"
else
  printf 'ERROR: unknown smoke test group: %s\n' "$group" >&2
  usage
  exit 2
fi

printf '==> Running canonical smoke tests for dotfiles (%s)...\n' "$label"
for stage in $stages; do
  "stage_$stage"
done

printf '\nOK: all %s dotfiles smoke tests passed successfully\n' "$label"
