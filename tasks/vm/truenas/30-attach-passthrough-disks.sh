#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export HOMELAB_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
source "$HOMELAB_ROOT/lib/truenas/vm101.sh"

require_root
require_cmd qm
truenas_validate_disks

qm set "$TRUENAS_VMID" --scsi1 "$TRUENAS_TANK_DISK",serial=TANK20TB
qm set "$TRUENAS_VMID" --scsi2 "$TRUENAS_PRIVATE_DISK",serial=PRIVATE4TB
echo "SATA passthrough diskleri takildi."
