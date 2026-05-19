/**
 * Generates strong JWT_SECRET and BOT_SHARED_SECRET and writes backend/.env.
 * - If .env is missing, seeds from .env.example when present.
 * - Never commits .env (see root .gitignore).
 *
 * Usage: npm run secrets
 * Production: copy the two values into backend/.env on your EC2 host (see DEPLOY.md).
 */
import crypto from "crypto";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const backendRoot = path.resolve(__dirname, "..");
const envPath = path.join(backendRoot, ".env");
const examplePath = path.join(backendRoot, ".env.example");

function randomHex(byteLength) {
  return crypto.randomBytes(byteLength).toString("hex");
}

/** Min 32 chars for production JWT check; 64 hex = 32 bytes. */
const jwtSecret = randomHex(32);
/** Min 16 chars for production bot check; 48 hex = 24 bytes. */
const botSecret = randomHex(24);

let content = "";
if (fs.existsSync(envPath)) {
  content = fs.readFileSync(envPath, "utf8");
} else if (fs.existsSync(examplePath)) {
  content = fs.readFileSync(examplePath, "utf8");
} else {
  content = "PORT=4000\n";
}

function setOrAppend(src, key, value) {
  const re = new RegExp(`^${key}=.*$`, "m");
  if (re.test(src)) {
    return src.replace(re, `${key}=${value}`);
  }
  const trimmed = src.replace(/\s*$/, "");
  return `${trimmed}\n${key}=${value}\n`;
}

let next = content;
next = setOrAppend(next, "JWT_SECRET", jwtSecret);
next = setOrAppend(next, "BOT_SHARED_SECRET", botSecret);

fs.writeFileSync(envPath, next, "utf8");

// eslint-disable-next-line no-console
console.log(`Updated ${envPath}`);
// eslint-disable-next-line no-console
console.log("");
// eslint-disable-next-line no-console
console.log("Set these in backend/.env on EC2 (and keep them secret):");
// eslint-disable-next-line no-console
console.log(`JWT_SECRET=${jwtSecret}`);
// eslint-disable-next-line no-console
console.log(`BOT_SHARED_SECRET=${botSecret}`);
// eslint-disable-next-line no-console
console.log("");
// eslint-disable-next-line no-console
console.log(
  "Use the same BOT_SHARED_SECRET where the Telegram bot runs (e.g. BOT_SHARED_SECRET in process env)."
);
