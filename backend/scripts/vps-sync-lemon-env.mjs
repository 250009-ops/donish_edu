/**
 * Merge Lemon Squeezy + plan limit vars from local backend/.env into VPS backend/.env
 */
import dotenv from "dotenv";
import { Client } from "ssh2";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const backendRoot = path.join(__dirname, "..");
dotenv.config({ path: path.join(backendRoot, ".env") });

const IP = process.env.IP?.trim();
const PASSWORD = process.env.PASSWORD?.trim();

const KEYS = [
  "BILLING_ENABLED",
  "LEMON_SQUEEZY_API_KEY",
  "LEMON_SQUEEZY_STORE_ID",
  "STORE_ID",
  "LEMON_SQUEEZY_VARIANT_ID",
  "VARIANT_ID",
  "LEMON_SQUEEZY_PRODUCT_ID",
  "PRODUCT_ID",
  "LEMON_SQUEEZY_WEBHOOK_SECRET",
  "CHECKOUT_URL",
  "PREMIUM_PRICE_UZS",
  "PREMIUM_REDIRECT_URL",
  "MAX_DEVICES_PER_USER",
  "FREE_MAX_MATERIALS",
  "FREE_MAX_TRANSLATE_TOTAL",
  "PREMIUM_MAX_TRANSLATE_PER_DAY"
];

function runSsh(cmd) {
  return new Promise((resolve, reject) => {
    const conn = new Client();
    let out = "";
    conn.on("ready", () => {
      conn.exec(cmd, { pty: true }, (err, stream) => {
        if (err) return reject(err);
        stream.on("data", (d) => {
          out += d.toString();
        });
        stream.on("close", (code) => {
          conn.end();
          code === 0 ? resolve(out) : reject(new Error(`exit ${code}: ${out}`));
        });
      });
    });
    conn.connect({ host: IP, port: 22, username: "root", password: PASSWORD });
  });
}

if (!IP || !PASSWORD) {
  console.error("IP and PASSWORD required");
  process.exit(1);
}

const lines = [];
for (const key of KEYS) {
  const val = process.env[key]?.trim();
  if (val) lines.push(`${key}=${val}`);
}

if (!lines.length) {
  console.error("No Lemon/plan vars in local .env");
  process.exit(1);
}

const remotePath = "/var/www/donish_edu/backend/.env";
const block = `\n# Lemon Squeezy + plan limits (synced)\n${lines.join("\n")}\n`;
const b64 = Buffer.from(block, "utf8").toString("base64");

await runSsh(
  `test -f ${remotePath} || touch ${remotePath}
for k in ${KEYS.join(" ")}; do sed -i "/^$k=/d" ${remotePath}; done
echo '${b64}' | base64 -d >> ${remotePath}
echo "Merged ${lines.length} env keys into ${remotePath}"
pm2 restart donish-api`
);

console.log("Lemon env synced to VPS.");
