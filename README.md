# donish_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Deploying the backend to Vercel

The API lives in the `backend/` folder. To avoid 404 on deployment:

1. In the **Vercel** project → **Settings** → **General**, set **Root Directory** to `backend`.
2. Save and **redeploy** so the Express app is built and served.
3. Add environment variables (e.g. `JWT_SECRET`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `OPENAI_API_KEY`, `TELEGRAM_BOT_TOKEN`) in **Settings** → **Environment Variables**.
4. For serverless Telegram bot delivery (no terminal process), set:
   - `TELEGRAM_WEBHOOK_SECRET` (random 16+ chars)
   - `BOT_WEBHOOK_SETUP_SECRET` (random 16+ chars, used only to call setup endpoint)
   - `APP_BASE_URL` (your backend base URL, e.g. `https://donish-edu.vercel.app`)
5. After deploy, register Telegram webhook once:
   - `POST https://<your-backend-domain>/bot/setup-webhook`
   - Header: `X-Setup-Secret: <BOT_WEBHOOK_SETUP_SECRET>`
   - This call sets Telegram webhook to `https://<your-backend-domain>/bot/webhook`
     and sets Telegram `secret_token` automatically to `TELEGRAM_WEBHOOK_SECRET`.
