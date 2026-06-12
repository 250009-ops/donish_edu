import { t } from "./i18n/index.js";

export const LANGUAGE_LABELS = {
  "O'zbek": "uz",
  Русский: "ru",
  English: "en"
};

/** @param {string} text @param {string} key */
export function matchesKey(text, key) {
  const trimmed = text.trim();
  return ["uz", "ru", "en"].some((lang) => t(lang, key) === trimmed);
}

/** @param {string} text */
export function parseLanguageLabel(text) {
  return LANGUAGE_LABELS[text.trim()] || null;
}
