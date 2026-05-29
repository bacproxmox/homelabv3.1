#!/usr/bin/env bash
set -Eeuo pipefail

echo
echo "===== Disk temperature ====="
export DEBIAN_FRONTEND="${DEBIAN_FRONTEND:-noninteractive}"
apt-get update -y >/dev/null 2>&1 || true
apt-get install -y smartmontools nvme-cli >/dev/null 2>&1 || true

warn=0

for dev in /dev/nvme[0-9]; do
  [[ -e "$dev" ]] || continue
  out="$(nvme smart-log "$dev" 2>/dev/null || true)"
  temp="$(awk -F: '/^temperature/ {gsub(/[^0-9]/,"",$2); print $2; exit}' <<<"$out")"
  [[ -n "${temp:-}" ]] || continue
  echo "$dev temperature=${temp}C"
  if [[ "$temp" =~ ^[0-9]+$ && "$temp" -ge 70 ]]; then
    echo "Uyari: NVMe sicakligi yuksek: $dev ${temp}C"
    warn=1
  fi
done

while read -r dev type; do
  [[ "$type" == "disk" ]] || continue
  [[ "$dev" == sd* || "$dev" == hd* ]] || continue
  path="/dev/$dev"
  out="$(smartctl -A "$path" 2>/dev/null || true)"
  temp="$(echo "$out" | awk '/Temperature_Celsius|Airflow_Temperature/ {print $10; exit}')"
  [[ -n "${temp:-}" ]] || continue
  echo "$path temperature=${temp}C"
  if [[ "$temp" =~ ^[0-9]+$ && "$temp" -ge 60 ]]; then
    echo "Uyari: disk sicakligi yuksek: $path ${temp}C"
    warn=1
  fi
done < <(lsblk -dn -o NAME,TYPE)

exit "$warn"
