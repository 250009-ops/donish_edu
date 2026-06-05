import dotenv from "dotenv";
import { Client } from "ssh2";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, "..", ".env") });

const cmd = `
ls -la /var/www/donish_live/ | head -15
cat /etc/nginx/sites-available/donish-site
curl -s -o /dev/null -w "donish:%{http_code}\\n" -H "Host: donish.live" http://127.0.0.1/
curl -sI -H "Host: donish.live" http://127.0.0.1/ | head -5
`;

const conn = new Client();
conn.on("ready", () => {
  conn.exec(cmd, { pty: true }, (err, stream) => {
    stream.on("data", (d) => process.stdout.write(d));
    stream.on("close", () => conn.end());
  });
});
conn.connect({
  host: process.env.IP,
  port: 22,
  username: "root",
  password: process.env.PASSWORD
});
