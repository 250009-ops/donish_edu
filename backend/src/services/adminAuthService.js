import bcrypt from "bcryptjs";
import crypto from "node:crypto";
import jwt from "jsonwebtoken";
import { authenticator } from "otplib";
import { query } from "../db/pool.js";
import { config } from "../config.js";

const BCRYPT_ROUNDS = 12;
const MFA_TTL_SEC = 300;

function encKey() {
  const raw = config.adminTotpEncKey || "dev-totp-key-change-in-production!!";
  return crypto.createHash("sha256").update(raw).digest();
}

export function encryptTotpSecret(secret) {
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv("aes-256-gcm", encKey(), iv);
  const enc = Buffer.concat([cipher.update(secret, "utf8"), cipher.final()]);
  const tag = cipher.getAuthTag();
  return Buffer.concat([iv, tag, enc]).toString("base64");
}

export function decryptTotpSecret(blob) {
  const buf = Buffer.from(blob, "base64");
  const iv = buf.subarray(0, 12);
  const tag = buf.subarray(12, 28);
  const enc = buf.subarray(28);
  const decipher = crypto.createDecipheriv("aes-256-gcm", encKey(), iv);
  decipher.setAuthTag(tag);
  return Buffer.concat([decipher.update(enc), decipher.final()]).toString("utf8");
}

export async function findAdminByEmail(email) {
  const { rows } = await query(
    `select * from admin_users where lower(email) = lower($1) limit 1`,
    [email.trim()]
  );
  return rows[0] || null;
}

export async function findAdminById(id) {
  const { rows } = await query(`select * from admin_users where id = $1`, [id]);
  return rows[0] || null;
}

export function signAccessToken(admin) {
  const secret = config.adminJwtSecret || config.jwtSecret;
  return jwt.sign(
    { sub: String(admin.id), role: admin.role, typ: "admin_access" },
    secret,
    { expiresIn: config.adminAccessTtl }
  );
}

export function signMfaToken(adminId) {
  const secret = config.adminJwtSecret || config.jwtSecret;
  return jwt.sign(
    { sub: String(adminId), typ: "admin_mfa" },
    secret,
    { expiresIn: MFA_TTL_SEC }
  );
}

export function verifyToken(token, expectedType) {
  const secret = config.adminJwtSecret || config.jwtSecret;
  const payload = jwt.verify(token, secret);
  if (expectedType && payload.typ !== expectedType) {
    throw new Error("Invalid token type");
  }
  return payload;
}

function refreshExpiry() {
  const raw = config.adminRefreshTtl || "7d";
  const m = raw.match(/^(\d+)([dhms])$/);
  if (!m) return Date.now() + 7 * 864e5;
  const n = Number(m[1]);
  const unit = { d: 864e5, h: 36e5, m: 6e4, s: 1e3 }[m[2]];
  return Date.now() + n * unit;
}

export async function createRefreshSession(adminId, { userAgent, ip } = {}) {
  const token = crypto.randomBytes(48).toString("hex");
  const hash = crypto.createHash("sha256").update(token).digest("hex");
  const expiresAt = new Date(refreshExpiry());
  await query(
    `insert into admin_sessions (admin_id, refresh_hash, user_agent, ip, expires_at)
     values ($1, $2, $3, $4, $5)`,
    [adminId, hash, userAgent || null, ip || null, expiresAt]
  );
  return { token, expiresAt };
}

export async function rotateRefreshSession(oldToken, { userAgent, ip } = {}) {
  const hash = crypto.createHash("sha256").update(oldToken).digest("hex");
  const { rows } = await query(
    `select * from admin_sessions where refresh_hash = $1 and revoked_at is null
     and expires_at > now() limit 1`,
    [hash]
  );
  const session = rows[0];
  if (!session) return null;
  await query(`update admin_sessions set revoked_at = now() where id = $1`, [
    session.id
  ]);
  return createRefreshSession(session.admin_id, { userAgent, ip });
}

export async function revokeRefreshToken(token) {
  const hash = crypto.createHash("sha256").update(token).digest("hex");
  await query(
    `update admin_sessions set revoked_at = now() where refresh_hash = $1`,
    [hash]
  );
}

export async function loginWithPassword(email, password) {
  const admin = await findAdminByEmail(email);
  if (!admin || !admin.is_active) {
    return { ok: false, error: "Invalid credentials." };
  }
  if (admin.locked_until && new Date(admin.locked_until) > new Date()) {
    return { ok: false, error: "Account locked. Try again later." };
  }
  const ok = await bcrypt.compare(password, admin.password_hash);
  if (!ok) {
    const attempts = (admin.failed_attempts || 0) + 1;
    const locked =
      attempts >= 5 ? new Date(Date.now() + 15 * 60 * 1000) : null;
    await query(
      `update admin_users set failed_attempts = $2, locked_until = $3 where id = $1`,
      [admin.id, attempts, locked]
    );
    return { ok: false, error: "Invalid credentials." };
  }
  await query(
    `update admin_users set failed_attempts = 0, locked_until = null where id = $1`,
    [admin.id]
  );
  if (admin.totp_enabled) {
    return { ok: true, mfa_required: true, mfa_token: signMfaToken(admin.id) };
  }
  const access = signAccessToken(admin);
  const refresh = await createRefreshSession(admin.id);
  await query(`update admin_users set last_login_at = now() where id = $1`, [
    admin.id
  ]);
  return { ok: true, access, refresh: refresh.token };
}

export async function verifyMfaAndLogin(mfaToken, code) {
  let payload;
  try {
    payload = verifyToken(mfaToken, "admin_mfa");
  } catch {
    return { ok: false, error: "MFA session expired." };
  }
  const admin = await findAdminById(Number(payload.sub));
  if (!admin?.totp_enabled || !admin.totp_secret) {
    return { ok: false, error: "2FA not configured." };
  }
  const secret = decryptTotpSecret(admin.totp_secret);
  if (!authenticator.verify({ token: code, secret })) {
    return { ok: false, error: "Invalid code." };
  }
  const access = signAccessToken(admin);
  const refresh = await createRefreshSession(admin.id);
  await query(`update admin_users set last_login_at = now() where id = $1`, [
    admin.id
  ]);
  return { ok: true, access, refresh: refresh.token };
}

export async function setup2fa(adminId) {
  const secret = authenticator.generateSecret();
  const admin = await findAdminById(adminId);
  const label = encodeURIComponent(admin.email);
  const uri = authenticator.keyuri(label, "Gotcha Admin", secret);
  await query(
    `update admin_users set totp_secret = $2, totp_enabled = false where id = $1`,
    [adminId, encryptTotpSecret(secret)]
  );
  return { secret, uri };
}

export async function confirm2fa(adminId, code) {
  const admin = await findAdminById(adminId);
  if (!admin?.totp_secret) return { ok: false, error: "Setup 2FA first." };
  const secret = decryptTotpSecret(admin.totp_secret);
  if (!authenticator.verify({ token: code, secret })) {
    return { ok: false, error: "Invalid code." };
  }
  await query(`update admin_users set totp_enabled = true where id = $1`, [
    adminId
  ]);
  return { ok: true };
}

export async function createAdmin({ email, password, role = "superadmin" }) {
  const hash = await bcrypt.hash(password, BCRYPT_ROUNDS);
  const { rows } = await query(
    `insert into admin_users (email, password_hash, role)
     values ($1, $2, $3) returning id, email, role`,
    [email.trim().toLowerCase(), hash, role]
  );
  return rows[0];
}
