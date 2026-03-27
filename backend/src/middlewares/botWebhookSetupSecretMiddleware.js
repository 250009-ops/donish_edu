/**
 * Protects webhook setup endpoint with an admin-only secret header.
 * Header: X-Setup-Secret
 */
let warnedInsecureSetup = false;

export function requireBotWebhookSetupSecret(req, res, next) {
  const expected = process.env.BOT_WEBHOOK_SETUP_SECRET || "";
  if (!expected) {
    const isProd =
      process.env.VERCEL === "1" || process.env.NODE_ENV === "production";
    if (isProd) {
      return res.status(503).json({
        error: "Server is not configured for webhook setup (missing BOT_WEBHOOK_SETUP_SECRET)."
      });
    }
    if (!warnedInsecureSetup) {
      warnedInsecureSetup = true;
      // eslint-disable-next-line no-console
      console.warn(
        "[bot] BOT_WEBHOOK_SETUP_SECRET is not set; /bot/setup-webhook is open (dev only)."
      );
    }
    return next();
  }

  const provided = req.headers["x-setup-secret"];
  if (typeof provided !== "string" || provided !== expected) {
    return res.status(401).json({ error: "Invalid or missing setup secret." });
  }
  return next();
}
