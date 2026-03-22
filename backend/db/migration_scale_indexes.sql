-- Speed up per-user lists at scale (run on Supabase SQL editor or psql).
create index if not exists idx_materials_user_created_at
  on materials (user_id, created_at desc);

create index if not exists idx_vocabulary_entries_user_created
  on vocabulary_entries (user_id, created_at desc);
