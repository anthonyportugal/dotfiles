#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd -P)

printf '==> Running canonical smoke tests for dotfiles (base)...\n'

printf '\n--> 1/7: Executing shared engine (lib/) smoke tests...\n'
"$SCRIPT_DIR/lib-smoke.sh"

printf '\n--> 2/7: Executing layer hook smoke tests...\n'
"$SCRIPT_DIR/layer-hooks-smoke.sh"

printf '\n--> 3/7: Executing WM layer smoke tests...\n'
"$SCRIPT_DIR/wm-layers-smoke.sh"

printf '\n--> 4/7: Executing MangoWM scaffold smoke tests...\n'
"$REPO_ROOT/layers/wm/mangowm/tests/scaffold-smoke.sh"

printf '\n--> 5/7: Executing WM session smoke tests...\n'
"$REPO_ROOT/layers/wm/bspwm/tests/session-smoke.sh"
"$REPO_ROOT/layers/wm/mangowm/tests/session-smoke.sh"

printf '\n--> 6/7: Executing bootstrap smoke tests...\n'
"$SCRIPT_DIR/bootstrap-smoke.sh"

printf '\n--> 7/7: Executing wizard orchestrator smoke tests...\n'
"$SCRIPT_DIR/wizard-smoke.sh"

printf '\nOK: all base dotfiles smoke tests passed successfully\n'
