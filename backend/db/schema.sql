create table if not exists users (
  id uuid primary key default gen_random_uuid(),
  username text not null unique,
  password_hash text not null,
  telegram_id bigint not null unique,
  created_at timestamptz not null default now()
);

create table if not exists materials (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  title text not null,
  file_path text not null,
  page_count integer,
  created_at timestamptz not null default now()
);

create table if not exists vocabulary_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  material_id uuid references materials(id) on delete set null,
  word text not null,
  context_sentence text,
  translation_uz text not null,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists practice_stats (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  vocab_id uuid not null references vocabulary_entries(id) on delete cascade,
  last_seen_at timestamptz,
  success_count integer not null default 0,
  failure_count integer not null default 0,
  ease_factor double precision
);

