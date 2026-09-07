# Proxmox Cluster Reference — `homelab`

Built September 2026. This doc exists so cluster architecture and known gotchas don't have to be reconstructed from memory next time something breaks.

## Overview

| Node | IP | Role / origin | Storage | NIC |
|---|---|---|---|---|
| host1 | 192.168.1.10 | Original standalone node, ~30 LXCs/VMs | LVM-thin (`local-lvm`) | Intel I219-LM |
| pve2 | 192.168.1.12 | Repurposed 3D-printing mini PC (HP Elite Mini 800 G9) | ZFS root (`rpool` / `local-zfs`) | Intel I219-LM |
| pve3 | 192.168.1.13 | Second node (already in hand) | ZFS root (`rpool` / `local-zfs`) | Intel I219-LM |

- Cluster name: `homelab`. Transport: knet. All three nodes on `pve-manager 9.2.11`.
- Quorum: 3 total votes, quorum = 2 — the cluster tolerates any **one** node going down. (During the brief 2-node window before the third joined, quorum required both nodes online — not the steady state.)
- host1's FQDN is `host1.eliminatrix.local` (Avahi/mDNS domain) — note this differs from `dv-lan.com`, the domain used elsewhere in the homelab. Not a functional problem for corosync/clustering, just worth knowing they're not the same domain.
- Gateway: `192.168.1.1`. DNS: AdGuard Home at `192.168.1.50`.

## Repos (all three nodes)

Fresh Proxmox installs default to the subscription-gated enterprise repo, which breaks `apt update` without a paid key. Fixed on all three nodes:

```bash
mv /etc/apt/sources.list.d/pve-enterprise.sources /etc/apt/sources.list.d/pve-enterprise.sources.disabled
mv /etc/apt/sources.list.d/ceph.sources /etc/apt/sources.list.d/ceph.sources.disabled

cat > /etc/apt/sources.list.d/pve-no-subscription.sources << 'EOF'
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: trixie
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF

apt update && apt full-upgrade -y
```

## NIC stability fix (Intel I219-LM / e1000e)

All three nodes share this chipset, which is prone to hangs under Proxmox's power management. Fix, applied identically on all three:

**1. Module option** — `/etc/modprobe.d/e1000e.conf`:
```
options e1000e SmartPowerDownEnable=0
```
(takes effect on next boot / module reload)

**2. Watchdog script** — `/usr/local/bin/nic-watchdog.sh` (pings the gateway every 3 min via cron; resets the interface if it fails):
```bash
#!/bin/bash
LOGFILE="/var/log/nic-watchdog.log"
if ! ping -c 2 -W 2 192.168.1.1 > /dev/null 2>&1; then
    echo "$(date): ping failed, resetting <IFACE>" >> $LOGFILE
    ip link set <IFACE> down
    sleep 3
    ip link set <IFACE> up
    echo "$(date): <IFACE> reset complete" >> $LOGFILE
fi
```
Cron: `*/3 * * * * /usr/local/bin/nic-watchdog.sh`

**Interface name differs per node** — host1 uses `eno1`; pve2 and pve3 use `nic0` (altname `enp0s31f6`). Check with `ip a` before assuming the name.

## Storage — current state and gap

No shared or replicated storage exists yet. Each node only has its single boot NVMe:
- host1: LVM-thin (`local-lvm`)
- pve2 / pve3: ZFS root (`rpool`), but see gotcha below

**Gotcha:** joining a cluster replaces a node's local `/etc/pve` config with the cluster's existing shared config. pve2/pve3 each had a `local-zfs` storage entry before joining, but since host1's `storage.cfg` never defined ZFS, that entry was wiped on join. The `rpool` data itself is untouched, but Proxmox currently has no registered storage entry pointing at it on pve2/pve3.

**TODO before setting up replication:** re-add a `local-zfs` (type `zfspool`) storage entry in Datacenter → Storage, scoped (`nodes:`) to just pve2 and pve3.

**Longer-term plan:** add a dedicated second drive to each node (host1 and pve2 both confirmed to have a free slot) for real ZFS pools + Proxmox's built-in storage replication — this is what unlocks genuine automatic HA failover. Ceph was considered and ruled out for now: no dedicated OSD disks on any node, and only gigabit networking (Ceph wants faster, dedicated interconnects to perform well).

## Backups

`pbs1` (Proxmox Backup Server) at `192.168.1.110:8007` is already available cluster-wide as a backup target — storage definitions are shared via `/etc/pve`, so anything backed up from host1 works identically from pve2/pve3, no extra config needed. Datastores: `host1-backups` and `klipper-laptop` (unrelated laptop, not part of this cluster).

## Future: automatic load rebalancing (CRS Dynamic mode)

Proxmox VE 9.1.8+ / pve-ha-manager 5.2.0+ (this cluster already qualifies) introduced a genuine DRS-like feature: **CRS Dynamic mode** with auto-rebalance, which migrates HA-managed guests off an overloaded node automatically.

Caveats: only affects **HA-managed** guests (not just any VM/CT), and it's driven by **CPU/memory** usage vs. each guest's configured limits — not storage capacity or network bandwidth. It also depends on the storage gap above being resolved first, since HA-managed guests need their disk reachable from more than one node to actually be movable.

**Sequencing:** (1) dedicated drives + ZFS replication per node → (2) HA groups with real CPU/memory limits set on guests → (3) enable via Datacenter → Options → Cluster Resource Scheduling, or in `/etc/pve/datacenter.cfg`:
```
crs: ha=dynamic,ha-auto-rebalance=1,ha-auto-rebalance-threshold=35,ha-auto-rebalance-margin=15,ha-auto-rebalance-hold-duration=5
```

## Troubleshooting cheat sheet

- **Is the cluster healthy?** `pvecm status` on any node — check `Quorate: Yes` and that all expected nodes are listed under Membership.
- **GUI cluster-wide event log:** Datacenter → Cluster log.
- **Corosync/cluster service issues:** `journalctl -u corosync -u pve-cluster -f` on the affected node.
- **A node won't join / rejoin:** check `pvecm updatecerts --force` + `systemctl restart pveproxy` on the target node if you hit `500 ... hostname verification failed` — this means the node's API cert is stale relative to its current hostname/IP.
- **`pvecm add` fails with `401 authentication failure`:** almost always means the password prompt didn't get a real interactive terminal. Re-run with `ssh -t root@<node> pvecm add <target-ip>` instead of plain `ssh root@<node> ...`.
- **A command containing `!` fails with `bash: !...: event not found`:** that's bash history expansion tripping on API token IDs like `user@pbs!tokenname`. Wrap with `set +H` / `set -H` around the command, or use single quotes consistently.
- **NIC watchdog log:** `/var/log/nic-watchdog.log` on any node — check this first if a node drops off the network intermittently.

## Cleanup already done

- CT116 (unused OctoPrint LXC) deleted from host1, Sept 2026.

## Still outstanding

- Repoint or remove the `DV-Desktop2025-Videos` DFS symlink on CT126 (`dfs-namespace`) — it currently points at the mini PC's old Windows install, which no longer exists (that mini PC is now `pve2`).
- Re-add `local-zfs` storage entries for pve2/pve3 (see Storage section above).
- Add pve2/pve3 to the `homelab-infra` Terraform/Ansible inventory (github.com/DorianSATX/homelab-infra) alongside host1.
