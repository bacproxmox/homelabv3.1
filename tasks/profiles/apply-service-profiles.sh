#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR"
while [[ ! -f "$ROOT_DIR/bin/homelab" && "$ROOT_DIR" != "/" ]]; do
  ROOT_DIR="$(cd "$ROOT_DIR/.." && pwd)"
done
[[ -f "$ROOT_DIR/bin/homelab" ]] || { echo "Hata: bin/homelab bulunamadi." >&2; exit 127; }

export HOMELAB_ROOT="$ROOT_DIR"
source "$HOMELAB_ROOT/lib/core/runner.sh"

failures=()
run_profile_task() {
  local target="$1"
  echo
  echo "==> $target"
  if homelab_run "$target"; then
    return 0
  fi
  local rc=$?
  failures+=("$target:$rc")
  echo "Uyari: profil task'i hata verdi, digerleri denenecek: $target ($rc)"
  return 0
}

run_profile_task tasks/profiles/apply-jellyfin-profiles.sh
run_profile_task tasks/profiles/apply-nextcloud-profiles.sh
run_profile_task tasks/profiles/apply-seerr-profiles.sh

if (( ${#failures[@]} > 0 )); then
  echo
  echo "Profil/avatar task'lari tamamlandi ama bazi hatalar var:"
  printf '  - %s\n' "${failures[@]}"
  exit 1
fi

echo
echo "Tum servis profil/avatar task'lari tamamlandi."
