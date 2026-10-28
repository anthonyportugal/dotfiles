#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd -P)

printf '==> Running canonical smoke tests for dotfiles (base)...\n'

printf '\n--> 1/10: Executing shared engine (lib/) smoke tests...\n'
"$SCRIPT_DIR/lib-smoke.sh"

printf '\n--> 2/10: Executing layer hook smoke tests...\n'
"$SCRIPT_DIR/layer-hooks-smoke.sh"

printf '\n--> 3/10: Executing shared theme engine and mimeapps smoke tests...\n'
"$SCRIPT_DIR/theme-smoke.sh"
"$SCRIPT_DIR/mimeapps-smoke.sh"

printf '\n--> 4/10: Executing WM, opt-in layer and overlay smoke tests...\n'
"$SCRIPT_DIR/wm-layers-smoke.sh"
"$SCRIPT_DIR/optional-layers-smoke.sh"
"$SCRIPT_DIR/overlay-smoke.sh"

printf '\n--> 5/10: Executing MangoWM scaffold smoke tests...\n'
"$REPO_ROOT/layers/wm/mangowm/tests/scaffold-smoke.sh"

printf '\n--> 6/10: Executing WM session smoke tests...\n'
"$REPO_ROOT/layers/wm/bspwm/tests/session-smoke.sh"
"$REPO_ROOT/layers/wm/mangowm/tests/session-smoke.sh"

printf '\n--> 7/10: Executing system layer smoke tests...\n'
"$REPO_ROOT/layers/system/tests/smoke.sh"
"$SCRIPT_DIR/system-smoke.sh"

printf '\n--> 8/10: Executing bootstrap smoke tests...\n'
"$SCRIPT_DIR/bootstrap-smoke.sh"

printf '\n--> 9/10: Executing wizard orchestrator smoke tests...\n'
"$SCRIPT_DIR/wizard-smoke.sh"

printf '\n--> 10/10: Executing external component smoke tests...\n'
"$SCRIPT_DIR/components-smoke.sh"

printf '\nOK: all base dotfiles smoke tests passed successfully\n'
