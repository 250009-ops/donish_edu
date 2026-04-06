import express from "express";
import bcrypt from "bcryptjs";
import { supabaseAdmin } from "../supabaseClient.js";
import {
  botAccountLimiter,
  botCreateUserLimiter
} from "../middlewares/rateLimits.js";
import { requireBotSharedSecret } from "../middlewares/botSecretMiddleware.js";

export const botRouter = express.Router();

const MIN_PASSWORD_LEN = 6;

/** @param {unknown} password */
function validateBotPassword(password) {
  if (typeof password !== "string" || password.length < MIN_PASSWORD_LEN) {
    return `Password must be at least ${MIN_PASSWORD_LEN} characters.`;
  }
  if (password.startsWith("/")) {
    return "Password cannot start with /. Choose a different password.";
  }
  return null;
}

botRouter.post(
  "/lookup-user",
  botAccountLimiter,
  requireBotSharedSecret,
  async (req, res) => {
    const { telegram_id } = req.body || {};
    const tid =
      telegram_id !== undefined && telegram_id !== null
        ? Number(telegram_id)
        : NaN;

    if (!Number.isInteger(tid)) {
      return res.status(400).json({ error: "telegram_id is required." });
    }

    const { data: row, error } = await supabaseAdmin
      .from("users")
      .select("telegram_id")
      .eq("telegram_id", tid)
      .limit(1)
      .maybeSingle();

    if (error) {
      // eslint-disable-next-line no-console
      console.error("lookup-user error:", error);
      return res.status(500).json({ error: "Failed to look up user." });
    }

    if (!row) {
      return res.json({ registered: false });
    }

    return res.json({ registered: true, telegram_id: row.telegram_id });
  }
);

botRouter.post(
  "/reset-password",
  botAccountLimiter,
  requireBotSharedSecret,
  async (req, res) => {
    const { telegram_id, password } = req.body || {};
    const tid =
      telegram_id !== undefined && telegram_id !== null
        ? Number(telegram_id)
        : NaN;

    if (!Number.isInteger(tid) || password === undefined || password === null) {
      return res
        .status(400)
        .json({ error: "telegram_id and password are required." });
    }

    const pwdErr = validateBotPassword(password);
    if (pwdErr) {
      return res.status(400).json({ error: pwdErr });
    }

    const { data: existing, error: findErr } = await supabaseAdmin
      .from("users")
      .select("id")
      .eq("telegram_id", tid)
      .limit(1)
      .maybeSingle();

    if (findErr) {
      // eslint-disable-next-line no-console
      console.error("reset-password find:", findErr);
      return res.status(500).json({ error: "Failed to update password." });
    }

    if (!existing) {
      return res.status(404).json({ error: "No account found for this Telegram user." });
    }

    const passwordHash = await bcrypt.hash(password, 10);
    const { error: updErr } = await supabaseAdmin
      .from("users")
      .update({ password_hash: passwordHash })
      .eq("telegram_id", tid);

    if (updErr) {
      // eslint-disable-next-line no-console
      console.error("reset-password update:", updErr);
      return res.status(500).json({ error: "Failed to update password." });
    }

    return res.json({
      ok: true,
      telegram_id: tid,
      message: "Password updated. Sign in to the app with your ID and new password."
    });
  }
);

botRouter.post(
  "/create-user",
  botCreateUserLimiter,
  requireBotSharedSecret,
  async (req, res) => {
  const { telegram_id, password } = req.body || {};
  const tid = telegram_id !== undefined && telegram_id !== null ? Number(telegram_id) : NaN;

  if (!Number.isInteger(tid) || !password) {
    return res.status(400).json({ error: "telegram_id and password are required." });
  }

  const pwdErr = validateBotPassword(password);
  if (pwdErr) {
    return res.status(400).json({ error: pwdErr });
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
  }
);

