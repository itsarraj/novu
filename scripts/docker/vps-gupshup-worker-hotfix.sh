#!/usr/bin/env bash
# After LOCAL: NX_NO_CLOUD=true NODE_ENV=production pnpm exec nx build @novu/worker --parallel=2
set -euo pipefail
KEY="${VPS_SSH_KEY:-$HOME/.ssh/finkhoz-tech.pem}"
H="${VPS_HOST:-ubuntu@148.113.52.70}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CTR="${WORKER_CONTAINER:-novu-worker-1}"
RDIR=/tmp/novu-hotfix-$$

ssh -i "$KEY" -o StrictHostKeyChecking=yes -o ConnectTimeout=60 "$H" "mkdir -p $RDIR"

scp -i "$KEY" -o StrictHostKeyChecking=yes -o ConnectTimeout=60 \
  "$ROOT/packages/providers/dist/cjs/lib/sms/gupshup-whatsapp/gupshup-whatsapp.provider.js" \
  "$ROOT/libs/application-generic/build/main/factories/sms/handlers/gupshup-whatsapp.handler.js" \
  "$ROOT/apps/worker/dist/app/workflow/usecases/send-message/send-message-sms.usecase.js" \
  "$ROOT/packages/shared/dist/cjs/types/providers.js" \
  "$H:$RDIR/"

ssh -i "$KEY" -o StrictHostKeyChecking=yes -o ConnectTimeout=60 "$H" env RDIR="$RDIR" CTR="$CTR" bash -s <<'REMOTE'
set -euo pipefail
docker start "$CTR" 2>/dev/null || true
sleep 2
docker cp "$RDIR/gupshup-whatsapp.provider.js" "$CTR:/usr/src/app/packages/providers/dist/cjs/lib/sms/gupshup-whatsapp/gupshup-whatsapp.provider.js"
docker cp "$RDIR/gupshup-whatsapp.provider.js" "$CTR:/usr/src/app/packages/providers/dist/esm/lib/sms/gupshup-whatsapp/gupshup-whatsapp.provider.js"
docker cp "$RDIR/gupshup-whatsapp.handler.js" "$CTR:/usr/src/app/libs/application-generic/build/main/factories/sms/handlers/gupshup-whatsapp.handler.js"
docker cp "$RDIR/send-message-sms.usecase.js" "$CTR:/usr/src/app/apps/worker/dist/app/workflow/usecases/send-message/send-message-sms.usecase.js"
docker cp "$RDIR/providers.js" "$CTR:/usr/src/app/packages/shared/dist/cjs/types/providers.js"
docker restart "$CTR"
rm -rf "$RDIR"
docker exec "$CTR" sh -c 'grep -q "Set Default template ID" /usr/src/app/packages/providers/dist/cjs/lib/sms/gupshup-whatsapp/gupshup-whatsapp.provider.js && echo HOTFIX_OK'
cd /home/ubuntu/novu && docker compose -f docker-compose.full.yml --env-file .env.deps up -d api ws dashboard 2>/dev/null || true
REMOTE
