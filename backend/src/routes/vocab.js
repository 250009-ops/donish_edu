import express from "express";
import { query } from "../db/pool.js";
import {
  requireAuth,
  requireRegisteredDevice
} from "../middlewares/authMiddleware.js";
import { authenticatedApiLimiter } from "../middlewares/rateLimits.js";
import {
  isValidLocalDate,
  listDistinctLocalDates,
  listEntriesForLocalDate,
  listUserLexicon,
  normalizeWord,
  pruneOlderThanRetention,
  recordTapForLocalDate,
  upsertUserWordCache
} from "../services/wordCache.js";

export const vocabRouter = express.Router();

vocabRouter.use(requireAuth);
vocabRouter.use(requireRegisteredDevice);
vocabRouter.use(authenticatedApiLimiter);

const QUIZ_PROGRESS_STEP = 0.25;

function parseDayWindow(req) {
  const dayStart = req.query.dayStart;
  const dayEnd = req.query.dayEnd;
  if (!dayStart || !dayEnd) {
    return {
      error: "dayStart and dayEnd query parameters are required (ISO 8601)."
    };
  }
  const startMs = Date.parse(dayStart);
  const endMs = Date.parse(dayEnd);
  if (Number.isNaN(startMs) || Number.isNaN(endMs)) {
    return { error: "Invalid dayStart or dayEnd." };
  }
  if (endMs <= startMs) {
    return { error: "dayEnd must be after dayStart." };
  }
  const startIso = new Date(startMs).toISOString();
  const endIso = new Date(endMs).toISOString();
  return { startIso, endIso };
}

function clamp01(x) {
  return Math.min(1, Math.max(0, x));
}

function quizProgressFromAggregated(agg) {
  if (!agg || agg.ui_progress == null || !Number.isFinite(Number(agg.ui_progress))) {
    return 0;
  }
  return clamp01(Number(agg.ui_progress));
}

function masteredFromAggregated(agg) {
  return !!agg?.flashcard_mastered;
}

function displayQuizProgressFromRow(row) {
  if (!row || row.ui_progress == null || !Number.isFinite(Number(row.ui_progress))) {
    return 0;
  }
  return clamp01(Number(row.ui_progress));
}

function aggregateStatsByVocabId(rows) {
  const map = {};
  for (const r of rows || []) {
    const vid = r.vocab_id;
    if (!map[vid]) {
      map[vid] = {
        success_count: 0,
        failure_count: 0,
        ui_progress: null,
        flashcard_mastered: false
      };
    }
    map[vid].success_count += Number(r.success_count) || 0;
    map[vid].failure_count += Number(r.failure_count) || 0;
    if (r.ui_progress != null && Number.isFinite(Number(r.ui_progress))) {
      map[vid].ui_progress = Number(r.ui_progress);
    }
    map[vid].flashcard_mastered =
      map[vid].flashcard_mastered || r.flashcard_mastered === true;
  }
  return map;
}

function displayTagForEntry(entry, lexiconSaved) {
  if (entry.saved_for_practice === true || lexiconSaved) {
    return "Saved";
  }
  return "Tapped";
}

async function enrichEntries(userId, entries) {
  const ids = entries.map((e) => e.id);
  let statsByVocab = {};
  if (ids.length > 0) {
    try {
      const { rows: statsRows } = await query(
        `select vocab_id, success_count, failure_count, ui_progress, flashcard_mastered
         from practice_stats
         where user_id = $1::uuid and vocab_id = any($2::uuid[])`,
        [userId, ids]
      );
      statsByVocab = aggregateStatsByVocabId(statsRows);
    } catch (statsErr) {
      // eslint-disable-next-line no-console
      console.error("enrichEntries stats:", statsErr);
    }
  }

  const words = [...new Set(entries.map((e) => e.word))];
  let lexiconByWord = {};
  if (words.length > 0) {
    try {
      const { rows: lexRows } = await query(
        `select word, saved_for_practice from user_word_cache
         where user_id = $1::uuid and word = any($2::text[])`,
        [userId, words]
      );
      for (const row of lexRows) {
        lexiconByWord[row.word] = row;
      }
    } catch {
      lexiconByWord = {};
    }
  }

  return entries.map((e) => {
    const agg = statsByVocab[e.id];
    const lex = lexiconByWord[e.word];
    return {
      ...e,
      translation_uz: e.translation_base_uz || e.translation_uz,
      progress: quizProgressFromAggregated(agg),
      flashcard_mastered: masteredFromAggregated(agg),
      saved_for_practice:
        e.saved_for_practice === true || lex?.saved_for_practice === true,
      display_tag: displayTagForEntry(e, lex?.saved_for_practice === true)
    };
  });
}

vocabRouter.get("/days", async (req, res) => {
  const userId = req.user.id;
  const pruneErr = await pruneOlderThanRetention(userId);
  if (pruneErr) {
    // eslint-disable-next-line no-console
    console.error("GET /vocab/days prune error:", pruneErr);
  }

  const { dates, error } = await listDistinctLocalDates(userId);
  if (error) {
    // eslint-disable-next-line no-console
    console.error("GET /vocab/days error:", error);
    return res.status(500).json({ error: "Failed to load vocabulary days." });
  }

  try {
    const { rows } = await query(
      `select created_at from users where id = $1::uuid`,
      [userId]
    );
    return res.json({
      dates,
      member_since: rows[0]?.created_at ?? null
    });
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error("GET /vocab/days user:", error);
    return res.json({ dates, member_since: null });
  }
});

vocabRouter.get("/lexicon", async (req, res) => {
  const userId = req.user.id;
  const pruneErr = await pruneOlderThanRetention(userId);
  if (pruneErr) {
    // eslint-disable-next-line no-console
    console.error("GET /vocab/lexicon prune error:", pruneErr);
  }

  const { rows, error } = await listUserLexicon(userId);
  if (error) {
    // eslint-disable-next-line no-console
    console.error("GET /vocab/lexicon error:", error);
    return res.status(500).json({ error: "Failed to load word lexicon." });
  }

  const words = rows.map((r) => ({
    word: r.word,
    translation_base_uz: r.translation_base_uz,
    saved_for_practice: r.saved_for_practice === true
  }));

  return res.json({ words });
});

vocabRouter.get("/", async (req, res) => {
  const localDate = req.query.localDate;
  const userId = req.user.id;

  const pruneErr = await pruneOlderThanRetention(userId);
  if (pruneErr) {
    // eslint-disable-next-line no-console
    console.error("GET /vocab prune error:", pruneErr);
    return res.status(500).json({ error: "Failed to prune old vocabulary." });
  }

  if (localDate) {
    if (!isValidLocalDate(localDate)) {
      return res.status(400).json({ error: "Invalid localDate (YYYY-MM-DD)." });
    }

    const { entries, error } = await listEntriesForLocalDate(userId, localDate);
    if (error) {
      // eslint-disable-next-line no-console
      console.error("GET /vocab error:", error);
      return res.status(500).json({ error: "Failed to load vocabulary entries." });
    }

    const enriched = await enrichEntries(userId, entries);
    return res.json(enriched);
  }

  const parsed = parseDayWindow(req);
  if (parsed.error) {
    return res.status(400).json({
      error:
        "localDate (YYYY-MM-DD) or dayStart+dayEnd query parameters are required."
    });
  }
  const { startIso, endIso } = parsed;

  try {
    const { rows } = await query(
      `select * from vocabulary_entries
       where user_id = $1::uuid
         and created_at >= $2::timestamptz
         and created_at < $3::timestamptz
       order by created_at desc`,
      [userId, startIso, endIso]
    );
    const enriched = await enrichEntries(userId, rows);
    return res.json(enriched);
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error("GET /vocab error:", error);
    return res.status(500).json({ error: "Failed to load vocabulary entries." });
  }
});

vocabRouter.post("/", async (req, res) => {
  const {
    word,
    translation_uz,
    context_sentence,
    material_id,
    notes,
    local_date: localDate
  } = req.body || {};

  if (!word || !translation_uz) {
    return res
      .status(400)
      .json({ error: "word and translation_uz are required." });
  }

  if (!localDate || !isValidLocalDate(localDate)) {
    return res.status(400).json({
      error: "local_date is required (YYYY-MM-DD, device local calendar day)."
    });
  }

  const userId = req.user.id;
  const normalizedWord = normalizeWord(word);
  const base = String(translation_uz).trim();

  const { error: cacheErr } = await upsertUserWordCache(userId, {
    word: normalizedWord,
    translationBaseUz: base,
    translationContextUz: null,
    savedForPractice: true
  });
  if (cacheErr) {
    // eslint-disable-next-line no-console
    console.error("POST /vocab cache upsert:", cacheErr);
    return res.status(500).json({ error: "Failed to update word cache." });
  }

  const { entry, error } = await recordTapForLocalDate(userId, {
    word: normalizedWord,
    localDate,
    translationBaseUz: base,
    contextSentence: context_sentence || "",
    materialId: material_id || null,
    savedForPractice: true
  });

  if (error) {
    // eslint-disable-next-line no-console
    console.error("POST /vocab error:", error);
    return res.status(500).json({ error: "Failed to save vocabulary entry." });
  }

  if (notes) {
    try {
      await query(`update vocabulary_entries set notes = $2 where id = $1::uuid`, [
        entry.id,
        notes
      ]);
    } catch (noteErr) {
      // eslint-disable-next-line no-console
      console.error("POST /vocab notes:", noteErr);
    }
  }

  return res.status(201).json({
    ...entry,
    saved_for_practice: true,
    display_tag: "Saved"
  });
});

const PRACTICE_ACTIONS = new Set([
  "quiz_correct",
  "quiz_incorrect",
  "flashcard_easy",
  "flashcard_hard"
]);

vocabRouter.post("/practice", async (req, res) => {
  const { vocab_id: vocabId, action } = req.body || {};

  if (!vocabId || typeof vocabId !== "string") {
    return res.status(400).json({ error: "vocab_id is required." });
  }
  if (!action || !PRACTICE_ACTIONS.has(action)) {
    return res.status(400).json({
      error:
        "action must be one of: quiz_correct, quiz_incorrect, flashcard_easy, flashcard_hard."
    });
  }

  const userId = req.user.id;

  try {
    const { rows: entryRows } = await query(
      `select id from vocabulary_entries
       where id = $1::uuid and user_id = $2::uuid`,
      [vocabId, userId]
    );
    if (!entryRows[0]) {
      return res.status(404).json({ error: "Vocabulary entry not found." });
    }

    const { rows: existingRows } = await query(
      `select id, success_count, failure_count, ui_progress, flashcard_mastered
       from practice_stats
       where user_id = $1::uuid and vocab_id = $2::uuid
       limit 1`,
      [userId, vocabId]
    );

    const existing = existingRows[0];
    const nowIso = new Date().toISOString();

    let nextSc = existing?.success_count ?? 0;
    let nextFc = existing?.failure_count ?? 0;
    let nextUi = existing?.ui_progress ?? null;
    let nextMastered = existing?.flashcard_mastered === true;

    if (action === "quiz_correct" || action === "quiz_incorrect") {
      const current = displayQuizProgressFromRow(existing);
      const stepped =
        action === "quiz_correct"
          ? clamp01(current + QUIZ_PROGRESS_STEP)
          : clamp01(current - QUIZ_PROGRESS_STEP);
      nextUi = stepped;
    } else if (action === "flashcard_easy") {
      nextMastered = true;
    } else if (action === "flashcard_hard") {
      nextMastered = false;
    }

    if (existing) {
      await query(
        `update practice_stats set
           success_count = $3,
           failure_count = $4,
           last_seen_at = $5::timestamptz,
           ui_progress = $6,
           flashcard_mastered = $7
         where id = $1::uuid`,
        [existing.id, userId, nextSc, nextFc, nowIso, nextUi, nextMastered]
      );
    } else {
      await query(
        `insert into practice_stats (
           user_id, vocab_id, success_count, failure_count,
           last_seen_at, ui_progress, flashcard_mastered
         ) values ($1::uuid, $2::uuid, $3, $4, $5::timestamptz, $6, $7)`,
        [userId, vocabId, nextSc, nextFc, nowIso, nextUi, nextMastered]
      );
    }

    const progress = quizProgressFromAggregated({
      ui_progress: nextUi,
      flashcard_mastered: nextMastered
    });

    return res.json({
      vocab_id: vocabId,
      success_count: nextSc,
      failure_count: nextFc,
      progress,
      flashcard_mastered: nextMastered
    });
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error("POST /vocab/practice:", error);
    return res.status(500).json({ error: "Failed to update practice stats." });
  }
});

vocabRouter.get("/stats", async (req, res) => {
  const localDate = req.query.localDate;
  const userId = req.user.id;

  const pruneErr = await pruneOlderThanRetention(userId);
  if (pruneErr) {
    // eslint-disable-next-line no-console
    console.error("GET /vocab/stats prune error:", pruneErr);
    return res.status(500).json({ error: "Failed to prune old vocabulary." });
  }

  let entries = [];
  if (localDate) {
    if (!isValidLocalDate(localDate)) {
      return res.status(400).json({ error: "Invalid localDate (YYYY-MM-DD)." });
    }
    const result = await listEntriesForLocalDate(userId, localDate);
    if (result.error) {
      return res.status(500).json({ error: "Failed to load vocab stats." });
    }
    entries = result.entries;
  } else {
    const parsed = parseDayWindow(req);
    if (parsed.error) {
      return res.status(400).json({ error: parsed.error });
    }
    const { startIso, endIso } = parsed;
    try {
      const { rows } = await query(
        `select id from vocabulary_entries
         where user_id = $1::uuid
           and created_at >= $2::timestamptz
           and created_at < $3::timestamptz`,
        [userId, startIso, endIso]
      );
      entries = rows;
    } catch (error) {
      return res.status(500).json({ error: "Failed to load vocab stats." });
    }
  }

  const ids = entries.map((e) => e.id);
  let statsByVocab = {};
  if (ids.length > 0) {
    try {
      const { rows: statsRows } = await query(
        `select vocab_id, success_count, failure_count, ui_progress, flashcard_mastered
         from practice_stats
         where user_id = $1::uuid and vocab_id = any($2::uuid[])`,
        [userId, ids]
      );
      statsByVocab = aggregateStatsByVocabId(statsRows);
    } catch {
      statsByVocab = {};
    }
  }

  const total = entries.length;
  let mastered = 0;
  for (const e of entries) {
    if (masteredFromAggregated(statsByVocab[e.id])) mastered += 1;
  }
  const learning = total - mastered;
  const masteryPercent = total === 0 ? 0 : mastered / total;

  return res.json({
    totalWords: total,
    masteredCount: mastered,
    learningCount: learning,
    masteryPercent
  });
});
