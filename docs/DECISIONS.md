# Decisions

A lightweight ADR (Architecture Decision Record) log. Each entry captures *why* a choice was made, so future-you (or contributors) don't have to guess.

Format: `ADR-NNNN: <title>` — Status, Context, Decision, Consequences.

---

## ADR-0001: Use Ansible (not Docker Compose alone, not k3s)

**Status:** Accepted

**Context:** The existing setup is plain `docker-compose.yml` files edited by hand. State drifts. Reproducibility is poor.

**Decision:** Keep Docker Compose as the runtime, use Ansible as the templating + orchestration layer above it.

**Consequences:**
- Templated configs and compose files become the source of truth.
- Idempotency comes from Ansible, not the runtime.
- k3s is out of scope — too much operational overhead for a single-node homelab.
- Plain Compose is too low-level for managing 10+ services' configs declaratively.

---

## ADR-0002: Two-repo overlay pattern (public + private)

**Status:** Accepted

**Context:** Some private services and all real secrets must stay private. But the rest is shareable with the community and benefits from being public.

**Decision:**
- `homelab-ansible` (public): roles, playbooks, example inventory, docs, scripts.
- `homelab-ansible-private` (private overlay): real inventory, ansible-vault secrets, private roles.
- Ansible runs with both repos on its inventory + role path.

**Consequences:**
- Slightly more complex Ansible invocation (handled by the CLI wrapper).
- No file duplication.
- Public repo is *complete and runnable* on its own with the example inventory.
- Rejected: single private repo (loses community value), two synced repos (drift), Git submodules (more complexity than it's worth here).

---

## ADR-0003: Bind mounts under `/opt/homelab/config/`, not Docker named volumes

**Status:** Accepted

**Context:** Current state uses anonymous volumes (`/var/lib/docker/volumes/<hash>/_data`). Scattered, hard to back up, not portable.

**Decision:** Migrate all service configs to bind mounts under a predictable, single root: `/opt/homelab/config/<service>`.

**Consequences:**
- Backup = tar one directory tree.
- Restore = untar to the same path.
- Permissions are explicit (PUID:PGID enforced by Ansible).
- One-time migration cost (one issue per service).
- Rejected named Docker volumes: still better than anonymous, but bind mounts are clearer and easier to reason about.

---

## ADR-0004: restic for backups

**Status:** Accepted (pending implementation epic confirms tool)

**Context:** Need encrypted, incremental, dedup'd, restorable backups of `/opt/homelab/config/`.

**Decision:** Use restic. Open-source, mature, single binary, ARM64-supported, supports local + S3-compatible + SFTP + Backblaze B2.

**Consequences:**
- Off-site backup is a config change, not a tool change, when added later.
- SQLite databases are backed up via app-aware dump first (each *arr's built-in backup), then restic snapshots the dumps. Avoids live-DB corruption.
- Rejected: borg (similar features but slightly less convenient for multi-target), kopia (newer, less battle-tested for this use case), plain tar + cron (no dedup, manual rotation).

---

## ADR-0005: Three targets — sandbox, staging, prod

**Status:** Accepted

**Context:** Need fast iteration without risking the running stack.

**Decision:**
- **sandbox** — Debian ARM64 VM in Colima on the Mac. Iteration, fail fast.
- **staging** — Pi 4 with a clean SD card. Release-candidate E2E test. Powered on manually for RC testing.
- **prod** — Pi 5. Real workload.

Same Ansible playbook, three inventories.

**Consequences:**
- Sandbox does not catch hardware-acceleration, USB, or systemd-init-script bugs. Staging exists for those.
- Pi 4 sitting idle gains a purpose.
- Rejected: single-environment (too risky), more environments (overkill for a homelab).

---

## ADR-0006: Trunk-based development on `main`

**Status:** Accepted

**Context:** Three environments could imply per-env branches (`dev` / `staging` / `main`). For a solo project, that's overhead.

**Decision:** Single `main` branch. Environments are inventory-driven, not branch-driven. Tags mark known-good points (`v0.0.x` after sandbox passes, `v0.x.0` after staging E2E passes).

**Consequences:**
- Simpler mental model.
- Tags are advisory, not gates.
- Promotion is a deploy command targeted at a different inventory, not a branch merge.

---

## ADR-0007: Colima (not Lima, not OrbStack)

**Status:** Accepted

**Context:** Need a local VM to host a Linux Docker target on the Mac.

**Decision:** Colima, already installed on the Mac.

**Consequences:**
- Free, open source, ARM64-native on Apple Silicon.
- Less polished UX than OrbStack but no licensing concerns.
- VM is named `homelab-sandbox`, runs Debian ARM64, 4 vCPU / 8 GB RAM, persistent.

---

## ADR-0008: Local Docker registry as pull-through cache (registry:3)

**Status:** Accepted

**Context:** Pi pulls over hotspot are slow. Pulling once on Mac and serving locally is faster and reduces bandwidth.

**Decision:** Run `registry:3` on the Mac configured as a Docker Hub pull-through cache. Pi's Docker daemon configured with a registry mirror pointing at it. Compose files use upstream image names (`jellyfin/jellyfin`) — portable, no rewriting.

**Consequences:**
- First pull of an image populates the cache transparently.
- Subsequent pulls (on the Pi, or after re-create on Mac) are local-network speed.
- Compose files stay portable to anyone else's setup.
- Rejected: Approach A (push-tagged images, rewrite compose) — less portable.

---

## ADR-0009: HTTP-only Caddy on LAN

**Status:** Accepted

**Context:** Local-only access, no need for public certs.

**Decision:** Caddy serves HTTP, no Let's Encrypt. Confirmed scope.

**Consequences:**
- No cert renewal logic to maintain.
- If the stack ever goes public (it shouldn't), this becomes a deliberate change with its own ADR.
- Browser warnings for "Not Secure" badges are acceptable for local LAN.

---

## ADR-0010: One CLI (`./homelab`) wrapping focused scripts

**Status:** Accepted

**Context:** Raw `ansible-playbook` invocations are long, error-prone, and don't enforce safety checks. But a monolithic mega-script is hard to test and maintain.

**Decision:**
- `./homelab` — entry point, parses subcommand + target, runs pre-flight, dispatches.
- `scripts/deploy.sh`, `scripts/backup.sh`, `scripts/restore.sh`, `scripts/test.sh`, `scripts/status.sh`, `scripts/preflight.sh`, `scripts/bootstrap.sh` — focused scripts.

**Consequences:**
- Each script can be invoked directly for debugging.
- The CLI is the canonical surface for routine ops.
- Bash for now. If complexity grows, revisit (Python / Go) — separate ADR.

---

## ADR-0011: Recyclarr for *arr quality profiles; defer Configarr

**Status:** Accepted

**Context:** Quality profiles drift over time and are tedious to recreate.

**Decision:** Adopt Recyclarr in MVP. Configarr is newer, broader, less mature — revisit later. 

**Consequences:**
- Sonarr and Radarr quality profiles become a YAML file in Git.
- One more container in the stack (runs as a cron job).

---

## ADR-0012: Defer Tailscale, monitoring, notifications, router

**Status:** Accepted (deferral)

**Context:** All valuable, none blocking. Doing the foundation first means these can be added cleanly.

**Decision:** Tracked as future epics. Visible in ROADMAP. Not in MVP, not in July transition.

**Consequences:**
- Network IP-drift pain continues until Tailscale lands.
- No observability until monitoring lands. Manual `docker logs` and `docker stats` are the fallback.
- These are post-July priorities.

---

## ADR template (for future entries)

```
## ADR-NNNN: <Short title>

**Status:** Proposed / Accepted / Superseded by ADR-MMMM

**Context:** What problem needs solving? What constraints apply?

**Decision:** What was chosen.

**Consequences:** Trade-offs accepted; alternatives rejected and why.
```
