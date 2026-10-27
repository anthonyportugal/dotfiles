#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)

printf '==> Running canonical smoke tests for dotfiles-system...\n'
exec "$SCRIPT_DIR/test_suite.sh" "$@"
