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
| `AWS_REGION` | Same region as EC2 / S3 (e.g. `us-east-1`) |
| `TEXTRACT_S3_BUCKET` | Private bucket for temporary PDFs (see below) |
| `TELEGRAM_BOT_TOKEN` | Bot + webhook |

**Textract (required):** All PDF text extraction uses Amazon Textract. On EC2, attach an IAM role (preferred) or set `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` with:

- `textract:StartDocumentTextDetection`, `textract:GetDocumentTextDetection`
- `s3:PutObject`, `s3:DeleteObject` on `TEXTRACT_S3_BUCKET` (prefix `textract-uploads/`)

Create a private S3 bucket in **eu-west-1** (Textract is not available in eu-north-1). Example: `donish-textract-uploads-eu-west-1`. Optional lifecycle rule to expire `textract-uploads/` after 1 day.

Optional: `TELEGRAM_WEBHOOK_SECRET` (recommended).

Do **not** set `VERCEL` or `VERCEL_URL` on EC2.

## First deploy / update

```bash
cd ~/donish_edu/backend   # or your clone path
git pull
npm ci                    # installs @aws-sdk/client-textract + client-s3 (required)
pm2 restart donish-api    # or your PM2 app name
pm2 save
```

Add to `backend/.env` on the server: `AWS_REGION`, `TEXTRACT_S3_BUCKET`, and IAM credentials (instance role recommended).

### Vocabulary / word-cache migration (required once)

After deploying backend commit `62c29f6` or later, run **`db/migration_word_cache_calendar.sql`** in the **Supabase SQL Editor** (creates `user_word_cache`, adds `local_date` on `vocabulary_entries`). Without this, `/vocab/days` and `/vocab/lexicon` return 500 and the app Vocabulary tab looks empty.

From Windows (project root): `.\deploy_backend_ec2.ps1` — pulls code on EC2 and restarts PM2. SSH must reach port 22; migration is still manual in Supabase.

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
