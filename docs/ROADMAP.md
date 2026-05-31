# Roadmap

The map of what's planned, when, and what depends on what. 

## Goal

A reproducible, version-controlled homelab where:

- The full media stack can be torn down and rebuilt from Ansible + a backup in under an hour
- All configuration is declarative and idempotent
- Sensitive bits stay private while reusable bits are open source
- Changes are tested on sandbox before touching production
- Backups are automated and restore-tested
- Media on HDDs is treated as immutable

## Milestones

| Milestone              | Target date | Definition of done                                                                          |
|------------------------|-------------|---------------------------------------------------------------------------------------------|
| `MVP-June30`           | 2026-06-30  | The Pi 5 can be nuked and rebuilt from Ansible + the latest backup, end-to-end, on demand. |
| `Full-Transition-July31` | 2026-07-31 | All polish complete: qBit/gluetun fix, Recyclarr, network separation, docs, repo published. |
| `Future`               | unscheduled | Tracked but not committed. Monitoring, networking, notifications, etc.                      |

## Time budget

~40 hours of focused work for MVP. ~1–2 hrs weekday evenings + weekends through June.

## Epic summary

| Epic                          | Label                        | Milestone               | Issues |
|-------------------------------|------------------------------|-------------------------|--------|
| Foundation (repo scaffolding) | `epic:foundation`            | MVP-June30              | 5      |
| Testing environments          | `epic:testing-env`           | MVP-June30              | 7      |
| Safety & invariants           | `epic:safety`                | MVP-June30              | 4      |
| Backup & restore              | `epic:backup`                | MVP-June30              | 6      |
| Ansible core (per-service)    | `epic:ansible-core`          | MVP-June30              | 11     |
| Volume migration              | `epic:volume-migration`      | MVP-June30              | 11     |
| Execution scripts (CLI)       | `epic:execution-scripts`     | MVP-June30              | 5      |
| Smoke & idempotency tests     | `epic:smoke-tests`           | MVP-June30              | 4      |
| qBit/gluetun startup fix      | `epic:qbit-gluetun`          | Full-Transition-July31  | 2      |
| Recyclarr                     | `epic:recyclarr`             | Full-Transition-July31  | 2      |
| Docker network separation     | `epic:network-separation`    | Full-Transition-July31  | 2      |
| Documentation polish          | `epic:docs`                  | Full-Transition-July31  | 3      |
| Future: monitoring            | `epic:future-monitoring`     | Future                  | 1      |
| Future: networking            | `epic:future-networking`     | Future                  | 1      |
| Future: notifications         | `epic:future-notifications`  | Future                  | 1      |
| Future: Pi 4 long-term role   | `epic:future-pi4-use`        | Future                  | 1      |
| Future: integration tests     | `epic:future-integration`    | Future                  | 1      |
| Future: qBit toggle           | `epic:future-qbit-toggle`    | Future                  | 1      |
| Future: NVMe download staging | `epic:future-nvme-staging`   | Future                  | 1      |
| **Total**                     |                              |                         | **69** |

## Labels

- **Epic:** `epic:<name>` (see above)
- **Size:** `size:S` (<1hr), `size:M` (1–4hr), `size:L` (4hr–full day), `size:XL` (multi-day)
- **Type:** `type:setup`, `type:code`, `type:docs`, `type:research`, `type:test`, `type:ops`
- **Milestone:** `MVP-June30`, `Full-Transition-July31`, `Future`

(No priority labels — kanban column ordering is the priority signal.)

## Dependency graph

The shape, top-down. Arrows = "must complete before". Items in the same level can be done in parallel.

```
                    ┌──────────────────────┐
                    │ Foundation (#1-#5)   │
                    └──────────┬───────────┘
                               │
        ┌──────────────────────┼──────────────────────┐
        ▼                      ▼                      ▼
┌───────────────┐    ┌─────────────────┐    ┌──────────────────┐
│ Testing env   │    │ Safety baseline │    │ Backup research  │
│ (#6-#12)      │    │ (#13)           │    │ (#17)            │
└───────┬───────┘    └────────┬────────┘    └────────┬─────────┘
        │                     │                      │
        ▼                     ▼                      ▼
┌───────────────────────────────────────────────────────────────┐
│  CLI scaffold (#48) + Ansible base structure (#23-#24)        │
└────────────────────────────┬──────────────────────────────────┘
                             │
        ┌────────────────────┼─────────────────────┐
        ▼                    ▼                     ▼
┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
│ Per-service      │ │ Smoke test       │ │ Backup impl +    │
│ Ansible roles    │ │ harness (#44)    │ │ restore test     │
│ (#25-#35)        │ │                  │ │ (#18-#22)        │
└────────┬─────────┘ └────────┬─────────┘ └────────┬─────────┘
         │                    │                    │
         └────────────────────┼────────────────────┘
                              ▼
              ┌───────────────────────────────┐
              │  Smoke tests per service      │
              │  (#45-#47, idempotency)       │
              └──────────────┬────────────────┘
                             │
                             ▼
                ┌────────────────────────┐
                │ Volume migration       │
                │ on prod (#36-#46)      │  ← Backup is hard prerequisite (R5)
                └───────────┬────────────┘
                            │
                            ▼
                ┌────────────────────────┐
                │ Staging E2E test       │
                │ (#43)                  │
                │ → MVP complete         │
                └───────────┬────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        ▼                   ▼                   ▼
┌──────────────┐  ┌──────────────────┐  ┌──────────────────┐
│ qBit/gluetun │  │ Recyclarr        │  │ Network          │
│ fix (#56-57) │  │ (#58-59)         │  │ separation       │
│              │  │                  │  │ (#60-61)         │
└──────┬───────┘  └────────┬─────────┘  └────────┬─────────┘
       │                   │                     │
       └───────────────────┼─────────────────────┘
                           ▼
                ┌────────────────────────┐
                │ Docs polish (#62-64)   │
                │ → Full transition done │
                └────────────────────────┘
```
