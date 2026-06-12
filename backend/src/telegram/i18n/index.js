import { uz } from "./uz.js";
import { ru } from "./ru.js";
import { en } from "./en.js";

const catalogs = { uz, ru, en };
const FALLBACK = "en";

/**
 * @param {string} [lang]
 * @param {string} key
 * @param {Record<string, string|number>} [vars]
 */
export function t(lang, key, vars = {}) {
  const l = catalogs[lang] ? lang : FALLBACK;
  let text = catalogs[l][key] ?? catalogs[FALLBACK][key] ?? key;
  for (const [k, v] of Object.entries(vars)) {
    text = text.replaceAll(`{${k}}`, String(v));
  }
  return text;
}

export function resolveLang(sessionLang, telegramLangCode) {
  if (sessionLang && catalogs[sessionLang]) return sessionLang;
  const code = String(telegramLangCode || "").toLowerCase();
  if (code.startsWith("uz")) return "uz";
  if (code.startsWith("ru")) return "ru";
  if (code.startsWith("en")) return "en";
  return "uz";
}
