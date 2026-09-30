#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)

printf '==> Running canonical smoke tests for dotfiles-mangowm...\n'

printf '\n--> 1/3: Executing bootstrap smoke tests...\n'
"$SCRIPT_DIR/bootstrap-smoke.sh"

printf '\n--> 2/3: Executing scaffold smoke tests...\n'
"$SCRIPT_DIR/scaffold-smoke.sh"

printf '\n--> 3/3: Executing session smoke tests...\n'
"$SCRIPT_DIR/session-smoke.sh"

printf '\nOK: all mangowm smoke tests passed successfully\n'
