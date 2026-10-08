#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
CONFIG="${GW_QM_CONFIG:-$ROOT/deploy/layers/gw/deploy.config.json}"
REMOTE_SCRIPT="$ROOT/deploy/layers/gw/scripts/remote-rollout.sh"

usage() {
  cat <<EOF
Usage: deploy-gw-qm.sh [--ref <git-ref>] [--infra] [--dry-run]

Deploy qm to Gentle Weapons GCP (qm-core-vm via gcloud ssh).

Options:
  --ref <git-ref>   Git ref to deploy (default: deploy.config.json gitRef)
  --infra           Run terraform plan/apply before the app rollout
  --dry-run         Print actions without mutating cloud or the VM
EOF
}

REF=""
INFRA=0
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ref)
      REF="${2:?--ref requires a value}"
      shift 2
      ;;
    --infra)
      INFRA=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

read_config() {
  node -e "
    const fs = require('node:fs');
    const cfg = JSON.parse(fs.readFileSync(process.argv[1], 'utf8'));
    for (const [key, value] of Object.entries(cfg)) {
      process.stdout.write(\`\${key}=\${value}\n\`);
    }
  " "$CONFIG"
}

eval "$(read_config)"
REF="${REF:-$gitRef}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required command: $1" >&2
    exit 1
  fi
}

require_cmd gcloud
require_cmd curl

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "would set gcloud project to ${gcpProjectId}"
  if [[ "$INFRA" -eq 1 ]]; then
    echo "would run terraform apply in ${ROOT}/${terraformDir}"
  fi
  echo "would ssh to ${coreVm} (${gcpZone}) and deploy ref ${REF} in ${appDir}"
  echo "would verify ${healthUrl}"
  exit 0
fi

gcloud config set project "$gcpProjectId" >/dev/null

if [[ "$INFRA" -eq 1 ]]; then
  require_cmd terraform
  terraform -chdir="${ROOT}/${terraformDir}" init -input=false
  terraform -chdir="${ROOT}/${terraformDir}" apply -input=false -auto-approve
fi

REMOTE_BODY="$(cat "$REMOTE_SCRIPT")"
gcloud compute ssh "$coreVm" \
  --zone="$gcpZone" \
  --project="$gcpProjectId" \
  --command="GW_QM_APP_DIR=$(printf '%q' "$appDir") GW_QM_GIT_REMOTE=$(printf '%q' "$gitRemote") GW_QM_GIT_REF=$(printf '%q' "$REF") bash -s" \
  <<<"$REMOTE_BODY"

curl -fsS "$healthUrl" >/dev/null
echo "deploy-gw-qm: ${healthUrl} is healthy (ref ${REF})"
