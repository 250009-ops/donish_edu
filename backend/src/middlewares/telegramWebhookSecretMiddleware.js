/**
 * Validates Telegram webhook secret token header:
 * `X-Telegram-Bot-Api-Secret-Token`.
 *
 * When TELEGRAM_WEBHOOK_SECRET is unset:
 * - production: reject (503) to avoid an unprotected webhook endpoint
 * - development: allow with one-time warning
 */
let warnedInsecureWebhook = false;

export function requireTelegramWebhookSecret(req, res, next) {
  const expected = process.env.TELEGRAM_WEBHOOK_SECRET || "";
  if (!expected) {
    const isProd =
      process.env.VERCEL === "1" || process.env.NODE_ENV === "production";
    if (isProd) {
      return res.status(503).json({
        error: "Server is not configured for Telegram webhook (missing TELEGRAM_WEBHOOK_SECRET)."
      });
    }
    if (!warnedInsecureWebhook) {
      warnedInsecureWebhook = true;
      // eslint-disable-next-line no-console
      console.warn(
        "[bot] TELEGRAM_WEBHOOK_SECRET is not set; /bot/webhook is open (dev only). Configure secret_token in setWebhook for production."
      );
    }
    return next();
  }

  const provided = req.headers["x-telegram-bot-api-secret-token"];
  if (typeof provided !== "string" || provided !== expected) {
    return res.status(401).json({ error: "Invalid or missing Telegram webhook secret." });
  }
  return next();
}
