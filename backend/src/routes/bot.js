import express from "express";
import bcrypt from "bcryptjs";
import { supabaseAdmin } from "../supabaseClient.js";

export const botRouter = express.Router();

botRouter.post("/check-username", async (req, res) => {
  const { username } = req.body || {};

  if (!username) {
    return res.status(400).json({ available: false, reason: "username_required" });
  }

  const { count, error } = await supabaseAdmin
    .from("users")
    .select("*", { count: "exact", head: true })
    .eq("username", username);

  if (error) {
    // eslint-disable-next-line no-console
    console.error("check-username error:", error);
    return res.status(500).json({ available: false, reason: "db_error" });
  }

  return res.json({ available: (count || 0) === 0 });
});

botRouter.post("/create-user", async (req, res) => {
  const { telegram_id, username, password } = req.body || {};

  if (!telegram_id || !username || !password) {
    return res.status(400).json({ error: "telegram_id, username and password are required." });
  }

  const passwordHash = await bcrypt.hash(password, 10);

  const { data, error } = await supabaseAdmin.from("users").insert({
    telegram_id,
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
    username: data.username
  });
});

