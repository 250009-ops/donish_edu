# Deploying the Donish backend (EC2)

Production API: **https://api.donish.live**

## Server layout

- **Node** (Express) on port `4000`, managed by **PM2**
- **nginx** terminates TLS and proxies to `127.0.0.1:4000`
- **Certbot** for Let's Encrypt on `api.donish.live`

## Environment (`backend/.env`)

Copy `.env.example` to `.env` on the server and fill in secrets (same values you used on Vercel if you want existing logins to keep working).

**Important:** Keep `~/donish_edu/backend` on the server. If that folder is deleted while PM2 is still running, the API may keep working temporarily but `.env` is gone — recreate it from Vercel env vars before the next `pm2 restart`.

Required in production:

| Variable | Notes |
|----------|--------|
| `NODE_ENV` | `production` |
| `PORT` | `4000` |
| `API_BASE_URL` | `https://api.donish.live` |
| `JWT_SECRET` | ≥ 32 characters |
| `BOT_SHARED_SECRET` | ≥ 16 characters |
| `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` | Supabase project |
| `OPENAI_API_KEY` | Translation |
| `TELEGRAM_BOT_TOKEN` | Bot + webhook |

Optional: `TELEGRAM_WEBHOOK_SECRET` (recommended).

Do **not** set `VERCEL` or `VERCEL_URL` on EC2.

## First deploy / update

```bash
cd ~/donish_edu/backend   # or your clone path
git pull
npm ci
pm2 restart donish-api    # or your PM2 app name
pm2 save
```

## Telegram webhook (after deploy or domain change)

On the server (needs `backend/.env` with `TELEGRAM_BOT_TOKEN`):

```bash
cd backend
npm run webhook:set
npm run webhook:info
```

Expected `url`: `https://api.donish.live/bot/telegram-webhook`

Do **not** run `npm run bot` (long polling) while webhook mode is active.

## Retire Vercel

See **[VERCEL_RETIRE.md](VERCEL_RETIRE.md)**. Summary:

1. Confirm EC2: `curl https://api.donish.live/health`
2. Run `./scripts/ec2-post-deploy.sh` (or `npm run webhook:set`) so Telegram stops sending updates to Vercel
3. In the Vercel dashboard: disable or delete the `donish-edu` project

## Ops checklist

- Attach an **Elastic IP** so reboots do not break DNS
- `pm2 startup` + `pm2 save`
- `sudo certbot renew --dry-run`
- Security group: allow `22` (your IP), `80`, `443` only
