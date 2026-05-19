#!/usr/bin/env bash
# If backend/.env is missing after the deploy folder was deleted, recreate it from
# Vercel → Project → Settings → Environment Variables (copy the same production values).
set -euo pipefail
ENV_FILE="$(dirname "$0")/../.env"
if [[ -f "$ENV_FILE" ]]; then
  echo "OK: $ENV_FILE exists"
  exit 0
fi
echo "MISSING: $ENV_FILE"
echo "Copy production secrets from Vercel (or your password manager) into backend/.env"
echo "See .env.example for required keys, then run: npm run env:audit && npm run webhook:set"
exit 1
