import dotenv from "dotenv";
import { Client } from "ssh2";
import { createReadStream } from "node:fs";
import { execSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const backendRoot = path.join(__dirname, "..");
dotenv.config({ path: path.join(backendRoot, ".env") });

const IP = process.env.IP?.trim();
const PASSWORD = process.env.PASSWORD?.trim();

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

const tarball = path.join(backendRoot, "deploy-bundle.tgz");
execSync(
  `tar -czf "${tarball}" -C "${backendRoot}" --exclude=node_modules --exclude=.env --exclude=data .`,
  { stdio: "inherit", shell: true }
);

await scp(tarball, "/tmp/backend-bundle.tgz");
await run(
  "cd /var/www/donish_edu/backend && tar -xzf /tmp/backend-bundle.tgz && npm install --omit=dev && pm2 restart donish-api"
);
console.log("Synced.");
