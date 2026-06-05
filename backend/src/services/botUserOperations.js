import bcrypt from "bcryptjs";
import { APP_DISPLAY_NAME } from "../branding.js";
import { query } from "../db/pool.js";

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

  try {
    const { rows } = await query(
      `select telegram_id from users where telegram_id = $1 limit 1`,
      [tid]
    );
    const row = rows[0];
    if (!row) {
      return { ok: true, registered: false, telegram_id: tid };
    }
    return { ok: true, registered: true, telegram_id: row.telegram_id };
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error("lookupTelegramUser:", error);
    return { ok: false, error: "Failed to look up user." };
  }
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

  try {
    const { rows: existing } = await query(
      `select id from users where telegram_id = $1 limit 1`,
      [tid]
    );
    if (existing[0]) {
      return {
        ok: false,
        status: 409,
        error: `Already registered. Use the ${APP_DISPLAY_NAME} app to sign in.`
      };
    }

    const passwordHash = await bcrypt.hash(password, 10);
    const username = String(tid);

    const { rows } = await query(
      `insert into users (telegram_id, username, password_hash)
       values ($1, $2, $3)
       returning *`,
      [tid, username, passwordHash]
    );

    const data = rows[0];
    return { ok: true, id: data.id, telegram_id: data.telegram_id };
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error("createTelegramUser:", error);
    return { ok: false, status: 500, error: "Failed to create user." };
  }
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

  try {
    const { rows: existing } = await query(
      `select id from users where telegram_id = $1 limit 1`,
      [tid]
    );
    if (!existing[0]) {
      return {
        ok: false,
        status: 404,
        error: "No account found for this Telegram user."
      };
    }

    const passwordHash = await bcrypt.hash(password, 10);
    await query(
      `update users set password_hash = $1 where telegram_id = $2`,
      [passwordHash, tid]
    );

    return { ok: true, telegram_id: tid };
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error("resetTelegramUserPassword:", error);
    return { ok: false, status: 500, error: "Failed to update password." };
  }
}
