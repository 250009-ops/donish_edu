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
  return step === "awaiting_password" ? "awaiting_password" : "idle";
}

/**
 * @param {number} telegramId
 * @param {"idle" | "awaiting_password"} step
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
  }
}
