#!/usr/bin/env bash
# lib/run-layer.sh - Runs one layer operation in a fresh bash process.
#
# Invoked by run_layer (lib/layer_ops.sh). A fresh process keeps errexit in
# force even when the caller checks the result with || or if, which a
# subshell cannot guarantee. Arguments: layers root, layer name, operation,
# profile and apply mode. The caller passes TARGET_DIR, PLATFORM_REQUEST,
# BACKEND_REQUEST, SYSTEM_ENABLED, STOW_ENABLED, PACKAGE_BACKENDS_FILE and
# REPO_ROOT through the environment.
#
# shellcheck source-path=SCRIPTDIR

set -Eeuo pipefail

RUN_LAYER_LIB=$(cd -- "${BASH_SOURCE[0]%/*}" && pwd -P)
# shellcheck source=colors.sh
source "$RUN_LAYER_LIB/colors.sh"
# shellcheck source=core.sh
source "$RUN_LAYER_LIB/core.sh"
# shellcheck source=receipts.sh
source "$RUN_LAYER_LIB/receipts.sh"
# shellcheck source=external.sh
source "$RUN_LAYER_LIB/external.sh"
# shellcheck source=packages.sh
source "$RUN_LAYER_LIB/packages.sh"
# shellcheck source=links.sh
source "$RUN_LAYER_LIB/links.sh"
# shellcheck source=layers.sh
source "$RUN_LAYER_LIB/layers.sh"
# shellcheck source=layer_ops.sh
source "$RUN_LAYER_LIB/layer_ops.sh"
setup_colors

_layer_setup "$1" "$2" "$4" "$3" "$5"
"layer_$3"
