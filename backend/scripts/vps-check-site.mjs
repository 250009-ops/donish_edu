import dotenv from "dotenv";
import { Client } from "ssh2";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, "..", ".env") });

const conn = new Client();
conn.on("ready", () => {
  conn.exec(
    `curl -s -o /dev/null -w "root:%{http_code}\\n" -H "Host: donish.live" http://127.0.0.1/
curl -s -o /dev/null -w "home:%{http_code}\\n" -H "Host: donish.live" http://127.0.0.1/home/
grep -o "<h1[^>]*>.*</h1>" /var/www/donish_live/index.html | head -1
grep -o "<h1[^>]*>.*</h1>" /var/www/donish_live/home/index.html | head -1`,
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
