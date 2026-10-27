#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd -P)

printf '==> Running canonical smoke tests for dotfiles (base)...\n'

printf '\n--> 1/9: Executing shared engine (lib/) smoke tests...\n'
"$SCRIPT_DIR/lib-smoke.sh"

printf '\n--> 2/9: Executing layer hook smoke tests...\n'
"$SCRIPT_DIR/layer-hooks-smoke.sh"

printf '\n--> 3/9: Executing shared theme engine and mimeapps smoke tests...\n'
"$SCRIPT_DIR/theme-smoke.sh"
"$SCRIPT_DIR/mimeapps-smoke.sh"

printf '\n--> 4/9: Executing WM layer smoke tests...\n'
"$SCRIPT_DIR/wm-layers-smoke.sh"

printf '\n--> 5/9: Executing MangoWM scaffold smoke tests...\n'
"$REPO_ROOT/layers/wm/mangowm/tests/scaffold-smoke.sh"

printf '\n--> 6/9: Executing WM session smoke tests...\n'
"$REPO_ROOT/layers/wm/bspwm/tests/session-smoke.sh"
"$REPO_ROOT/layers/wm/mangowm/tests/session-smoke.sh"

printf '\n--> 7/9: Executing system layer smoke tests...\n'
"$REPO_ROOT/layers/system/tests/smoke.sh"

printf '\n--> 8/9: Executing bootstrap smoke tests...\n'
"$SCRIPT_DIR/bootstrap-smoke.sh"

printf '\n--> 9/9: Executing wizard orchestrator smoke tests...\n'
"$SCRIPT_DIR/wizard-smoke.sh"

printf '\nOK: all base dotfiles smoke tests passed successfully\n'
