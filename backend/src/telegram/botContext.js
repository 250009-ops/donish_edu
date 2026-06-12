/** Shared bot instance reference (set by telegramWebhook.js). */
/** @type {import('telegraf').Telegraf | null} */
let botInstance = null;

/** @param {import('telegraf').Telegraf} bot */
export function setBotInstance(bot) {
  botInstance = bot;
}

export function getBotInstance() {
  return botInstance;
}
