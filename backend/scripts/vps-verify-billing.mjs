/**
 * Verify billing + webhook endpoints on production VPS.
 */
import crypto from "node:crypto";
import dotenv from "dotenv";
import { Client } from "ssh2";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, "..", ".env") });

const IP = process.env.IP?.trim();
const PASSWORD = process.env.PASSWORD?.trim();
const WEBHOOK_SECRET = process.env.LEMON_SQUEEZY_WEBHOOK_SECRET?.trim() || "";

function ssh(cmd) {
  return new Promise((resolve, reject) => {
    const conn = new Client();
    let out = "";
    conn.on("ready", () => {
      conn.exec(cmd, { pty: true }, (err, stream) => {
        if (err) return reject(err);
        stream.on("data", (d) => {
          out += d.toString();
          process.stdout.write(d);
        });
        stream.on("close", (code) => {
          conn.end();
          code === 0 ? resolve(out) : reject(new Error(`exit ${code}`));
        });
      });
    });
    conn.connect({ host: IP, port: 22, username: "root", password: PASSWORD });
  });
}

if (!IP || !PASSWORD) {
  console.error("IP and PASSWORD required in backend/.env");
  process.exit(1);
}

console.log("=== API health ===");
await ssh("curl -s https://api.donish.live/health && echo");

console.log("\n=== Webhook without signature (expect 401) ===");
await ssh(
  `code=$(curl -s -o /tmp/wh.json -w "%{http_code}" -X POST https://api.donish.live/webhooks/lemon-squeezy -H "Content-Type: application/json" -d '{"meta":{"event_name":"test"}}')
echo "HTTP $code"
cat /tmp/wh.json
echo`
);

if (WEBHOOK_SECRET) {
  const body = JSON.stringify({
    meta: {
      event_name: "subscription_created",
      custom_data: { user_id: "00000000-0000-4000-8000-000000000099" }
    },
    data: {
      type: "subscriptions",
      id: "999999",
      attributes: { status: "active", customer_id: "1" }
    }
  });
  const sig = crypto.createHmac("sha256", WEBHOOK_SECRET).update(body).digest("hex");
  const b64 = Buffer.from(body, "utf8").toString("base64");
  const sigEsc = sig.replace(/'/g, "'\\''");

  console.log("\n=== Webhook with valid signature (expect 200) ===");
  await ssh(
    `body=$(echo '${b64}' | base64 -d)
code=$(curl -s -o /tmp/wh2.json -w "%{http_code}" -X POST https://api.donish.live/webhooks/lemon-squeezy -H "Content-Type: application/json" -H "X-Signature: ${sigEsc}" -d "$body")
echo "HTTP $code"
cat /tmp/wh2.json
echo`
  );
} else {
  console.warn("\nSkipping signed webhook test — LEMON_SQUEEZY_WEBHOOK_SECRET not set locally.");
}

console.log("\n=== VPS env keys (names only) ===");
await ssh(
  "grep -E '^(LEMON_SQUEEZY_|STORE_ID|VARIANT_ID|CHECKOUT_URL|FREE_MAX|MAX_DEVICES)' /var/www/donish_edu/backend/.env | cut -d= -f1 | sort"
);

console.log("\n=== PM2 status ===");
await ssh("pm2 status donish-api 2>/dev/null | tail -5");

console.log("\nBilling verification complete.");
