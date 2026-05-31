# Development

How to work on this repo.

## Prerequisites

On your Mac:

- Colima (already installed)
- Docker CLI
- Ansible (`brew install ansible`)
- `pre-commit` (`brew install pre-commit`)
- `gh` CLI (`brew install gh`) — for issue management
- `jq` (`brew install jq`) — used by some scripts

## Repo layout

```
homelab-ansible/                 # public
├── ansible.cfg
├── roles/
│   ├── caddy/
│   ├── gluetun/
│   ├── qbittorrent/
│   ├── prowlarr/
│   ├── sonarr/
│   ├── radarr/
│   ├── bazarr/
│   ├── jellyfin/
│   └── recyclarr/               # added in #59
├── playbooks/
│   └── site.yml
├── group_vars.example/
├── host_vars.example/
├── inventory.example/
│   ├── sandbox.yml
│   ├── staging.yml
│   └── prod.yml
├── scripts/
│   ├── bootstrap-sandbox.sh
│   ├── bootstrap-staging.sh
│   ├── bootstrap-prod.sh
│   ├── deploy.sh
│   ├── backup.sh
│   ├── restore.sh
│   ├── test.sh
│   ├── status.sh
│   ├── preflight.sh
│   ├── warm-cache.sh
│   ├── images.txt
│   ├── issues.json
│   └── create-issues.sh
├── tests/
│   ├── smoke/
│   └── idempotency/
├── docs/
└── homelab                      # CLI entry point (bash)

homelab-ansible-private/         # private overlay
├── inventory/
│   └── hosts.yml
├── group_vars/
│   └── all/
│       ├── vars.yml
│       └── vault.yml            # ansible-vault encrypted
├── host_vars/
│   └── pi5.yml
└── roles/
    └── private_role/
```

## Variable precedence

Loosest to strictest (Ansible default order):

1. `group_vars/all/main.yml` — truly global
2. `group_vars/<env>/main.yml` — per environment (sandbox/staging/prod)
3. `host_vars/<host>.yml` — per host
4. Inline in playbook (rare)

Secrets always come from `group_vars/all/vault.yml` (encrypted) in the private overlay.

## Naming conventions

- **Roles:** lowercase, hyphen-free where possible (`sonarr`, `qbittorrent`)
- **Role variables:** prefixed with role name (`sonarr_api_key`, `sonarr_naming_format`)
- **Global vars:** prefixed with `homelab_` (`homelab_config_root`, `homelab_media_root`)
- **Vault secrets:** prefixed with `vault_` (`vault_sonarr_api_key`); referenced via a plain var (`sonarr_api_key: "{{ vault_sonarr_api_key }}"`)

## Running Ansible with the private overlay

The CLI handles this for you, but the long form is:

```bash
ansible-playbook \
  -i ../homelab-ansible-private/inventory/hosts.yml \
  -e @../homelab-ansible-private/group_vars/all/vars.yml \
  -e @../homelab-ansible-private/group_vars/all/vault.yml \
  --vault-password-file ~/.vault-pass-homelab \
  --roles-path roles:../homelab-ansible-private/roles \
  playbooks/site.yml
```

The CLI wrapper (`./homelab deploy`) figures out the overlay path automatically if the sibling directory exists.

## Pre-commit

```bash
pre-commit install
```

Runs lint + secret detection on every commit. Bypass with `--no-verify` only if absolutely necessary; better to fix the lint warning.

## Adding a new role

Each role should follow the same skeleton:

```
roles/<name>/
├── README.md              # what this role does, vars it expects
├── defaults/main.yml      # default values for all vars
├── vars/main.yml          # constants (rarely used)
├── tasks/main.yml         # actual tasks
├── handlers/main.yml      # restart handlers
├── templates/
│   └── config.j2          # templated configs
└── meta/main.yml          # role dependencies
```

After creating: add the role to `playbooks/site.yml` and create a smoke test module in `tests/smoke/<name>.bats` (or whatever framework is chosen in #53).

## Testing locally

```bash
./homelab deploy --target sandbox     # iterate
./homelab test --target sandbox       # smoke + idempotency
./homelab status --target sandbox     # service health
```

Once green on sandbox, the same commands target staging.

## Sandbox VM lifecycle

```bash
# create + bootstrap
./scripts/bootstrap-sandbox.sh

# reset (destroy and recreate)
colima delete homelab-sandbox && ./scripts/bootstrap-sandbox.sh

# manual SSH
colima ssh -p homelab-sandbox
```

## Issue management

Issues are managed via the GitHub Projects board: <https://github.com/users/sukhiboi/projects/2>.

To create issues from `scripts/issues.json` after editing the file:

```bash
./scripts/create-issues.sh
```

Idempotent: it will not create duplicates if an issue with the same title already exists.

## Commit style

- Short imperative subject line ("Add caddy role", not "Added" or "Adds")
- Reference the issue ("Add caddy role (#25)")
- Body explains *why*, not *what* (the diff explains the what)

## Branching

Trunk-based. Work on `main`. Tags mark known-good points:

- `v0.0.x` — after sandbox passes
- `v0.x.0` — after staging E2E passes
- `v1.0.0` — first prod-stable, public-ready

Feature branches only for genuinely risky multi-day work.
