/**
 * Build Astro site locally and deploy static files to VPS (donish.live).
 * Does not overwrite nginx SSL config — only updates /var/www/donish_live.
 */
import dotenv from "dotenv";
import { Client } from "ssh2";
import { createReadStream } from "node:fs";
import { execSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const backendRoot = path.join(__dirname, "..");
const websiteRoot = path.join(backendRoot, "..", "website");
const distDir = path.join(websiteRoot, "dist");

dotenv.config({ path: path.join(backendRoot, ".env") });

const IP = process.env.IP?.trim();
const PASSWORD = process.env.PASSWORD?.trim();

if (!IP || !PASSWORD) {
  console.error("IP and PASSWORD required in backend/.env");
  process.exit(1);
}

console.log("=== npm install + build (website) ===");
execSync("npm install", { cwd: websiteRoot, stdio: "inherit", shell: true });
execSync("npm run build", { cwd: websiteRoot, stdio: "inherit", shell: true });

const tarball = path.join(backendRoot, "website-bundle.tgz");
execSync(`tar -czf "${tarball}" -C "${distDir}" .`, {
  stdio: "inherit",
  shell: true
});

function run(cmd, timeoutMs = 120_000) {
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

await scp(tarball, "/tmp/website-bundle.tgz");

await run(
  `mkdir -p /var/www/donish_live
cd /var/www/donish_live && tar -xzf /tmp/website-bundle.tgz
echo "Deployed static site to /var/www/donish_live"`
);

console.log("\nDone. Landing page: https://donish.live/home");
