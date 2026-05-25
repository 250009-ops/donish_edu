#!/usr/bin/env bash
set -euo pipefail
cd ~/donish_edu/backend
cp .env /tmp/donish-backend.env.bak
tar -xzf /tmp/backend-deploy.tgz
cp /tmp/donish-backend.env.bak .env

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 60" || true)
REGION=eu-north-1
if [ -n "$TOKEN" ]; then
  REGION=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
    http://169.254.169.254/latest/meta-data/placement/region 2>/dev/null || echo eu-north-1)
fi

grep -q '^AWS_REGION=' .env || echo "AWS_REGION=$REGION" >> .env
grep -q '^TEXTRACT_S3_BUCKET=' .env || echo 'TEXTRACT_S3_BUCKET=donish-textract-uploads-prod' >> .env

npm ci
pm2 restart donish-api
pm2 save
curl -s http://127.0.0.1:4000/health
