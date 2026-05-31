# Architecture

## Current state (as of project start)

### Hardware

- **Pi 5 (16 GB)** — production host
  - NVMe SSD via M.2 HAT — runs OS + Docker + container data
  - HDD #1 — general media (movies, TV, adult content)
  - HDD #2 — dedicated to One Piece
  - Connected to network via Mac ethernet (Mac on phone hotspot)
- **Pi 4 (8 or 16 GB)** — currently idle, SD card only
- **MacBook Air M5 (16 GB)** — dev machine
- **No router** — all devices use an Android phone hotspot

### Stack on Pi 5 (all Docker)

| Service     | Purpose                                              |
|-------------|------------------------------------------------------|
| Jellyfin    | Media streaming                                      |
| Sonarr      | TV show management                                   |
| Radarr      | Movie management                                     |
| Bazarr      | Subtitle management                                  |
| Prowlarr    | Indexer aggregator                                   |
| qBittorrent | Torrent client (routed through gluetun)              |
| gluetun     | NordVPN tunnel for qBittorrent                       |
| Caddy       | HTTP reverse proxy (local only, no HTTPS)            |

### Known issues

1. **Anonymous Docker volumes** — config is scattered across `/var/lib/docker/volumes/<hash>/_data`, hard to back up and not portable.
2. **No backups** — losing the SD card or NVMe means rebuilding from memory.
3. **No source of truth for configuration** — API keys, paths, naming conventions live only in the running services.
4. **gluetun + qBit startup race** — after reboots, qBit often needs a manual restart because gluetun isn't ready yet.
5. **Manual deployment** — `ansible-playbook` invocations are long-form and easy to misuse.
6. **No testing environment** — every change happens in production.
7. **Single Docker network** — all services share one bridge, blast radius is wide.
8. **Periodic unresponsiveness** — services (especially qBit's WebUI) hang after several hours of idle.

### Out of scope for this project

Hardware purchases, public exposure, networking redesign, and monitoring are deferred to future epics. See [ROADMAP](ROADMAP.md).

## Desired state (end of July)

### Repository

Two repos under the same GitHub account:

- **`homelab-ansible`** (public) — roles, playbooks, examples, docs, scripts. Runnable with example inventory; community-shareable.
- **`homelab-ansible-private`** (private overlay) — real inventory, real secrets (ansible-vault), and other roles. Cloned alongside the public repo; Ansible runs with both on its inventory + role path.

### Directory layout on Pi 5

```
/opt/homelab/
├── compose/
│   └── docker-compose.yml           # rendered by Ansible
├── config/
│   ├── jellyfin/
│   ├── sonarr/
│   ├── radarr/
│   ├── bazarr/
│   ├── prowlarr/
│   ├── qbittorrent/
│   ├── gluetun/
│   └── caddy/
├── secrets/
│   └── .env                         # rendered from ansible-vault
└── backups/                         # local restic repository
```

Media drives stay at `/mnt/hdd1` and `/mnt/hdd2` (managed outside Ansible).

### Targets

Three deploy targets, same playbook, different inventories:

| Target    | Where                                          | Purpose                           |
|-----------|------------------------------------------------|-----------------------------------|
| `sandbox` | Debian ARM64 VM in Colima on the Mac           | Fast-iteration development        |
| `staging` | Pi 4 with a fresh SD card                      | Release-candidate E2E testing     |
| `prod`    | Pi 5                                           | Real workload                     |

### Execution surface

A single CLI wraps everything:

```
./homelab deploy --target sandbox
./homelab backup --target prod
./homelab restore --target prod --snapshot <id>
./homelab test --target sandbox
./homelab status --target prod
```

Each subcommand delegates to a focused script in `scripts/`. The CLI handles target selection, dry-run mode, and pre-flight safety checks.

### Backup model

- **Daily, automated** — restic snapshots of `/opt/homelab/config/` to a known location on HDD #1.
- **App-aware** — each *arr's built-in backup feature runs first, writing SQLite dumps into its config dir, which restic then picks up.
- **Restore-tested** — at least once per quarter, the restore path is exercised on staging.
- Off-site backup is deferred but the tool choice (restic) supports it natively when added.

### Safety model

The media on HDDs is the only truly irreplaceable thing. Configuration can be lost and rebuilt; media cannot. See [SAFETY.md](SAFETY.md) for the rules and [`scripts/preflight.sh`](../scripts/preflight.sh) for the automated checks.

### Docker network separation

Four bridge networks instead of one:

- `vpn_net` — gluetun, qBittorrent, Prowlarr
- `media_net` — Jellyfin, Sonarr, Radarr, Bazarr
- `proxy_net` — Caddy; joined by `media_net` for upstream access
- `monitoring_net` — reserved for future monitoring epic

This is opportunistic — applied during volume migration, not a separate project.

### Deferred (future epics, planned but not committed)

- **Networking** — Tailscale for stable cross-network addressing; Pi-hole for local DNS; eventual router.
- **Monitoring** — Prometheus, Grafana, node-exporter, cAdvisor, exportarr, smartctl-exporter, Scrutiny.
- **Notifications** — Apprise / ntfy / Discord; Diun for image-update notifications.
- **Pi 4 long-term role** — local DNS, monitoring host, or backup target.
- **Integration tests** — automated download-and-resume tests on staging.
- **NVMe download staging** — move qBit incomplete dir to NVMe; copy-on-complete to HDD.
- **qBit-without-gluetun toggle** — optional second qBit profile that runs without VPN.

## Component map

```
                    ┌──────────────┐
                    │   Browser /  │
                    │ Jellyfin app │
                    └──────┬───────┘
                           │ HTTP (LAN)
                    ┌──────▼───────┐
                    │    Caddy     │  proxy_net + media_net
                    └──────┬───────┘
                           │
       ┌───────────────────┼──────────────────────┐
       │                   │                      │
┌──────▼─────┐      ┌──────▼──────┐        ┌──────▼──────┐
│  Jellyfin  │      │   Sonarr    │        │  Prowlarr   │
│ media_net  │      │  media_net  │        │   vpn_net   │
└──────┬─────┘      └──────┬──────┘        └──────┬──────┘
       │                   │                      │
       │            ┌──────▼──────┐               │
       │            │   Radarr    │               │
       │            │  media_net  │               │
       │            └──────┬──────┘               │
       │                   │                      │
       │            ┌──────▼──────┐               │
       │            │   Bazarr    │               │
       │            │  media_net  │               │
       │            └──────┬──────┘               │
       │                   │                      │
       │                   ▼                      │
       │            ┌──────────────┐              │
       └───────────►│  qBittorrent │◄─────────────┘
                    │  vpn_net     │
                    └──────┬───────┘
                           │ network_mode: service:gluetun
                    ┌──────▼───────┐
                    │   Gluetun    │ → NordVPN
                    │   vpn_net    │
                    └──────────────┘
```
