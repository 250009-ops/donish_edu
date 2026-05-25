# Deploy latest backend to EC2 (run from project root in PowerShell).
# Requires: EC2 key at Downloads\donish-backend-prod-key.pem and SSH access to port 22.

$ErrorActionPreference = "Stop"

$Key = "$env:USERPROFILE\Downloads\donish-backend-prod-key.pem"
$Host_ = "ubuntu@13.53.192.193"
$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$BackendDir = Join-Path $RepoRoot "backend"
$Tarball = Join-Path $env:TEMP "donish-backend-deploy.tgz"

if (-not (Test-Path $Key)) {
  Write-Error "EC2 key not found at $Key"
}

Write-Host "Packaging backend (excluding node_modules and .env)..."
if (Test-Path $Tarball) { Remove-Item $Tarball -Force }
tar -czf $Tarball -C $BackendDir --exclude=node_modules --exclude=.env .

Write-Host "Uploading to $Host_ ..."
scp -i $Key -o ConnectTimeout=30 $Tarball "${Host_}:/tmp/backend-deploy.tgz"

$remote = "set -e; cd ~/donish_edu/backend; cp .env /tmp/donish-backend.env.bak; tar -xzf /tmp/backend-deploy.tgz; cp /tmp/donish-backend.env.bak .env; npm ci; pm2 restart donish-api; pm2 save; curl -s http://127.0.0.1:4000/health"

Write-Host "Installing on server and restarting PM2..."
ssh -i $Key -o ConnectTimeout=30 -o StrictHostKeyChecking=yes $Host_ $remote

if ($LASTEXITCODE -ne 0) {
  Write-Warning @"
Deploy failed. API may still be live at https://api.donish.live/health

On EC2 (browser shell), after uploading backend-deploy.tgz:
  cd ~/donish_edu/backend && cp .env /tmp/donish-backend.env.bak
  tar -xzf /tmp/backend-deploy.tgz && cp /tmp/donish-backend.env.bak .env
  npm ci && pm2 restart donish-api && pm2 save

IMPORTANT — apply Supabase migration once (SQL Editor):
  backend/db/migration_word_cache_calendar.sql
"@
  exit 1
}

Write-Host "Done. Public health: https://api.donish.live/health"
Write-Host "If Vocabulary still errors, run migration_word_cache_calendar.sql in Supabase SQL Editor."
