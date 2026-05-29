# Homelab v3.1 Modular

Homelab v3.1 keeps the working v3.0 backend available under `backend/v3.0`, then adds a modular task/flow layer on top.

## Start

From Proxmox, inside the package:

```bash
bash bootstrap.sh
```

Or run the modular command directly:

```bash
bash bin/homelab tui
bash bin/homelab list
bash bin/homelab run flows/truenas/create-vm.sh
```

## Main changes

- New task runner: `bin/homelab run <task-or-flow>`.
- Manifest-driven TUI: `installer/tui.sh` reads `manifests/guided-steps.tsv`.
- Guided install now collects install preferences at the start in `/root/homelab-secrets/install-preferences.env`.
- Guided progress is non-stop between phases; only the TrueNAS manual checkpoint is expected to wait for human action.
- Small TrueNAS VM tasks for ISO discovery/download/verify, storage preparation, VM shell creation, ISO attach, disk passthrough, and config verification.
- Small disk health tasks for NVMe, SMART, temperatures, and kernel disk errors.
- Jellyfin theme selection is install-time configurable: `bacsflix`, `finimalism`, `elegantfin`, `better-jellyfin-ui`, `abyss`, or `none`.
- Post-config profile tasks apply Bacsflix/Bacneyplus/Bacscloud branding and user avatars for `bacmaster`, `Atlon`, `Elifezel`, and `Tulumba`.
- Legacy script paths remain available as thin wrappers.

## Logs and state

- Logs: `/root/homelab-logs/v3.1-session-*`
- Master log: `/root/homelab-logs/v3.1-session-*/00-v3.1-master.log`
- State: `/root/homelabv3.1-state/state.tsv`
- Support bundle menu: TUI option `Support bundle topla`

## Compatibility

Existing paths such as `vm/101-truenas-vm-install.sh`, `services/truenas/01-truenas-api-bootstrap-storage.sh`, and `maintenance/health/full-health-check.sh` still work. They dispatch into the modular task/flow layer where a v3.1 replacement exists, or into the preserved v3.0 backend when behavior should remain unchanged.
