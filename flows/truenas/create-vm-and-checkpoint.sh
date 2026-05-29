#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export HOMELAB_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$HOMELAB_ROOT/lib/core/runner.sh"

homelab_run "flows/truenas/create-vm.sh"
homelab_run "flows/truenas/manual-install-checkpoint.sh"
