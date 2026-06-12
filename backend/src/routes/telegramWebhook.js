import express from "express";
import { Telegraf } from "telegraf";
import { config } from "../config.js";
import { resolvePublicApiBaseUrl } from "../publicApi.js";
import { attachDonishBotHandlers } from "../telegram/attachHandlers.js";
import { setBotInstance } from "../telegram/botContext.js";
import { getSession, setSession } from "../telegram/sessionStore.js";

export const telegramWebhookRouter = express.Router();

const token = process.env.TELEGRAM_BOT_TOKEN || "";
const apiBaseUrl = resolvePublicApiBaseUrl();

/** @type {import('telegraf').Telegraf | null} */
export let telegrafBot = null;

if (token) {
  telegrafBot = new Telegraf(token);
  setBotInstance(telegrafBot);

  attachDonishBotHandlers(telegrafBot, {
    session: {
      getSession,
      setSession,
      getStep: async (id) => (await getSession(id)).step,
      setStep: async (id, step) => setSession(id, { step })
    },
    apiBaseUrl,
    botSharedSecret: config.botSharedSecret || process.env.BOT_SHARED_SECRET || "",
    internalUserOps: true
  });

  telegramWebhookRouter.post("/telegram-webhook", (req, res) => {
    const expected = config.telegramWebhookSecret;
    if (!expected) {
      if (process.env.NODE_ENV === "production") {
        return res.status(503).send("Webhook not configured");
      }
    } else {
      const header = req.get("X-Telegram-Bot-Api-Secret-Token");
      if (typeof header !== "string" || header !== expected) {
        return res.status(401).send("Unauthorized");
      }
    }

    telegrafBot
      .handleUpdate(req.body)
      .then(() => res.sendStatus(200))
      .catch((err) => {
        // eslint-disable-next-line no-console
        console.error("telegram webhook handleUpdate:", err);
        res.sendStatus(500);
      });
  });
}
