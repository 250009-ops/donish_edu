import bcrypt from "bcryptjs";
import { supabaseAdmin } from "../supabaseClient.js";

export const MIN_PASSWORD_LEN = 6;

/** @param {unknown} password */
export function validateBotPassword(password) {
  if (typeof password !== "string" || password.length < MIN_PASSWORD_LEN) {
    return `Password must be at least ${MIN_PASSWORD_LEN} characters.`;
  }
  if (password.startsWith("/")) {
    return "Password cannot start with /. Choose a different password.";
  }
  return null;
}

/**
 * @param {number} tid
 * @returns {Promise<{ ok: true, registered: boolean, telegram_id: number } | { ok: false, error: string }>}
 */
export async function lookupTelegramUser(tid) {
  if (!Number.isInteger(tid)) {
    return { ok: false, error: "telegram_id is required." };
  }

  const { data: row, error } = await supabaseAdmin
    .from("users")
    .select("telegram_id")
    .eq("telegram_id", tid)
    .limit(1)
    .maybeSingle();

  if (error) {
    // eslint-disable-next-line no-console
    console.error("lookupTelegramUser:", error);
    return { ok: false, error: "Failed to look up user." };
  }

  if (!row) {
    return { ok: true, registered: false, telegram_id: tid };
  }

  return { ok: true, registered: true, telegram_id: row.telegram_id };
}

/**
 * @param {number} tid
 * @param {string} password
 * @returns {Promise<{ ok: true, id: string, telegram_id: number } | { ok: false, status: number, error: string }>}
 */
export async function createTelegramUser(tid, password) {
  if (!Number.isInteger(tid) || !password) {
    return {
      ok: false,
      status: 400,
      error: "telegram_id and password are required."
    };
  }

  const pwdErr = validateBotPassword(password);
  if (pwdErr) {
    return { ok: false, status: 400, error: pwdErr };
  }

  const { data: existing } = await supabaseAdmin
    .from("users")
    .select("id")
    .eq("telegram_id", tid)
    .limit(1)
    .maybeSingle();

  if (existing) {
    return {
      ok: false,
      status: 409,
      error: "Already registered. Use the Donish app to sign in."
    };
  }

  const passwordHash = await bcrypt.hash(password, 10);
  const username = String(tid);

  const { data, error } = await supabaseAdmin
    .from("users")
    .insert({
      telegram_id: tid,
      username,
      password_hash: passwordHash
    })
    .select("*")
    .single();

  if (error) {
    // eslint-disable-next-line no-console
    console.error("createTelegramUser:", error);
    return { ok: false, status: 500, error: "Failed to create user." };
  }

  return { ok: true, id: data.id, telegram_id: data.telegram_id };
}

/**
 * @param {number} tid
 * @param {string} password
 * @returns {Promise<{ ok: true, telegram_id: number } | { ok: false, status: number, error: string }>}
 */
export async function resetTelegramUserPassword(tid, password) {
  if (!Number.isInteger(tid) || password === undefined || password === null) {
    return {
      ok: false,
      status: 400,
      error: "telegram_id and password are required."
    };
  }

  const pwdErr = validateBotPassword(password);
  if (pwdErr) {
    return { ok: false, status: 400, error: pwdErr };
  }

  const { data: existing, error: findErr } = await supabaseAdmin
    .from("users")
    .select("id")
    .eq("telegram_id", tid)
    .limit(1)
    .maybeSingle();

  if (findErr) {
    // eslint-disable-next-line no-console
    console.error("resetTelegramUserPassword find:", findErr);
    return { ok: false, status: 500, error: "Failed to update password." };
  }

  if (!existing) {
    return {
      ok: false,
      status: 404,
      error: "No account found for this Telegram user."
    };
  }

  const passwordHash = await bcrypt.hash(password, 10);
  const { error: updErr } = await supabaseAdmin
    .from("users")
    .update({ password_hash: passwordHash })
    .eq("telegram_id", tid);

  if (updErr) {
    // eslint-disable-next-line no-console
    console.error("resetTelegramUserPassword update:", updErr);
    return { ok: false, status: 500, error: "Failed to update password." };
  }

  return { ok: true, telegram_id: tid };
}
