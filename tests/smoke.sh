#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd -P)

printf '==> Running canonical smoke tests for dotfiles (base)...\n'

printf '\n--> 1/13: Executing shared engine (lib/) and external download smoke tests...\n'
"$SCRIPT_DIR/lib-smoke.sh"
"$SCRIPT_DIR/external-smoke.sh"

printf '\n--> 2/13: Executing layer hook smoke tests...\n'
"$SCRIPT_DIR/layer-hooks-smoke.sh"

printf '\n--> 3/13: Executing shared theme engine, mimeapps, font and image viewer smoke tests...\n'
"$SCRIPT_DIR/theme-smoke.sh"
"$SCRIPT_DIR/theme-schema-smoke.sh"
"$SCRIPT_DIR/theme-apps-smoke.sh"
"$SCRIPT_DIR/mimeapps-smoke.sh"
"$SCRIPT_DIR/fonts-smoke.sh"
"$SCRIPT_DIR/imv-folder-smoke.sh"
"$SCRIPT_DIR/checkout-copy-smoke.sh"

printf '\n--> 4/13: Executing WM, opt-in layer and overlay smoke tests...\n'
"$SCRIPT_DIR/wm-layers-smoke.sh"
"$SCRIPT_DIR/optional-layers-smoke.sh"
"$SCRIPT_DIR/overlay-smoke.sh"

printf '\n--> 5/13: Executing MangoWM scaffold and menu smoke tests...\n'
"$REPO_ROOT/layers/wm/mangowm/tests/scaffold-smoke.sh"
"$REPO_ROOT/layers/wm/mangowm/tests/menu-smoke.sh"

printf '\n--> 6/13: Executing WM session smoke tests...\n'
"$REPO_ROOT/layers/wm/bspwm/tests/session-smoke.sh"
"$REPO_ROOT/layers/wm/mangowm/tests/session-smoke.sh"

printf '\n--> 7/13: Executing system layer smoke tests...\n'
"$REPO_ROOT/layers/system/tests/smoke.sh"
"$SCRIPT_DIR/system-smoke.sh"

printf '\n--> 8/13: Executing bootstrap smoke tests...\n'
"$SCRIPT_DIR/bootstrap-smoke.sh"

printf '\n--> 9/13: Executing wizard orchestrator smoke tests...\n'
"$SCRIPT_DIR/wizard-smoke.sh"

printf '\n--> 10/13: Executing external component smoke tests...\n'
"$SCRIPT_DIR/components-smoke.sh"

printf '\n--> 11/13: Executing guided setup smoke tests...\n'
"$SCRIPT_DIR/setup-smoke.sh"

printf '\n--> 12/13: Executing dropped selection retire smoke tests...\n'
"$SCRIPT_DIR/retire-smoke.sh"

printf '\n--> 13/13: Executing checkout switch smoke tests...\n'
"$SCRIPT_DIR/switch-smoke.sh"

printf '\nOK: all base dotfiles smoke tests passed successfully\n'
