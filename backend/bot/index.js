import dotenv from "dotenv";
import { Telegraf } from "telegraf";
import axios from "axios";

dotenv.config();

const botToken = process.env.TELEGRAM_BOT_TOKEN;
const apiBaseUrl = process.env.API_BASE_URL || "http://localhost:4000";

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
  AWAITING_USERNAME: "awaiting_username",
  AWAITING_PASSWORD: "awaiting_password"
};

function setState(chatId, newState, data = {}) {
  state.set(chatId, { step: newState, data });
}

function getState(chatId) {
  return state.get(chatId) || { step: STATES.IDLE, data: {} };
}

bot.start(async (ctx) => {
  const chatId = ctx.chat.id;
  setState(chatId, STATES.AWAITING_USERNAME, {});

  await ctx.reply(
    "Welcome to Donish!\n\nLet's create your account.\n\nPlease send the username you want to use in the Donish app."
  );
});

bot.on("text", async (ctx) => {
  const chatId = ctx.chat.id;
  const message = ctx.message.text.trim();
  const current = getState(chatId);

  if (current.step === STATES.AWAITING_USERNAME) {
    // Check username availability with backend.
    try {
      const checkRes = await axios.post(
        `${apiBaseUrl}/bot/check-username`,
        { username: message }
      );

      if (!checkRes.data.available) {
        await ctx.reply(
          "Sorry, that username is already taken. Please send a different username."
        );
        return;
      }

      setState(chatId, STATES.AWAITING_PASSWORD, { username: message });
      await ctx.reply(
        `Great, "${message}" is available.\n\nNow send a password you will use to sign in to the Donish app.`
      );
      return;
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error("check-username error:", error?.response?.data || error);
      await ctx.reply(
        "I could not verify that username right now. Please try again later."
      );
      setState(chatId, STATES.IDLE, {});
      return;
    }
  }

  if (current.step === STATES.AWAITING_PASSWORD) {
    const username = current.data.username;
    const password = message;

    try {
      await axios.post(`${apiBaseUrl}/bot/create-user`, {
        telegram_id: chatId,
        username,
        password
      });

      await ctx.reply(
        `Your Donish account is ready!\n\nUsername: ${username}\nPassword: (hidden)\n\nOpen the Donish app and sign in with this username and password.`
      );
      setState(chatId, STATES.IDLE, {});
      return;
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error("create-user error:", error?.response?.data || error);
      await ctx.reply(
        "I could not create your account due to a server error. Please try again later."
      );
      setState(chatId, STATES.IDLE, {});
      return;
    }
  }

  // Default: ask user to run /start to begin.
  await ctx.reply(
    "To create or manage your Donish account, please send /start."
  );
});

// eslint-disable-next-line no-console
console.log("Donish Telegram bot is starting...");
bot.launch();

