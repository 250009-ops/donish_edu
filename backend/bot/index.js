import path from "path";
import { fileURLToPath } from "url";
import dotenv from "dotenv";
import { Telegraf } from "telegraf";
import axios from "axios";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.resolve(__dirname, "..", ".env") });

const botToken = process.env.TELEGRAM_BOT_TOKEN;
const defaultApiBaseUrl = "https://donish-edu.vercel.app";
const apiBaseUrl = String(process.env.API_BASE_URL || defaultApiBaseUrl).replace(
  /\/+$/,
  ""
);
const botSharedSecret = process.env.BOT_SHARED_SECRET || "";

if (!botToken) {
  // eslint-disable-next-line no-console
  console.error("TELEGRAM_BOT_TOKEN is not set. Bot cannot start.");
  process.exit(1);
}

const bot = new Telegraf(botToken);

bot.catch((err, ctx) => {
  // eslint-disable-next-line no-console
  console.error("Unhandled bot error:", {
    error: err?.description || err?.message || err,
    updateType: ctx?.updateType
  });
});

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
        const headers = { "Content-Type": "application/json" };
        if (botSharedSecret) {
          headers["X-Bot-Secret"] = botSharedSecret;
        }
        const createRes = await axios.post(
          `${apiBaseUrl}/bot/create-user`,
          { telegram_id: chatId, password },
          { timeout: 15000, headers }
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

async function ensurePollingCanWork() {
  try {
    const webhookInfo = await bot.telegram.getWebhookInfo();
    if (webhookInfo?.url) {
      // eslint-disable-next-line no-console
      console.warn(
        "Active Telegram webhook detected. Clearing it so polling can receive updates:",
        webhookInfo.url
      );
      await bot.telegram.callApi("deleteWebhook", {
        drop_pending_updates: false
      });
      // eslint-disable-next-line no-console
      console.log("Telegram webhook cleared.");
    }
  } catch (err) {
    // eslint-disable-next-line no-console
    console.warn(
      "Could not inspect/clear webhook. Continuing startup:",
      err?.description || err?.message || err
    );
  }
}

async function launchBot() {
  if (botSharedSecret && botSharedSecret.length < 16) {
    // eslint-disable-next-line no-console
    console.warn(
      "BOT_SHARED_SECRET is set but shorter than 16 characters. This may fail server-side checks in production."
    );
  }

  try {
    const healthRes = await axios.get(`${apiBaseUrl}/health`, { timeout: 7000 });
    // eslint-disable-next-line no-console
    console.log(
      "API health check:",
      healthRes.status,
      healthRes.data?.status || "unknown"
    );
  } catch (err) {
    // eslint-disable-next-line no-console
    console.warn(
      "API health check failed; account creation may fail:",
      err?.response?.status || err?.code || err?.message || err
    );
  }

  try {
    const me = await bot.telegram.getMe();
    // eslint-disable-next-line no-console
    console.log(`Logged in as @${me.username} (${me.id}).`);
  } catch (err) {
    // eslint-disable-next-line no-console
    console.warn(
      "Could not fetch bot profile during startup:",
      err?.description || err?.message || err
    );
  }

  await ensurePollingCanWork();

  try {
    await bot.launch({ dropPendingUpdates: false });
    // eslint-disable-next-line no-console
    console.log("Telegram long polling started.");
  } catch (err) {
    const message = err?.description || err?.message || String(err);
    if (/webhook is active/i.test(message)) {
      // eslint-disable-next-line no-console
      console.warn("Launch failed due to active webhook. Retrying after clearing it...");
      await bot.telegram.callApi("deleteWebhook", {
        drop_pending_updates: false
      });
      await bot.launch({ dropPendingUpdates: false });
      // eslint-disable-next-line no-console
      console.log("Telegram long polling started after webhook cleanup.");
      return;
    }
    throw err;
  }
}

launchBot().catch((err) => {
  // eslint-disable-next-line no-console
  console.error("Bot launch failed:", err?.description || err?.message || err);
  process.exit(1);
});

process.once("SIGINT", () => bot.stop("SIGINT"));
process.once("SIGTERM", () => bot.stop("SIGTERM"));

