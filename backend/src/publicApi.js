/** Public HTTPS base URL for the Donish API (EC2 + nginx). */
export const DEFAULT_PUBLIC_API_BASE_URL = "https://api.donish.live";

export function resolvePublicApiBaseUrl() {
  const fromEnv = process.env.API_BASE_URL?.trim();
  if (fromEnv) return fromEnv.replace(/\/$/, "");
  return DEFAULT_PUBLIC_API_BASE_URL;
}

export const TELEGRAM_WEBHOOK_PATH = "/bot/telegram-webhook";

export function telegramWebhookUrl() {
  return `${resolvePublicApiBaseUrl()}${TELEGRAM_WEBHOOK_PATH}`;
}
