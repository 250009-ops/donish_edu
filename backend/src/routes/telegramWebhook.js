import express from "express";
import { Telegraf } from "telegraf";
import { config } from "../config.js";
import { attachDonishBotHandlers } from "../telegram/attachHandlers.js";
import { getSessionStep, setSessionStep } from "../telegram/sessionStore.js";

export const telegramWebhookRouter = express.Router();

const token = process.env.TELEGRAM_BOT_TOKEN || "";
const webhookSecret = process.env.TELEGRAM_WEBHOOK_SECRET || "";
const apiBaseUrl =
  process.env.API_BASE_URL ||
  (process.env.VERCEL_URL
    ? `https://${process.env.VERCEL_URL}`
    : "https://donish-edu.vercel.app");

if (token) {
  const bot = new Telegraf(token);

  attachDonishBotHandlers(bot, {
    session: {
      getStep: getSessionStep,
      setStep: setSessionStep
    },
    apiBaseUrl,
    botSharedSecret: config.botSharedSecret || process.env.BOT_SHARED_SECRET || "",
    /** Same Node process as Express — avoid HTTP self-call to /bot/* (401, URL, rate limits). */
    internalUserOps: true
  });

  telegramWebhookRouter.post("/telegram-webhook", (req, res) => {
    if (webhookSecret) {
      const header = req.get("X-Telegram-Bot-Api-Secret-Token");
      if (header !== webhookSecret) {
        return res.status(401).send("Unauthorized");
      }
    }

    bot
      .handleUpdate(req.body)
      .then(() => res.sendStatus(200))
      .catch((err) => {
        // eslint-disable-next-line no-console
        console.error("telegram webhook handleUpdate:", err);
        res.sendStatus(500);
      });
  });
}
