-- Run this in Supabase SQL Editor (once) so the Telegram bot can remember
-- "awaiting password" across Vercel serverless invocations (webhook mode).

create table if not exists telegram_bot_sessions (
  telegram_id bigint primary key,
  step text not null default 'idle',
  updated_at timestamptz not null default now()
);

create index if not exists telegram_bot_sessions_updated_at_idx
  on telegram_bot_sessions (updated_at desc);
