import { query } from "../db/pool.js";

/** @param {number} telegramId */
export async function getSessionStep(telegramId) {
  try {
    const { rows } = await query(
      `select step from telegram_bot_sessions where telegram_id = $1`,
      [telegramId]
    );
    const step = rows[0]?.step;
    if (step === "awaiting_password") return "awaiting_password";
    if (step === "awaiting_new_password") return "awaiting_new_password";
    return "idle";
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error("[telegram_bot_sessions] getSessionStep:", error.message);
    return "idle";
  }
}

/**
 * @param {number} telegramId
 * @param {"idle" | "awaiting_password" | "awaiting_new_password"} step
 * @returns {Promise<boolean>}
 */
export async function setSessionStep(telegramId, step) {
  try {
    await query(
      `insert into telegram_bot_sessions (telegram_id, step, updated_at)
       values ($1, $2, now())
       on conflict (telegram_id) do update set
         step = excluded.step,
         updated_at = now()`,
      [telegramId, step]
    );
    return true;
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error("[telegram_bot_sessions] setSessionStep:", error.message);
    return false;
  }
}
