import { Markup } from "telegraf";
import { t } from "./i18n/index.js";

/** Persistent reply keyboard — main submenu at the bottom of the chat. */
export function mainMenuReply(lang) {
  return Markup.keyboard([
    [t(lang, "menu.download")],
    [t(lang, "menu.account"), t(lang, "menu.feedback")],
    [t(lang, "menu.reset"), t(lang, "menu.subscription")],
    [t(lang, "menu.language"), t(lang, "menu.help")]
  ]).resize();
}

export function languageReply(lang, { withBack = false } = {}) {
  const rows = [["O'zbek", "Русский", "English"]];
  if (withBack) rows.push([t(lang, "menu.back")]);
  return Markup.keyboard(rows).resize();
}

export function downloadReply(lang) {
  return Markup.keyboard([
    [t(lang, "download.android"), t(lang, "download.ios")],
    [t(lang, "menu.back")]
  ]).resize();
}

export function phoneRequestReply(lang) {
  return Markup.keyboard([
    [Markup.button.contactRequest(t(lang, "btn.share_phone"))],
    [t(lang, "btn.enter_phone")]
  ])
    .resize()
    .oneTime();
}

export function emailSkipReply(lang) {
  return Markup.keyboard([[t(lang, "onboarding.skip")]]).resize().oneTime();
}

export function feedbackDoneReply(lang) {
  return Markup.keyboard([[t(lang, "feedback.done")]]).resize();
}

export function backOnlyReply(lang) {
  return Markup.keyboard([[t(lang, "menu.back")]]).resize();
}

export function removeKeyboard() {
  return Markup.removeKeyboard();
}
