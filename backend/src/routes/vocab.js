import express from "express";
import { supabaseAdmin } from "../supabaseClient.js";
import { requireAuth } from "../middlewares/authMiddleware.js";

export const vocabRouter = express.Router();

vocabRouter.use(requireAuth);

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

function progressFromCounts(successCount, failureCount) {
  const sc = successCount ?? 0;
  const fc = failureCount ?? 0;
  const t = sc + fc;
  if (t === 0) return 0.35;
  return Math.min(1, sc / t);
}

function progressFromStats(row) {
  if (!row) return 0.35;
  return progressFromCounts(row.success_count, row.failure_count);
}

/** Merge duplicate practice_stats rows per vocab_id (same user). */
function aggregateStatsByVocabId(rows) {
  const map = {};
  for (const r of rows || []) {
    const vid = r.vocab_id;
    if (!map[vid]) {
      map[vid] = { success_count: 0, failure_count: 0 };
    }
    map[vid].success_count += Number(r.success_count) || 0;
    map[vid].failure_count += Number(r.failure_count) || 0;
  }
  return map;
}

function applyPracticeAction(action, success, failure) {
  let sc = success;
  let fc = failure;
  switch (action) {
    case "quiz_correct":
      sc = Math.max(sc, 100);
      fc = 0;
      break;
    case "quiz_incorrect":
      fc += 2;
      sc = Math.max(0, sc - 2);
      break;
    case "flashcard_easy":
      sc += 5;
      fc = Math.max(0, fc - 1);
      break;
    case "flashcard_hard":
      sc = Math.max(0, sc - 10);
      fc += 8;
      break;
    default:
      return null;
  }
  return { success_count: sc, failure_count: fc };
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
      .select("vocab_id, success_count, failure_count")
      .eq("user_id", userId)
      .in("vocab_id", ids);

    if (statsErr) {
      // eslint-disable-next-line no-console
      console.error("GET /vocab practice_stats error:", statsErr);
    } else {
      statsByVocab = aggregateStatsByVocabId(statsRows);
    }
  }

  const enriched = entries.map((e) => ({
    ...e,
    progress: progressFromStats(statsByVocab[e.id]),
    display_tag: "Saved"
  }));

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
    .select("id, success_count, failure_count")
    .eq("user_id", userId)
    .eq("vocab_id", vocabId)
    .limit(1);

  if (findErr) {
    // eslint-disable-next-line no-console
    console.error("POST /vocab/practice find stats:", findErr);
    return res.status(500).json({ error: "Failed to load practice stats." });
  }

  const existing = existingRows?.[0];
  const baseSc = existing?.success_count ?? 0;
  const baseFc = existing?.failure_count ?? 0;
  const next = applyPracticeAction(action, baseSc, baseFc);
  if (!next) {
    return res.status(400).json({ error: "Invalid action." });
  }

  const { success_count: sc, failure_count: fc } = next;
  const nowIso = new Date().toISOString();
  const progress = progressFromCounts(sc, fc);

  if (existing) {
    const { error: upErr } = await supabaseAdmin
      .from("practice_stats")
      .update({
        success_count: sc,
        failure_count: fc,
        last_seen_at: nowIso
      })
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
      success_count: sc,
      failure_count: fc,
      last_seen_at: nowIso
    });

    if (insErr) {
      // eslint-disable-next-line no-console
      console.error("POST /vocab/practice insert:", insErr);
      return res.status(500).json({ error: "Failed to save practice stats." });
    }
  }

  return res.json({
    vocab_id: vocabId,
    success_count: sc,
    failure_count: fc,
    progress
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
      .select("vocab_id, success_count, failure_count")
      .eq("user_id", userId)
      .in("vocab_id", ids);

    if (!statsErr && statsRows) {
      statsByVocab = aggregateStatsByVocabId(statsRows);
    }
  }

  const total = entries.length;
  let mastered = 0;
  for (const e of entries) {
    if (progressFromStats(statsByVocab[e.id]) >= 0.85) mastered += 1;
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
