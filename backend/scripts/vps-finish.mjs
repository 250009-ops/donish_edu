/**
 * Finish VPS deploy after partial run (reconnects fresh SSH each step).
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
  process.env.DB_PASSWORD?.trim() ||
  process.env.VPS_DB_PASSWORD?.trim() ||
  "DonishPg_prod_2026";
const DB_PASSWORD_SQL = DB_PASSWORD.replace(/'/g, "''");

function run(cmd, timeoutMs = 300_000) {
  return new Promise((resolve, reject) => {
    const conn = new Client();
    conn
      .on("ready", () => {
        conn.exec(cmd, { pty: true }, (err, stream) => {
          if (err) {
            conn.end();
            return reject(err);
          }
          let out = "";
          const timer = setTimeout(() => {
            stream.close();
            conn.end();
            reject(new Error("timeout"));
          }, timeoutMs);
          stream
            .on("close", (code) => {
              clearTimeout(timer);
              conn.end();
              if (code === 0) resolve(out);
              else reject(new Error(`exit ${code}: ${out.slice(-1500)}`));
            })
            .on("data", (d) => {
              out += d;
              process.stdout.write(d);
            })
            .stderr.on("data", (d) => process.stderr.write(d));
        });
      })
      .on("error", reject)
      .connect({ host: IP, port: 22, username: "root", password: PASSWORD });
  });
}

if (!IP || !PASSWORD) {
  console.error("IP and PASSWORD required");
  process.exit(1);
}

const envLines = await readFile(path.join(backendRoot, ".env"), "utf8");
let dbUrl = "";
const m = envLines.match(/^DATABASE_URL=(.+)$/m);
if (m) dbUrl = m[1].trim();
if (!dbUrl && DB_PASSWORD) {
  dbUrl = `postgresql://donish:${encodeURIComponent(DB_PASSWORD)}@127.0.0.1:5432/donish`;
}

console.log("=== Sync Postgres password ===");
await run(
  `sudo -u postgres psql -c "ALTER USER donish WITH PASSWORD '${DB_PASSWORD_SQL}';" 2>/dev/null || sudo -u postgres psql -c "CREATE USER donish WITH PASSWORD '${DB_PASSWORD_SQL}';"`
);

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

console.log("=== Health check ===");
try {
  await run("curl -s http://127.0.0.1:4000/health; echo");
} catch {
  console.log("API not up yet, starting...");
}

console.log("\n=== Supabase export + import ===");
try {
  await run(
    `cd /var/www/donish_edu/backend && test -f .env.migrate && cp .env.migrate .env
export DATABASE_URL='${dbUrl.replace(/'/g, "'\\''")}'
npm install @supabase/supabase-js --no-save 2>/dev/null || npm install --include=dev
mkdir -p data && node scripts/export-supabase.mjs && cp .env.production .env 2>/dev/null || true
echo 'DATABASE_URL=${dbUrl.replace(/'/g, "'\\''")}' >> .env
node scripts/import-postgres.mjs`
  );
} catch (e) {
  console.warn("Export/import:", e.message);
}

console.log("\n=== Write production .env ===");
await run(
  `cat > /var/www/donish_edu/backend/.env << 'ENVEOF'
${serverEnv}
ENVEOF`
);

console.log("\n=== PM2 ===");
await run(
  `cd /var/www/donish_edu/backend && pm2 delete donish-api 2>/dev/null || true
pm2 start src/server.js --name donish-api
pm2 save`
);

console.log("\n=== nginx ===");
const nginxConf = `server {
    listen 80;
    server_name ${API_HOST} ${DOMAIN} ${IP};
    client_max_body_size 15m;
    location / {
        proxy_pass http://127.0.0.1:4000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 300s;
    }
}`;
await writeFile(path.join(backendRoot, "nginx-donish.conf"), nginxConf);
const { createReadStream } = await import("node:fs");
await new Promise((resolve, reject) => {
  const conn = new Client();
  conn.on("ready", () => {
    conn.sftp((err, sftp) => {
      if (err) return reject(err);
      const rs = createReadStream(path.join(backendRoot, "nginx-donish.conf"));
      const ws = sftp.createWriteStream("/etc/nginx/sites-available/donish");
      ws.on("close", () => {
        conn.end();
        resolve();
      });
      ws.on("error", reject);
      rs.pipe(ws);
    });
  });
  conn.connect({ host: IP, port: 22, username: "root", password: PASSWORD });
});

await run(
  `ln -sf /etc/nginx/sites-available/donish /etc/nginx/sites-enabled/donish
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx`
);

console.log("\n=== certbot ===");
try {
  await run(
    `apt-get install -y -qq certbot python3-certbot-nginx 2>/dev/null
certbot --nginx -d ${API_HOST} --non-interactive --agree-tos --register-unsafely-without-email --redirect`,
    180_000
  );
} catch (e) {
  console.warn("certbot:", e.message);
}

console.log("\n=== webhook ===");
try {
  await run("cd /var/www/donish_edu/backend && npm run webhook:set");
} catch (e) {
  console.warn("webhook:", e.message);
}

await run("curl -s http://127.0.0.1:4000/health; echo; curl -sI http://127.0.0.1/health | head -5");
console.log("\nDone. Test: https://api.donish.live/health");
