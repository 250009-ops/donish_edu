/**
 * Applies backend/db/migration_materials_20250321.sql to Postgres.
 *
 * Requires DATABASE_URL or SUPABASE_DB_URL (Supabase: Project Settings → Database → URI).
 * Loads backend/.env via dotenv if present.
 *
 * Usage (from backend/):
 *   npm run migrate:materials
 *
 * Or one-shot:
 *   set DATABASE_URL=postgresql://... && npm run migrate:materials
 */

import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

import dotenv from "dotenv";
import pg from "pg";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const backendRoot = path.join(__dirname, "..");

dotenv.config({ path: path.join(backendRoot, ".env") });

const connectionString =
  process.env.DATABASE_URL || process.env.SUPABASE_DB_URL || "";

if (!connectionString) {
  console.error(
    "Missing DATABASE_URL or SUPABASE_DB_URL.\n" +
      "Add one to backend/.env (see .env.example), or set the variable in your shell.\n" +
      "Supabase: Dashboard → Project Settings → Database → Connection string → URI."
  );
  process.exit(1);
}

const sqlPath = path.join(backendRoot, "db", "migration_materials_20250321.sql");
const sqlRaw = fs.readFileSync(sqlPath, "utf8");

const withoutComments = sqlRaw
  .split("\n")
  .filter((line) => !line.trim().startsWith("--"))
  .join("\n");

const statements = withoutComments
  .split(";")
  .map((s) => s.trim())
  .filter((s) => s.length > 0);

const client = new pg.Client({
  connectionString,
  ssl: connectionString.includes("localhost")
    ? undefined
    : { rejectUnauthorized: false }
});

await client.connect();

try {
  for (const st of statements) {
    await client.query(st + ";");
    console.log("OK:", st.slice(0, 72) + (st.length > 72 ? "…" : ""));
  }
  console.log("\nMigration finished successfully.");
} catch (err) {
  console.error("Migration failed:", err.message);
  process.exitCode = 1;
} finally {
  await client.end();
}
