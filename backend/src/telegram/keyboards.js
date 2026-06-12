import { Markup } from "telegraf";
import { t } from "./i18n/index.js";

export function languagePicker() {
  return Markup.inlineKeyboard([
    [Markup.button.callback("O'zbek", "lang:uz")],
    [Markup.button.callback("Русский", "lang:ru")],
    [Markup.button.callback("English", "lang:en")]
  ]);
}

/** @param {string} lang */
export function mainMenu(lang) {
  return Markup.inlineKeyboard([
    [Markup.button.callback(t(lang, "menu.download"), "menu:download")],
    [
      Markup.button.callback(t(lang, "menu.account"), "menu:account"),
      Markup.button.callback(t(lang, "menu.feedback"), "menu:feedback")
    ],
    [
      Markup.button.callback(t(lang, "menu.reset"), "menu:reset"),
      Markup.button.callback(t(lang, "menu.subscription"), "menu:subscription")
    ],
    [
      Markup.button.callback(t(lang, "menu.language"), "menu:lang"),
      Markup.button.callback(t(lang, "menu.help"), "menu:help")
    ]
  ]);
}

/** @param {string} lang */
export function downloadPicker(lang) {
  return Markup.inlineKeyboard([
    [
      Markup.button.callback(t(lang, "download.android"), "download:android"),
      Markup.button.callback(t(lang, "download.ios"), "download:ios")
    ],
    [Markup.button.callback(t(lang, "menu.back"), "menu:main")]
  ]);
}

/** @param {string} lang */
export function phoneRequestKeyboard(lang) {
  return Markup.keyboard([
    [Markup.button.contactRequest(t(lang, "btn.share_phone"))],
    [t(lang, "btn.enter_phone")]
  ])
    .oneTime()
    .resize();
}

export function removeKeyboard() {
  return Markup.removeKeyboard();
}

/** @param {string} lang */
export function emailSkipKeyboard(lang) {
  return Markup.inlineKeyboard([
    [Markup.button.callback(t(lang, "onboarding.skip"), "onboard:skip_email")]
  ]);
}

/** @param {string} lang */
export function feedbackDoneKeyboard(lang) {
  return Markup.inlineKeyboard([
    [Markup.button.callback(t(lang, "feedback.done"), "feedback:done")]
  ]);
}

/** @param {string} url */
export function urlButton(label, url) {
  return Markup.inlineKeyboard([[Markup.button.url(label, url)]]);
}
