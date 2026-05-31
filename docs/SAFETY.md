# Safety Invariants

Rules that must not be violated. Some are documented for humans; some are enforced by [`scripts/preflight.sh`](../scripts/preflight.sh) before destructive operations.

## The prime directive

**Media on HDDs is the only irreplaceable asset.** Configuration can be lost and rebuilt from Ansible + backup. Media files cannot be regenerated.

Every safety check is in service of protecting the contents of `/mnt/hdd1` and `/mnt/hdd2`.

## Hard rules

### R1 — Ansible never deletes from media drives

No Ansible task may issue a destructive file operation (`file: state=absent`, `command: rm`, etc.) against any path on a media drive. Period. Refactors that touch the media drives must use `read_only: true` mounts wherever possible.

**Enforcement:** code review + `ansible-lint` custom rule (deferred).

### R2 — Pre-flight aborts deploys when media drives are not mounted

If `/mnt/hdd1` or `/mnt/hdd2` are not present, or are mounted but the wrong UUID, the deploy aborts before any container starts. Otherwise, an *arr could "organize" files into a directory that looks right but is actually the root filesystem, and qBit could fill the SD card with downloads.

**Enforcement:** `scripts/preflight.sh` — automatic, runs at the top of `./homelab deploy`.

### R3 — Media drives are checked by UUID, not by path

`/mnt/hdd1` is just a mount point — anything could be mounted there. The pre-flight check verifies the **filesystem UUID** matches the value declared in Ansible vars. UUIDs are environment-specific:

| Environment | HDD1 UUID source       | HDD2 UUID source       |
|-------------|------------------------|------------------------|
| sandbox     | declared in vars (loopback file or named volume) |
| staging     | declared in vars (pen drive UUIDs)               |
| prod        | declared in vars (real HDD UUIDs)                |

**Enforcement:** `scripts/preflight.sh`.

### R4 — Each service has a declared write allowlist

A service may write only to paths it has declared. Anything else is a bug.

| Service        | Write paths allowed                                                                 |
|----------------|-------------------------------------------------------------------------------------|
| qBittorrent    | `<config>/qBittorrent/`, `<incomplete-dir>`, `<complete-dir>` (under media root)    |
| Sonarr         | `<config>/`, media library paths (rename/move/hardlink only)                        |
| Radarr         | `<config>/`, media library paths (rename/move/hardlink only)                        |
| Bazarr         | `<config>/`, sidecar `.srt` next to media files                                     |
| Jellyfin       | `<config>/`, sidecar NFO/artwork/trickplay next to media files                      |
| Prowlarr       | `<config>/` only                                                                    |
| gluetun        | `<config>/` only                                                                    |
| Caddy          | `<config>/`, `<data>/` (auto-generated certs, even though unused locally)           |

**Enforcement:** smoke tests after deploy walk the mount list of each container and assert no surprise writable paths exist.

### R5 — Backups must exist and be fresh before any deploy that could affect state

Before running any deploy that touches an existing service's config, the pre-flight check verifies:

- A backup exists at the declared backup location.
- The latest backup is less than 24 hours old (configurable per environment; sandbox is exempt).
- The backup is restorable (a periodic restore-test marker file is checked).

If these are not satisfied, `./homelab deploy --target prod` refuses to run. Override with `--force-no-backup` (intentionally verbose).

**Enforcement:** `scripts/preflight.sh`.

### R6 — Media drives mount read-only during smoke tests and idempotency tests

When running automated tests on any environment, the media drives are remounted read-only first (or in sandbox, mounted read-only from the start). This guarantees a buggy test cannot delete or modify media.

**Enforcement:** test harness sets the mount mode; assertion at test start.

### R7 — Permissions are declared, not discovered

Each service has a declared `PUID:PGID`. Ansible enforces ownership on `<config>/` and incoming media paths before starting the container. Permission drift is treated as a configuration error, not silently fixed at runtime.

**Enforcement:** Ansible role tasks + smoke tests verify `stat` matches expectation.

### R8 — Secrets never enter the public repo

The public repo contains no secrets, ever. The private overlay contains them, encrypted with ansible-vault. Pre-commit hook in the public repo scans for common secret patterns and blocks the commit.

**Enforcement:** `pre-commit` hook with `detect-secrets` or `gitleaks`.

### R9 — Production deploys require a typed confirmation

`./homelab deploy --target prod` asks for explicit "yes-deploy-to-prod" confirmation. No flag bypasses this for prod. (Sandbox and staging deploy without prompts.)

**Enforcement:** the CLI script.

### R10 — Destructive operations are dry-run by default

`./homelab restore` defaults to a dry-run that lists what would be restored. Actually performing the restore requires `--execute`. Same for any future `prune`, `clean`, or `wipe` subcommands.

**Enforcement:** the CLI script.

## Soft rules

These are conventions, not enforced:

- **No SSH'ing into prod to "fix it manually."** If a fix is needed, codify it in Ansible and deploy.
- **No editing config files on the running host.** Edit vars, deploy, let Ansible render.
- **Every change has an issue.** Even small ones — keeps the project trail readable.
- **Test on sandbox before staging, on staging before prod.** No skipping levels in normal flow.

## Acknowledged risks

- Configuration loss is acceptable. Watch history, queue state, scheduled tasks — all reproducible from Ansible + an old backup.
- Sandbox does not simulate the Pi's video acceleration, USB topology, or systemd quirks. Some bugs will only appear on staging.
- Phone hotspot can drop mid-deploy. Use SSH `tmux` / `mosh` for long deploys.
- A bug in `preflight.sh` could let a bad deploy through. Pre-flight is a safety net, not a guarantee.
