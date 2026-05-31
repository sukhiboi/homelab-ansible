# homelab-ansible

Declarative, reproducible homelab managed with Ansible.

A media stack (Jellyfin + the *arrs + qBittorrent + Caddy) running on a Raspberry Pi 5, with infrastructure-as-code so the whole thing can be torn down and rebuilt from a Git repo + a backup.

## Status

🚧 Bootstrapping. See [`docs/ROADMAP.md`](docs/ROADMAP.md) for what's planned and where it is.

## Quick links

- [Architecture](docs/ARCHITECTURE.md) — what's here and how it fits together
- [Roadmap](docs/ROADMAP.md) — epics, milestones, dependency graph
- [Issues](docs/ISSUES.md) — detailed work items
- [Safety invariants](docs/SAFETY.md) — rules that must not be broken
- [Decisions](docs/DECISIONS.md) — why things were chosen
- [Runbook](docs/RUNBOOK.md) — how to operate the stack
- [Development](docs/DEVELOPMENT.md) — how to work on this repo

## Goal

> A reproducible, version-controlled homelab where the full media stack can be torn down and rebuilt from Ansible + a backup in under an hour, with all configuration declarative and idempotent, sensitive bits private, reusable bits open source, changes tested on a sandbox before touching production, and the media library on HDDs treated as immutable.

## Non-goals (for now)

- Kubernetes / k3s migration
- Moving off Docker Compose
- Exposing services publicly to the internet
- Buying new hardware as a prerequisite

## License

MIT. See [LICENSE](LICENSE).
