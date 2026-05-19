import path from "path";
import { fileURLToPath } from "url";
import dotenv from "dotenv";
import { Telegraf } from "telegraf";

import { attachDonishBotHandlers } from "../src/telegram/attachHandlers.js";
import { memorySession } from "../src/telegram/memorySession.js";
import { resolvePublicApiBaseUrl } from "../src/publicApi.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.resolve(__dirname, "..", ".env") });

const botToken = process.env.TELEGRAM_BOT_TOKEN;
const apiBaseUrl = resolvePublicApiBaseUrl();
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
  "If the API uses Telegram webhook mode (npm run webhook:set), do not run this process."
);

bot.launch().catch((err) => {
  // eslint-disable-next-line no-console
  console.error("Bot launch failed:", err);
  process.exit(1);
});
