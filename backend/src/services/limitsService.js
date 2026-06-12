import { query } from "../db/pool.js";
import { config } from "../config.js";

let globalCache = null;
let globalCacheAt = 0;
const CACHE_MS = 60_000;

async function loadGlobal() {
  const now = Date.now();
  if (globalCache && now - globalCacheAt < CACHE_MS) return globalCache;
  try {
    const { rows } = await query(`select * from usage_limits_global where id = true`);
    globalCache = rows[0] || null;
    globalCacheAt = now;
  } catch {
    globalCache = null;
  }
  return globalCache;
}

export function invalidateLimitsCache() {
  globalCache = null;
  globalCacheAt = 0;
}

/**
 * @param {string} userId uuid
 */
export async function getEffectiveLimits(userId) {
  const global = await loadGlobal();
  let userRow = null;
  if (userId) {
    const { rows } = await query(
      `select * from user_limits where user_id = $1::uuid`,
      [userId]
    );
    userRow = rows[0] || null;
  }

  return {
    freeMaxTranslateTotal:
      userRow?.translate_total_override ??
      global?.free_max_translate_total ??
      config.freeMaxTranslateTotal,
    premiumMaxTranslatePerDay:
      userRow?.translate_per_day_override ??
      global?.premium_max_translate_per_day ??
      config.premiumMaxTranslatePerDay,
    freeMaxMaterials:
      userRow?.materials_override ??
      global?.free_max_materials ??
      config.freeMaxMaterials,
    maxDevicesPerUser:
      userRow?.max_devices_override ??
      global?.max_devices_per_user ??
      config.maxDevicesPerUser,
    isBlocked: userRow?.is_blocked === true
  };
}

export async function getGlobalLimits() {
  const global = await loadGlobal();
  return {
    free_max_translate_total:
      global?.free_max_translate_total ?? config.freeMaxTranslateTotal,
    premium_max_translate_per_day:
      global?.premium_max_translate_per_day ?? config.premiumMaxTranslatePerDay,
    free_max_materials: global?.free_max_materials ?? config.freeMaxMaterials,
    max_devices_per_user: global?.max_devices_per_user ?? config.maxDevicesPerUser
  };
}

export async function updateGlobalLimits(patch, adminId) {
  const current = await getGlobalLimits();
  const next = { ...current, ...patch };
  await query(
    `insert into usage_limits_global (
       id, free_max_translate_total, premium_max_translate_per_day,
       free_max_materials, max_devices_per_user, updated_by, updated_at
     ) values (true, $1, $2, $3, $4, $5, now())
     on conflict (id) do update set
       free_max_translate_total = excluded.free_max_translate_total,
       premium_max_translate_per_day = excluded.premium_max_translate_per_day,
       free_max_materials = excluded.free_max_materials,
       max_devices_per_user = excluded.max_devices_per_user,
       updated_by = excluded.updated_by,
       updated_at = now()`,
    [
      next.free_max_translate_total,
      next.premium_max_translate_per_day,
      next.free_max_materials,
      next.max_devices_per_user,
      adminId
    ]
  );
  invalidateLimitsCache();
  return next;
}

export async function getUserLimitsOverride(userId) {
  const { rows } = await query(
    `select * from user_limits where user_id = $1::uuid`,
    [userId]
  );
  return rows[0] || null;
}

export async function updateUserLimitsOverride(userId, patch, adminId) {
  const existing = await getUserLimitsOverride(userId);
  const next = {
    translate_total_override:
      patch.translate_total_override !== undefined
        ? patch.translate_total_override
        : existing?.translate_total_override ?? null,
    translate_per_day_override:
      patch.translate_per_day_override !== undefined
        ? patch.translate_per_day_override
        : existing?.translate_per_day_override ?? null,
    materials_override:
      patch.materials_override !== undefined
        ? patch.materials_override
        : existing?.materials_override ?? null,
    max_devices_override:
      patch.max_devices_override !== undefined
        ? patch.max_devices_override
        : existing?.max_devices_override ?? null,
    is_blocked:
      patch.is_blocked !== undefined
        ? patch.is_blocked
        : existing?.is_blocked ?? false,
    note: patch.note !== undefined ? patch.note : existing?.note ?? null
  };
  await query(
    `insert into user_limits (
       user_id, translate_total_override, translate_per_day_override,
       materials_override, max_devices_override, is_blocked, note, updated_by, updated_at
     ) values ($1::uuid, $2, $3, $4, $5, $6, $7, $8, now())
     on conflict (user_id) do update set
       translate_total_override = excluded.translate_total_override,
       translate_per_day_override = excluded.translate_per_day_override,
       materials_override = excluded.materials_override,
       max_devices_override = excluded.max_devices_override,
       is_blocked = excluded.is_blocked,
       note = excluded.note,
       updated_by = excluded.updated_by,
       updated_at = now()`,
    [
      userId,
      next.translate_total_override,
      next.translate_per_day_override,
      next.materials_override,
      next.max_devices_override,
      next.is_blocked,
      next.note,
      adminId
    ]
  );
  return getUserLimitsOverride(userId);
}
