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

## Backend API (EC2)

The API lives in `backend/` and runs on **https://api.donish.live** (AWS EC2 + nginx + PM2).

See **[backend/DEPLOY.md](backend/DEPLOY.md)** for environment variables, deploy steps, and Telegram webhook setup.

### Database migration (word cache + calendar)

Run `backend/db/migration_word_cache_calendar.sql` on Supabase before deploying the new backend. It adds `user_word_cache`, `local_date`, and `saved_for_practice` columns.

After moving off Vercel, disable the old Vercel project so traffic and webhooks only hit EC2.
