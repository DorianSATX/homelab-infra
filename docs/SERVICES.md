# Services

A working reference for what's running where. IP/port so I stop forgetting which LXC is which.

**No credentials in this file, ever.** Actual usernames/passwords live in Vaultwarden — this
column just names the Vaultwarden entry to look up. This file is public; Vaultwarden isn't.

| ID  | Name                   | Type | IP              | Port(s) | Purpose                                         | Credentials (Vaultwarden entry) |
|-----|------------------------|------|-----------------|---------|--------------------------------------------------|----------------------------------|
| —   | host1 (Proxmox)        | node | 192.168.1.10    | 8006    | Proxmox VE host                                 | proxmox-host1                   |
| 100 | HomeAssistant          | VM   |                 |         | Home automation platform                        | homeassistant                   |
| 101 | ubuntu                 | LXC  |                 |         |                                                  |                                  |
| 102 | CT102                  | LXC  |                 |         | TBD                                              |                                  |
| 103 | tailscale              | LXC  | 192.168.1.222   |         | Tailscale subnet router + tailnet exit node     |                                  |
| 104 | openwebui              | LXC  |                 |         | Web UI for local LLMs                           | openwebui                       |
| 105 | adguard                | LXC  |                 |         | AdGuard Home — DNS / ad blocking                | adguard                         |
| 106 | zabbix                 | LXC  |                 |         | Monitoring                                      | zabbix                          |
| 107 | openproject            | LXC  |                 |         | ERP / project management                        | openproject                     |
| 108 | uptimekuma             | LXC  |                 |         | Uptime monitoring                               | uptimekuma                      |
| 109 | prometheus             | LXC  |                 |         | Metrics collection                              |                                  |
| 110 | grafana                | LXC  |                 |         | Dashboards / visualization                      | grafana                         |
| 111 | docker                 | VM   |                 |         | Docker host                                     |                                  |
| 112 | pulse                  | LXC  |                 |         | Proxmox monitoring dashboard                    |                                  |
| 113 | durid.io               | LXC  |                 |         | TBD                                              |                                  |
| 114 | smokeping              | LXC  |                 |         | Network latency monitoring                      |                                  |
| 115 | prometheus-pve-exporter| LXC  |                 |         | Proxmox metrics exporter for Prometheus         |                                  |
| 118 | changedetection        | LXC  |                 |         | Webpage change detection                        | changedetection                 |
| 119 | n8n                    | LXC  |                 |         | Workflow automation                             | n8n                              |
| 120 | watchyourlan           | LXC  |                 |         | LAN device monitoring                           |                                  |
| 121 | vaultwarden            | LXC  |                 |         | Password manager (source of truth for the above)| —                                |
| 122 | netvisor               | LXC  |                 |         | TBD                                              |                                  |
| 123 | checkmk                | LXC  |                 |         | Infrastructure monitoring                        | checkmk                         |
| 124 | docker                 | VM   |                 |         | Docker host                                     |                                  |
| 125 | netbox                 | LXC  |                 |         | IPAM/DCIM — not configured yet                  |                                  |
| 126 | dfs-namespace          | LXC  | 192.168.1.230   | 445     | SAMBA/DFS namespace, media consolidation        |                                  |
| 127 | librenms               | LXC  |                 |         | Network monitoring                               | librenms                        |
| 129 | paperless-ngx          | LXC  |                 |         | Document management                              | paperless-ngx                   |
| 130 | nginxproxymanager      | LXC  |                 |         | Reverse proxy management                         | nginxproxymanager               |
| 131 | hermesagent            | LXC  |                 |         | AI automation agent                              |                                  |
| 132 | paperless-gpt          | LXC  |                 |         | AI-assisted OCR/tagging for paperless-ngx        |                                  |
| 133 | llama-cpp              | LXC  |                 |         | Local LLM inference                              |                                  |

Blank IP/port cells: fill in as you go, or run the script below on host1 and paste the output back
to me — I'll fill the whole table in one pass from real data instead of guesses.

## Gathering real IPs

Run this from the Proxmox **Shell** on host1 (Datacenter → host1 → Shell) to dump ID/hostname/IP
for every container and VM in one shot:

```bash
echo "--- LXC ---"
for id in $(pct list | awk 'NR>1{print $1}'); do
  ip=$(pct exec "$id" -- hostname -I 2>/dev/null | awk '{print $1}')
  name=$(pct config "$id" | awk -F': ' '/^hostname/{print $2}')
  echo "$id | $name | $ip"
done

echo "--- VM (requires qemu-guest-agent running) ---"
for id in $(qm list | awk 'NR>1{print $1}'); do
  ip=$(qm guest cmd "$id" network-get-interfaces 2>/dev/null | grep -oP '"ip-address":"\K[0-9.]+' | grep -v '^127' | head -1)
  name=$(qm config "$id" | awk -F': ' '/^name/{print $2}')
  echo "$id | $name | $ip"
done
```
