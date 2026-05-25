# Deploy latest backend to EC2 (run from project root in PowerShell).
# Requires: EC2 key at Downloads\donish-backend-prod-key.pem and SSH access to port 22.
$ErrorActionPreference = "Stop"
$Key = "$env:USERPROFILE\Downloads\donish-backend-prod-key.pem"
$Host_ = "ubuntu@13.53.192.193"

if (-not (Test-Path $Key)) {
  Write-Error "EC2 key not found at $Key"
}

Write-Host "Deploying to $Host_ ..."
$remote = @'
set -e
cd ~/donish_edu
git pull origin main
cd backend
npm ci
pm2 restart donish-api || pm2 restart all
pm2 save
curl -s http://127.0.0.1:4000/health
'@

ssh -i $Key -o ConnectTimeout=30 -o StrictHostKeyChecking=yes $Host_ $remote
if ($LASTEXITCODE -ne 0) {
  Write-Warning @"
SSH deploy failed (timeout or blocked). API may still be live at https://api.donish.live/health

Run these on the EC2 instance (AWS console / another network):
  cd ~/donish_edu && git pull origin main
  cd backend && npm ci && pm2 restart donish-api && pm2 save

IMPORTANT — apply Supabase migration once (SQL Editor):
  backend/db/migration_word_cache_calendar.sql
Without it, Vocabulary tab API calls return 500.
"@
  exit 1
}

Write-Host "Done. Public health: https://api.donish.live/health"
Write-Host "If Vocabulary still errors, run migration_word_cache_calendar.sql in Supabase SQL Editor."
