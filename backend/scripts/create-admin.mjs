import dotenv from "dotenv";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { upsertAdmin } from "../src/services/adminAuthService.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, "../.env") });

const email = process.argv[2];
const password = process.argv[3];
const role = process.argv[4] || "superadmin";

if (!email || !password) {
  console.error("Usage: node scripts/create-admin.mjs <email> <password> [role]");
  process.exit(1);
}

const admin = await upsertAdmin({ email, password, role });
console.log(admin.updated ? "Admin updated:" : "Admin created:", admin);
console.log("Log in at /admin and run setup-2fa from settings.");
