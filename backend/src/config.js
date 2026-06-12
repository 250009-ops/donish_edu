import dotenv from "dotenv";

dotenv.config();

export const config = {
  port: process.env.PORT || 4000,
  jwtSecret: process.env.JWT_SECRET || "CHANGE_ME_IN_PRODUCTION",
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || "3d",
  databaseUrl: process.env.DATABASE_URL || "",
  openAiApiKey: process.env.OPENAI_API_KEY || "",
  /** When set, Telegram bot must send `X-Bot-Secret` for /bot/create-user. */
  botSharedSecret: process.env.BOT_SHARED_SECRET || "",
  /** Required in production; Telegram sends as X-Telegram-Bot-Api-Secret-Token. */
  telegramWebhookSecret: process.env.TELEGRAM_WEBHOOK_SECRET || "",
  lemonSqueezyApiKey: process.env.LEMON_SQUEEZY_API_KEY || "",
  lemonSqueezyStoreId:
    process.env.LEMON_SQUEEZY_STORE_ID || process.env.STORE_ID || "",
  lemonSqueezyVariantId:
    process.env.LEMON_SQUEEZY_VARIANT_ID || process.env.VARIANT_ID || "",
  lemonSqueezyProductId:
    process.env.LEMON_SQUEEZY_PRODUCT_ID || process.env.PRODUCT_ID || "",
  lemonSqueezyCheckoutUrl: process.env.CHECKOUT_URL || "",
  lemonSqueezyWebhookSecret: process.env.LEMON_SQUEEZY_WEBHOOK_SECRET || "",
  premiumRedirectUrl:
    process.env.PREMIUM_REDIRECT_URL || "https://donish.live/home#pricing",
  premiumPriceUzs: Number(process.env.PREMIUM_PRICE_UZS || "56000"),
  maxDevicesPerUser: Number(process.env.MAX_DEVICES_PER_USER || "3"),
  freeMaxMaterials: Number(process.env.FREE_MAX_MATERIALS || "1"),
  /** Lifetime new-word translations on the free plan (cached taps do not count). */
  freeMaxTranslateTotal: Number(process.env.FREE_MAX_TRANSLATE_TOTAL || "5"),
  premiumMaxTranslatePerDay: Number(
    process.env.PREMIUM_MAX_TRANSLATE_PER_DAY || "500"
  ),
  /** When false, material/translate quotas and checkout are disabled (device limits stay). */
  billingEnabled: process.env.BILLING_ENABLED === "true",
  /** Telegram IDs allowed to upload APK / set iOS URL via bot. */
  botAdminIds: (process.env.BOT_ADMIN_IDS || "")
    .split(",")
    .map((s) => Number(s.trim()))
    .filter((n) => Number.isInteger(n) && n > 0),
  download: {
    apkUrlFallback: process.env.APK_DOWNLOAD_URL || "",
    iosStoreUrl: process.env.IOS_STORE_URL || ""
  },
  adminJwtSecret: process.env.ADMIN_JWT_SECRET || "",
  adminTotpEncKey: process.env.ADMIN_TOTP_ENC_KEY || "",
  adminAccessTtl: process.env.ADMIN_ACCESS_TTL || "30m",
  adminRefreshTtl: process.env.ADMIN_REFRESH_TTL || "7d",
  adminIpAllowlist: (process.env.ADMIN_IP_ALLOWLIST || "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean),
  openAiPricePer1kInput: Number(process.env.OPENAI_PRICE_PER_1K_INPUT || "0.00015"),
  openAiPricePer1kOutput: Number(process.env.OPENAI_PRICE_PER_1K_OUTPUT || "0.0006")
};

/**
 * Fail fast in production with weak or missing secrets.
 * Call once at process startup (see server.js).
 */
export function validateDeploymentConfig() {
  const isProd = process.env.NODE_ENV === "production";
  if (!isProd) return;

  const jwt = process.env.JWT_SECRET || "";
  if (!jwt || jwt === "CHANGE_ME_IN_PRODUCTION" || jwt.length < 32) {
    throw new Error(
      "Production requires JWT_SECRET (at least 32 random characters). Do not use the default placeholder."
    );
  }

  const bot = process.env.BOT_SHARED_SECRET || "";
  if (!bot || bot.length < 16) {
    throw new Error(
      "Production requires BOT_SHARED_SECRET (min 16 chars). Use the same value in the bot's environment and send header X-Bot-Secret."
    );
  }

  const webhook = process.env.TELEGRAM_WEBHOOK_SECRET || "";
  if (!webhook || webhook.length < 16) {
    throw new Error(
      "Production requires TELEGRAM_WEBHOOK_SECRET (min 16 chars). Set it via npm run webhook:set (Telegram secret_token)."
    );
  }

  const db = process.env.DATABASE_URL || "";
  if (!db.trim()) {
    throw new Error(
      "Production requires DATABASE_URL (PostgreSQL connection string)."
    );
  }
}
