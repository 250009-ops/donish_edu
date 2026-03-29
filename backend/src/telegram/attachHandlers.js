import axios from "axios";

export const STATES = {
  IDLE: "idle",
  AWAITING_PASSWORD: "awaiting_password"
};

/**
 * @typedef {object} SessionAdapter
 * @property {(chatId: number) => Promise<string>} getStep
 * @property {(chatId: number, step: string) => Promise<void>} setStep
 */

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

  bot.start(async (ctx) => {
    try {
      const chatId = ctx.chat.id;
      await session.setStep(chatId, STATES.AWAITING_PASSWORD);

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
      const step = await session.getStep(chatId);

      if (step === STATES.AWAITING_PASSWORD) {
        const password = message;

        try {
          const headers = { "Content-Type": "application/json" };
          if (botSharedSecret) {
            headers["X-Bot-Secret"] = botSharedSecret;
          }
          const createRes = await axios.post(
            `${apiBaseUrl.replace(/\/$/, "")}/bot/create-user`,
            { telegram_id: chatId, password },
            { timeout: 15000, headers }
          );

          const telegramId = createRes.data?.telegram_id ?? chatId;
          await ctx.reply(
            `Your Donish account is ready!\n\nYour ID is: ${telegramId}\n\nUse this ID and your password to sign in to the Donish app. Keep your ID private.`
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
              "You already have an account. Use your ID and password to sign in to the Donish app."
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
}
