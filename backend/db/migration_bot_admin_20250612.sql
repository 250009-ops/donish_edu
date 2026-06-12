-- Bot profile, app artifacts, support, admin panel, limits, usage tracking.

-- User profile (bot onboarding)
alter table users add column if not exists full_name text;
alter table users add column if not exists email text;
alter table users add column if not exists phone_e164 text;
alter table users add column if not exists language text not null default 'uz';
alter table users add column if not exists profile_completed_at timestamptz;
alter table users add column if not exists updated_at timestamptz not null default now();

create unique index if not exists users_email_unique
  on users (lower(email)) where email is not null;
create index if not exists users_phone_idx on users (phone_e164);

-- Bot session state (partial onboarding + language)
alter table telegram_bot_sessions add column if not exists data jsonb not null default '{}'::jsonb;
alter table telegram_bot_sessions add column if not exists language text;

-- App delivery (Android file_id / iOS store_url)
create table if not exists app_artifacts (
  id              bigserial primary key,
  platform        text not null,
  version_name    text,
  file_id         text,
  file_unique_id  text,
  file_name       text,
  size_bytes      bigint,
  store_url       text,
  uploaded_by     bigint,
  is_current      boolean not null default false,
  created_at      timestamptz not null default now(),
  constraint app_artifacts_delivery_chk
    check ((file_id is not null) <> (store_url is not null))
);
create unique index if not exists app_artifacts_current_idx
  on app_artifacts (platform) where is_current;

-- Support / feedback (two-way chat)
create table if not exists support_messages (
  id           bigserial primary key,
  user_id      uuid references users(id) on delete set null,
  telegram_id  bigint not null,
  direction    text not null check (direction in ('in', 'out')),
  body         text not null,
  admin_id     bigint,
  read_at      timestamptz,
  created_at   timestamptz not null default now()
);
create index if not exists support_messages_user_idx
  on support_messages (telegram_id, created_at desc);
create index if not exists support_messages_unread_idx
  on support_messages (created_at desc) where direction = 'in' and read_at is null;

-- Bot analytics (optional)
create table if not exists bot_events (
  id          bigserial primary key,
  telegram_id bigint,
  event       text not null,
  meta        jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now()
);
create index if not exists bot_events_event_idx on bot_events (event, created_at desc);

-- Admin accounts
create table if not exists admin_users (
  id              bigserial primary key,
  email           text not null unique,
  password_hash   text not null,
  totp_secret     text,
  totp_enabled    boolean not null default false,
  role            text not null default 'support',
  is_active       boolean not null default true,
  failed_attempts integer not null default 0,
  locked_until    timestamptz,
  last_login_at   timestamptz,
  created_at      timestamptz not null default now()
);

create table if not exists admin_sessions (
  id           bigserial primary key,
  admin_id     bigint not null references admin_users(id) on delete cascade,
  refresh_hash text not null,
  user_agent   text,
  ip           text,
  revoked_at   timestamptz,
  expires_at   timestamptz not null,
  created_at   timestamptz not null default now()
);

create table if not exists admin_recovery_codes (
  id        bigserial primary key,
  admin_id  bigint not null references admin_users(id) on delete cascade,
  code_hash text not null,
  used_at   timestamptz
);

create table if not exists admin_audit_log (
  id         bigserial primary key,
  admin_id   bigint references admin_users(id) on delete set null,
  action     text not null,
  target     text,
  meta       jsonb not null default '{}'::jsonb,
  ip         text,
  created_at timestamptz not null default now()
);

-- Global OpenAI / plan limits (admin-editable)
create table if not exists usage_limits_global (
  id                            boolean primary key default true check (id),
  free_max_translate_total      integer not null default 5,
  premium_max_translate_per_day integer not null default 500,
  free_max_materials            integer not null default 1,
  max_devices_per_user          integer not null default 3,
  updated_by                    bigint,
  updated_at                    timestamptz not null default now()
);
insert into usage_limits_global (id) values (true) on conflict (id) do nothing;

-- Per-user limit overrides
create table if not exists user_limits (
  user_id                    uuid primary key references users(id) on delete cascade,
  translate_total_override     integer,
  translate_per_day_override   integer,
  materials_override           integer,
  max_devices_override         integer,
  is_blocked                   boolean not null default false,
  note                       text,
  updated_by                 bigint,
  updated_at                 timestamptz not null default now()
);

-- OpenAI usage events
create table if not exists openai_usage_events (
  id                bigserial primary key,
  user_id           uuid references users(id) on delete set null,
  action            text not null,
  model             text,
  prompt_tokens     integer,
  completion_tokens integer,
  total_tokens      integer,
  cost_usd          numeric(10, 5),
  created_at        timestamptz not null default now()
);
create index if not exists openai_usage_user_day_idx
  on openai_usage_events (user_id, created_at desc);
create index if not exists openai_usage_action_idx
  on openai_usage_events (action, created_at desc);

-- Broadcast jobs
create table if not exists broadcast_jobs (
  id           bigserial primary key,
  admin_id     bigint references admin_users(id) on delete set null,
  body         text not null,
  audience     text not null default 'all',
  status       text not null default 'pending',
  sent_count   integer not null default 0,
  failed_count integer not null default 0,
  total_count  integer not null default 0,
  created_at   timestamptz not null default now(),
  finished_at  timestamptz
);
