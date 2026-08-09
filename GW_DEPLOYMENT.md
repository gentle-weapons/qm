# Gentle Weapons (GW) QM Deployment Guide

This document details the deployment, operational architecture, management, and maintenance procedures for the QM application deployed on Google Cloud Platform (GCP) for Gentle Weapons.

---

## 1. Architecture Overview

### GCP Infrastructure Context
- **GCP Project ID**: `root-truth-504504-u4`
- **Region**: `us-central1`
- **Zone**: `us-central1-a`
- **VPC Network**: `qm-vpc` (`10.0.1.0/24`)

### Compute & Database Components

#### Core Application VM (`qm-core-vm`)
- **External IP**: `35.255.31.143`
- **Internal IP**: `10.0.1.2`
- **Runtime**: Node.js 24
- **API Framework**: Fastify running on port `3000`
- **Process Manager**: PM2 (`qm-core`)
- **Integrations**: Slack Socket Mode client
- **Role**: Handles HTTP API traffic, inbound Slack event subscriptions via WebSocket Socket Mode, process orchestration, and database interaction.

#### Cloud SQL PostgreSQL Database (`qm-postgres-32afcc0b`)
- **Instance Name**: `qm-postgres-32afcc0b`
- **Public Endpoint**: `34.172.135.125:5432`
- **Database Name**: `qm`
- **Database User**: `qm_user`
- **Durable Storage Stores**:
  - `SESSION_STORE=postgres`
  - `RUN_STORE=postgres`
  - `ARTIFACT_STORE=postgres`
- **Role**: Serves as the durable database layer for persistent session states, run histories, and artifact metadata.

#### Isolated Execution Sandbox VM (`qm-sandbox-vm`)
- **Internal IP**: `10.0.1.4`
- **Egress Restrictions**: Egress to the GCP Metadata Server (`169.254.169.254`) is explicitly blocked via GCP egress firewall rules (`qm-deny-sandbox-metadata`).
- **Role**: Provides an isolated environment for untrusted or dynamic code execution, enforcing security boundaries away from core credentials and cloud metadata services.

---

## 2. How to Access & Manage

### SSH Access
Connect to the core application VM using the `gcloud` CLI:

```bash
gcloud compute ssh qm-core-vm --zone=us-central1-a
```

### Process Management with PM2
The application process is managed by PM2 under the process name `qm-core`.

Check status:
```bash
pm2 status
```

View real-time logs:
```bash
pm2 logs qm-core
```

Restart application:
```bash
pm2 restart qm-core
```

Stop application:
```bash
pm2 stop qm-core
```

### Environment Configuration
The environment variables for the application are configured in:
```text
/home/cory_gentleweapons_com/app/.env
```

After modifying the `.env` file, restart the process to apply changes:
```bash
pm2 restart qm-core
```

### Database Management & Queries
Database queries can be executed directly using Node.js with environment variables or via `psql`.

Using Node.js:
```bash
node --env-file-if-exists=.env -e "const { Client } = require('pg'); const client = new Client({ connectionString: process.env.DATABASE_URL }); client.connect().then(() => client.query('SELECT NOW()')).then(res => { console.log(res.rows); client.end(); });"
```

Using `psql`:
```bash
psql "postgresql://qm_user:<password>@34.172.135.125:5432/qm"
```

---

## 3. Debugging & Maintenance

### Log Inspection
PM2 maintains stdout and stderr logs on the `qm-core-vm` at:

- Standard Output Log: `~/.pm2/logs/qm-core-out.log`
- Standard Error Log: `~/.pm2/logs/qm-core-error.log`

Inspect recent logs:
```bash
tail -n 100 -f ~/.pm2/logs/qm-core-out.log
tail -n 100 -f ~/.pm2/logs/qm-core-error.log
```

### Health Check Verification
Verify API server health and availability by making a request to the Fastify health endpoint:

```bash
curl http://35.255.31.143/healthz
```

Expected response should confirm operational status (`{"status":"ok"}` or HTTP 200).

### Slack Integration Troubleshooting
When troubleshooting Slack connectivity issues:

1. **Socket Mode Connection**: Verify WebSocket connection established in PM2 logs.
2. **Required OAuth Scopes**: Ensure the Slack App configuration includes required bot token scopes:
   - `users:read`
   - `emoji:read`
   - `app_mentions:read`
3. **Identity Verification Setting**: Ensure `SLACK_IDENTITY_EMAIL=0` is set in `.env` if email-based identity matching is disabled.

### Local Sandbox & Docker Socket Permissions
When using `SANDBOX_BACKEND=local`:

1. **Docker Socket Access**: Linux user `cory_gentleweapons_com` must belong to the `docker` group (`gid 121`).
2. **PM2 Group Context**: If user permissions or group assignments change, the PM2 daemon MUST be killed and restarted (`pm2 kill && cd /home/cory_gentleweapons_com/app && pm2 start npm --name qm-core -- run start`) so the PM2 daemon process inherits group 121 permissions to access `/var/run/docker.sock`.
3. **Sandbox Base Image**: Compile the local container image using:
   ```bash
   npm run sandbox:local:build
   ```

### Model Provider & Multi-Tool Execution Setup
1. **Google Gemini Flash 3.6 Setup in `.env`**:
   ```text
   HARNESS=pi
   MODEL_PROVIDER=google
   PI_MODEL=gemini-3.6-flash
   GEMINI_API_KEY=<active_key>
   ```
2. **Multi-Tool Batch Safety**: Multi-tool calls emitted in parallel (e.g. `execute` + `slack`) are pre-registered in `agent.onResponse`. `slack.post` automatically gates speculative/premature posts until execution tool results (`execute`, `read`, `write`) have returned and been evaluated in the subsequent step.

---

## 4. Terraform Infrastructure

The GCP infrastructure for QM is defined in the `terraform/` directory.

### Configuration Files
Located at `/Users/corycooper/workspace/gw/qm/terraform/`:
- `main.tf`: VPC networks, firewall rules, compute instances (`qm-core-vm`, `qm-sandbox-vm`), and Cloud SQL PostgreSQL instance (`qm-postgres-*`).
- `variables.tf`: Input variables (`gcp_project_id`, `gcp_region`, `gcp_zone`, `db_password`).
- `outputs.tf`: Output specifications for instance public/private IPs (`core_public_ip`, `sandbox_private_ip`, `postgres_public_ip`).
- `versions.tf`: Provider requirements (`hashicorp/google`, `hashicorp/random`) and Terraform CLI version constraints.

### Managing Infrastructure via Terraform

Plan infrastructure changes:
```bash
terraform plan
```

Apply infrastructure changes:
```bash
terraform apply
```

Inspect state outputs:
```bash
terraform output
```
