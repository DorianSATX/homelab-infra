# homelab-infra

[![CI](https://github.com/DorianSATX/homelab-infra/actions/workflows/ci.yml/badge.svg)](https://github.com/DorianSATX/homelab-infra/actions/workflows/ci.yml)

Infrastructure-as-code for my home lab: a 3-node Proxmox cluster, a k3s cluster on top of it,
segmented VLANs, and ~30 self-hosted services — built, documented, and (increasingly) automated
from this repo.

> Hostnames, domains and IPs in this repo are placeholders (`example.lan`, `192.0.2.x`).
> Real values live in a private repo.

---

## The stack

```
                         Internet
                            │
                     ISP modem (double NAT)
                            │
                ┌───────────┴───────────┐
                │  Ubiquiti EdgeRouter X │  routing · DHCP · inter-VLAN firewall
                └───────────┬───────────┘
                            │  802.1Q trunk
      ┌──────────┬──────────┼──────────┬──────────┬──────────┐
      ▼          ▼          ▼          ▼          ▼          ▼
   Mgmt /     Trusted     IoT       Cameras    Storage    Media / Guest
   Servers    clients                (NVR)
      │
      │   ┌──────────────── Remote access ────────────────┐
      │   │  Tailscale subnet router + exit node (LXC)    │
      │   │  split DNS → AdGuard, so names work off-LAN    │
      │   └────────────────────────────────────────────────┘
      │
      ▼
  AdGuard Home  ── *.example.lan ──▶  Nginx Proxy Manager
  (DNS + ad-block)                     wildcard TLS · LAN-only ACL
                                       · HTTP/2 · forced HTTPS
                                              │
                                              ▼
  ┌────────────────────── Proxmox VE cluster "homelab" ──────────────────────┐
  │                                                                          │
  │   host1                      pve2                      pve3              │
  │   (main node, LVM-thin)      (HP Elite Mini, ZFS)      (ZFS)             │
  │        │                         │                        │              │
  │        └──────────── corosync / knet, quorum 2 of 3 ──────┘              │
  │                                                                          │
  │   ~30 LXCs / VMs                    k3s cluster (3 VMs)                  │
  │   • AdGuard · NPM · Vaultwarden     • kube-vip (API + LB VIPs)           │
  │   • Netbox · Paperless-ngx/-gpt     • Traefik ingress                    │
  │   • Home Assistant · Frigate NVR    • Dynacat dashboard                  │
  │   • Zabbix · Grafana · Prometheus   • ntfy · Uptime Kuma · Scrutiny      │
  │   • Smokeping · changedetection                                          │
  │   • llama.cpp · Homelable map                                            │
  └──────────────────────────────────┬───────────────────────────────────────┘
                                     │  nightly vzdump
                                     ▼
                         Proxmox Backup Server (pbs1)
```

## What's in here

```
homelab-infra
├── terraform/proxmox/     new LXC/VM shells via the bpg/proxmox provider
├── ansible/
│   ├── inventory/         cluster nodes, PBS, NVR, LXCs
│   └── playbooks/
│       ├── site.yml              baseline config (common role)
│       ├── set-ips.yml           DHCP → static IP migration, safely
│       ├── npm-hosts.yml         create reverse-proxy hosts via the NPM API
│       ├── k3s-join.yml          join nodes to k3s
│       └── scrutiny-collector.yml  SMART disk-health collectors
├── k3s/manifests/         kube-vip, ntfy, Uptime Kuma, Scrutiny
├── configs/smokeping/     latency probes + ntfy alert hook
├── docs/                  cluster runbook, Frigate, Paperless, Klipper/prind
└── .github/workflows/     CI: terraform validate · ansible-lint · yamllint
```

## Highlights

**Static IPs without the pain — `set-ips.yml`**
Moves guests off DHCP one at a time: asserts the hostname matches, pre-flights the new IP
(cluster config grep + ping + ARP) so nothing collides, rewrites `net0` with `pct set`,
reboots, waits for ping, then repoints the matching Nginx Proxy Manager host at the new address.

**Reverse proxy as code — `npm-hosts.yml`**
Creates proxy hosts through the NPM API with the wildcard cert, "LAN only" access list,
websockets, HTTP/2, forced SSL and exploit blocking — then curls every host and fails on 5xx.

**Monitoring that actually pings me**
Smokeping watches every VLAN gateway, the ISP path and DNS resolution; alerts go to a
self-hosted ntfy topic on my phone. Uptime Kuma and Scrutiny cover service and disk health.

**Cluster runbook — [`docs/cluster.md`](docs/cluster.md)**
How the 3-node cluster was built, the Intel I219-LM NIC hang fix + watchdog, quorum
behavior, and the gotchas I hit so I don't have to rediscover them.

## Philosophy

- **Terraform provisions, Ansible configures.** Terraform creates the shell; Ansible owns what
  runs inside it.
- **No big-bang imports.** Hand-built services move under management one at a time as they're
  rebuilt — see [ROADMAP.md](ROADMAP.md).
- **Nothing exposed to the internet.** Every web UI is LAN/Tailscale only behind NPM's access
  list. Remote access is Tailscale, not port forwards.
- **No secrets in git.** `terraform.tfvars`, state, vault files and tokens are gitignored;
  credentials come from environment variables.

## Running it

```bash
# Terraform
cd terraform/proxmox
cp terraform.tfvars.example terraform.tfvars   # add your Proxmox API token (gitignored)
terraform init && terraform plan

# Ansible
cd ../../ansible
ansible-inventory -i inventory/hosts.yml --list            # sanity-check inventory
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --check   # dry run
```

## Roadmap

Shared storage + replication so HA failover is real, centralized logging (Loki), and more
hand-built LXCs converted into Ansible roles. Details in [ROADMAP.md](ROADMAP.md).

## License

[MIT](LICENSE)
