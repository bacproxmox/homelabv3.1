#!/usr/bin/env bash
set -Eeuo pipefail

if [[ -z "${HOMELAB_ROOT:-}" ]]; then
  HOMELAB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

source "$HOMELAB_ROOT/lib/core/env.sh"
source "$HOMELAB_ROOT/lib/core/state.sh"
load_all_env

TRUENAS_VMID="${TRUENAS_VMID:-101}"
TRUENAS_VMNAME="${TRUENAS_VMNAME:-truenas}"
TRUENAS_VM_STORAGE="${VM_STORAGE:-${TRUENAS_VM_STORAGE:-nvme-vm}}"
PVE_NVME_DISK="${PVE_NVME_DISK:-/dev/disk/by-id/nvme-XPG_SPECTRIX_S40G_2J4520139863}"
TRUENAS_TANK_DISK="${TRUENAS_TANK_DISK:-/dev/disk/by-id/ata-TOSHIBA_MG10ACA20TE_4580A0BSF4MJ}"
TRUENAS_PRIVATE_DISK="${TRUENAS_PRIVATE_DISK:-/dev/disk/by-id/ata-ST4000NM0053_Z1Z5KNAT}"
TRUENAS_ISO_DIR="${TRUENAS_ISO_DIR:-/var/lib/vz/template/iso}"
TRUENAS_DOWNLOAD_PAGE="${TRUENAS_DOWNLOAD_PAGE:-https://www.truenas.com/download/}"
TRUENAS_CODENAME="${TRUENAS_CODENAME:-Goldeye}"
TRUENAS_VM_RAM="${TRUENAS_VM_RAM:-32768}"
TRUENAS_OS_DISK="${TRUENAS_OS_DISK:-64}"
TRUENAS_FIXED_MAC="${TRUENAS_FIXED_MAC:-${VM101_MAC:-02:23:14:00:01:01}}"
TRUENAS_ISO_STATE="${TRUENAS_ISO_STATE:-$STATE_DIR/truenas-iso.env}"

truenas_fail_disk_missing() {
  local label="$1" path="$2"
  echo "Hata: $label bulunamadi: $path"
  echo
  echo "Mevcut diskler:"
  lsblk -o NAME,SIZE,TYPE,MODEL,SERIAL,TRAN | sed 's/^/  /' || true
  echo
  echo "/dev/disk/by-id listesi:"
  find /dev/disk/by-id -maxdepth 1 -type l | sort | sed 's/^/  /' || true
  exit 1
}

truenas_assert_not_nvme_passthrough() {
  local disk="$1"
  if [[ "$disk" == *nvme* || "$disk" == "$PVE_NVME_DISK" ]]; then
    echo "Hata: TrueNAS passthrough icin NVMe secilemez: $disk"
    exit 1
  fi
}

truenas_discover_latest_version() {
  curl -fsSL "$TRUENAS_DOWNLOAD_PAGE" \
    | grep -Eo '[0-9]{2}\.[0-9]{2}\.[0-9]+(\.[0-9]+)?(-[A-Za-z0-9.]+)?' \
    | grep -v -Ei 'BETA|RC|ALPHA|NIGHTLY|MASTER' \
    | sort -V \
    | tail -n 1
}

truenas_write_iso_state() {
  local version="$1"
  local iso_file="TrueNAS-SCALE-${version}.iso"
  local local_iso="$TRUENAS_ISO_DIR/$iso_file"
  local pve_iso="local:iso/$iso_file"
  local iso_url="https://download.sys.truenas.net/TrueNAS-SCALE-${TRUENAS_CODENAME}/${version}/TrueNAS-SCALE-${version}.iso"

  mkdir -p "$STATE_DIR"
  cat > "$TRUENAS_ISO_STATE" <<ENV
TRUENAS_LATEST_VERSION=$version
TRUENAS_ISO_FILE=$iso_file
TRUENAS_LOCAL_ISO=$local_iso
TRUENAS_PVE_ISO=$pve_iso
TRUENAS_ISO_URL=$iso_url
ENV
}

truenas_load_iso_state() {
  if [[ ! -f "$TRUENAS_ISO_STATE" ]]; then
    local version
    version="$(truenas_discover_latest_version)"
    [[ -n "$version" ]] || {
      echo "Hata: TrueNAS stable surumu otomatik bulunamadi."
      exit 1
    }
    truenas_write_iso_state "$version"
  fi
  # shellcheck disable=SC1090
  source "$TRUENAS_ISO_STATE"
}

truenas_validate_disks() {
  [[ -e "$PVE_NVME_DISK" ]] || truenas_fail_disk_missing "XPG SPECTRIX S40G NVMe" "$PVE_NVME_DISK"
  [[ -e "$TRUENAS_TANK_DISK" ]] || truenas_fail_disk_missing "20TB tank disk" "$TRUENAS_TANK_DISK"
  [[ -e "$TRUENAS_PRIVATE_DISK" ]] || truenas_fail_disk_missing "4TB private disk" "$TRUENAS_PRIVATE_DISK"
  truenas_assert_not_nvme_passthrough "$TRUENAS_TANK_DISK"
  truenas_assert_not_nvme_passthrough "$TRUENAS_PRIVATE_DISK"
}
