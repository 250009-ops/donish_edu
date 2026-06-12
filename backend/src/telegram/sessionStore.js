import { query } from "../db/pool.js";

const VALID_STEPS = new Set([
  "idle",
  "onboard_language",
  "onboard_name",
  "onboard_phone",
  "onboard_email",
  "onboard_password",
  "awaiting_new_password",
  "edit_name",
  "edit_email",
  "edit_phone",
  "support_chat",
  "pick_language",
  "download_menu"
]);

/** @param {number} telegramId */
export async function getSession(telegramId) {
  try {
    const { rows } = await query(
      `select step, data, language from telegram_bot_sessions where telegram_id = $1`,
      [telegramId]
    );
    const row = rows[0];
    if (!row) {
      return { step: "idle", data: {}, language: null };
    }
    const step = VALID_STEPS.has(row.step) ? row.step : "idle";
    return {
      step,
      data: row.data && typeof row.data === "object" ? row.data : {},
      language: row.language || null
    };
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error("[telegram_bot_sessions] getSession:", error.message);
    return { step: "idle", data: {}, language: null };
  }
}

/** @param {number} telegramId */
export async function getSessionStep(telegramId) {
  const s = await getSession(telegramId);
  return s.step;
}

/**
 * @param {number} telegramId
 * @param {object} patch
 * @param {string} [patch.step]
 * @param {object} [patch.data]
 * @param {string|null} [patch.language]
 * @param {boolean} [patch.mergeData]
 */
export async function setSession(telegramId, patch) {
  const current = await getSession(telegramId);
  const step = patch.step ?? current.step;
  const language =
    patch.language !== undefined ? patch.language : current.language;
  let data = current.data;
  if (patch.data !== undefined) {
    data = patch.mergeData ? { ...current.data, ...patch.data } : patch.data;
  }
  try {
    await query(
      `insert into telegram_bot_sessions (telegram_id, step, data, language, updated_at)
       values ($1, $2, $3::jsonb, $4, now())
       on conflict (telegram_id) do update set
         step = excluded.step,
         data = excluded.data,
         language = excluded.language,
         updated_at = now()`,
      [telegramId, step, JSON.stringify(data), language]
    );
    return true;
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error("[telegram_bot_sessions] setSession:", error.message);
    return false;
  }
}

/** @param {number} telegramId @param {string} step */
export async function setSessionStep(telegramId, step) {
  return setSession(telegramId, { step });
}

/** @param {number} telegramId */
export async function clearSessionData(telegramId) {
  return setSession(telegramId, { data: {}, step: "idle" });
}
