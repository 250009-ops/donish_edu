-- Per-user word lexicon (one row per word) + practice flag + 90-day retention support.

create table if not exists user_word_cache (
  user_id uuid not null references users(id) on delete cascade,
  word text not null,
  translation_base_uz text not null,
  translation_context_uz text,
  saved_for_practice boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (user_id, word)
);

create index if not exists idx_user_word_cache_user_updated
  on user_word_cache (user_id, updated_at desc);

alter table vocabulary_entries
  add column if not exists saved_for_practice boolean not null default false;

alter table vocabulary_entries
  add column if not exists translation_base_uz text;

-- Device-local calendar day (YYYY-MM-DD) supplied by the client on each tap.
alter table vocabulary_entries
  add column if not exists local_date date;

create index if not exists idx_vocabulary_entries_user_local_date
  on vocabulary_entries (user_id, local_date desc);

create index if not exists idx_vocabulary_entries_user_created
  on vocabulary_entries (user_id, created_at desc);
