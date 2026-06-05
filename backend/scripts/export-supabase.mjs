/**
 * Export Donish tables from Supabase via PostgREST (no WebSocket).
 */
import dotenv from "dotenv";
import { writeFile, mkdir } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, "..", ".env") });

const baseUrl = process.env.SUPABASE_URL?.trim()?.replace(/\/$/, "");
const key = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();

if (!baseUrl || !key) {
  console.error("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY required in .env");
  process.exit(1);
}

const TABLES = [
  "users",
  "materials",
  "vocabulary_entries",
  "practice_stats",
  "user_word_cache",
  "telegram_bot_sessions"
];

/** @param {string} table */
async function fetchAll(table) {
  const pageSize = 1000;
  let offset = 0;
  const all = [];
  for (;;) {
    const url = `${baseUrl}/rest/v1/${table}?select=*`;
    const res = await fetch(url, {
      headers: {
        apikey: key,
        Authorization: `Bearer ${key}`,
        Range: `${offset}-${offset + pageSize - 1}`
      }
    });
    if (!res.ok) {
      const body = await res.text();
      throw new Error(`${table}: HTTP ${res.status} ${body}`);
    }
    const batch = await res.json();
    if (!Array.isArray(batch)) {
      throw new Error(`${table}: unexpected response`);
    }
    all.push(...batch);
    if (batch.length < pageSize) break;
    offset += pageSize;
  }
  return all;
}

const dump = {};
for (const table of TABLES) {
  console.log(`Exporting ${table}...`);
  dump[table] = await fetchAll(table);
  console.log(`  ${dump[table].length} rows`);
}

const dataDir = path.join(__dirname, "..", "data");
await mkdir(dataDir, { recursive: true });
const outPath = path.join(dataDir, "supabase-export.json");
await writeFile(outPath, JSON.stringify(dump), "utf8");
console.log(`Wrote ${outPath}`);
