# Frigate NVR

Frigate ([blakeblackshear/frigate](https://github.com/blakeblackshear/frigate)), currently
`0.16.3`, running four cameras: `front_door`, `upstairs`, `bedroom`, `kitchen`. Detection
runs on the host's Intel iGPU via OpenVINO + QSV hardware acceleration.

## Where it runs
A dedicated Debian 13 host on the Camera VLAN — **not** part of the k3s cluster, on purpose.
Frigate needs direct GPU device passthrough, host-level network access to the camera VLAN,
and dedicated local NVMe storage; none of that gains anything from running in k8s, and
keeping it off the (still actively being learned) k3s cluster means cluster experiments
can't take security camera recording down with it.

## Storage
Two dedicated NVMe drives, separate from the OS disk: one for continuous recordings, one
for saved clips/events. Retention is currently 3 days for continuous footage, 14 days for
alert/detection clips and snapshots.

## Config and secrets
The actual `docker-compose.yml`, `config.yml`, `.env`, and camera/MQTT credentials live in
the private repo (`homelab-infra-private/frigate/`), not here — the config embeds camera
RTSP credentials and MQTT auth.
