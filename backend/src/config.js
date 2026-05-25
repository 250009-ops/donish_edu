import dotenv from "dotenv";

dotenv.config();

export const config = {
  port: process.env.PORT || 4000,
  jwtSecret: process.env.JWT_SECRET || "CHANGE_ME_IN_PRODUCTION",
  jwtExpiresIn: "7d",
  supabaseUrl: process.env.SUPABASE_URL || "",
  supabaseServiceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY || "",
  openAiApiKey: process.env.OPENAI_API_KEY || "",
  /** When set, Telegram bot must send `X-Bot-Secret` for /bot/create-user. */
  botSharedSecret: process.env.BOT_SHARED_SECRET || "",
  /** AWS region for Textract + S3 (e.g. us-east-1). */
  awsRegion: process.env.AWS_REGION || "",
  /** Private bucket for temporary PDF uploads before Textract async jobs. */
  textractS3Bucket: process.env.TEXTRACT_S3_BUCKET || ""
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

  const region = process.env.AWS_REGION || "";
  if (!region.trim()) {
    throw new Error(
      "Production requires AWS_REGION for Amazon Textract (e.g. us-east-1)."
    );
  }

  const bucket = process.env.TEXTRACT_S3_BUCKET || "";
  if (!bucket.trim()) {
    throw new Error(
      "Production requires TEXTRACT_S3_BUCKET (private S3 bucket for temporary PDF uploads)."
    );
  }
}
