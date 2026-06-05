import dotenv from "dotenv";
import { Client } from "ssh2";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, "..", ".env") });

const conn = new Client();
conn.on("ready", () => {
  conn.exec(
    "cd /var/www/donish_edu/backend && npm run webhook:set && npm run webhook:info && curl -s https://api.donish.live/health",
    { pty: true },
    (err, stream) => {
      stream.on("data", (d) => process.stdout.write(d));
      stream.stderr.on("data", (d) => process.stderr.write(d));
      stream.on("close", (code) => {
        conn.end();
        process.exit(code || 0);
      });
    }
  );
});
conn.connect({
  host: process.env.IP,
  port: 22,
  username: "root",
  password: process.env.PASSWORD
});
