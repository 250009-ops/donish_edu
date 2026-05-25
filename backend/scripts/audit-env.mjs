/**
 * Lists required env keys in backend/.env (values redacted). Exit 1 if any are missing.
 * Usage: npm run env:audit
 */
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import dotenv from "dotenv";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const envPath = path.resolve(__dirname, "..", ".env");

const REQUIRED = [
  "NODE_ENV",
  "PORT",
  "API_BASE_URL",
  "JWT_SECRET",
  "BOT_SHARED_SECRET",
  "SUPABASE_URL",
  "SUPABASE_SERVICE_ROLE_KEY",
  "OPENAI_API_KEY",
  "AWS_REGION",
  "TEXTRACT_S3_BUCKET",
  "TELEGRAM_BOT_TOKEN"
];

const OPTIONAL = ["TELEGRAM_WEBHOOK_SECRET"];

if (!fs.existsSync(envPath)) {
  console.error(`Missing ${envPath} — copy from .env.example`);
  process.exit(1);
}

dotenv.config({ path: envPath });

const missing = [];
const weak = [];

for (const key of REQUIRED) {
  const v = process.env[key]?.trim() ?? "";
  if (!v || v.includes("your-") || v.includes("change-me")) {
    missing.push(key);
  }
}

const jwt = process.env.JWT_SECRET?.trim() ?? "";
if (jwt && jwt.length < 32) weak.push("JWT_SECRET (need ≥ 32 chars in production)");

const bot = process.env.BOT_SHARED_SECRET?.trim() ?? "";
if (bot && bot.length < 16) weak.push("BOT_SHARED_SECRET (need ≥ 16 chars)");

const api = process.env.API_BASE_URL?.trim() ?? "";
if (api && !api.startsWith("https://api.donish.live")) {
  weak.push(`API_BASE_URL should be https://api.donish.live (got ${api})`);
}

console.log(`Audited ${envPath}`);
console.log("Present keys:", [...REQUIRED, ...OPTIONAL].filter((k) => process.env[k]?.trim()).join(", "));
if (missing.length) {
  console.error("Missing or placeholder:", missing.join(", "));
}
if (weak.length) {
  console.warn("Warnings:", weak.join("; "));
}

process.exit(missing.length ? 1 : 0);
