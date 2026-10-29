#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd -P)

printf '==> Running canonical smoke tests for dotfiles (base)...\n'

printf '\n--> 1/12: Executing shared engine (lib/) smoke tests...\n'
"$SCRIPT_DIR/lib-smoke.sh"

printf '\n--> 2/12: Executing layer hook smoke tests...\n'
"$SCRIPT_DIR/layer-hooks-smoke.sh"

printf '\n--> 3/12: Executing shared theme engine and mimeapps smoke tests...\n'
"$SCRIPT_DIR/theme-smoke.sh"
"$SCRIPT_DIR/mimeapps-smoke.sh"

printf '\n--> 4/12: Executing WM, opt-in layer and overlay smoke tests...\n'
"$SCRIPT_DIR/wm-layers-smoke.sh"
"$SCRIPT_DIR/optional-layers-smoke.sh"
"$SCRIPT_DIR/overlay-smoke.sh"

printf '\n--> 5/12: Executing MangoWM scaffold smoke tests...\n'
"$REPO_ROOT/layers/wm/mangowm/tests/scaffold-smoke.sh"

printf '\n--> 6/12: Executing WM session smoke tests...\n'
"$REPO_ROOT/layers/wm/bspwm/tests/session-smoke.sh"
"$REPO_ROOT/layers/wm/mangowm/tests/session-smoke.sh"

printf '\n--> 7/12: Executing system layer smoke tests...\n'
"$REPO_ROOT/layers/system/tests/smoke.sh"
"$SCRIPT_DIR/system-smoke.sh"

printf '\n--> 8/12: Executing bootstrap smoke tests...\n'
"$SCRIPT_DIR/bootstrap-smoke.sh"

printf '\n--> 9/12: Executing wizard orchestrator smoke tests...\n'
"$SCRIPT_DIR/wizard-smoke.sh"

printf '\n--> 10/12: Executing external component smoke tests...\n'
"$SCRIPT_DIR/components-smoke.sh"

printf '\n--> 11/12: Executing guided setup smoke tests...\n'
"$SCRIPT_DIR/setup-smoke.sh"

printf '\n--> 12/12: Executing dropped selection retire smoke tests...\n'
"$SCRIPT_DIR/retire-smoke.sh"

printf '\nOK: all base dotfiles smoke tests passed successfully\n'
