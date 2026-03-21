-- Run once on existing databases (Supabase SQL editor or psql).
alter table practice_stats
  add column if not exists ui_progress double precision;
