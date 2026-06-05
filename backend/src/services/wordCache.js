import { query } from "../db/pool.js";

export const RETENTION_DAYS = 90;

export function normalizeWord(input) {
  return String(input || "")
    .trim()
    .toLowerCase()
    .replace(/^[^a-zA-Z'’-]+|[^a-zA-Z'’-]+$/g, "")
    .replace(/\s+/g, " ");
}

/** @param {string} localDate YYYY-MM-DD */
export function isValidLocalDate(localDate) {
  return /^\d{4}-\d{2}-\d{2}$/.test(String(localDate || ""));
}

export function retentionCutoffLocalDate() {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() - RETENTION_DAYS);
  return d.toISOString().slice(0, 10);
}

export async function pruneOlderThanRetention(userId) {
  const cutoff = retentionCutoffLocalDate();
  const cutoffIso = new Date(`${cutoff}T00:00:00.000Z`).toISOString();

  try {
    await query(
      `delete from vocabulary_entries
       where user_id = $1::uuid and local_date < $2::date`,
      [userId, cutoff]
    );
    await query(
      `delete from vocabulary_entries
       where user_id = $1::uuid and local_date is null and created_at < $2::timestamptz`,
      [userId, cutoffIso]
    );
    await query(
      `delete from user_word_cache
       where user_id = $1::uuid and updated_at < $2::timestamptz`,
      [userId, cutoffIso]
    );
    return null;
  } catch (err) {
    return err;
  }
}

export async function getUserWordCache(userId, word) {
  try {
    const { rows } = await query(
      `select * from user_word_cache where user_id = $1::uuid and word = $2`,
      [userId, word]
    );
    return { error: null, row: rows[0] || null };
  } catch (error) {
    return { error, row: null };
  }
}

export async function upsertUserWordCache(userId, {
  word,
  translationBaseUz,
  translationContextUz,
  savedForPractice
}) {
  try {
    const saveFlag =
      typeof savedForPractice === "boolean" ? savedForPractice : false;
    const { rows } = await query(
      `insert into user_word_cache (
         user_id, word, translation_base_uz, translation_context_uz,
         saved_for_practice, updated_at
       ) values ($1::uuid, $2, $3, $4, $5, now())
       on conflict (user_id, word) do update set
         translation_base_uz = excluded.translation_base_uz,
         translation_context_uz = excluded.translation_context_uz,
         saved_for_practice = case
           when $6::boolean then excluded.saved_for_practice
           else user_word_cache.saved_for_practice
         end,
         updated_at = now()
       returning *`,
      [
        userId,
        word,
        translationBaseUz,
        translationContextUz || null,
        saveFlag,
        typeof savedForPractice === "boolean"
      ]
    );
    return { error: null, row: rows[0] };
  } catch (error) {
    return { error, row: null };
  }
}

export async function listUserLexicon(userId) {
  const cutoff = retentionCutoffLocalDate();
  const cutoffIso = new Date(`${cutoff}T00:00:00.000Z`).toISOString();
  try {
    const { rows } = await query(
      `select word, translation_base_uz, saved_for_practice, updated_at
       from user_word_cache
       where user_id = $1::uuid and updated_at >= $2::timestamptz
       order by word asc`,
      [userId, cutoffIso]
    );
    return { error: null, rows };
  } catch (error) {
    return { error, rows: [] };
  }
}

export async function recordTapForLocalDate(
  userId,
  {
    word,
    localDate,
    translationBaseUz,
    contextSentence,
    materialId,
    savedForPractice
  }
) {
  try {
    const { rows: existing } = await query(
      `select id, saved_for_practice from vocabulary_entries
       where user_id = $1::uuid and word = $2 and local_date = $3::date
       limit 1`,
      [userId, word, localDate]
    );

    const row = existing[0];
    const keepSaved =
      savedForPractice === true || row?.saved_for_practice === true;

    if (row) {
      const { rows } = await query(
        `update vocabulary_entries set
           translation_uz = $2,
           translation_base_uz = $2,
           context_sentence = $3,
           material_id = $4::uuid,
           saved_for_practice = $5
         where id = $1::uuid
         returning *`,
        [
          row.id,
          translationBaseUz,
          contextSentence || "",
          materialId || null,
          keepSaved
        ]
      );
      return { error: null, entry: rows[0] };
    }

    const { rows } = await query(
      `insert into vocabulary_entries (
         user_id, word, local_date, translation_uz, translation_base_uz,
         context_sentence, material_id, saved_for_practice
       ) values ($1::uuid, $2, $3::date, $4, $4, $5, $6::uuid, $7)
       returning *`,
      [
        userId,
        word,
        localDate,
        translationBaseUz,
        contextSentence || "",
        materialId || null,
        savedForPractice === true
      ]
    );
    return { error: null, entry: rows[0] };
  } catch (error) {
    return { error, entry: null };
  }
}

export async function listDistinctLocalDates(userId) {
  const cutoff = retentionCutoffLocalDate();
  try {
    const { rows } = await query(
      `select distinct local_date
       from vocabulary_entries
       where user_id = $1::uuid and local_date is not null and local_date >= $2::date
       order by local_date desc`,
      [userId, cutoff]
    );
    const dates = rows.map((r) => r.local_date).filter(Boolean);
    return { error: null, dates };
  } catch (error) {
    return { error, dates: [] };
  }
}

export async function listEntriesForLocalDate(userId, localDate) {
  try {
    const { rows } = await query(
      `select * from vocabulary_entries
       where user_id = $1::uuid and local_date = $2::date
       order by created_at desc`,
      [userId, localDate]
    );
    return { error: null, entries: rows };
  } catch (error) {
    return { error, entries: [] };
  }
}
