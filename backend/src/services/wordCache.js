import { supabaseAdmin } from "../supabaseClient.js";

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

  const { error: byDate } = await supabaseAdmin
    .from("vocabulary_entries")
    .delete()
    .eq("user_id", userId)
    .lt("local_date", cutoff);

  if (byDate) return byDate;

  const { error: legacy } = await supabaseAdmin
    .from("vocabulary_entries")
    .delete()
    .eq("user_id", userId)
    .is("local_date", null)
    .lt("created_at", cutoffIso);

  if (legacy) return legacy;

  const { error: lexErr } = await supabaseAdmin
    .from("user_word_cache")
    .delete()
    .eq("user_id", userId)
    .lt("updated_at", cutoffIso);

  return lexErr;
}

export async function getUserWordCache(userId, word) {
  const { data, error } = await supabaseAdmin
    .from("user_word_cache")
    .select("*")
    .eq("user_id", userId)
    .eq("word", word)
    .maybeSingle();
  if (error) return { error, row: null };
  return { error: null, row: data };
}

export async function upsertUserWordCache(userId, {
  word,
  translationBaseUz,
  translationContextUz,
  savedForPractice
}) {
  const payload = {
    user_id: userId,
    word,
    translation_base_uz: translationBaseUz,
    translation_context_uz: translationContextUz || null,
    updated_at: new Date().toISOString()
  };
  if (typeof savedForPractice === "boolean") {
    payload.saved_for_practice = savedForPractice;
  }

  const { data, error } = await supabaseAdmin
    .from("user_word_cache")
    .upsert(payload, { onConflict: "user_id,word" })
    .select("*")
    .single();

  return { error, row: data };
}

export async function listUserLexicon(userId) {
  const cutoff = retentionCutoffLocalDate();
  const { data, error } = await supabaseAdmin
    .from("user_word_cache")
    .select("word, translation_base_uz, saved_for_practice, updated_at")
    .eq("user_id", userId)
    .gte("updated_at", new Date(`${cutoff}T00:00:00.000Z`).toISOString())
    .order("word", { ascending: true });

  if (error) return { error, rows: [] };
  return { error: null, rows: data || [] };
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
  const { data: existing, error: findErr } = await supabaseAdmin
    .from("vocabulary_entries")
    .select("id, saved_for_practice")
    .eq("user_id", userId)
    .eq("word", word)
    .eq("local_date", localDate)
    .limit(1);

  if (findErr) return { error: findErr, entry: null };

  const row = existing?.[0];
  const keepSaved =
    savedForPractice === true || row?.saved_for_practice === true;

  if (row) {
    const { data, error } = await supabaseAdmin
      .from("vocabulary_entries")
      .update({
        translation_uz: translationBaseUz,
        translation_base_uz: translationBaseUz,
        context_sentence: contextSentence || "",
        material_id: materialId || null,
        saved_for_practice: keepSaved
      })
      .eq("id", row.id)
      .select("*")
      .single();
    return { error, entry: data };
  }

  const { data, error } = await supabaseAdmin
    .from("vocabulary_entries")
    .insert({
      user_id: userId,
      word,
      local_date: localDate,
      translation_uz: translationBaseUz,
      translation_base_uz: translationBaseUz,
      context_sentence: contextSentence || "",
      material_id: materialId || null,
      saved_for_practice: keepSaved === true
    })
    .select("*")
    .single();

  return { error, entry: data };
}

export async function listDistinctLocalDates(userId) {
  const cutoff = retentionCutoffLocalDate();
  const { data, error } = await supabaseAdmin
    .from("vocabulary_entries")
    .select("local_date")
    .eq("user_id", userId)
    .gte("local_date", cutoff)
    .not("local_date", "is", null)
    .order("local_date", { ascending: false });

  if (error) return { error, dates: [] };

  const seen = new Set();
  const dates = [];
  for (const row of data || []) {
    const d = row.local_date;
    if (!d || seen.has(d)) continue;
    seen.add(d);
    dates.push(d);
  }
  return { error: null, dates };
}

export async function listEntriesForLocalDate(userId, localDate) {
  const { data, error } = await supabaseAdmin
    .from("vocabulary_entries")
    .select("*")
    .eq("user_id", userId)
    .eq("local_date", localDate)
    .order("created_at", { ascending: false });

  if (error) return { error, entries: [] };
  return { error: null, entries: data || [] };
}
