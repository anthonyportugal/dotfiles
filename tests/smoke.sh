#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)

printf '==> Running canonical smoke tests for dotfiles (base)...\n'

printf '\n--> 1/4: Executing shared engine (lib/) smoke tests...\n'
"$SCRIPT_DIR/lib-smoke.sh"

printf '\n--> 2/4: Executing layer hook smoke tests...\n'
"$SCRIPT_DIR/layer-hooks-smoke.sh"

printf '\n--> 3/4: Executing bootstrap smoke tests...\n'
"$SCRIPT_DIR/bootstrap-smoke.sh"

printf '\n--> 4/4: Executing wizard orchestrator smoke tests...\n'
"$SCRIPT_DIR/wizard-smoke.sh"

printf '\nOK: all base dotfiles smoke tests passed successfully\n'
