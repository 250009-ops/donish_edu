import path from "path";
import { fileURLToPath } from "url";
import dotenv from "dotenv";
import { Telegraf } from "telegraf";
import axios from "axios";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.resolve(__dirname, "..", ".env") });

const botToken = process.env.TELEGRAM_BOT_TOKEN;
const apiBaseUrl =
  process.env.API_BASE_URL ||
  "https://donish-edu.vercel.app";

if (!botToken) {
  // eslint-disable-next-line no-console
  console.error("TELEGRAM_BOT_TOKEN is not set. Bot cannot start.");
  process.exit(1);
}

const bot = new Telegraf(botToken);

// Simple in-memory conversation state keyed by chat id.
const state = new Map();

const STATES = {
  IDLE: "idle",
  AWAITING_PASSWORD: "awaiting_password"
};

function setState(chatId, newState, data = {}) {
  state.set(chatId, { step: newState, data });
}

function getState(chatId) {
  return state.get(chatId) || { step: STATES.IDLE, data: {} };
}

bot.start(async (ctx) => {
  try {
    const chatId = ctx.chat.id;
    setState(chatId, STATES.AWAITING_PASSWORD, {});

    await ctx.reply(
      "Welcome to Donish!\n\nTo use the Donish app, set a password. Send the password you'll use to sign in (you'll sign in with your ID and this password in the app)."
    );
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error("bot.start error:", err);
  }
});

bot.on("text", async (ctx) => {
  try {
    const chatId = ctx.chat.id;
    const message = ctx.message?.text?.trim() ?? "";
    const current = getState(chatId);

    if (current.step === STATES.AWAITING_PASSWORD) {
      const password = message;

      try {
        const createRes = await axios.post(
          `${apiBaseUrl}/bot/create-user`,
          { telegram_id: chatId, password },
          { timeout: 15000, headers: { "Content-Type": "application/json" } }
        );

        const telegramId = createRes.data?.telegram_id ?? chatId;
        await ctx.reply(
          `Your Donish account is ready!\n\nYour ID is: ${telegramId}\n\nUse this ID and your password to sign in to the Donish app. Keep your ID private.`
        );
        setState(chatId, STATES.IDLE, {});
        return;
      } catch (error) {
        const status = error?.response?.status;
        const msg = error?.response?.data?.error;
        // eslint-disable-next-line no-console
        console.error("create-user error:", error?.response?.data || error.message);
        if (status === 409) {
          await ctx.reply(
            "You already have an account. Use your ID and password to sign in to the Donish app."
          );
        } else {
          await ctx.reply(
            msg || "I could not create your account. Please try again later."
          );
        }
        setState(chatId, STATES.IDLE, {});
        return;
      }
    }

    await ctx.reply(
      "To create or manage your Donish account, please send /start."
    );
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error("bot text handler error:", err);
    try {
      await ctx.reply("Something went wrong. Please try /start again.");
    } catch (_) {}
  }
});

// eslint-disable-next-line no-console
console.log("Donish Telegram bot is starting... (API:", apiBaseUrl, ")");
bot.launch().catch((err) => {
  // eslint-disable-next-line no-console
  console.error("Bot launch failed:", err);
  process.exit(1);
});

