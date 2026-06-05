/**
 * Provision Eskiz VPS and deploy Donish backend.
 * Reads IP, PASSWORD, DOMAIN from backend/.env
 */
import dotenv from "dotenv";
import { Client } from "ssh2";
import { readFile, writeFile, mkdir } from "node:fs/promises";
import { createReadStream } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { execSync } from "node:child_process";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const backendRoot = path.join(__dirname, "..");
const projectRoot = path.join(backendRoot, "..");

dotenv.config({ path: path.join(backendRoot, ".env") });

const IP = process.env.IP?.trim();
const PASSWORD = process.env.PASSWORD?.trim();
const DOMAIN = process.env.DOMAIN?.trim() || "";
const API_HOST = process.env.API_BASE_URL?.includes("donish.live")
  ? "api.donish.live"
  : DOMAIN;

if (!IP || !PASSWORD) {
  console.error("IP and PASSWORD required in backend/.env");
  process.exit(1);
}

const DB_PASSWORD =
  process.env.DB_PASSWORD?.trim() ||
  "DonishPg_" + Math.random().toString(36).slice(2, 12);
const DB_PASSWORD_SQL = DB_PASSWORD.replace(/'/g, "''");
const DATABASE_URL = `postgresql://donish:${DB_PASSWORD}@127.0.0.1:5432/donish`;

function sshExec(conn, cmd, timeoutMs = 300_000) {
  return new Promise((resolve, reject) => {
    conn.exec(cmd, { pty: true }, (err, stream) => {
      if (err) return reject(err);
      let out = "";
      const timer = setTimeout(() => {
        stream.close();
        reject(new Error(`Timeout: ${cmd.slice(0, 80)}`));
      }, timeoutMs);
      stream
        .on("close", (code) => {
          clearTimeout(timer);
          if (code === 0) resolve(out);
          else reject(new Error(`Exit ${code}: ${out.slice(-2000)}`));
        })
        .on("data", (d) => {
          out += d.toString();
          process.stdout.write(d);
        })
        .stderr.on("data", (d) => {
          out += d.toString();
          process.stderr.write(d);
        });
    });
  });
}

function connect() {
  return new Promise((resolve, reject) => {
    const conn = new Client();
    conn
      .on("ready", () => resolve(conn))
      .on("error", reject)
      .connect({
        host: IP,
        port: 22,
        username: "root",
        password: PASSWORD,
        readyTimeout: 30_000
      });
  });
}

function scpFile(conn, localPath, remotePath) {
  return new Promise((resolve, reject) => {
    conn.sftp((err, sftp) => {
      if (err) return reject(err);
      const rs = createReadStream(localPath);
      const ws = sftp.createWriteStream(remotePath);
      ws.on("close", resolve);
      ws.on("error", reject);
      rs.pipe(ws);
    });
  });
}

const setupScript = `#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl git nginx postgresql postgresql-contrib poppler-utils tesseract-ocr tesseract-ocr-eng

if ! command -v node >/dev/null || [[ "$(node -v 2>/dev/null || echo v0)" < "v20" ]]; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y -qq nodejs
fi
npm install -g pm2

sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='donish'" | grep -q 1 || \
  sudo -u postgres psql -c "CREATE USER donish WITH PASSWORD '${DB_PASSWORD_SQL}';"
sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='donish'" | grep -q 1 || \
  sudo -u postgres psql -c "CREATE DATABASE donish OWNER donish;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE donish TO donish;"
sudo -u postgres psql -d donish -c "GRANT ALL ON SCHEMA public TO donish;"
sudo -u postgres psql -d donish -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO donish;"

mkdir -p /var/www/donish_edu/backend
`;

console.log("Connecting to", IP, "...");
const conn = await connect();

try {
  console.log("\n=== Provisioning server ===");
  await sshExec(conn, setupScript, 600_000);

  console.log("\n=== Packaging backend ===");
  const tarball = path.join(backendRoot, "deploy-bundle.tgz");
  execSync(
    `tar -czf "${tarball}" -C "${backendRoot}" --exclude=node_modules --exclude=.env --exclude=data .`,
    { stdio: "inherit", shell: true }
  );

  console.log("\n=== Uploading backend ===");
  await sshExec(conn, "mkdir -p /var/www/donish_edu/backend");
  await scpFile(conn, tarball, "/tmp/backend-bundle.tgz");
  await sshExec(
    conn,
    "cd /var/www/donish_edu/backend && tar -xzf /tmp/backend-bundle.tgz && npm install --omit=dev"
  );

  let hasExport = false;

  const envLines = await readFile(path.join(backendRoot, ".env"), "utf8");
  const prodEnv = envLines
    .split("\n")
    .filter(
      (l) =>
        !/^(DOMAIN|PASSWORD|IP|DB_PASSWORD)=/i.test(l.trim()) &&
        !/^SUPABASE_/i.test(l.trim()) &&
        !/^AWS_/i.test(l.trim()) &&
        !/^TEXTRACT_/i.test(l.trim()) &&
        l.trim().length > 0
    )
    .join("\n");

  const serverEnv = `${prodEnv}
DATABASE_URL=${DATABASE_URL}
`;
  const localEnvPath = path.join(backendRoot, ".env.production");
  await writeFile(localEnvPath, serverEnv, "utf8");

  const migrateEnvPath = path.join(backendRoot, ".env.migrate");
  await writeFile(migrateEnvPath, envLines, "utf8");
  await scpFile(conn, migrateEnvPath, "/var/www/donish_edu/backend/.env.migrate");

  console.log("\n=== Database schema ===");
  const sqlFiles = [
    "schema.sql",
    "migration_materials_20250321.sql",
    "migration_telegram_bot_sessions.sql",
    "migration_word_cache_calendar.sql",
    "migration_practice_ui_progress.sql",
    "migration_flashcard_mastered.sql",
    "migration_scale_indexes.sql"
  ];
  for (const f of sqlFiles) {
    const p = path.join(backendRoot, "db", f);
    await scpFile(conn, p, `/tmp/${f}`);
    await sshExec(
      conn,
      `sudo -u postgres psql -d donish -v ON_ERROR_STOP=1 -f /tmp/${f} 2>/dev/null || sudo -u postgres psql -d donish -f /tmp/${f}`
    );
  }

  console.log("\n=== Export from Supabase (on VPS) ===");
  try {
    await sshExec(
      conn,
      `cd /var/www/donish_edu/backend && cp .env.migrate .env && npm install --include=dev 2>/dev/null; mkdir -p data && node scripts/export-supabase.mjs`
    );
    hasExport = true;
  } catch (e) {
    console.warn("Supabase export on VPS failed:", e.message);
  }

  await scpFile(conn, localEnvPath, "/var/www/donish_edu/backend/.env");

  if (hasExport) {
    console.log("\n=== Importing data into PostgreSQL ===");
    await sshExec(
      conn,
      `cd /var/www/donish_edu/backend && node scripts/import-postgres.mjs`
    );
  }

  console.log("\n=== PM2 + nginx ===");
  await sshExec(
    conn,
    `cd /var/www/donish_edu/backend && pm2 delete donish-api 2>/dev/null || true
pm2 start src/server.js --name donish-api
pm2 save
pm2 startup systemd -u root --hp /root 2>/dev/null | tail -1 | bash || true`
  );

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
}
`;
  await writeFile(path.join(backendRoot, "nginx-donish.conf"), nginxConf, "utf8");
  await scpFile(conn, path.join(backendRoot, "nginx-donish.conf"), "/etc/nginx/sites-available/donish");
  await sshExec(
    conn,
    `ln -sf /etc/nginx/sites-available/donish /etc/nginx/sites-enabled/donish
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx`
  );

  console.log("\n=== TLS (if DNS points here) ===");
  try {
    await sshExec(
      conn,
      `certbot --nginx -d ${API_HOST} --non-interactive --agree-tos --register-unsafely-without-email --redirect`,
      120_000
    );
  } catch (e) {
    console.warn("Certbot skipped (DNS may not point to VPS yet):", e.message);
  }

  console.log("\n=== Telegram webhook ===");
  try {
    await sshExec(conn, "cd /var/www/donish_edu/backend && npm run webhook:set");
  } catch (e) {
    console.warn("Webhook set failed:", e.message);
  }

  await sshExec(conn, "curl -s http://127.0.0.1:4000/health || true");

  console.log("\n=== Done ===");
  console.log("API:", `https://${API_HOST}/health`);
  console.log("DATABASE_URL saved on server in /var/www/donish_edu/backend/.env");
  console.log("DB password (save locally):", DB_PASSWORD);
} finally {
  conn.end();
}
