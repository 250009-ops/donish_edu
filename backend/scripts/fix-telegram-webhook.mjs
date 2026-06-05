/**
 * Reset Telegram webhook so delivery uses VPS IP (not cached EC2).
 */
import dotenv from "dotenv";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { telegramWebhookUrl } from "../src/publicApi.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, "..", ".env") });

const token = process.env.TELEGRAM_BOT_TOKEN?.trim();
const vpsIp = process.env.IP?.trim() || "170.168.6.42";
const secret = process.env.TELEGRAM_WEBHOOK_SECRET?.trim();
const webhookUrl = telegramWebhookUrl();

if (!token) {
  console.error("TELEGRAM_BOT_TOKEN missing");
  process.exit(1);
}

async function api(method, params = {}) {
  const url = new URL(`https://api.telegram.org/bot${token}/${method}`);
  for (const [k, v] of Object.entries(params)) {
    if (v !== undefined && v !== "") url.searchParams.set(k, String(v));
  }
  const res = await fetch(url);
  const data = await res.json();
  if (!data.ok) throw new Error(data.description || method);
  return data.result;
}

console.log("Before:", JSON.stringify(await api("getWebhookInfo"), null, 2));

await api("deleteWebhook", { drop_pending_updates: "true" });
console.log("Deleted webhook.");

await api("setWebhook", {
  url: webhookUrl,
  ip_address: vpsIp,
  ...(secret ? { secret_token: secret } : {}),
  allowed_updates: JSON.stringify(["message", "callback_query", "my_chat_member"]),
  drop_pending_updates: "true"
});

const after = await api("getWebhookInfo");
console.log("After:", JSON.stringify(after, null, 2));

if (after.url !== webhookUrl) {
  console.error("URL mismatch");
  process.exit(1);
}
if (after.ip_address !== vpsIp) {
  console.warn(`ip_address is ${after.ip_address}, expected ${vpsIp}`);
}
console.log("Webhook fixed.");
