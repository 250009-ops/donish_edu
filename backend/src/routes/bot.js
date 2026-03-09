import express from "express";
import bcrypt from "bcryptjs";
import { supabaseAdmin } from "../supabaseClient.js";

export const botRouter = express.Router();

botRouter.post("/create-user", async (req, res) => {
  const { telegram_id, password } = req.body || {};
  const tid = telegram_id !== undefined && telegram_id !== null ? Number(telegram_id) : NaN;

  if (!Number.isInteger(tid) || !password) {
    return res.status(400).json({ error: "telegram_id and password are required." });
  }

  const { data: existing } = await supabaseAdmin
    .from("users")
    .select("id")
    .eq("telegram_id", tid)
    .limit(1)
    .maybeSingle();

  if (existing) {
    return res.status(409).json({ error: "Already registered. Use the Donish app to sign in." });
  }

  const passwordHash = await bcrypt.hash(password, 10);
  const username = String(tid);

  const { data, error } = await supabaseAdmin.from("users").insert({
    telegram_id: tid,
    username,
    password_hash: passwordHash
  }).select("*").single();

  if (error) {
    // eslint-disable-next-line no-console
    console.error("create-user error:", error);
    return res.status(500).json({ error: "Failed to create user." });
  }

  return res.status(201).json({
    id: data.id,
    telegram_id: data.telegram_id
  });
});

