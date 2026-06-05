/**
 * Post-DNS cutover: TLS, production .env, webhook, health checks.
 */
import dotenv from "dotenv";
import { Client } from "ssh2";
import { readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const backendRoot = path.join(__dirname, "..");
dotenv.config({ path: path.join(backendRoot, ".env") });

const IP = process.env.IP?.trim();
const PASSWORD = process.env.PASSWORD?.trim();
const DOMAIN = process.env.DOMAIN?.trim() || "";
const API_HOST = "api.donish.live";
const DB_PASSWORD =
  process.env.DB_PASSWORD?.trim() || "DonishPg_prod_2026";
const dbUrl = `postgresql://donish:${encodeURIComponent(DB_PASSWORD)}@127.0.0.1:5432/donish`;
const DB_PASSWORD_SQL = DB_PASSWORD.replace(/'/g, "''");

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

const envLines = await readFile(path.join(backendRoot, ".env"), "utf8");
const prodEnv = envLines
  .split("\n")
  .filter(
    (l) =>
      !/^(DOMAIN|PASSWORD|IP|DB_PASSWORD)=/i.test(l.trim()) &&
      !/^SUPABASE_/i.test(l.trim()) &&
      !/^AWS_/i.test(l.trim()) &&
      !/^TEXTRACT_/i.test(l.trim()) &&
      !/^DATABASE_URL=/i.test(l.trim()) &&
      l.trim().length > 0
  )
  .join("\n");

const serverEnv = `${prodEnv}\nDATABASE_URL=${dbUrl}\n`;
await writeFile(path.join(backendRoot, ".env.production"), serverEnv);

console.log("=== Postgres + production .env ===");
await run(
  `sudo -u postgres psql -c "ALTER USER donish WITH PASSWORD '${DB_PASSWORD_SQL}';" 2>/dev/null || true`
);
await run(
  `cat > /var/www/donish_edu/backend/.env << 'ENVEOF'
${serverEnv}
ENVEOF`
);

console.log("\n=== PM2 restart ===");
await run(
  `cd /var/www/donish_edu/backend && pm2 restart donish-api --update-env && pm2 save`
);

console.log("\n=== Certbot HTTPS ===");
try {
  await run(
    `certbot --nginx -d ${API_HOST} --non-interactive --agree-tos --register-unsafely-without-email --redirect`,
    180_000
  );
} catch (e) {
  console.warn("Certbot:", e.message);
}

console.log("\n=== Telegram webhook ===");
await run("cd /var/www/donish_edu/backend && npm run webhook:set");
await run("cd /var/www/donish_edu/backend && npm run webhook:info");

console.log("\n=== Health ===");
await run(
  `curl -s http://127.0.0.1:4000/health; echo
curl -s http://${API_HOST}/health; echo
curl -s https://${API_HOST}/health; echo`
);

console.log("\nGo-live complete.");
