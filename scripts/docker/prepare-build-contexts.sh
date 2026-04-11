#!/usr/bin/env bash
# Prepares per-app Docker build contexts for api/worker/ws (pnpm-context tarball)
# and copies scripts/dotenvcreate.mjs into each app src/ (same as Novu CI).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

if ! command -v pnpm >/dev/null 2>&1; then
  echo "pnpm is required on PATH" >&2
  exit 1
fi

# Keep CI parity: the app Dockerfiles expect apps/*/src/dotenvcreate.mjs.
for app in api worker ws; do
  cp -f scripts/dotenvcreate.mjs "apps/${app}/src/dotenvcreate.mjs"
done

mkdir -p .docker/build/api .docker/build/worker .docker/build/ws

ctx="$(mktemp)"
trap 'rm -f "$ctx"' EXIT

for app in api worker ws; do
  rm -f "$ctx"

  # -s keeps lifecycle text off stdout so the stream is a valid gzip tarball.
  # Node may still exit 13 (top-level await warning) after the file is fully written.
  set +e
  pnpm -s pnpm-context -- "apps/${app}/Dockerfile" >"$ctx"
  ec=$?
  set -e
  if [ "$ec" -ne 0 ] && [ "$ec" -ne 13 ]; then
    echo "pnpm-context failed for ${app} (exit ${ec})" >&2
    exit "$ec"
  fi

  h1=$(head -c 1 "$ctx" | od -An -tu1 | tr -d ' ')
  h2=$(dd if="$ctx" bs=1 skip=1 count=1 2>/dev/null | od -An -tu1 | tr -d ' ')
  if [ "$h1" != "31" ] || [ "$h2" != "139" ]; then
    echo "Invalid gzip magic for ${app} context (got ${h1} ${h2}, expected 31 139)" >&2
    exit 1
  fi

  rm -rf ".docker/build/${app}"
  mkdir -p ".docker/build/${app}"
  tar -xzf "$ctx" -C ".docker/build/${app}"

  # `pnpm-context` respects .gitignore; since apps/*/src/dotenvcreate.mjs is gitignored,
  # make sure it exists inside the extracted build context.
  mkdir -p ".docker/build/${app}/pkg/apps/${app}/src"
  cp -f scripts/dotenvcreate.mjs ".docker/build/${app}/pkg/apps/${app}/src/dotenvcreate.mjs"
done

echo "Docker build contexts ready under ${ROOT}/.docker/build/{api,worker,ws}"
