import { query } from "../db/pool.js";
import { config } from "../config.js";

const DEVICE_ID_RE = /^[a-zA-Z0-9_-]{8,128}$/;

export function normalizeDeviceId(deviceId) {
  const id = String(deviceId || "").trim();
  if (!DEVICE_ID_RE.test(id)) return null;
  return id;
}

export async function listUserDevices(userId) {
  const { rows } = await query(
    `select device_id, device_label, last_seen_at, created_at
     from user_devices where user_id = $1::uuid
     order by last_seen_at desc`,
    [userId]
  );
  return rows;
}

export async function touchUserDevice(userId, deviceId, deviceLabel) {
  const label =
    typeof deviceLabel === "string" && deviceLabel.trim()
      ? deviceLabel.trim().slice(0, 120)
      : null;

  const { rows } = await query(
    `insert into user_devices (user_id, device_id, device_label, last_seen_at)
     values ($1::uuid, $2, $3, now())
     on conflict (user_id, device_id) do update
     set last_seen_at = now(),
         device_label = coalesce(excluded.device_label, user_devices.device_label)
     returning device_id, device_label, last_seen_at, created_at`,
    [userId, deviceId, label]
  );
  return rows[0];
}

export async function ensureDeviceSlot(userId, deviceId, deviceLabel) {
  const existing = await query(
    `select device_id from user_devices
     where user_id = $1::uuid and device_id = $2`,
    [userId, deviceId]
  );
  if (existing.rows[0]) {
    return { ok: true, device: await touchUserDevice(userId, deviceId, deviceLabel) };
  }

  const { rows: countRows } = await query(
    `select count(*)::int as n from user_devices where user_id = $1::uuid`,
    [userId]
  );
  const count = countRows[0]?.n ?? 0;
  if (count >= config.maxDevicesPerUser) {
    const devices = await listUserDevices(userId);
    return {
      ok: false,
      code: "device_limit_reached",
      message: `This account is already active on ${config.maxDevicesPerUser} devices. Log out on another device or revoke other devices from your profile.`,
      devices
    };
  }

  const device = await touchUserDevice(userId, deviceId, deviceLabel);
  return { ok: true, device };
}

export async function isDeviceRegistered(userId, deviceId) {
  const { rows } = await query(
    `select 1 from user_devices
     where user_id = $1::uuid and device_id = $2 limit 1`,
    [userId, deviceId]
  );
  return Boolean(rows[0]);
}

export async function removeUserDevice(userId, deviceId) {
  const { rowCount } = await query(
    `delete from user_devices
     where user_id = $1::uuid and device_id = $2`,
    [userId, deviceId]
  );
  return rowCount > 0;
}

export async function revokeOtherDevices(userId, keepDeviceId) {
  const { rowCount } = await query(
    `delete from user_devices
     where user_id = $1::uuid and device_id <> $2`,
    [userId, keepDeviceId]
  );
  return rowCount;
}
