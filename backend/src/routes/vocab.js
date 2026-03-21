import express from "express";
import { supabaseAdmin } from "../supabaseClient.js";
import { requireAuth } from "../middlewares/authMiddleware.js";

export const vocabRouter = express.Router();

vocabRouter.use(requireAuth);

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

/** Per-word bar: quiz-only (ui_progress). No flashcard influence. */
function quizProgressFromAggregated(agg) {
  if (!agg || agg.ui_progress == null || !Number.isFinite(Number(agg.ui_progress))) {
    return 0;
  }
  return clamp01(Number(agg.ui_progress));
}

function masteredFromAggregated(agg) {
  return !!agg?.flashcard_mastered;
}

/** Quiz ladder from one practice_stats row (or null). */
function displayQuizProgressFromRow(row) {
  if (!row || row.ui_progress == null || !Number.isFinite(Number(row.ui_progress))) {
    return 0;
  }
  return clamp01(Number(row.ui_progress));
}

/** Merge duplicate practice_stats rows per vocab_id (same user). */
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

async function pruneEntriesBefore(userId, startIso) {
  const { error } = await supabaseAdmin
    .from("vocabulary_entries")
    .delete()
    .eq("user_id", userId)
    .lt("created_at", startIso);
  return error;
}

async function listEntriesInWindow(userId, startIso, endIso) {
  const { data, error } = await supabaseAdmin
    .from("vocabulary_entries")
    .select("*")
    .eq("user_id", userId)
    .gte("created_at", startIso)
    .lt("created_at", endIso)
    .order("created_at", { ascending: false });

  if (error) return { error, entries: [] };
  return { error: null, entries: data || [] };
}

vocabRouter.get("/", async (req, res) => {
  const parsed = parseDayWindow(req);
  if (parsed.error) {
    return res.status(400).json({ error: parsed.error });
  }
  const { startIso, endIso } = parsed;
  const userId = req.user.id;

  const delErr = await pruneEntriesBefore(userId, startIso);
  if (delErr) {
    // eslint-disable-next-line no-console
    console.error("GET /vocab prune error:", delErr);
    return res.status(500).json({ error: "Failed to prune old vocabulary." });
  }

  const { entries, error } = await listEntriesInWindow(userId, startIso, endIso);
  if (error) {
    // eslint-disable-next-line no-console
    console.error("GET /vocab error:", error);
    return res.status(500).json({ error: "Failed to load vocabulary entries." });
  }

  const ids = entries.map((e) => e.id);
  let statsByVocab = {};
  if (ids.length > 0) {
    const { data: statsRows, error: statsErr } = await supabaseAdmin
      .from("practice_stats")
      .select(
        "vocab_id, success_count, failure_count, ui_progress, flashcard_mastered"
      )
      .eq("user_id", userId)
      .in("vocab_id", ids);

    if (statsErr) {
      // eslint-disable-next-line no-console
      console.error("GET /vocab practice_stats error:", statsErr);
    } else {
      statsByVocab = aggregateStatsByVocabId(statsRows);
    }
  }

  const enriched = entries.map((e) => {
    const agg = statsByVocab[e.id];
    return {
      ...e,
      progress: quizProgressFromAggregated(agg),
      flashcard_mastered: masteredFromAggregated(agg),
      display_tag: "Saved"
    };
  });

  return res.json(enriched);
});

vocabRouter.post("/", async (req, res) => {
  const { word, translation_uz, context_sentence, material_id, notes } = req.body || {};

  if (!word || !translation_uz) {
    return res
      .status(400)
      .json({ error: "word and translation_uz are required." });
  }

  const { data, error } = await supabaseAdmin
    .from("vocabulary_entries")
    .insert({
      user_id: req.user.id,
      word,
      translation_uz,
      context_sentence: context_sentence || "",
      material_id: material_id || null,
      notes: notes || null
    })
    .select("*")
    .single();

  if (error) {
    // eslint-disable-next-line no-console
    console.error("POST /vocab error:", error);
    return res.status(500).json({ error: "Failed to save vocabulary entry." });
  }

  return res.status(201).json(data);
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

  const { data: entry, error: entryErr } = await supabaseAdmin
    .from("vocabulary_entries")
    .select("id")
    .eq("id", vocabId)
    .eq("user_id", userId)
    .maybeSingle();

  if (entryErr) {
    // eslint-disable-next-line no-console
    console.error("POST /vocab/practice entry lookup:", entryErr);
    return res.status(500).json({ error: "Failed to verify vocabulary entry." });
  }
  if (!entry) {
    return res.status(404).json({ error: "Vocabulary entry not found." });
  }

  const { data: existingRows, error: findErr } = await supabaseAdmin
    .from("practice_stats")
    .select(
      "id, success_count, failure_count, ui_progress, flashcard_mastered"
    )
    .eq("user_id", userId)
    .eq("vocab_id", vocabId)
    .limit(1);

  if (findErr) {
    // eslint-disable-next-line no-console
    console.error("POST /vocab/practice find stats:", findErr);
    return res.status(500).json({ error: "Failed to load practice stats." });
  }

  const existing = existingRows?.[0];
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

  const payload = {
    success_count: nextSc,
    failure_count: nextFc,
    last_seen_at: nowIso,
    ui_progress: nextUi,
    flashcard_mastered: nextMastered
  };

  if (existing) {
    const { error: upErr } = await supabaseAdmin
      .from("practice_stats")
      .update(payload)
      .eq("id", existing.id);

    if (upErr) {
      // eslint-disable-next-line no-console
      console.error("POST /vocab/practice update:", upErr);
      return res.status(500).json({ error: "Failed to update practice stats." });
    }
  } else {
    const { error: insErr } = await supabaseAdmin.from("practice_stats").insert({
      user_id: userId,
      vocab_id: vocabId,
      ...payload
    });

    if (insErr) {
      // eslint-disable-next-line no-console
      console.error("POST /vocab/practice insert:", insErr);
      return res.status(500).json({ error: "Failed to save practice stats." });
    }
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
});

vocabRouter.get("/stats", async (req, res) => {
  const parsed = parseDayWindow(req);
  if (parsed.error) {
    return res.status(400).json({ error: parsed.error });
  }
  const { startIso, endIso } = parsed;
  const userId = req.user.id;

  const delErr = await pruneEntriesBefore(userId, startIso);
  if (delErr) {
    // eslint-disable-next-line no-console
    console.error("GET /vocab/stats prune error:", delErr);
    return res.status(500).json({ error: "Failed to prune old vocabulary." });
  }

  const { entries, error } = await listEntriesInWindow(userId, startIso, endIso);
  if (error) {
    // eslint-disable-next-line no-console
    console.error("GET /vocab/stats error:", error);
    return res.status(500).json({ error: "Failed to load vocab stats." });
  }

  const ids = entries.map((e) => e.id);
  let statsByVocab = {};
  if (ids.length > 0) {
    const { data: statsRows, error: statsErr } = await supabaseAdmin
      .from("practice_stats")
      .select(
        "vocab_id, success_count, failure_count, ui_progress, flashcard_mastered"
      )
      .eq("user_id", userId)
      .in("vocab_id", ids);

    if (!statsErr && statsRows) {
      statsByVocab = aggregateStatsByVocabId(statsRows);
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
