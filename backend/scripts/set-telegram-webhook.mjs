/**
 * Point Telegram at the EC2 API webhook (run once after deploy / domain change).
 * Reads TELEGRAM_BOT_TOKEN and optional TELEGRAM_WEBHOOK_SECRET from backend/.env.
 *
 * Usage (from backend/): npm run webhook:set
 * Verify only: npm run webhook:info
 */
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import dotenv from "dotenv";
import {
  DEFAULT_PUBLIC_API_BASE_URL,
  telegramWebhookUrl
} from "../src/publicApi.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const backendRoot = path.resolve(__dirname, "..");
const envPath = path.join(backendRoot, ".env");

dotenv.config({ path: envPath });

const token = process.env.TELEGRAM_BOT_TOKEN?.trim();
const secret = process.env.TELEGRAM_WEBHOOK_SECRET?.trim();
const webhookUrl = telegramWebhookUrl();
const infoOnly = process.argv.includes("--info");

if (!token) {
  console.error(
    `TELEGRAM_BOT_TOKEN is missing. Create ${envPath} (see .env.example) or export the variable.`
  );
  process.exit(1);
}

const apiBase = process.env.API_BASE_URL?.trim() || DEFAULT_PUBLIC_API_BASE_URL;

async function telegramApi(method, params = {}) {
  const url = new URL(`https://api.telegram.org/bot${token}/${method}`);
  Object.entries(params).forEach(([k, v]) => {
    if (v !== undefined && v !== "") url.searchParams.set(k, String(v));
  });
  const res = await fetch(url);
  const data = await res.json();
  if (!data.ok) {
    throw new Error(data.description || `Telegram API ${method} failed`);
  }
  return data.result;
}

async function main() {
  if (infoOnly) {
    const info = await telegramApi("getWebhookInfo");
    console.log(JSON.stringify(info, null, 2));
    return;
  }

  console.log(`API base: ${apiBase}`);
  console.log(`Setting webhook → ${webhookUrl}`);
  if (secret) {
    console.log("Using TELEGRAM_WEBHOOK_SECRET (secret_token).");
  }

  await telegramApi("setWebhook", {
    url: webhookUrl,
    ...(secret ? { secret_token: secret } : {}),
    allowed_updates: JSON.stringify([
      "message",
      "callback_query",
      "my_chat_member"
    ]),
    drop_pending_updates: "true"
  });

  const info = await telegramApi("getWebhookInfo");
  console.log("Webhook registered.");
  console.log(JSON.stringify(info, null, 2));

  if (info.url !== webhookUrl) {
    console.warn(
      `Warning: Telegram reports url=${info.url} but expected ${webhookUrl}`
    );
    process.exit(1);
  }
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
