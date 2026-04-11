#!/usr/bin/env bash
# Sync API + worker + shared libs to VPS, rebuild images, restart stack.
# Requires: rsync, ssh; run from a network that can reach the VPS.
#
#   VPS_HOST=148.113.52.70 VPS_SSH_KEY=$HOME/.ssh/finkhoz-tech.pem bash deploy-vps-api-worker.sh
#
set -euo pipefail

VPS_USER="${VPS_USER:-ubuntu}"
VPS_HOST="${VPS_HOST:-148.113.52.70}"
VPS_SSH_KEY="${VPS_SSH_KEY:-$HOME/.ssh/finkhoz-tech.pem}"
REMOTE_DIR="${REMOTE_NOVU_DIR:-/home/ubuntu/novu}"

ROOT="$(cd "$(dirname "$0")" && pwd)"
SSH=(ssh -i "$VPS_SSH_KEY" -o StrictHostKeyChecking=yes -o ConnectTimeout=30 "$VPS_USER@$VPS_HOST")
RSYNC=(rsync -az --progress -e "ssh -i $VPS_SSH_KEY -o StrictHostKeyChecking=yes -o ConnectTimeout=30")

echo "== Sync (API, worker, DAL, app-generic, packages) → $VPS_USER@$VPS_HOST:$REMOTE_DIR =="
for d in apps/worker/src apps/api/src libs/application-generic/src libs/dal/src packages/shared/src packages/providers/src packages/framework/src; do
  echo "  $d"
  "${RSYNC[@]}" "$ROOT/$d/" "$VPS_USER@$VPS_HOST:$REMOTE_DIR/$d/"
done
"${RSYNC[@]}" "$ROOT/apps/worker/Dockerfile" "$VPS_USER@$VPS_HOST:$REMOTE_DIR/apps/worker/Dockerfile"
"${RSYNC[@]}" "$ROOT/apps/api/Dockerfile" "$VPS_USER@$VPS_HOST:$REMOTE_DIR/apps/api/Dockerfile"

echo "== Remote: build contexts, docker compose build api worker, up =="
"${SSH[@]}" bash <<REMOTE
set -euo pipefail
cd "$REMOTE_DIR"
export NVM_DIR="\$HOME/.nvm"
. "\$NVM_DIR/nvm.sh"
nvm use 22 >/dev/null

refresh_ctx() {
  local dockerfile="\$1"
  local outdir="\$2"
  local tmp="/tmp/novu-ctx-\$\$.tgz"
  rm -f "\$tmp"
  set +e
  pnpm -s pnpm-context -- "\$dockerfile" > "\$tmp"
  ec=\$?
  set -e
  if [ "\$ec" -eq 0 ] || [ "\$ec" -eq 13 ]; then
    mkdir -p "\$outdir"
    tar -xzf "\$tmp" -C "\$outdir"
  fi
  rm -f "\$tmp"
}

refresh_ctx apps/api/Dockerfile .docker/build/api
cp -f scripts/dotenvcreate.mjs .docker/build/api/pkg/apps/api/src/dotenvcreate.mjs 2>/dev/null || true

refresh_ctx apps/worker/Dockerfile .docker/build/worker
cp -f scripts/dotenvcreate.mjs .docker/build/worker/pkg/apps/worker/src/dotenvcreate.mjs 2>/dev/null || true

export DOCKER_BUILDKIT=1
docker compose -f docker-compose.full.yml --env-file .env.deps build api worker
docker compose -f docker-compose.full.yml --env-file .env.deps up -d api worker ws
REMOTE

echo "== Checks =="
"${SSH[@]}" "docker exec novu-api-1 sh -c 'grep -R templateId /usr/src/app/libs/dal/src/repositories/integration/integration.schema.js 2>/dev/null | head -1' || docker exec novu-api-1 sh -c 'grep -R templateId /usr/src/app/apps/api/dist 2>/dev/null | head -1' || true"
"${SSH[@]}" "docker exec novu-worker-1 sh -c 'grep -R \"Set Default template ID\" /usr/src/app/apps/worker/dist 2>/dev/null | head -1' || true"
echo ""
echo "Next: in Dashboard, open Gupshup WhatsApp integration, set Default template ID, Save (re-persists credentials with new schema)."
echo Done.
