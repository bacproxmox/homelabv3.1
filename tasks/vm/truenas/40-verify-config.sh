#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export HOMELAB_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
source "$HOMELAB_ROOT/lib/truenas/vm101.sh"

require_root
require_cmd qm
truenas_load_iso_state

cfg="$(qm config "$TRUENAS_VMID")"
echo "$cfg"

echo
echo "VM101 dogrulama..."
echo "$cfg" | grep -q '^ide2: local:iso/TrueNAS-SCALE-' || {
  echo "Hata: ISO ide2 uzerinde local:iso/... olarak bagli degil."
  exit 1
}
echo "$cfg" | grep -q "^scsi1: $TRUENAS_TANK_DISK" || {
  echo "Hata: scsi1 20TB tank passthrough bagli degil."
  exit 1
}
echo "$cfg" | grep -q "^scsi2: $TRUENAS_PRIVATE_DISK" || {
  echo "Hata: scsi2 4TB private passthrough bagli degil."
  exit 1
}
if echo "$cfg" | grep -E '^scsi[12]:' | grep -q 'nvme'; then
  echo "Hata: NVMe scsi1/scsi2 passthrough olarak gorunuyor."
  exit 1
fi
echo "VM101 ISO + passthrough dogrulamasi tamam."
