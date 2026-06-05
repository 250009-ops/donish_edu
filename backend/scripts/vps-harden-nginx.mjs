/**
 * Add security headers to HTTPS nginx blocks (preserves certbot SSL config).
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

function scpFile(local, remote) {
  return new Promise((resolve, reject) => {
    const conn = new Client();
    conn.on("ready", () => {
      conn.sftp((err, sftp) => {
        if (err) return reject(err);
        sftp.fastPut(local, remote, (e) => {
          conn.end();
          e ? reject(e) : resolve();
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

await scpFile(
  path.join(backendRoot, "nginx-gotcha-security.conf"),
  "/etc/nginx/snippets/gotcha-security.conf"
);

await run(
  `for f in /etc/nginx/sites-available/*; do
  if grep -q "gotcha-security.conf" "$f"; then
    echo "skip $f"
    continue
  fi
  if grep -q "listen 443 ssl" "$f"; then
    sed -i '/listen 443 ssl;/a \\    include /etc/nginx/snippets/gotcha-security.conf;' "$f"
    echo "hardened $f"
  fi
done
nginx -t && systemctl reload nginx
echo "Security headers applied"`
);

console.log("\nDone.");
