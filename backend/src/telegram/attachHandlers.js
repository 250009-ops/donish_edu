import axios from "axios";

export const STATES = {
  IDLE: "idle",
  AWAITING_PASSWORD: "awaiting_password",
  AWAITING_NEW_PASSWORD: "awaiting_new_password"
};

/**
 * @typedef {object} SessionAdapter
 * @property {(chatId: number) => Promise<string>} getStep
 * @property {(chatId: number, step: string) => Promise<boolean | void>} setStep
 */

/**
 * @param {string} botSharedSecret
 */
function secretHeaders(botSharedSecret) {
  const headers = { "Content-Type": "application/json" };
  if (botSharedSecret) {
    headers["X-Bot-Secret"] = botSharedSecret;
  }
  return headers;
}

/**
 * Register Donish bot conversation handlers on a Telegraf instance.
 *
 * @param {import("telegraf").Telegraf} bot
 * @param {object} options
 * @param {SessionAdapter} options.session
 * @param {string} options.apiBaseUrl
 * @param {string} [options.botSharedSecret]
 */
export function attachDonishBotHandlers(bot, options) {
  const { session, apiBaseUrl, botSharedSecret = "" } = options;
  const base = apiBaseUrl.replace(/\/$/, "");
  const hdr = () => secretHeaders(botSharedSecret);

  bot.start(async (ctx) => {
    try {
      const chatId = ctx.chat.id;

      try {
        const look = await axios.post(
          `${base}/bot/lookup-user`,
          { telegram_id: chatId },
          { timeout: 15000, headers: hdr() }
        );
        if (look.data?.registered) {
          const tid = look.data.telegram_id ?? chatId;
          await session.setStep(chatId, STATES.IDLE);
          await ctx.reply(
            `Welcome back to Donish!\n\nYour ID: ${tid}\n\nPasswords are stored securely (hashed) — I can't show your old password. Sign in to the app with this ID and the password you set.\n\nForgot it? Send /reset_password and I'll ask you for a new password.`
          );
          return;
        }
      } catch (err) {
        // eslint-disable-next-line no-console
        console.error(
          "lookup-user error:",
          err?.response?.data || err.message
        );
        await ctx.reply(
          "I couldn't reach Donish right now. Please try /start again in a minute."
        );
        return;
      }

      const persisted =
        (await session.setStep(chatId, STATES.AWAITING_PASSWORD)) !== false;
      if (!persisted) {
        await ctx.reply(
          "Welcome to Donish!\n\nAccount setup is unavailable: the server could not save your session. Ask the admin to create the `telegram_bot_sessions` table in Supabase (see backend/db/migration_telegram_bot_sessions.sql), then try /start again."
        );
        return;
      }

      await ctx.reply(
        "Welcome to Donish!\n\nChoose a password (at least 6 characters, must not start with /). Send it in your next message — you'll sign in to the app with your Telegram ID and this password."
      );
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error("bot.start error:", err);
    }
  });

  bot.command("reset_password", async (ctx) => {
    try {
      const chatId = ctx.chat.id;
      const look = await axios.post(
        `${base}/bot/lookup-user`,
        { telegram_id: chatId },
        { timeout: 15000, headers: hdr() }
      );
      if (!look.data?.registered) {
        await ctx.reply(
          "You don't have a Donish account yet. Send /start to register."
        );
        return;
      }
      const persisted =
        (await session.setStep(chatId, STATES.AWAITING_NEW_PASSWORD)) !== false;
      if (!persisted) {
        await ctx.reply(
          "Can't save your session right now. Try again later or ask the admin to check the bot session database table."
        );
        return;
      }
      await ctx.reply(
        "Send your new password in one message (at least 6 characters, must not start with /). You'll use it with your Donish ID in the app."
      );
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error(
        "reset_password command:",
        err?.response?.data || err.message
      );
      await ctx.reply("Something went wrong. Try /start or try again later.");
    }
  });

  bot.on("text", async (ctx) => {
    try {
      const chatId = ctx.chat.id;
      const message = ctx.message?.text?.trim() ?? "";

      if (message.startsWith("/")) {
        return;
      }

      const step = await session.getStep(chatId);

      if (step === STATES.AWAITING_NEW_PASSWORD) {
        try {
          const resetRes = await axios.post(
            `${base}/bot/reset-password`,
            { telegram_id: chatId, password: message },
            { timeout: 15000, headers: hdr() }
          );
          const tid = resetRes.data?.telegram_id ?? chatId;
          await ctx.reply(
            `Your password was updated.\n\nYour ID: ${tid}\n\nSign in to the Donish app with this ID and your new password.`
          );
        } catch (error) {
          const msg = error?.response?.data?.error;
          // eslint-disable-next-line no-console
          console.error(
            "reset-password error:",
            error?.response?.data || error.message
          );
          await ctx.reply(
            msg ||
              "Could not update your password. Try again or send /reset_password."
          );
        }
        await session.setStep(chatId, STATES.IDLE);
        return;
      }

      if (step === STATES.AWAITING_PASSWORD) {
        const password = message;

        try {
          const createRes = await axios.post(
            `${base}/bot/create-user`,
            { telegram_id: chatId, password },
            { timeout: 15000, headers: hdr() }
          );

          const telegramId = createRes.data?.telegram_id ?? chatId;
          await ctx.reply(
            `Your Donish account is ready!\n\nYour ID: ${telegramId}\nPassword: the one you just sent (save it — I won't show it again).\n\nUse this ID and password to sign in to the Donish app. Keep your ID private.`
          );
          await session.setStep(chatId, STATES.IDLE);
          return;
        } catch (error) {
          const status = error?.response?.status;
          const msg = error?.response?.data?.error;
          // eslint-disable-next-line no-console
          console.error(
            "create-user error:",
            error?.response?.data || error.message
          );
          if (status === 409) {
            await ctx.reply(
              "You already have an account.\n\nSend /start to see your Donish ID. To change your password, send /reset_password."
            );
          } else {
            await ctx.reply(
              msg || "I could not create your account. Please try again later."
            );
          }
          await session.setStep(chatId, STATES.IDLE);
          return;
        }
      }

      await ctx.reply(
        "Send /start to register or see your Donish ID. Forgot your password? Send /reset_password."
      );
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error("bot text handler error:", err);
      try {
        await ctx.reply("Something went wrong. Please try /start again.");
      } catch (_) {}
    }
  });
}
