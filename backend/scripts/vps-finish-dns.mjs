/**
 * Post-Namecheap DNS: TLS for donish.live + www, verify site & API.
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

function run(cmd, timeoutMs = 300_000) {
  return new Promise((resolve, reject) => {
    const conn = new Client();
    conn.on("ready", () => {
      conn.exec(cmd, { pty: true }, (err, stream) => {
        if (err) return reject(err);
        const timer = setTimeout(() => {
          stream.close();
          conn.end();
          reject(new Error("timeout"));
        }, timeoutMs);
        stream
          .on("close", (code) => {
            clearTimeout(timer);
            conn.end();
            code === 0 ? resolve() : reject(new Error(`exit ${code}`));
          })
          .on("data", (d) => process.stdout.write(d))
          .stderr.on("data", (d) => process.stderr.write(d));
      });
    });
    conn.connect({ host: IP, port: 22, username: "root", password: PASSWORD });
  });
}

if (!IP || !PASSWORD) {
  console.error("IP and PASSWORD required in backend/.env");
  process.exit(1);
}

console.log("=== DNS from VPS ===");
await run(
  `dig +short donish.live A @8.8.8.8
dig +short www.donish.live A @8.8.8.8
dig +short api.donish.live A @8.8.8.8`
);

console.log("\n=== Certbot: donish.live + www ===");
try {
  await run(
    `apt-get install -y -qq certbot python3-certbot-nginx 2>/dev/null || true
certbot --nginx -d donish.live -d www.donish.live --non-interactive --agree-tos --register-unsafely-without-email --redirect`,
    240_000
  );
} catch (e) {
  console.warn("donish.live certbot:", e.message);
}

console.log("\n=== Ensure api.donish.live TLS ===");
try {
  await run(
    `certbot --nginx -d api.donish.live --non-interactive --agree-tos --register-unsafely-without-email --redirect`,
    180_000
  );
} catch (e) {
  console.warn("api certbot (may already exist):", e.message);
}

console.log("\n=== HTTPS checks ===");
await run(
  `curl -sI https://donish.live/ | head -3
curl -sI https://donish.live/home/ | head -3
curl -sI https://www.donish.live/home/ | head -3
curl -s https://api.donish.live/health
echo
pm2 status donish-api | head -5`
);

console.log("\nDone.");
