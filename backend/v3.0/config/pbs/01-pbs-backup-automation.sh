#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/utils/logging.sh"; start_log "pbs-backup-automation"
source "$ROOT_DIR/utils/env-loader.sh"; load_all_env

PBS_IP="${PBS_IP:-192.168.50.110}"
PBS_STORAGE_ID="${PBS_STORAGE_ID:-pbs-pi-a}"
PBS_DATASTORE_NAME="${PBS_DATASTORE_NAME:-pi-pbs-a}"
PBS_USER_REALM="${PBS_USER_REALM:-${BACKUP_USER:-backup}@pam}"
PBS_FINGERPRINT_FILE="/root/homelab-secrets/pbs-fingerprint.env"
JOB_ID="${PBS_BACKUP_JOB_ID:-homelab-daily-pbs}"
SCHEDULE="${PBS_BACKUP_SCHEDULE:-03:30}"
VMIDS="${PBS_BACKUP_VMIDS:-101,102,103,104,105,106,107}"

: "${BACKUP_USER:=backup}"
: "${BACKUP_PASS:?BACKUP_PASS eksik.}"

apt-get update -y >/dev/null 2>&1 || true
apt-get install -y sshpass curl jq openssl >/dev/null

SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10)

pbs_http_code() { curl -k -sS -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 10 "https://${PBS_IP}:8007/api2/json/version" 2>/dev/null || true; }
pbs_reachable() { local c; c="$(pbs_http_code)"; case "$c" in 200|401|403) echo "✅ PBS reachable: HTTP $c"; return 0;; *) echo "HTTP_CODE=${c:-curl_failed}"; return 1;; esac; }

get_pbs_fingerprint() {
  local fp=""
  fp="$(echo | openssl s_client -connect "${PBS_IP}:8007" -servername "${PBS_IP}" 2>/dev/null \
    | openssl x509 -noout -fingerprint -sha256 2>/dev/null \
    | sed 's/.*=//' || true)"
  if [[ -z "$fp" ]]; then
    fp="$(sshpass -p "$BACKUP_PASS" ssh "${SSH_OPTS[@]}" root@"$PBS_IP" "proxmox-backup-manager cert info --output-format json 2>/dev/null | jq -r '.fingerprint // empty'" || true)"
  fi
  echo "$fp"
}

echo "🔎 PBS API/WebUI erişim kontrolü: https://${PBS_IP}:8007"
if ! pbs_reachable; then
  echo "⚠️ PBS reachable değil; önce service install repair deneniyor."
  bash "$ROOT_DIR/services/pbs/01-pbs-service-install.sh"
fi
pbs_reachable || { echo "❌ PBS hala reachable değil."; exit 1; }

FINGERPRINT=""
if [[ -f "$PBS_FINGERPRINT_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$PBS_FINGERPRINT_FILE"
  FINGERPRINT="${PBS_FINGERPRINT:-}"
fi
if [[ -z "$FINGERPRINT" ]]; then
  echo "🔐 PBS fingerprint alınıyor..."
  FINGERPRINT="$(get_pbs_fingerprint)"
fi
if [[ -z "$FINGERPRINT" ]]; then
  echo "❌ PBS fingerprint alınamadı. Fingerprint'siz pvesm add denenmeyecek."
  exit 1
fi
mkdir -p /root/homelab-secrets; chmod 700 /root/homelab-secrets
printf 'PBS_FINGERPRINT=%q\n' "$FINGERPRINT" > "$PBS_FINGERPRINT_FILE"
chmod 600 "$PBS_FINGERPRINT_FILE"
echo "✅ PBS fingerprint: $FINGERPRINT"

echo "🔐 PVE tarafında PBS storage hazırlanıyor: $PBS_STORAGE_ID"
if pvesm status 2>/dev/null | awk '{print $1}' | grep -qx "$PBS_STORAGE_ID"; then
  echo "ℹ️ Eski/yarım PBS storage kaydı kaldırılıyor: $PBS_STORAGE_ID"
  pvesm remove "$PBS_STORAGE_ID" 2>/dev/null || true
fi

pvesm add pbs "$PBS_STORAGE_ID" \
  --server "$PBS_IP" \
  --datastore "$PBS_DATASTORE_NAME" \
  --username "$PBS_USER_REALM" \
  --password "$BACKUP_PASS" \
  --fingerprint "$FINGERPRINT" \
  --content backup

pvesm status | grep -E "^${PBS_STORAGE_ID}[[:space:]]" || { echo "❌ PVE PBS storage doğrulanamadı."; pvesm status || true; exit 1; }

echo "🗓️ PVE backup job hazırlanıyor: $JOB_ID -> $PBS_STORAGE_ID"
if command -v pvesh >/dev/null 2>&1; then
  existing="$(pvesh get /cluster/backup --output-format json 2>/dev/null | jq -r --arg id "$JOB_ID" '.[]? | select(.id==$id) | .id' || true)"
  if [[ -n "$existing" ]]; then
    pvesh set "/cluster/backup/${JOB_ID}" --storage "$PBS_STORAGE_ID" --schedule "$SCHEDULE" --vmid "$VMIDS" --mode snapshot --compress zstd --enabled 1 --notes-template '{{guestname}} {{vmid}}' >/dev/null
  else
    pvesh create /cluster/backup --id "$JOB_ID" --storage "$PBS_STORAGE_ID" --schedule "$SCHEDULE" --vmid "$VMIDS" --mode snapshot --compress zstd --enabled 1 --notes-template '{{guestname}} {{vmid}}' >/dev/null
  fi
  pvesh get /cluster/backup --output-format json | jq -e --arg id "$JOB_ID" '.[]? | select(.id==$id and .storage!=null)' >/dev/null || { echo "❌ Backup job doğrulanamadı."; exit 1; }
else
  echo "⚠️ pvesh yok; backup job otomatik eklenemedi."
fi

echo
printf '===== PBS storage =====\n'
pvesm status | grep -E "^${PBS_STORAGE_ID}[[:space:]]" || true

echo
printf '===== Backup jobs =====\n'
pvesh get /cluster/backup --output-format json 2>/dev/null | jq -r '.[] | select(.id=="'"$JOB_ID"'") | {id, storage, schedule, vmid, enabled}' || true

echo "🧹 Retention policy notu: Öneri keep-daily=7, keep-weekly=4, keep-monthly=3, weekly verify."
echo "✅ PBS backup automation tamamlandı."
