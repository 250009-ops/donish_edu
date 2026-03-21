-- Run once on existing Supabase projects (skip if columns already exist).
alter table materials add column if not exists material_type text;
alter table materials add column if not exists english_level text;
alter table materials add column if not exists content_text text;
