-- Premium subscriptions (Lemon Squeezy) and per-account device sessions.

alter table users add column if not exists plan text not null default 'free';
alter table users add column if not exists subscription_status text;
alter table users add column if not exists lemon_subscription_id text;
alter table users add column if not exists lemon_customer_id text;
alter table users add column if not exists premium_until timestamptz;
alter table users add column if not exists subscription_renews_at timestamptz;

create table if not exists user_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  device_id text not null,
  device_label text,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (user_id, device_id)
);

create index if not exists user_devices_user_id_idx on user_devices(user_id);
create index if not exists user_devices_last_seen_idx on user_devices(user_id, last_seen_at desc);

create table if not exists usage_daily (
  user_id uuid not null references users(id) on delete cascade,
  local_date date not null,
  translate_count integer not null default 0,
  primary key (user_id, local_date)
);

create table if not exists subscription_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references users(id) on delete set null,
  lemon_event_name text not null,
  lemon_event_id text,
  payload jsonb,
  created_at timestamptz not null default now()
);

create unique index if not exists subscription_events_lemon_event_id_idx
  on subscription_events(lemon_event_id)
  where lemon_event_id is not null;
