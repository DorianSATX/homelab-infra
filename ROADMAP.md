# Roadmap

Current state vs. where this is headed. Updated as things actually get done, not aspirationally.

## Cluster

- [x] Single Proxmox node (`host1`, 192.168.1.10) managing ~30 LXCs/VMs
- [ ] Expand to 3-node HA cluster — two more nodes planned, not yet racked/joined
- [ ] Once HA is live: `target_node` in terraform/proxmox becomes a per-resource choice
      (or a round-robin `for_each`) instead of a single default

## Backup

- [ ] Proxmox Backup Server — currently manual/UI-driven; bring backup job schedules under
      Terraform or Ansible once the PBS Terraform provider or API approach is settled

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

## Cloud

- [ ] First Terraform resource against Azure (azurerm provider), tied into the existing
      Tailscale network as a hybrid-cloud exercise
