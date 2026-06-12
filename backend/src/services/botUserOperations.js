import bcrypt from "bcryptjs";
import { APP_DISPLAY_NAME } from "../branding.js";
import { query } from "../db/pool.js";
import { revokeAllUserDevices } from "./deviceService.js";

export const MIN_PASSWORD_LEN = 10;
export const MAX_PASSWORD_LEN = 128;

/** @param {unknown} password */
export function validateBotPassword(password) {
  if (typeof password !== "string" || password.length < MIN_PASSWORD_LEN) {
    return `Password must be at least ${MIN_PASSWORD_LEN} characters.`;
  }
  if (password.length > MAX_PASSWORD_LEN) {
    return `Password must be at most ${MAX_PASSWORD_LEN} characters.`;
  }
  if (password.startsWith("/")) {
    return "Password cannot start with /. Choose a different password.";
  }
  return null;
}

/** @param {unknown} name */
export function validateName(name) {
  if (typeof name !== "string") return "Name is required.";
  const t = name.trim();
  if (t.length < 2 || t.length > 80) return "Name must be 2–80 characters.";
  return null;
}

/** @param {unknown} email */
export function validateEmail(email) {
  if (email === null || email === undefined || email === "") return null;
  if (typeof email !== "string") return "Invalid email.";
  const t = email.trim().toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(t)) return "Invalid email.";
  return null;
}

/** @param {unknown} phone */
export function normalizePhoneE164(phone) {
  if (typeof phone !== "string") return null;
  let t = phone.trim().replace(/[\s()-]/g, "");
  if (!t.startsWith("+")) {
    if (t.startsWith("998")) t = `+${t}`;
    else if (/^\d{9}$/.test(t)) t = `+998${t}`;
    else return null;
  }
  if (!/^\+[1-9]\d{7,14}$/.test(t)) return null;
  return t;
}

/**
 * @param {number} tid
 * @returns {Promise<object>}
 */
export async function lookupTelegramUser(tid) {
  if (!Number.isInteger(tid)) {
    return { ok: false, error: "telegram_id is required." };
  }

  try {
    const { rows } = await query(
      `select id, telegram_id, full_name, email, phone_e164, language,
              profile_completed_at, created_at
       from users where telegram_id = $1 limit 1`,
      [tid]
    );
    const row = rows[0];
    if (!row) {
      return { ok: true, registered: false, telegram_id: tid };
    }
    const profileComplete = Boolean(
      row.full_name && row.phone_e164 && row.profile_completed_at
    );
    return {
      ok: true,
      registered: true,
      telegram_id: row.telegram_id,
      user_id: row.id,
      full_name: row.full_name,
      email: row.email,
      phone_e164: row.phone_e164,
      language: row.language,
      profile_complete: profileComplete
    };
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error("lookupTelegramUser:", error);
    return { ok: false, error: "Failed to look up user." };
  }
}

/**
 * @param {number} tid
 * @param {string} password
 * @param {object} [profile]
 */
export async function createTelegramUser(tid, password, profile = {}) {
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

  const nameErr = validateName(profile.full_name);
  if (nameErr) {
    return { ok: false, status: 400, error: nameErr };
  }

  const phone = normalizePhoneE164(profile.phone_e164);
  if (!phone) {
    return { ok: false, status: 400, error: "Valid phone number is required." };
  }

  const emailErr = validateEmail(profile.email);
  if (emailErr) {
    return { ok: false, status: 400, error: emailErr };
  }

  const email =
    profile.email && String(profile.email).trim()
      ? String(profile.email).trim().toLowerCase()
      : null;
  const language = ["uz", "ru", "en"].includes(profile.language)
    ? profile.language
    : "uz";

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

    if (email) {
      const { rows: emailClash } = await query(
        `select id from users where lower(email) = $1 limit 1`,
        [email]
      );
      if (emailClash[0]) {
        return { ok: false, status: 409, error: "Email is already in use." };
      }
    }

    const passwordHash = await bcrypt.hash(password, 10);
    const username = String(tid);

    const { rows } = await query(
      `insert into users (
         telegram_id, username, password_hash, full_name, email, phone_e164,
         language, profile_completed_at, updated_at
       )
       values ($1, $2, $3, $4, $5, $6, $7, now(), now())
       returning *`,
      [
        tid,
        username,
        passwordHash,
        profile.full_name.trim(),
        email,
        phone,
        language
      ]
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
 * @param {object} patch
 */
export async function updateTelegramUserProfile(tid, patch) {
  if (!Number.isInteger(tid)) {
    return { ok: false, status: 400, error: "telegram_id is required." };
  }

  const sets = [];
  const params = [tid];

  if (patch.full_name !== undefined) {
    const err = validateName(patch.full_name);
    if (err) return { ok: false, status: 400, error: err };
    params.push(patch.full_name.trim());
    sets.push(`full_name = $${params.length}`);
  }
  if (patch.email !== undefined) {
    const err = validateEmail(patch.email);
    if (err) return { ok: false, status: 400, error: err };
    const email =
      patch.email && String(patch.email).trim()
        ? String(patch.email).trim().toLowerCase()
        : null;
    params.push(email);
    sets.push(`email = $${params.length}`);
  }
  if (patch.phone_e164 !== undefined) {
    const phone = normalizePhoneE164(patch.phone_e164);
    if (!phone) return { ok: false, status: 400, error: "Invalid phone." };
    params.push(phone);
    sets.push(`phone_e164 = $${params.length}`);
  }
  if (patch.language !== undefined) {
    if (!["uz", "ru", "en"].includes(patch.language)) {
      return { ok: false, status: 400, error: "Invalid language." };
    }
    params.push(patch.language);
    sets.push(`language = $${params.length}`);
  }

  if (!sets.length) {
    return { ok: false, status: 400, error: "Nothing to update." };
  }

  sets.push("updated_at = now()");

  try {
    const { rows } = await query(
      `update users set ${sets.join(", ")} where telegram_id = $1 returning *`,
      params
    );
    if (!rows[0]) {
      return { ok: false, status: 404, error: "User not found." };
    }
    return { ok: true, user: rows[0] };
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error("updateTelegramUserProfile:", error);
    return { ok: false, status: 500, error: "Failed to update profile." };
  }
}

/**
 * @param {number} tid
 * @param {string} password
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

    const userId = existing[0].id;
    const passwordHash = await bcrypt.hash(password, 10);
    await query(
      `update users set password_hash = $1 where telegram_id = $2`,
      [passwordHash, tid]
    );
    await revokeAllUserDevices(userId);

    return { ok: true, telegram_id: tid };
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error("resetTelegramUserPassword:", error);
    return { ok: false, status: 500, error: "Failed to update password." };
  }
}
