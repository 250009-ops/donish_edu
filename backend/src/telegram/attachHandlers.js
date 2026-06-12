import { APP_DISPLAY_NAME } from "../branding.js";
import { config } from "../config.js";
import {
  createTelegramUser,
  lookupTelegramUser,
  MIN_PASSWORD_LEN,
  normalizePhoneE164,
  resetTelegramUserPassword,
  updateTelegramUserProfile,
  validateEmail,
  validateName
} from "../services/botUserOperations.js";
import {
  getCurrentArtifact,
  MAX_UPLOAD_BYTES,
  setCurrentAndroidArtifact,
  setCurrentIosArtifact
} from "../services/appArtifactsService.js";
import { storeInboundMessage } from "../services/supportService.js";
import { buildSubscriptionPayload } from "../services/subscriptionService.js";
import { t, resolveLang } from "./i18n/index.js";
import {
  downloadPicker,
  emailSkipKeyboard,
  feedbackDoneKeyboard,
  languagePicker,
  mainMenu,
  phoneRequestKeyboard,
  removeKeyboard,
  urlButton
} from "./keyboards.js";
import { clearSessionData, getSession, setSession } from "./sessionStore.js";

export const STATES = {
  IDLE: "idle",
  ONBOARD_LANGUAGE: "onboard_language",
  ONBOARD_NAME: "onboard_name",
  ONBOARD_PHONE: "onboard_phone",
  ONBOARD_EMAIL: "onboard_email",
  ONBOARD_PASSWORD: "onboard_password",
  AWAITING_NEW_PASSWORD: "awaiting_new_password",
  EDIT_NAME: "edit_name",
  EDIT_EMAIL: "edit_email",
  EDIT_PHONE: "edit_phone",
  SUPPORT_CHAT: "support_chat"
};

function isAdmin(telegramId) {
  return config.botAdminIds.includes(telegramId);
}

function langOf(session, ctx) {
  return resolveLang(session.language, ctx.from?.language_code);
}

async function persistSession(chatId, patch) {
  const ok = await setSession(chatId, patch);
  if (!ok) {
    throw new Error("session_persist_failed");
  }
}

/**
 * @param {import("telegraf").Telegraf} bot
 * @param {object} options
 */
export function attachDonishBotHandlers(bot, options) {
  const { session, internalUserOps = true } = options;

  const getSess = session?.getStep
    ? async (id) => {
        if (session.getSession) return session.getSession(id);
        return {
          step: await session.getStep(id),
          data: {},
          language: null
        };
      }
    : getSession;

  const setSess = session?.setStep
    ? async (id, patch) => {
        if (session.setSession) return session.setSession(id, patch);
        if (patch.step) return session.setStep(id, patch.step);
        return false;
      }
    : setSession;

  async function showMenu(ctx, lang) {
    await ctx.reply(t(lang, "menu.title"), mainMenu(lang));
  }

  async function handleStart(ctx) {
    const chatId = ctx.chat.id;
    const look = await lookupTelegramUser(chatId);
    if (!look.ok) {
      await ctx.reply(t("uz", "error.api", { app: APP_DISPLAY_NAME }));
      return;
    }

    if (look.registered) {
      const sess = await getSess(chatId);
      const lang = resolveLang(look.language || sess.language, ctx.from?.language_code);
      await setSess(chatId, { step: STATES.IDLE, language: lang });
      const name = look.full_name;
      const welcome = name
        ? t(lang, "welcome.back", { app: APP_DISPLAY_NAME, name })
        : t(lang, "welcome.back_no_name", { app: APP_DISPLAY_NAME });
      await ctx.reply(
        `${welcome}\n\n${t(lang, "account.id", { id: look.telegram_id })}`,
        mainMenu(lang)
      );
      if (!look.profile_complete) {
        await ctx.reply(t(lang, "account.incomplete"));
      }
      return;
    }

    await setSess(chatId, {
      step: STATES.ONBOARD_LANGUAGE,
      data: {},
      language: null
    });
    await ctx.reply(
      t("uz", "welcome.new", { app: APP_DISPLAY_NAME }) +
        "\n\n" +
        t("uz", "onboarding.pick_language"),
      languagePicker()
    );
  }

  bot.start(handleStart);
  bot.command("menu", async (ctx) => {
    const sess = await getSess(ctx.chat.id);
    const lang = langOf(sess, ctx);
    await setSess(ctx.chat.id, { step: STATES.IDLE });
    await showMenu(ctx, lang);
  });

  bot.command("cancel", async (ctx) => {
    const sess = await getSess(ctx.chat.id);
    const lang = langOf(sess, ctx);
    await clearSessionData(ctx.chat.id);
    await setSess(ctx.chat.id, { step: STATES.IDLE, language: sess.language });
    await ctx.reply(t(lang, "menu.back"), removeKeyboard());
    await showMenu(ctx, lang);
  });

  bot.command("download", async (ctx) => {
    const sess = await getSess(ctx.chat.id);
    const lang = langOf(sess, ctx);
    await ctx.reply(t(lang, "download.pick", { app: APP_DISPLAY_NAME }), downloadPicker(lang));
  });

  bot.command("account", async (ctx) => {
    await handleAccount(ctx, getSess, setSess);
  });

  bot.command("language", async (ctx) => {
    const sess = await getSess(ctx.chat.id);
    const lang = langOf(sess, ctx);
    await ctx.reply(t(lang, "onboarding.pick_language"), languagePicker());
  });

  bot.command("help", async (ctx) => {
    const sess = await getSess(ctx.chat.id);
    await ctx.reply(t(langOf(sess, ctx), "help.text"));
  });

  bot.command("reset_password", async (ctx) => {
    const chatId = ctx.chat.id;
    const sess = await getSess(chatId);
    const lang = langOf(sess, ctx);
    const look = await lookupTelegramUser(chatId);
    if (!look.ok || !look.registered) {
      await ctx.reply(t(lang, "idle.hint"));
      return;
    }
    await setSess(chatId, { step: STATES.AWAITING_NEW_PASSWORD });
    await ctx.reply(
      t(lang, "reset.prompt", { min: MIN_PASSWORD_LEN }),
      removeKeyboard()
    );
  });

  bot.command("upload_app", async (ctx) => {
    if (!isAdmin(ctx.from.id)) return;
    await ctx.reply("Send me the .apk file. Put version in caption, e.g. 1.0.0");
  });

  bot.command("set_ios_url", async (ctx) => {
    if (!isAdmin(ctx.from.id)) return;
    const parts = (ctx.message.text || "").split(/\s+/);
    const url = parts[1];
    if (!url || !/^https?:\/\//i.test(url)) {
      await ctx.reply("Usage: /set_ios_url https://apps.apple.com/...");
      return;
    }
    const version = parts[2] || null;
    await setCurrentIosArtifact({
      storeUrl: url,
      versionName: version,
      uploadedBy: ctx.from.id
    });
    await ctx.reply(`iOS link saved${version ? ` (v${version})` : ""}.`);
  });

  bot.on("callback_query", async (ctx) => {
    try {
      const data = ctx.callbackQuery?.data || "";
      const chatId = ctx.chat.id;
      const sess = await getSess(chatId);
      let lang = langOf(sess, ctx);

      if (data.startsWith("lang:")) {
        const picked = data.slice(5);
        if (!["uz", "ru", "en"].includes(picked)) return ctx.answerCbQuery();
        lang = picked;
        const look = await lookupTelegramUser(chatId);
        if (look.registered) {
          await updateTelegramUserProfile(chatId, { language: picked });
          await setSess(chatId, { step: STATES.IDLE, language: picked });
          await ctx.answerCbQuery();
          await ctx.reply(t(lang, "lang.changed"), mainMenu(lang));
          return;
        }
        await setSess(chatId, {
          step: STATES.ONBOARD_NAME,
          language: picked,
          data: sess.data
        });
        await ctx.answerCbQuery();
        await ctx.editMessageText(t(lang, "onboarding.ask_name"));
        return;
      }

      if (data === "menu:main") {
        await setSess(chatId, { step: STATES.IDLE });
        await ctx.answerCbQuery();
        await showMenu(ctx, lang);
        return;
      }

      if (data === "menu:download") {
        await ctx.answerCbQuery();
        await ctx.reply(t(lang, "download.pick", { app: APP_DISPLAY_NAME }), downloadPicker(lang));
        return;
      }

      if (data === "download:android") {
        await ctx.answerCbQuery();
        const art = await getCurrentArtifact("android");
        if (art?.file_id) {
          await ctx.replyWithDocument(art.file_id, {
            caption: t(lang, "download.android_sent", { app: APP_DISPLAY_NAME })
          });
        } else if (config.download.apkUrlFallback) {
          await ctx.reply(
            t(lang, "download.android_missing"),
            urlButton("Download APK", config.download.apkUrlFallback)
          );
        } else {
          await ctx.reply(t(lang, "download.android_missing"));
        }
        return;
      }

      if (data === "download:ios") {
        await ctx.answerCbQuery();
        const art = await getCurrentArtifact("ios");
        const url = art?.store_url || config.download.iosStoreUrl;
        if (url) {
          await ctx.reply(
            t(lang, "download.ios_link", { app: APP_DISPLAY_NAME }),
            urlButton("App Store", url)
          );
        } else {
          await ctx.reply(t(lang, "download.ios_coming"));
        }
        return;
      }

      if (data === "menu:account") {
        await ctx.answerCbQuery();
        await handleAccount(ctx, getSess, setSess);
        return;
      }

      if (data === "menu:feedback") {
        await setSess(chatId, { step: STATES.SUPPORT_CHAT });
        await ctx.answerCbQuery();
        await ctx.reply(t(lang, "feedback.prompt"), feedbackDoneKeyboard(lang));
        return;
      }

      if (data === "feedback:done") {
        await setSess(chatId, { step: STATES.IDLE });
        await ctx.answerCbQuery();
        await showMenu(ctx, lang);
        return;
      }

      if (data === "menu:reset") {
        await ctx.answerCbQuery();
        const look = await lookupTelegramUser(chatId);
        if (!look.registered) {
          await ctx.reply(t(lang, "idle.hint"));
          return;
        }
        await setSess(chatId, { step: STATES.AWAITING_NEW_PASSWORD });
        await ctx.reply(t(lang, "reset.prompt", { min: MIN_PASSWORD_LEN }), removeKeyboard());
        return;
      }

      if (data === "menu:subscription") {
        await ctx.answerCbQuery();
        const look = await lookupTelegramUser(chatId);
        if (!look.registered) {
          await ctx.reply(t(lang, "idle.hint"));
          return;
        }
        const sub = await buildSubscriptionPayload(look.user_id);
        const plan = sub?.is_premium
          ? t(lang, "subscription.premium")
          : t(lang, "subscription.free");
        await ctx.reply(plan);
        return;
      }

      if (data === "menu:lang") {
        await ctx.answerCbQuery();
        await ctx.reply(t(lang, "onboarding.pick_language"), languagePicker());
        return;
      }

      if (data === "menu:help") {
        await ctx.answerCbQuery();
        await ctx.reply(t(lang, "help.text"));
        return;
      }

      if (data === "onboard:skip_email") {
        await setSess(chatId, {
          step: STATES.ONBOARD_PASSWORD,
          mergeData: true,
          data: { ...sess.data, email: null }
        });
        await ctx.answerCbQuery();
        await ctx.editMessageReplyMarkup({ inline_keyboard: [] });
        await ctx.reply(
          t(lang, "onboarding.ask_password", { min: MIN_PASSWORD_LEN }),
          removeKeyboard()
        );
        return;
      }

      await ctx.answerCbQuery();
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error("callback_query:", err);
      try {
        await ctx.answerCbQuery();
      } catch (_) {}
    }
  });

  bot.on("contact", async (ctx) => {
    try {
      const chatId = ctx.chat.id;
      const sess = await getSess(chatId);
      const lang = langOf(sess, ctx);
      if (sess.step !== STATES.ONBOARD_PHONE && sess.step !== STATES.EDIT_PHONE) return;

      const contact = ctx.message.contact;
      const phone = normalizePhoneE164(contact?.phone_number || "");
      if (!phone) {
        await ctx.reply(t(lang, "onboarding.invalid_phone"));
        return;
      }

      if (sess.step === STATES.EDIT_PHONE) {
        await updateTelegramUserProfile(chatId, { phone_e164: phone });
        await setSess(chatId, { step: STATES.IDLE });
        await ctx.reply(t(lang, "lang.changed"), removeKeyboard());
        await showMenu(ctx, lang);
        return;
      }

      await setSess(chatId, {
        step: STATES.ONBOARD_EMAIL,
        mergeData: true,
        data: { phone_e164: phone }
      });
      await ctx.reply(t(lang, "onboarding.ask_email"), {
        ...emailSkipKeyboard(lang),
        ...removeKeyboard()
      });
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error("contact handler:", err);
    }
  });

  bot.on("document", async (ctx) => {
    if (!isAdmin(ctx.from?.id)) return;
    const doc = ctx.message.document;
    const name = (doc.file_name || "").toLowerCase();
    if (!name.endsWith(".apk")) {
      await ctx.reply("Please send an .apk file (not .aab).");
      return;
    }
    if (doc.file_size > MAX_UPLOAD_BYTES) {
      await ctx.reply("File too large (>50 MB). Use APK_DOWNLOAD_URL fallback.");
      return;
    }
    const version = (ctx.message.caption || "").trim() || null;
    await setCurrentAndroidArtifact({
      fileId: doc.file_id,
      fileUniqueId: doc.file_unique_id,
      fileName: doc.file_name,
      sizeBytes: doc.file_size,
      versionName: version,
      uploadedBy: ctx.from.id
    });
    await ctx.reply(
      `Saved ${doc.file_name} (${Math.round(doc.file_size / 1024)} KB) as current Android build${version ? ` v${version}` : ""}.`
    );
  });

  bot.on("text", async (ctx) => {
    try {
      const chatId = ctx.chat.id;
      const message = ctx.message?.text?.trim() ?? "";
      if (message.startsWith("/")) return;

      const sess = await getSess(chatId);
      const lang = langOf(sess, ctx);

      if (sess.step === STATES.SUPPORT_CHAT) {
        if (!message) return;
        const look = await lookupTelegramUser(chatId);
        const { query: dbQuery } = await import("../db/pool.js");
        const { rows: countRows } = await dbQuery(
          `select count(*)::int as n from support_messages
           where telegram_id = $1 and direction = 'in'`,
          [chatId]
        );
        const prior = countRows[0]?.n ?? 0;
        await storeInboundMessage({
          telegramId: chatId,
          userId: look.registered ? look.user_id : null,
          body: message.slice(0, 4000)
        });
        await ctx.reply(
          prior === 0 ? t(lang, "feedback.ack") : t(lang, "feedback.sent"),
          feedbackDoneKeyboard(lang)
        );
        return;
      }

      if (sess.step === STATES.AWAITING_NEW_PASSWORD) {
        const resetRes = await resetTelegramUserPassword(chatId, message);
        if (resetRes.ok) {
          await ctx.reply(
            t(lang, "reset.done", { id: resetRes.telegram_id ?? chatId })
          );
        } else {
          await ctx.reply(resetRes.error || t(lang, "error.generic"));
        }
        await setSess(chatId, { step: STATES.IDLE });
        await showMenu(ctx, lang);
        return;
      }

      if (sess.step === STATES.ONBOARD_NAME) {
        const err = validateName(message);
        if (err) {
          await ctx.reply(t(lang, "onboarding.invalid_name"));
          return;
        }
        await setSess(chatId, {
          step: STATES.ONBOARD_PHONE,
          mergeData: true,
          data: { full_name: message.trim() }
        });
        await ctx.reply(t(lang, "onboarding.ask_phone"), phoneRequestKeyboard(lang));
        return;
      }

      if (sess.step === STATES.ONBOARD_PHONE) {
        if (message === t(lang, "btn.enter_phone")) {
          await ctx.reply(t(lang, "onboarding.invalid_phone"));
          return;
        }
        const phone = normalizePhoneE164(message);
        if (!phone) {
          await ctx.reply(t(lang, "onboarding.invalid_phone"));
          return;
        }
        await setSess(chatId, {
          step: STATES.ONBOARD_EMAIL,
          mergeData: true,
          data: { phone_e164: phone }
        });
        await ctx.reply(t(lang, "onboarding.ask_email"), {
          ...emailSkipKeyboard(lang),
          ...removeKeyboard()
        });
        return;
      }

      if (sess.step === STATES.ONBOARD_EMAIL) {
        if (message.toLowerCase() === t(lang, "onboarding.skip").toLowerCase()) {
          await setSess(chatId, {
            step: STATES.ONBOARD_PASSWORD,
            mergeData: true,
            data: { email: null }
          });
        } else {
          const err = validateEmail(message);
          if (err) {
            await ctx.reply(t(lang, "onboarding.invalid_email"));
            return;
          }
          await setSess(chatId, {
            step: STATES.ONBOARD_PASSWORD,
            mergeData: true,
            data: { email: message.trim().toLowerCase() }
          });
        }
        await ctx.reply(
          t(lang, "onboarding.ask_password", { min: MIN_PASSWORD_LEN }),
          removeKeyboard()
        );
        return;
      }

      if (sess.step === STATES.ONBOARD_PASSWORD) {
        const profile = {
          full_name: sess.data.full_name,
          phone_e164: sess.data.phone_e164,
          email: sess.data.email,
          language: sess.language || "uz"
        };
        const createRes = await createTelegramUser(chatId, message, profile);
        if (createRes.ok) {
          const tid = createRes.telegram_id ?? chatId;
          await ctx.reply(
            t(lang, "onboarding.done", {
              app: APP_DISPLAY_NAME,
              id: tid,
              name: profile.full_name
            }),
            downloadPicker(lang)
          );
        } else if (createRes.status === 409) {
          await ctx.reply(t(lang, "idle.hint"));
        } else {
          await ctx.reply(createRes.error || t(lang, "error.generic"));
        }
        await setSess(chatId, { step: STATES.IDLE, data: {} });
        return;
      }

      if (
        sess.step === STATES.EDIT_NAME ||
        sess.step === STATES.EDIT_EMAIL ||
        sess.step === STATES.EDIT_PHONE
      ) {
        const patch = {};
        if (sess.step === STATES.EDIT_NAME) patch.full_name = message;
        if (sess.step === STATES.EDIT_EMAIL) patch.email = message;
        if (sess.step === STATES.EDIT_PHONE) patch.phone_e164 = message;
        const res = await updateTelegramUserProfile(chatId, patch);
        await setSess(chatId, { step: STATES.IDLE });
        await ctx.reply(res.ok ? t(lang, "lang.changed") : res.error || t(lang, "error.generic"));
        await showMenu(ctx, lang);
        return;
      }

      await ctx.reply(t(lang, "idle.hint"), mainMenu(lang));
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error("bot text handler:", err);
      try {
        await ctx.reply(t("uz", "error.generic"));
      } catch (_) {}
    }
  });

  bot.telegram.setMyCommands([
    { command: "start", description: "Open Gotcha / main menu" },
    { command: "download", description: "Get the app" },
    { command: "account", description: "My profile" },
    { command: "language", description: "Change language" },
    { command: "help", description: "Help" }
  ]).catch(() => {});
}

async function handleAccount(ctx, getSess, setSess) {
  const chatId = ctx.chat.id;
  const sess = await getSess(chatId);
  const lang = resolveLang(sess.language, ctx.from?.language_code);
  const look = await lookupTelegramUser(chatId);
  if (!look.ok || !look.registered) {
    await ctx.reply(t(lang, "idle.hint"));
    return;
  }
  const lines = [
    t(lang, "account.title"),
    t(lang, "account.id", { id: look.telegram_id }),
    t(lang, "account.name", { name: look.full_name || "—" }),
    t(lang, "account.email", { email: look.email || "—" }),
    t(lang, "account.phone", { phone: look.phone_e164 || "—" }),
    t(lang, "account.language", { lang: look.language || "uz" })
  ];
  await ctx.reply(lines.join("\n"), mainMenu(lang));
}
