# Deploying the Gotcha backend (Eskiz VPS)

Production API: **https://api.donish.live**

## Stack on VPS

- **Node 20** + **PM2** on port `4000`
- **PostgreSQL** (`donish` database, local)
- **nginx** reverse proxy
- **Certbot** TLS (after DNS points to the VPS)
- **PDF extraction**: `pdf-parse` + Poppler (`pdftotext`) + Tesseract (no AWS)

## DNS (required)

At your domain registrar for **donish.live**, set **all** of these A records to your VPS IP (`170.168.6.42`):

| Type | Name / Host | Points to | Used for |
|------|-------------|-----------|----------|
| A | `api` | `170.168.6.42` | Backend API (already working) |
| A | `@` (root) | `170.168.6.42` | App home `https://donish.live/` |
| A | `www` | `170.168.6.42` | `https://www.donish.live/` |

**If only `api` is set**, `donish.live` and `www.donish.live` will show `DNS_PROBE_FINISHED_NXDOMAIN` in the browser — the site is deployed on the VPS, but the domain name does not resolve yet.

Check propagation: `nslookup donish.live` should return `170.168.6.42`.

After DNS propagates (check with `nslookup donish.live` → `170.168.6.42`):

```powershell
cd backend
npm run finish:dns
```

This runs Certbot for `donish.live`, `www.donish.live`, and confirms `api.donish.live` HTTPS.

## Environment (`backend/.env` on server)

| Variable | Notes |
|----------|--------|
| `NODE_ENV` | `production` |
| `PORT` | `4000` |
| `API_BASE_URL` | `https://api.donish.live` |
| `DATABASE_URL` | `postgresql://donish:PASSWORD@127.0.0.1:5432/donish` |
| `JWT_SECRET` | ≥ 32 characters |
| `BOT_SHARED_SECRET` | ≥ 16 characters |
| `OPENAI_API_KEY` | Translation |
| `TELEGRAM_BOT_TOKEN` | Bot + webhook |

Do **not** set `SUPABASE_*`, `AWS_*`, or `TEXTRACT_*`.

## Deploy from Windows (project root)

```powershell
cd backend
# One-time: IP, PASSWORD, DOMAIN in .env (deploy only — do not commit)
npm run deploy:vps
# If interrupted:
node scripts/vps-finish.mjs
# After code changes:
node scripts/vps-sync.mjs
```

## Migrate data from Supabase (optional)

If the old Supabase project is still online:

```powershell
cd backend
# Temporary: keep SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY in .env
node scripts/export-supabase.mjs
node scripts/vps-import-data.mjs
```

Then remove Supabase keys from server `.env`.

## After DNS update

On the VPS:

```bash
certbot --nginx -d api.donish.live --non-interactive --agree-tos --register-unsafely-without-email --redirect
cd /var/www/donish_edu/backend && npm run webhook:set
curl https://api.donish.live/health
```

## Fresh database (no Supabase import)

Existing users must **register again** via the Telegram bot (`/start`) and sign in to the app with the new ID and password. Old Supabase accounts are not migrated.

## Go live after DNS

```powershell
cd backend
node scripts/vps-go-live.mjs   # TLS + .env + PM2
node scripts/vps-webhook.mjs     # Telegram webhook (retry if needed)
```

## Marketing website (donish.live)

Built with **Astro 5** in `website/` (static HTML, SEO, legal pages).

```powershell
cd backend
node scripts/vps-sync-website.mjs
```

DNS: point **donish.live** and **www.donish.live** A records to the VPS IP (same as `api`).

TLS after DNS:

```bash
certbot --nginx -d donish.live -d www.donish.live --non-interactive --agree-tos --register-unsafely-without-email --redirect
```

Use **https://donish.live/home** for Lemon Squeezy business verification (marketing page). Root **https://donish.live** is the app entry point.

After deploy, verify readiness:

```powershell
node scripts/vps-lemon-check.mjs
```

Checks: HTTPS redirect, legal pages (`/privacy`, `/terms`, `/refund`), Gotcha branding, security headers, API health.

## Ops

- `pm2 logs donish-api`
- `pm2 restart donish-api`
- Daily DB backup: `pg_dump -U donish donish > /root/donish-backup.sql`

## Retire old hosting

After confirming `https://api.donish.live/health` and the Telegram bot work, stop **AWS EC2** and disable the old **Supabase** project to avoid extra cost.
