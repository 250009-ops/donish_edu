import express from "express";
import { supabaseAdmin } from "../supabaseClient.js";
import { requireAuth } from "../middlewares/authMiddleware.js";

export const vocabRouter = express.Router();

vocabRouter.use(requireAuth);

vocabRouter.get("/", async (req, res) => {
  const { data, error } = await supabaseAdmin
    .from("vocabulary_entries")
    .select("*")
    .eq("user_id", req.user.id)
    .order("created_at", { ascending: false });

  if (error) {
    // eslint-disable-next-line no-console
    console.error("GET /vocab error:", error);
    return res.status(500).json({ error: "Failed to load vocabulary entries." });
  }

  return res.json(data || []);
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

vocabRouter.get("/stats", async (req, res) => {
  const { data, error } = await supabaseAdmin
    .from("vocabulary_entries")
    .select("id, created_at")
    .eq("user_id", req.user.id);

  if (error) {
    // eslint-disable-next-line no-console
    console.error("GET /vocab/stats error:", error);
    return res.status(500).json({ error: "Failed to load vocab stats." });
  }

  const total = data?.length || 0;

  return res.json({
    totalWords: total,
    masteredCount: 0,
    learningCount: total,
    masteryPercent: total === 0 ? 0 : 0
  });
});

