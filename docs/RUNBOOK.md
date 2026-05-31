# Runbook

How to operate the stack. Placeholder sections will fill in as the implementing issues land.

## CLI quick reference

```
./homelab deploy   --target {sandbox|staging|prod}
./homelab backup   --target {sandbox|staging|prod}
./homelab restore  --target {sandbox|staging|prod} [--snapshot ID] [--execute]
./homelab test     --target {sandbox|staging|prod}
./homelab status   --target {sandbox|staging|prod}
./homelab help
```

Default for any subcommand without `--target` is `sandbox` (safest). `prod` always prompts for typed confirmation.

## Sandbox (Colima VM on Mac)

*To be filled in by #6, #12.*

- Start / stop / inspect commands
- Reset to clean state
- SSH into VM directly
- Where VM data lives

## Staging (Pi 4)

*To be filled in by #7.*

- SD card flashing procedure
- First boot + SSH access
- Running bootstrap script
- Reset for new RC test

## Production (Pi 5)

*To be filled in by #8.*

- Current state inventory
- Prerequisites check
- Deploy procedure

## Backup & restore

*To be filled in by #22.*

- Take a manual backup
- List snapshots
- Restore (dry-run vs execute)
- Recover the encryption key
- Prune old snapshots

## Local Docker registry

*To be filled in by #9, #12.*

- Start / stop the registry on Mac
- Inspect cached images
- Warm cache from `images.txt`
- Configure Docker daemon on a new target

## Adding a new service

*To be filled in after first 2–3 roles exist.*

1. Create role skeleton in `roles/<name>/`
2. Add vars to `group_vars/all/main.yml`
3. Add secrets to `group_vars/all/vault.yml`
4. Add compose snippet
5. Add smoke test module
6. Test on sandbox
7. E2E on staging
8. Deploy to prod

## Troubleshooting

### qBit unresponsive after hours of idle

Check in this order:

1. `docker stats` — is qBit using a lot of RAM?
2. `cat /proc/sys/net/netfilter/nf_conntrack_count` vs `nf_conntrack_max` — table full?
3. `docker logs gluetun --tail 200` — gluetun restart loop?
4. Reduce qBit's per-torrent connection limit (300 → 100)

### Container fails to pull image

1. Check registry mirror is reachable from the target: `curl http://<mac-ip>:5000/v2/`
2. Check `daemon.json` has the mirror configured
3. Manually pull on Mac to populate cache

### Preflight check failed

The script will print which invariant failed. Common cases:

- **UUID mismatch:** a drive isn't mounted, or a different drive is mounted at that path. Check `lsblk -f`.
- **Stale backup:** last backup is older than threshold. Run `./homelab backup` first.
- **Free space low:** clean up something, or extend `/opt/homelab/`.

### Restore failed midway

restic restores are not atomic. If a restore fails midway:

1. The partial state is in `/opt/homelab/config/` — do not start services
2. Re-run `./homelab restore --execute` (it's idempotent at the file level)
3. If that fails too, manually `rm -rf /opt/homelab/config/<service>/` and retry

## Disaster recovery

Pi 5 dies. SD card / NVMe is unreadable. The plan:

1. New Pi 5 (or same one with new storage)
2. Flash Raspberry Pi OS, enable SSH, set hostname
3. Mount the two HDDs (they're untouched — UUIDs in fstab)
4. Pull the public + private repos
5. Run `./homelab deploy --target prod` (preflight will catch missing backup)
6. Run `./homelab restore --target prod --execute --snapshot latest`
7. Run `./homelab deploy --target prod` again to start services
8. Run `./homelab test --target prod` to verify

Expected time: under 1 hour if storage swap is the only physical work.
