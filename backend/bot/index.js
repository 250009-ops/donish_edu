import path from "path";
import { fileURLToPath } from "url";
import dotenv from "dotenv";
import { Telegraf } from "telegraf";

import { attachDonishBotHandlers } from "../src/telegram/attachHandlers.js";
import { memorySession } from "../src/telegram/memorySession.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.resolve(__dirname, "..", ".env") });

const botToken = process.env.TELEGRAM_BOT_TOKEN;
const apiBaseUrl =
  process.env.API_BASE_URL ||
  "https://donish-edu.vercel.app";
const botSharedSecret = process.env.BOT_SHARED_SECRET || "";

if (!botToken) {
  // eslint-disable-next-line no-console
  console.error("TELEGRAM_BOT_TOKEN is not set. Bot cannot start.");
  process.exit(1);
}

const bot = new Telegraf(botToken);

attachDonishBotHandlers(bot, {
  session: memorySession,
  apiBaseUrl,
  botSharedSecret
});

// eslint-disable-next-line no-console
console.log("Donish Telegram bot is starting (long polling)... (API:", apiBaseUrl, ")");
// eslint-disable-next-line no-console
console.log(
  "If you use a Telegram webhook on Vercel, do not run this process — webhook handles updates."
);

bot.launch().catch((err) => {
  // eslint-disable-next-line no-console
  console.error("Bot launch failed:", err);
  process.exit(1);
});
