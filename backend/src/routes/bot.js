import express from "express";
import { botCreateUserLimiter } from "../middlewares/rateLimits.js";
import { requireBotSharedSecret } from "../middlewares/botSecretMiddleware.js";
import { requireTelegramWebhookSecret } from "../middlewares/telegramWebhookSecretMiddleware.js";
import { requireBotWebhookSetupSecret } from "../middlewares/botWebhookSetupSecretMiddleware.js";
import {
  processTelegramUpdate,
  registerBotWebhook,
  getTelegramWebhookInfo,
  createDonishUser
} from "../services/telegramBotService.js";

export const botRouter = express.Router();

botRouter.post(
  "/create-user",
  botCreateUserLimiter,
  requireBotSharedSecret,
  async (req, res) => {
  const { telegram_id, password } = req.body || {};
  const tid = telegram_id !== undefined && telegram_id !== null ? Number(telegram_id) : NaN;

  const createRes = await createDonishUser(tid, password);
  if (createRes.status === 201) {
    return res.status(201).json(createRes.data);
  }
  return res.status(createRes.status).json({ error: createRes.error });
  }
);

botRouter.post("/webhook", requireTelegramWebhookSecret, async (req, res) => {
  try {
    await processTelegramUpdate(req.body);
    return res.status(200).json({ ok: true });
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error("telegram webhook processing error:", error);
    return res.status(200).json({ ok: true });
  }
});

botRouter.post("/setup-webhook", requireBotWebhookSetupSecret, async (req, res) => {
  const domain = process.env.APP_BASE_URL || "";
  const webhookSecret = process.env.TELEGRAM_WEBHOOK_SECRET || "";
  const webhookOverride = req.body?.webhook_url;

  if (!domain || !/^https:\/\//.test(domain)) {
    return res.status(503).json({
      error: "APP_BASE_URL is missing or invalid. Expected https://<your-domain>."
    });
  }
  if (!webhookSecret) {
    return res.status(503).json({
      error: "TELEGRAM_WEBHOOK_SECRET is missing."
    });
  }

  const normalizedDomain = domain.replace(/\/+$/, "");
  const webhookUrl =
    typeof webhookOverride === "string" && webhookOverride.trim()
      ? webhookOverride.trim()
      : `${normalizedDomain}/bot/webhook`;

  try {
    await registerBotWebhook(webhookUrl, webhookSecret);
    const info = await getTelegramWebhookInfo();
    return res.status(200).json({
      ok: true,
      webhook_url: webhookUrl,
      telegram_webhook_info: info
    });
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error("telegram webhook register error:", error);
    return res.status(500).json({
      error: "Failed to register webhook.",
      details: error?.description || error?.message || String(error)
    });
  }
});

