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
