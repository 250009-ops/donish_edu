import { config } from "../config.js";

/**
 * When BOT_SHARED_SECRET is set, require matching `X-Bot-Secret` header.
 * In non-production without a secret, registration stays open for local dev (with a console warning once).
 */
let warnedInsecureBot = false;

export function requireBotSharedSecret(req, res, next) {
  const expected = config.botSharedSecret;
  if (!expected) {
    const isProd = process.env.NODE_ENV === "production";
    if (isProd) {
      return res.status(503).json({
        error: "Server is not configured for bot registration (missing BOT_SHARED_SECRET)."
      });
    }
    if (!warnedInsecureBot) {
      warnedInsecureBot = true;
      // eslint-disable-next-line no-console
      console.warn(
        "[bot] BOT_SHARED_SECRET is not set; /bot/create-user is open (dev only). Set BOT_SHARED_SECRET and send X-Bot-Secret from the bot in production."
      );
    }
    return next();
  }

  const provided = req.headers["x-bot-secret"];
  if (typeof provided !== "string" || provided !== expected) {
    return res.status(401).json({ error: "Invalid or missing bot secret." });
  }
  return next();
}
