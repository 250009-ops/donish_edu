-- Run once on existing databases. Flashcard Easy/Hard toggles mastery for stats only (not quiz bar).
alter table practice_stats
  add column if not exists flashcard_mastered boolean not null default false;
