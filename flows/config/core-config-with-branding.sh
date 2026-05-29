#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR"
while [[ ! -f "$ROOT_DIR/bin/homelab" && "$ROOT_DIR" != "/" ]]; do
  ROOT_DIR="$(cd "$ROOT_DIR/.." && pwd)"
done
[[ -f "$ROOT_DIR/bin/homelab" ]] || { echo "Hata: bin/homelab bulunamadi." >&2; exit 127; }

export HOMELAB_ROOT="$ROOT_DIR"
export HOMELAB_NO_JELLYFIN_WIZARD_PROMPT="${HOMELAB_NO_JELLYFIN_WIZARD_PROMPT:-1}"
export HOMELAB_NO_JELLYFIN_WIZARD_GATE="${HOMELAB_NO_JELLYFIN_WIZARD_GATE:-1}"

source "$HOMELAB_ROOT/lib/core/runner.sh"

failures=()
run_and_keep_going() {
  local title="$1" target="$2"
  echo
  echo "==> $title"
  if homelab_run "$target"; then
    return 0
  fi
  local rc=$?
  failures+=("$target:$rc")
  echo "Uyari: $title hata verdi ($rc); sonraki post-config adimlari denenmeye devam edecek."
  return 0
}

run_and_keep_going "Core config (v3.0 backend, non-interactive gate)" "backend/v3.0/config/00-run-all-core-config.sh"
run_and_keep_going "Jellyfin tema secimi uygula" "tasks/config/jellyfin/apply-theme.sh"
run_and_keep_going "Bacsflix/Bacneyplus/Bacscloud profil ve avatar uygula" "tasks/profiles/apply-service-profiles.sh"

if (( ${#failures[@]} > 0 )); then
  echo
  echo "Core config/branding flow bazi hatalarla tamamlandi:"
  printf '  - %s\n' "${failures[@]}"
  exit 1
fi

echo
echo "Core config + branding/profil flow tamamlandi."
