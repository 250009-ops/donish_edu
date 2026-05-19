#!/usr/bin/env bash
# Run on EC2 after git pull (from backend/):
#   chmod +x scripts/ec2-post-deploy.sh && ./scripts/ec2-post-deploy.sh
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> npm ci"
npm ci

echo "==> env audit"
npm run env:audit

echo "==> Telegram webhook -> api.donish.live"
npm run webhook:set

echo "==> pm2 restart"
if command -v pm2 >/dev/null 2>&1; then
  pm2 restart all || pm2 restart donish-api || true
  pm2 save
else
  echo "pm2 not found; restart your Node process manually."
fi

echo "==> done"
