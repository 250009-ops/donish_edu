import dotenv from "dotenv";
import { Client } from "ssh2";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, "..", ".env") });

const body = JSON.stringify({ id: 5710604544, password: "Sarvarbek" });

const conn = new Client();
conn.on("ready", () => {
  conn.exec(
    `curl -s -w "\\nHTTP:%{http_code}" -X POST http://127.0.0.1:4000/auth/login -H 'Content-Type: application/json' -d '${body.replace(/'/g, "'\\''")}'
curl -s -w "\\nHTTP:%{http_code}" -X POST https://api.donish.live/auth/login -H 'Content-Type: application/json' -d '${body.replace(/'/g, "'\\''")}'`,
    { pty: true },
    (err, stream) => {
      stream.on("data", (d) => process.stdout.write(d));
      stream.on("close", () => conn.end());
    }
  );
});
conn.connect({
  host: process.env.IP,
  username: "root",
  password: process.env.PASSWORD
});
