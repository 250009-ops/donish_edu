/**
 * End-to-end checks for Lemon Squeezy business verification landing page.
 */
import dotenv from "dotenv";
import { Client } from "ssh2";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, "..", ".env") });

const IP = process.env.IP?.trim();
const PASSWORD = process.env.PASSWORD?.trim();

const PAGES = [
  {
    name: "marketing home",
    url: "https://donish.live/home/",
    must: ["Gotcha", "pricing", "Refund Policy", "support@donish.live"]
  },
  { name: "app entry", url: "https://donish.live/", must: ["Gotcha"] },
  {
    name: "privacy",
    url: "https://donish.live/privacy/",
    must: ["Gotcha", "Lemon Squeezy"]
  },
  {
    name: "terms",
    url: "https://donish.live/terms/",
    must: ["Gotcha", "Lemon Squeezy"]
  },
  {
    name: "refund",
    url: "https://donish.live/refund/",
    must: ["Gotcha", "Lemon Squeezy"]
  }
];

function run(cmd) {
  return new Promise((resolve, reject) => {
    const conn = new Client();
    let out = "";
    conn.on("ready", () => {
      conn.exec(cmd, { pty: true }, (err, stream) => {
        if (err) return reject(err);
        stream.on("data", (d) => {
          out += d.toString();
          process.stdout.write(d);
        });
        stream.on("close", (code) => {
          conn.end();
          code === 0 ? resolve(out) : reject(new Error(`exit ${code}`));
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

console.log("=== HTTP → HTTPS redirect ===");
await run(
  `curl -sI http://donish.live/home/ | head -3
curl -sI http://www.donish.live/home/ | head -3`
);

console.log("\n=== HTTPS + content checks ===");
let failed = 0;
for (const page of PAGES) {
  const grepChecks = page.must
    .map((m) => `echo "$body" | grep -qi '${m.replace(/'/g, "'\\''")}'`)
    .join(" && ");
  const cmd = `code=$(curl -s -o /tmp/page.html -w "%{http_code}" "${page.url}")
body=$(cat /tmp/page.html)
echo "[${page.name}] $code ${page.url}"
test "$code" = "200" || exit 1
${grepChecks} || exit 1
echo "  OK: contains ${page.must.join(", ")}"`;
  try {
    await run(cmd);
  } catch {
    console.error(`  FAIL: ${page.name}`);
    failed++;
  }
}

console.log("\n=== Security headers (marketing) ===");
await run(
  `curl -sI https://donish.live/home/ | grep -iE "strict-transport|content-type-options|frame-options" || true`
);

console.log("\n=== API health ===");
await run(`curl -s https://api.donish.live/health && echo`);

console.log(
  failed === 0
    ? "\nAll Lemon Squeezy landing checks passed."
    : `\n${failed} check(s) failed.`
);
process.exit(failed === 0 ? 0 : 1);
