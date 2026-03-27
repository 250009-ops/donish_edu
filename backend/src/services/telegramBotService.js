import bcrypt from "bcryptjs";
import { Telegraf } from "telegraf";
import { supabaseAdmin } from "../supabaseClient.js";

const botToken = process.env.TELEGRAM_BOT_TOKEN || "";

export const bot = botToken ? new Telegraf(botToken) : null;

function isCommand(text) {
  return typeof text === "string" && text.trim().startsWith("/");
}

async function findUserByTelegramId(telegramId) {
  const { data, error } = await supabaseAdmin
    .from("users")
    .select("id, telegram_id")
    .eq("telegram_id", telegramId)
    .limit(1)
    .maybeSingle();

  if (error) {
    // eslint-disable-next-line no-console
    console.error("find user by telegram_id error:", error);
    return { status: 500, error: "Failed to query user." };
  }

  return { status: 200, data };
}

export async function createDonishUser(telegramId, password) {
  if (!Number.isInteger(telegramId) || !password) {
    return { status: 400, error: "telegram_id and password are required." };
  }

  const existingRes = await findUserByTelegramId(telegramId);
  if (existingRes.status !== 200) {
    return { status: existingRes.status, error: existingRes.error };
  }

  if (existingRes.data) {
    return { status: 409, error: "Already registered. Use the Donish app to sign in." };
  }

  const passwordHash = await bcrypt.hash(password, 10);
  const username = String(telegramId);

  const { data, error } = await supabaseAdmin
    .from("users")
    .insert({
      telegram_id: telegramId,
      username,
      password_hash: passwordHash
    })
    .select("*")
    .single();

  if (error) {
    // eslint-disable-next-line no-console
    console.error("create-user error:", error);
    return { status: 500, error: "Failed to create user." };
  }

  return {
    status: 201,
    data: {
      id: data.id,
      telegram_id: data.telegram_id
    }
  };
}

async function replyAccountReady(ctx, telegramId) {
  await ctx.reply(
    `Your Donish account is ready!\n\nYour ID is: ${telegramId}\n\nUse this ID and your password to sign in to the Donish app. Keep your ID private.`
  );
}

export function ensureBotIsConfiguredOrThrow() {
  if (!bot) {
    const error = new Error("TELEGRAM_BOT_TOKEN is not set. Telegram webhook is not configured.");
    error.statusCode = 503;
    throw error;
  }
}

if (bot) {
  bot.catch((err, ctx) => {
    // eslint-disable-next-line no-console
    console.error("Unhandled bot error:", {
      error: err?.description || err?.message || err,
      updateType: ctx?.updateType
    });
  });

  bot.start(async (ctx) => {
    try {
      await ctx.reply(
        "Welcome to Donish!\n\nTo use the Donish app, send the password you'll use to sign in.\n\nTip: you can send it as a normal message, or use /setpassword <your_password>."
      );
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error("bot.start error:", err);
    }
  });

  bot.command("setpassword", async (ctx) => {
    try {
      const chatId = ctx.chat.id;
      const text = ctx.message?.text || "";
      const password = text.replace(/^\/setpassword(@\w+)?\s*/i, "").trim();
      if (!password) {
        await ctx.reply("Please provide a password. Example: /setpassword myStrongPass123");
        return;
      }

      const createRes = await createDonishUser(chatId, password);
      if (createRes.status === 201) {
        await replyAccountReady(ctx, createRes.data?.telegram_id ?? chatId);
        return;
      }
      if (createRes.status === 409) {
        await ctx.reply(
          "You already have an account. Use your ID and password to sign in to the Donish app."
        );
        return;
      }
      await ctx.reply(createRes.error || "I could not create your account. Please try again later.");
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error("bot setpassword handler error:", err);
      try {
        await ctx.reply("Something went wrong. Please try /start again.");
      } catch (_) {}
    }
  });

  bot.on("text", async (ctx) => {
    try {
      const chatId = ctx.chat.id;
      const message = ctx.message?.text?.trim() ?? "";
      if (!message || isCommand(message)) {
        return;
      }

      const lookupRes = await findUserByTelegramId(chatId);
      if (lookupRes.status !== 200) {
        await ctx.reply(lookupRes.error || "Something went wrong. Please try again.");
        return;
      }

      if (lookupRes.data) {
        await ctx.reply(
          "You already have an account. Use your ID and password to sign in to the Donish app."
        );
        return;
      }

      const createRes = await createDonishUser(chatId, message);
      if (createRes.status === 201) {
        await replyAccountReady(ctx, createRes.data?.telegram_id ?? chatId);
        return;
      }

      if (createRes.status === 409) {
        await ctx.reply(
          "You already have an account. Use your ID and password to sign in to the Donish app."
        );
        return;
      }

      await ctx.reply(
        createRes.error || "I could not create your account. Please try again later."
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

export async function processTelegramUpdate(update) {
  ensureBotIsConfiguredOrThrow();
  return bot.handleUpdate(update);
}

export async function registerBotWebhook(webhookUrl, secretToken) {
  ensureBotIsConfiguredOrThrow();
  await bot.telegram.setWebhook(webhookUrl, {
    secret_token: secretToken
  });
}

export async function getTelegramWebhookInfo() {
  ensureBotIsConfiguredOrThrow();
  return bot.telegram.getWebhookInfo();
}

export function getBotMeta() {
  return {
    isConfigured: Boolean(bot)
  };
}
