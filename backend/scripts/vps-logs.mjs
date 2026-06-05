import dotenv from "dotenv";
import { Client } from "ssh2";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, "..", ".env") });

const cmd = process.argv[2] || `pm2 logs donish-api --lines 40 --nostream
curl -s -X POST http://127.0.0.1:4000/auth/login -H 'Content-Type: application/json' -d '{"id":5710604544,"password":"test"}'
echo
sudo -u postgres psql -d donish -c "select telegram_id, username, left(password_hash,20) from users limit 5;"`;

const conn = new Client();
conn.on("ready", () => {
  conn.exec(cmd, { pty: true }, (err, stream) => {
    stream.on("data", (d) => process.stdout.write(d));
    stream.stderr.on("data", (d) => process.stderr.write(d));
    stream.on("close", () => conn.end());
  });
});
conn.connect({
  host: process.env.IP,
  port: 22,
  username: "root",
  password: process.env.PASSWORD
});
