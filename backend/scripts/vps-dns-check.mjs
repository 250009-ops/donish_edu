import dotenv from "dotenv";
import { Client } from "ssh2";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, "..", ".env") });

const conn = new Client();
conn.on("ready", () => {
  conn.exec(
    `echo "=== Authoritative (Namecheap) ==="
dig @dns1.registrar-servers.com donish.live A +short
dig @dns1.registrar-servers.com www.donish.live A +short
echo "=== Public ==="
dig @8.8.8.8 donish.live A +short
dig @1.1.1.1 donish.live A +short
echo "=== HTTPS ==="
curl -sI https://donish.live/home/ | head -4`,
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
