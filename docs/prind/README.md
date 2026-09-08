# Klipper / prind — 3D printer host

Not a Proxmox guest — this is a **separate physical Debian 13 (trixie) laptop** sitting in the
printer corner, on VLAN 50. It replaces the old Klipper host (an HP Elite Mini 800 G9 mini PC
running Windows 11 IoT + WSL2), which has since been wiped and repurposed as `pve2` in the
`homelab` Proxmox cluster (see [../cluster.md](../cluster.md)).

Current lease: `192.168.50.122` (DHCP, **not static yet** — same drift risk that bit the old
mini PC, which is why its address kept changing). SSH: `dorian@192.168.50.122`.

## Stack: Docker Compose, not KIAUH

The original migration plan assumed a bare-metal KIAUH install (systemd units, config at
`~/printer_data`). What's actually running is a dockerized stack called **prind**
(`~/prind/docker-compose.yaml`) — five containers:

| Container | Image | Purpose |
|---|---|---|
| `prind-klipper-1` | `mkuf/klipper:latest` | Klipper firmware host, privileged (needs `/dev`) |
| `prind-moonraker-1` | `mkuf/moonraker:latest` | API layer |
| `prind-mainsail-1` | `ghcr.io/mainsail-crew/mainsail:edge` | Web UI |
| `prind-traefik-1` | `traefik:3.6` | Reverse proxy, binds host `:80` |
| `prind-webcam-1` | `mkuf/ustreamer:latest` | Webcam stream, `:8080` |

```
                         ~/prind/  (docker compose project)
                         ┌─────────────────────────────────────────────┐
   browser ──:80───────▶ │  traefik ──▶ mainsail (UI)                  │
   browser ──:8080──────▶│  ustreamer (webcam)                         │
                         │                                             │
   printer (USB) ◀───────┼── klipper ◀── config: ./config (bind mount) │
                         │      │         → /opt/printer_data/config   │
                         │      ▼                                      │
                         │  moonraker ──▶ vol: prind_moonraker-db      │
                         │      │                                      │
                         │      ▼                                      │
                         │  vol: prind_gcode, prind_log, prind_run     │
                         └─────────────────────────────────────────────┘
```

**Config lives in a plain bind-mounted folder, not a Docker volume** — `~/prind/config` on the
host maps straight to `/opt/printer_data/config` in the klipper container. That means
`printer.cfg`, `moonraker.conf`, `klipperscreen.conf`, etc. are directly readable/editable from
the host shell, no `docker exec` needed. `docker-compose.yaml`'s klipper `command:` block spells
out the exact paths:
```
-I printer_data/run/klipper.tty
-a printer_data/run/klipper.sock
printer_data/config/printer.cfg
-l printer_data/logs/klippy.log
```

The four **named volumes** (`prind_gcode`, `prind_log`, `prind_moonraker-db`, `prind_run`) are
the only things that need `docker run --rm -v <vol>:/from ...` gymnastics to reach directly.

## Working setup (confirmed 2026-09-08)

`~/prind/config/printer.cfg` already carries real, non-default calibration —
`[bltouch] z_offset = 1.014` and a full 7×7 `[bed_mesh default]` grid with genuine (non-uniform)
point data. This survived the whole migration intact; **no config restore was actually needed**
by the time it was checked. `~/prind/config` also holds ~50 timestamped
`printer-YYYYMMDD_HHMMSS.cfg` snapshots going back to January — Klipper/Moonraker's own automatic
pre-`SAVE_CONFIG` backups, not something manually curated.

Prints work: confirmed printing successfully as of Sept 2026.

## Migration backups (Sept 6, pre-wipe of the old mini PC)

Three separate landing spots, not all where the original runbook planned:

- **host1 ZFS**, `/rpool/backups/printer-minipc-2026-09/`:
  - `printer_data.tar.gz` — the *old* WSL2 Klipper install's config/database (superseded now
    that `prind`'s own config is confirmed good, but kept as historical reference)
  - `klipper-wsl.tar` (~5.9 GB) — full WSL Ubuntu distro export, the "whole machine" escape hatch
- **USB stick** (`D:\printer-backup` on the Windows ThinkPad):
  - `PrusaSlicer.zip` — Windows `%APPDATA%\PrusaSlicer` profiles from the old mini PC. The
    migration runbook's plan was to scp this to host1 alongside the tarball above; it ended up
    on the USB stick instead. Imported onto the ThinkPad's fresh PrusaSlicer install 2026-09-08
    (merged just `printer/`, `filament/`, `print/`, `physical_printer/` — left `PrusaSlicer.ini`
    and `vendor/`/`cache/` alone so the fresh install's own state wasn't clobbered).
  - a second copy of `klipper-wsl.tar`
- **On the Klipper laptop itself**, `~/migration-backup/volumes/`:
  - `prind_gcode.tar.gz` (130 MB) and `prind_moonraker-db.tar.gz` — tarred copies of the two
    named Docker volumes that actually matter, taken 2026-09-06.

## Snags hit during the migration (2026-09-08)

1. **Wrong assumed stack.** The runbook was written assuming KIAUH/bare-metal (systemd units
   `klipper.service`/`moonraker.service`, config at `~/printer_data`). Neither existed —
   `systemctl status klipper` came back "could not be found." `docker ps -a` + reading
   `docker-compose.yaml`'s `volumes:` block is what actually located the real config path.
2. **Backup location drift.** `PrusaSlicer.zip` wasn't where the runbook said it would be
   (host1) — it was on a USB stick instead. Nothing was lost, but it cost a round of checking
   host1, coming up empty, and then remembering the USB stick existed.
3. **Near-miss: restoring a working config over itself.** The plan called for restoring
   `printer_data.tar.gz` onto the new host. Checking the live `printer.cfg` *first* showed real
   calibration data already in place — a straight restore would have overwritten current,
   correct data with the old machine's (stale, and possibly no-longer-accurate) mesh/Z-offset.
   Always diff before restoring.
4. **PrusaSlicer import overwrite risk.** A flat overwrite of `%APPDATA%\PrusaSlicer` would have
   clobbered a profile the fresh install had already created. Fixed by merging only the profile
   subfolders (`printer/`, `filament/`, `print/`, `physical_printer/`) and leaving
   `PrusaSlicer.ini` + `vendor/`/`cache/` untouched.

## Automated backups (added 2026-09-08)

`~/prind/config` and the two named volumes that matter now back up weekly to `pbs1`'s
`klipper-laptop` datastore via `proxmox-backup-client`, installed directly on the Klipper laptop
(client-only repo, no full PBS install needed):
```bash
wget https://enterprise.proxmox.com/debian/proxmox-release-trixie.gpg -O /etc/apt/trusted.gpg.d/proxmox-release-trixie.gpg
echo "deb http://download.proxmox.com/debian/pbs-client trixie main" | sudo tee /etc/apt/sources.list.d/pbs-client.list
sudo apt update && sudo apt install proxmox-backup-client
```

**Auth:** dedicated PBS user `klipper-backup@pbs` (no login password — token-only), with token
`klipper-laptop-token` scoped to `DatastoreBackup` on `/datastore/klipper-laptop` only (not the
whole PBS instance). Secret lives in Vaultwarden.

**Backup command** (must run as root — see gotcha below — with `PBS_REPOSITORY`/`PBS_PASSWORD`
set):
```bash
proxmox-backup-client backup \
  config.pxar:/home/dorian/prind/config \
  gcode.pxar:/var/lib/docker/volumes/prind_gcode/_data \
  moonraker-db.pxar:/var/lib/docker/volumes/prind_moonraker-db/_data \
  --repository "$PBS_REPOSITORY"
```

**Cron** (root's crontab, weekly, Sundays 3am — same off-hours slot as the existing gcode rsync
job):
```
0 3 * * 0 PBS_REPOSITORY='klipper-backup@pbs!klipper-laptop-token@192.168.1.110:klipper-laptop' PBS_PASSWORD='<secret, see Vaultwarden>' proxmox-backup-client backup config.pxar:/home/dorian/prind/config gcode.pxar:/var/lib/docker/volumes/prind_gcode/_data moonraker-db.pxar:/var/lib/docker/volumes/prind_moonraker-db/_data --repository 'klipper-backup@pbs!klipper-laptop-token@192.168.1.110:klipper-laptop' >> /var/log/pbs-backup.log 2>&1
```

### Gotchas hit setting this up

- **Must run as root.** `/var/lib/docker` is root-owned, mode `710` — no non-root user can
  traverse into it at all, so the two Docker-volume archive specs fail with `Permission denied`
  under a plain user even though the files themselves might otherwise be readable.
- **The `!` in API token IDs triggers bash history expansion** (`klipper-backup@pbs!token` →
  `-bash: !token: event not found`) if double-quoted in an interactive shell. Single-quote
  `PBS_REPOSITORY`/`PBS_PASSWORD` always. (This is the same class of bug already documented in
  [../cluster.md](../cluster.md) for Proxmox API token IDs — same `!` syntax, same fix.)
- **Deleting a token drops its ACL grants with it.** Cycling `klipper-laptop-token`'s secret
  (delete + regenerate under the same name, needed because the first secret was lost before it
  got saved) silently wiped the `DatastoreBackup` ACL grant tied to that auth-id. Symptom:
  `permission check failed - missing Datastore.Audit|Datastore.Backup`. Fix: re-run
  `proxmox-backup-manager acl update /datastore/klipper-laptop DatastoreBackup --auth-id '<auth-id>'`
  after any token cycle, not just at initial creation.
- **Backup groups are owned by a specific auth-id and don't transfer automatically.** An earlier
  token (`klipper-backup@pbs!backup`) had already created the `host/klipper` backup group before
  it was deleted during token cleanup; the new token was then blocked from writing into that same
  group (`backup owner check failed`). Fixed via the PBS web UI — Datastore → klipper-laptop →
  Content → `host/klipper` row → **Change Owner** → reassign to the surviving token. (This one
  doesn't have a CLI path worth guessing at; the web UI action is the reliable one.)

Still on a DHCP lease, not a reservation — same failure mode that made the old mini PC's address
drift over time. `prind_log` / `prind_run` volumes deliberately aren't backed up — logs and
runtime sockets, nothing worth keeping.

## Possible next steps

- DHCP reservation (or static IP) for this laptop on the EdgeRouter.
- **k3s candidacy:** `prind`'s containers are compose-based already, which makes them look like
  an easy fit for the "move standalone services into k3s" line in
  [../../ROADMAP.md](../../ROADMAP.md) — but `klipper` needs privileged host + `/dev` access for
  the printer's USB/serial connection, which complicates a straight lift into k3s. Worth treating
  as a design question (node affinity + device plugin, or leave klipper bare-metal/Compose and
  only migrate `mainsail`/`ustreamer`) rather than assuming it's a drop-in candidate.
