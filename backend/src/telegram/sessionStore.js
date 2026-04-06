import { supabaseAdmin } from "../supabaseClient.js";

const TABLE = "telegram_bot_sessions";

/** @param {number} telegramId */
export async function getSessionStep(telegramId) {
  const { data, error } = await supabaseAdmin
    .from(TABLE)
    .select("step")
    .eq("telegram_id", telegramId)
    .maybeSingle();

  if (error) {
    // eslint-disable-next-line no-console
    console.error("[telegram_bot_sessions] getSessionStep:", error.message);
    return "idle";
  }
  const step = data?.step;
  if (step === "awaiting_password") return "awaiting_password";
  if (step === "awaiting_new_password") return "awaiting_new_password";
  return "idle";
}

/**
 * @param {number} telegramId
 * @param {"idle" | "awaiting_password" | "awaiting_new_password"} step
 * @returns {Promise<boolean>} false if the row could not be saved (e.g. missing table)
 */
export async function setSessionStep(telegramId, step) {
  const { error } = await supabaseAdmin.from(TABLE).upsert(
    {
      telegram_id: telegramId,
      step,
      updated_at: new Date().toISOString()
    },
    { onConflict: "telegram_id" }
  );

  if (error) {
    // eslint-disable-next-line no-console
    console.error("[telegram_bot_sessions] setSessionStep:", error.message);
    return false;
  }
  return true;
}
