---
name: deploy-gw-qm
description: Deploy qm to Gentle Weapons GCP (qm-core-vm, Cloud SQL, Caddy, PM2). Use when asked to deploy GW qm, ship to production, roll out to GCP, or run terraform for GW infra.
---

# deploy-gw-qm

Fully automated deploy for the Gentle Weapons GCP stack documented in
[`deploy/layers/gw/GW_DEPLOYMENT.md`](../../../deploy/layers/gw/GW_DEPLOYMENT.md).

## One command

From the repository root:

```bash
bash deploy/layers/gw/scripts/deploy-gw-qm.sh
```

Deploy a specific ref:

```bash
bash deploy/layers/gw/scripts/deploy-gw-qm.sh --ref feat/my-branch
```

Apply Terraform first, then roll out the app:

```bash
bash deploy/layers/gw/scripts/deploy-gw-qm.sh --infra
```

Dry run:

```bash
bash deploy/layers/gw/scripts/deploy-gw-qm.sh --dry-run
```

The repo-root launcher `.claude/skills/deploy-gw-qm/deploy-gw-qm.sh` is equivalent.

## Preconditions

Local machine:

- `gcloud` authenticated with SSH access to `qm-core-vm`
- `curl`

For `--infra`:

- `terraform`
- `TF_VAR_db_password` in the environment

VM (`deploy/layers/gw/deploy.config.json` → `appDir`):

- git clone of this repository
- `.env` with production secrets (never committed)
- `node` 24+, `npm`, `pm2`

GitHub Actions (optional): workflow `.github/workflows/deploy-gw.yml` deploys on
push to `main` and supports manual dispatch. Configure repository secrets:

- `GW_GCP_SA_KEY` — service account JSON with compute.instanceAdmin and
  compute.osLogin (or equivalent SSH access)
- `GW_TF_DB_PASSWORD` — only when using `--infra` from CI

## What the script does

1. Reads `deploy/layers/gw/deploy.config.json` for project, zone, VM, app path,
   and health URL.
2. Optionally runs `terraform apply` in `terraform/`.
3. SSHes to `qm-core-vm` and runs `deploy/layers/gw/scripts/remote-rollout.sh`:
   - `git fetch`, checkout, and fast-forward to the requested ref
   - `npm ci` at root and in web-ui, admin, and portal plugins
   - `npm run typecheck`
   - `npm run sandbox:local:build` when `.env` sets `SANDBOX_BACKEND=local`
   - `pm2 startOrReload deploy/layers/gw/ecosystem.config.cjs`
4. Verifies `healthUrl` (default `https://joe.gentleweapons.xyz/healthz`).

## PM2 layout

`deploy/layers/gw/ecosystem.config.cjs` runs:

| Process | Port | Role |
|---------|------|------|
| qm-core | 3000 | API + Slack |
| qm-worker | — | background queue |
| qm-web-ui | 3001 | web surface |
| qm-admin | 3002 | admin surface |
| qm-portal | 8080 | Caddy front door |

Caddy on the VM terminates TLS and reverse-proxies to port 8080.

## First-time VM bootstrap

When the VM has no checkout yet:

```bash
gcloud compute ssh qm-core-vm --zone=us-central1-a
git clone git@github.com:gentle-weapons/qm.git /home/cory_gentleweapons_com/app
cd /home/cory_gentleweapons_com/app
cp /path/to/production/.env .env
npm ci
bash deploy/layers/gw/scripts/deploy-gw-qm.sh
```

Then run `pm2 startup` once if PM2 is not yet registered with systemd.

## Troubleshooting

See [`GW_DEPLOYMENT.md`](../../../deploy/layers/gw/GW_DEPLOYMENT.md) for logs,
Slack, Docker sandbox permissions, and database access.

After deploy:

```bash
gcloud compute ssh qm-core-vm --zone=us-central1-a -- pm2 logs
gcloud compute ssh qm-core-vm --zone=us-central1-a -- pm2 status
```
