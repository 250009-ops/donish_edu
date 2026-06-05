/**
 * Import supabase-export.json into PostgreSQL (DATABASE_URL).
 */
import dotenv from "dotenv";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import pg from "pg";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, "..", ".env") });

const connectionString = process.env.DATABASE_URL?.trim();
if (!connectionString) {
  console.error("DATABASE_URL is required.");
  process.exit(1);
}

const dumpPath = path.join(__dirname, "..", "data", "supabase-export.json");
const raw = await readFile(dumpPath, "utf8");
const dump = JSON.parse(raw);

const client = new pg.Client({ connectionString });
await client.connect();

const importers = [
  {
    table: "users",
    sql: `insert into users (id, username, password_hash, telegram_id, created_at)
          values ($1,$2,$3,$4,$5)
          on conflict (id) do update set
            username=excluded.username,
            password_hash=excluded.password_hash,
            telegram_id=excluded.telegram_id`
  },
  {
    table: "materials",
    sql: `insert into materials (id, user_id, title, file_path, page_count, material_type, english_level, content_text, created_at)
          values ($1,$2,$3,$4,$5,$6,$7,$8,$9)
          on conflict (id) do nothing`
  },
  {
    table: "vocabulary_entries",
    sql: `insert into vocabulary_entries (id, user_id, material_id, word, context_sentence, translation_uz, translation_base_uz, local_date, saved_for_practice, notes, created_at)
          values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
          on conflict (id) do nothing`
  },
  {
    table: "practice_stats",
    sql: `insert into practice_stats (id, user_id, vocab_id, last_seen_at, success_count, failure_count, ease_factor, ui_progress, flashcard_mastered)
          values ($1,$2,$3,$4,$5,$6,$7,$8,$9)
          on conflict (id) do nothing`
  },
  {
    table: "user_word_cache",
    sql: `insert into user_word_cache (user_id, word, translation_base_uz, translation_context_uz, saved_for_practice, updated_at)
          values ($1,$2,$3,$4,$5,$6)
          on conflict (user_id, word) do update set
            translation_base_uz=excluded.translation_base_uz,
            translation_context_uz=excluded.translation_context_uz,
            saved_for_practice=excluded.saved_for_practice,
            updated_at=excluded.updated_at`
  },
  {
    table: "telegram_bot_sessions",
    sql: `insert into telegram_bot_sessions (telegram_id, step, updated_at)
          values ($1,$2,$3)
          on conflict (telegram_id) do update set
            step=excluded.step,
            updated_at=excluded.updated_at`
  }
];

const rowValues = {
  users: (r) => [r.id, r.username, r.password_hash, r.telegram_id, r.created_at],
  materials: (r) => [
    r.id,
    r.user_id,
    r.title,
    r.file_path,
    r.page_count,
    r.material_type,
    r.english_level,
    r.content_text,
    r.created_at
  ],
  vocabulary_entries: (r) => [
    r.id,
    r.user_id,
    r.material_id,
    r.word,
    r.context_sentence,
    r.translation_uz,
    r.translation_base_uz,
    r.local_date,
    r.saved_for_practice,
    r.notes,
    r.created_at
  ],
  practice_stats: (r) => [
    r.id,
    r.user_id,
    r.vocab_id,
    r.last_seen_at,
    r.success_count,
    r.failure_count,
    r.ease_factor,
    r.ui_progress,
    r.flashcard_mastered
  ],
  user_word_cache: (r) => [
    r.user_id,
    r.word,
    r.translation_base_uz,
    r.translation_context_uz,
    r.saved_for_practice,
    r.updated_at
  ],
  telegram_bot_sessions: (r) => [r.telegram_id, r.step, r.updated_at]
};

try {
  await client.query("begin");
  for (const { table, sql } of importers) {
    const rows = dump[table] || [];
    for (const row of rows) {
      await client.query(sql, rowValues[table](row));
    }
    console.log(`${table}: ${rows.length} rows`);
  }
  await client.query("commit");
  console.log("Import finished.");
} catch (err) {
  await client.query("rollback");
  console.error("Import failed:", err);
  process.exitCode = 1;
} finally {
  await client.end();
}
