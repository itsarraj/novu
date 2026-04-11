#!/usr/bin/env bash
# Sync worker-related sources to the VPS and rebuild/restart worker (and api/ws).
# Run from your machine where SSH works.
#
#   VPS_HOST=148.113.52.70 VPS_SSH_KEY=$HOME/.ssh/finkhoz-tech.pem bash scripts/docker/vps-sync-worker-and-rebuild.sh
#
set -euo pipefail

VPS_USER="${VPS_USER:-ubuntu}"
VPS_HOST="${VPS_HOST:-148.113.52.70}"
VPS_SSH_KEY="${VPS_SSH_KEY:-$HOME/.ssh/finkhoz-tech.pem}"
REMOTE_DIR="${REMOTE_NOVU_DIR:-/home/ubuntu/novu}"

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SSH=(ssh -i "$VPS_SSH_KEY" -o StrictHostKeyChecking=yes -o ConnectTimeout=30 "$VPS_USER@$VPS_HOST")
RSYNC=(rsync -az -e "ssh -i $VPS_SSH_KEY -o StrictHostKeyChecking=yes -o ConnectTimeout=30")

echo "== Sync sources to $VPS_USER@$VPS_HOST:$REMOTE_DIR =="
for d in apps/worker/src libs/application-generic/src packages/shared/src packages/providers/src packages/framework/src libs/dal/src; do
  echo "  $d"
  "${RSYNC[@]}" "$ROOT/$d/" "$VPS_USER@$VPS_HOST:$REMOTE_DIR/$d/"
done
"${RSYNC[@]}" "$ROOT/apps/worker/Dockerfile" "$VPS_USER@$VPS_HOST:$REMOTE_DIR/apps/worker/Dockerfile"

echo "== Remote: pnpm-context, build worker, up =="
"${SSH[@]}" "REMOTE_DIR='$REMOTE_DIR' bash -s" <<'REMOTE_EOF'
set -euo pipefail
cd "$REMOTE_DIR"
export NVM_DIR="$HOME/.nvm"
. "$NVM_DIR/nvm.sh"
nvm use 22 >/dev/null
TMP=/tmp/novu-wctx-$$.tgz
rm -f "$TMP"
set +e
pnpm -s pnpm-context -- apps/worker/Dockerfile > "$TMP"
ec=$?
set -e
if [ "$ec" -eq 0 ] || [ "$ec" -eq 13 ]; then
  mkdir -p .docker/build/worker
  tar -xzf "$TMP" -C .docker/build/worker
  cp -f scripts/dotenvcreate.mjs .docker/build/worker/pkg/apps/worker/src/dotenvcreate.mjs
fi
rm -f "$TMP"
export DOCKER_BUILDKIT=1
docker compose -f docker-compose.full.yml --env-file .env.deps build worker
docker compose -f docker-compose.full.yml --env-file .env.deps up -d worker api ws
REMOTE_EOF

echo "== Smoke check =="
"${SSH[@]}" "docker exec novu-worker-1 sh -c 'grep -R \"Set Default template ID\" /usr/src/app/apps/worker/dist 2>/dev/null | head -1' || true"
echo Done.
