import dotenv from "dotenv";
import { Client } from "ssh2";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const backendRoot = path.join(__dirname, "..");
dotenv.config({ path: path.join(backendRoot, ".env") });

const IP = process.env.IP?.trim();
const PASSWORD = process.env.PASSWORD?.trim();
const ADMIN_EMAIL = process.env.ADMIN_EMAIL || "admin@donish.live";
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || "GotchaAdmin2026!";

function run(cmd) {
  return new Promise((resolve, reject) => {
    const conn = new Client();
    conn.on("ready", () => {
      conn.exec(cmd, { pty: true }, (err, stream) => {
        if (err) return reject(err);
        stream.on("data", (d) => process.stdout.write(d));
        stream.stderr.on("data", (d) => process.stderr.write(d));
        stream.on("close", (code) => {
          conn.end();
          code === 0 ? resolve() : reject(new Error(`exit ${code}`));
        });
      });
    });
    conn.connect({ host: IP, port: 22, username: "root", password: PASSWORD });
  });
}

await run(`
sudo -u postgres psql -d donish -c "GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO donish;"
cd /var/www/donish_edu/backend
node scripts/create-admin.mjs "${ADMIN_EMAIL}" "${ADMIN_PASSWORD}" superadmin || true
if [ -f nginx-donish-site.conf ]; then
  cp nginx-donish-site.conf /etc/nginx/sites-available/donish-site.conf 2>/dev/null || true
  cp nginx-donish-site.conf /etc/nginx/sites-enabled/donish-site.conf 2>/dev/null || true
fi
nginx -t && systemctl reload nginx
curl -s http://127.0.0.1:4000/health
echo ""
`);
console.log("Post-deploy done.");
