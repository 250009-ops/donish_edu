import dotenv from "dotenv";

dotenv.config();

export const config = {
  port: process.env.PORT || 4000,
  jwtSecret: process.env.JWT_SECRET || "CHANGE_ME_IN_PRODUCTION",
  jwtExpiresIn: "7d",
  databaseUrl: process.env.DATABASE_URL || "",
  openAiApiKey: process.env.OPENAI_API_KEY || "",
  /** When set, Telegram bot must send `X-Bot-Secret` for /bot/create-user. */
  botSharedSecret: process.env.BOT_SHARED_SECRET || "",
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
  billingEnabled: process.env.BILLING_ENABLED === "true"
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

  const db = process.env.DATABASE_URL || "";
  if (!db.trim()) {
    throw new Error(
      "Production requires DATABASE_URL (PostgreSQL connection string)."
    );
  }
}
