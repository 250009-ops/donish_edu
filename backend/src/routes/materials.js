import express from "express";
import { supabaseAdmin } from "../supabaseClient.js";
import { requireAuth } from "../middlewares/authMiddleware.js";

export const materialsRouter = express.Router();

materialsRouter.use(requireAuth);

materialsRouter.get("/", async (req, res) => {
  const { data, error } = await supabaseAdmin
    .from("materials")
    .select("*")
    .eq("user_id", req.user.id)
    .order("created_at", { ascending: false });

  if (error) {
    // eslint-disable-next-line no-console
    console.error("GET /materials error:", error);
    return res.status(500).json({ error: "Failed to load materials." });
  }

  return res.json(data || []);
});

materialsRouter.post("/", async (req, res) => {
  const { title, file_path, page_count } = req.body || {};

  if (!title || !file_path) {
    return res.status(400).json({ error: "title and file_path are required." });
  }

  const { data, error } = await supabaseAdmin
    .from("materials")
    .insert({
      user_id: req.user.id,
      title,
      file_path,
      page_count: page_count || null
    })
    .select("*")
    .single();

  if (error) {
    // eslint-disable-next-line no-console
    console.error("POST /materials error:", error);
    return res.status(500).json({ error: "Failed to create material." });
  }

  return res.status(201).json(data);
});

