#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${GW_QM_APP_DIR:?GW_QM_APP_DIR is required}"
GIT_REMOTE="${GW_QM_GIT_REMOTE:-origin}"
GIT_REF="${GW_QM_GIT_REF:?GW_QM_GIT_REF is required}"
ECOSYSTEM="${APP_DIR}/deploy/layers/gw/ecosystem.config.cjs"

cd "$APP_DIR"

if ! command -v node >/dev/null 2>&1; then
  echo "node is not installed on the VM" >&2
  exit 1
fi

if ! command -v pm2 >/dev/null 2>&1; then
  echo "pm2 is not installed on the VM" >&2
  exit 1
fi

if [[ ! -f .env ]]; then
  echo "missing ${APP_DIR}/.env — bootstrap secrets on the VM before deploying" >&2
  exit 1
fi

git fetch "$GIT_REMOTE" --prune
git checkout "$GIT_REF"
git pull --ff-only "$GIT_REMOTE" "$GIT_REF"

npm ci
npm run typecheck
npm ci --prefix plugins/web-ui
npm ci --prefix plugins/admin
npm ci --prefix plugins/portal

if grep -q '^SANDBOX_BACKEND=local' .env 2>/dev/null; then
  npm run sandbox:local:build
fi

export GW_QM_APP_ROOT="$APP_DIR"
pm2 startOrReload "$ECOSYSTEM" --update-env
pm2 save

sleep 3
pm2 status

curl -fsS "http://127.0.0.1:3000/healthz" >/dev/null
curl -fsS -o /dev/null "http://127.0.0.1:8080/"

echo "remote rollout complete for ${GIT_REF}"
