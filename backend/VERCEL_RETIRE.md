# Retire Vercel (manual — dashboard)

The codebase no longer includes `vercel.json`. Production is **https://api.donish.live** on EC2.

## Before you disable Vercel

1. EC2 health: `https://api.donish.live/health` returns `ok`
2. On EC2, from `backend/`:
   ```bash
   git pull
   npm ci
   npm run webhook:set
   npm run webhook:info
   ```
   Confirm webhook `url` is `https://api.donish.live/bot/telegram-webhook` (not `donish-edu.vercel.app`)
3. Test the Telegram bot (`/start`) and the Flutter app login

## Disable Vercel

1. Open [vercel.com](https://vercel.com) → project **donish-edu** (or your project name)
2. **Settings** → scroll to **Delete Project** (or remove the production domain and pause deployments)
3. Optional: remove Vercel Git integration so pushes no longer deploy there

After deletion, `https://donish-edu.vercel.app` should stop responding. If the bot still misbehaves, run `npm run webhook:set` again on EC2.
