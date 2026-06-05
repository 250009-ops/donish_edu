import pg from "pg";
import { config } from "../config.js";

const { Pool } = pg;

/** @type {import("pg").Pool | null} */
let pool = null;

export function getPool() {
  if (!pool) {
    if (!config.databaseUrl?.trim()) {
      throw new Error("DATABASE_URL is not configured.");
    }
    pool = new Pool({
      connectionString: config.databaseUrl.trim(),
      max: 12,
      idleTimeoutMillis: 30_000,
      connectionTimeoutMillis: 10_000
    });
  }
  return pool;
}

/**
 * @param {string} text
 * @param {unknown[]} [params]
 */
export async function query(text, params = []) {
  return getPool().query(text, params);
}
