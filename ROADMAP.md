# Roadmap

Current state vs. where this is headed. Updated as things actually get done, not aspirationally.

## Cluster

- [x] Single Proxmox node (`host1`, 192.168.1.10) managing ~30 LXCs/VMs
- [x] Expand to 3-node HA cluster — `homelab` cluster live as of Sept 2026: host1, pve2
      (repurposed 3D-printing mini PC, 192.168.1.12), pve3 (192.168.1.13). Quorate,
      tolerates one node loss. See docs/cluster.md for full setup + troubleshooting.
- [x] pve2/pve3 added to the Ansible inventory (`proxmox_host` group) and a `proxmox_nodes`
      list variable added in terraform/proxmox, alongside host1
- [ ] `target_node` in terraform/proxmox is still a single default (`host1`); no resource has
      moved to per-resource/round-robin placement over `proxmox_nodes` yet since nothing has
      been created against pve2/pve3 through Terraform so far
- [ ] No shared/replicated storage yet — host1 is LVM-thin, pve2/pve3 are ZFS root but with
      no registered `local-zfs` storage entry post-join (see docs/cluster.md). Add a dedicated
      second drive per node, then Proxmox storage replication, before HA failover is real
- [ ] Once storage replication exists: enable CRS Dynamic mode + auto-rebalance
      (Datacenter > Options > Cluster Resource Scheduling) so host1 can offload
      HA-managed guests to pve2/pve3 automatically under CPU/memory pressure

## Backup

- [ ] Proxmox Backup Server — currently manual/UI-driven; bring backup job schedules under
      Terraform or Ansible once the PBS Terraform provider or API approach is settled
- [x] `pbs1`'s `klipper-laptop` datastore now receives real backups — `proxmox-backup-client`
      installed on the Klipper laptop, scoped token (`klipper-backup@pbs!klipper-laptop-token`),
      weekly cron (Sundays 3am). See docs/prind/README.md.

## Observability

- [x] Zabbix, Grafana, Prometheus, Smokeping already running
- [ ] Centralized logging (Loki+Promtail, or similar) — nothing aggregates logs across
      hosts yet; each service's logs are wherever that service is

## Config management

- [ ] Convert existing hand-built LXCs into Ansible roles, one service at a time
      (candidates: AdGuard, Vaultwarden, Netbox — services with simple, well-documented configs)
- [ ] SAMBA/DFS namespace (dfs-namespace, CT126) brought under Ansible

## Containers

- [ ] Move 2-3 simple standalone services (changedetection, uptimekuma, smokeping) into k3s
      as the first real test of the k3s/manifests/ folder
- [ ] Klipper laptop (192.168.50.122, standalone Debian box, not in the Proxmox cluster) runs
      a Docker Compose stack ("prind") that's already container-native — a candidate for k3s,
      but klipper needs privileged host + `/dev` access for the printer's USB/serial connection,
      so it needs a real node-affinity/device-plugin design rather than a blind lift-and-shift.
      See docs/prind/README.md.

## Cloud

- [ ] First Terraform resource against Azure (azurerm provider), tied into the existing
      Tailscale network as a hybrid-cloud exercise
