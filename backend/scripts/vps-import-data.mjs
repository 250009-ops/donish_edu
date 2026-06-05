import dotenv from "dotenv";
import { Client } from "ssh2";
import { createReadStream } from "node:fs";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const backendRoot = path.join(__dirname, "..");
dotenv.config({ path: path.join(backendRoot, ".env") });

const IP = process.env.IP?.trim();
const PASSWORD = process.env.PASSWORD?.trim();
const dbUrl = `postgresql://donish:${encodeURIComponent(process.env.DB_PASSWORD?.trim() || "DonishPg_prod_2026")}@127.0.0.1:5432/donish`;

function run(cmd) {
  return new Promise((resolve, reject) => {
    const conn = new Client();
    conn.on("ready", () => {
      conn.exec(cmd, { pty: true }, (err, stream) => {
        if (err) return reject(err);
        stream.on("close", (code) => {
          conn.end();
          code === 0 ? resolve() : reject(new Error(`exit ${code}`));
        });
        stream.on("data", (d) => process.stdout.write(d));
        stream.stderr.on("data", (d) => process.stderr.write(d));
      });
    });
    conn.connect({ host: IP, port: 22, username: "root", password: PASSWORD });
  });
}

const exportPath = path.join(backendRoot, "data", "supabase-export.json");
try {
  await readFile(exportPath);
} catch {
  console.log("Running export on VPS...");
  await run(
    `cd /var/www/donish_edu/backend && cp .env.migrate .env 2>/dev/null || true
node scripts/export-supabase.mjs`
  );
}

function scp(local, remote) {
  return new Promise((resolve, reject) => {
    const conn = new Client();
    conn.on("ready", () => {
      conn.sftp((err, sftp) => {
        if (err) return reject(err);
        const rs = createReadStream(local);
        const ws = sftp.createWriteStream(remote);
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
}

try {
  await readFile(exportPath);
  await scp(exportPath, "/var/www/donish_edu/backend/data/supabase-export.json");
} catch {
  /* exported on VPS */
}

await run(
  `cd /var/www/donish_edu/backend && mkdir -p data
export DATABASE_URL='${dbUrl.replace(/'/g, "'\\''")}'
node scripts/import-postgres.mjs
pm2 restart donish-api`
);
console.log("Import done.");
