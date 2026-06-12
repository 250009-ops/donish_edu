import express from "express";
import {
  confirm2fa,
  loginWithPassword,
  revokeRefreshToken,
  rotateRefreshSession,
  setup2fa,
  signAccessToken,
  verifyMfaAndLogin,
  findAdminById
} from "../../services/adminAuthService.js";
import { requireAdminAuth } from "../../middlewares/adminAuth.js";

export const adminAuthRouter = express.Router();

const REFRESH_COOKIE = "admin_refresh";

function setRefreshCookie(res, token) {
  res.cookie(REFRESH_COOKIE, token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "strict",
    path: "/admin",
    maxAge: 7 * 864e5
  });
}

adminAuthRouter.post("/login", async (req, res) => {
  const { email, password } = req.body || {};
  if (!email || !password) {
    return res.status(400).json({ error: "Email and password required." });
  }
  const result = await loginWithPassword(email, password);
  if (!result.ok) {
    return res.status(401).json({ error: result.error });
  }
  if (result.mfa_required) {
    return res.json({ mfa_required: true, mfa_token: result.mfa_token });
  }
  setRefreshCookie(res, result.refresh);
  return res.json({ access: result.access });
});

adminAuthRouter.post("/2fa", async (req, res) => {
  const { mfa_token, code } = req.body || {};
  if (!mfa_token || !code) {
    return res.status(400).json({ error: "mfa_token and code required." });
  }
  const result = await verifyMfaAndLogin(mfa_token, code);
  if (!result.ok) {
    return res.status(401).json({ error: result.error });
  }
  setRefreshCookie(res, result.refresh);
  return res.json({ access: result.access });
});

adminAuthRouter.post("/refresh", async (req, res) => {
  const old = req.cookies?.[REFRESH_COOKIE];
  if (!old) {
    return res.status(401).json({ error: "No refresh token." });
  }
  const crypto = await import("node:crypto");
  const hash = crypto.createHash("sha256").update(old).digest("hex");
  const { query } = await import("../../db/pool.js");
  const { rows } = await query(
    `select admin_id from admin_sessions
     where refresh_hash = $1 and revoked_at is null and expires_at > now() limit 1`,
    [hash]
  );
  const session = rows[0];
  if (!session) {
    return res.status(401).json({ error: "Session expired." });
  }
  const rotated = await rotateRefreshSession(old, {
    userAgent: req.get("user-agent"),
    ip: req.ip
  });
  if (!rotated) {
    return res.status(401).json({ error: "Session expired." });
  }
  const adminUser = await findAdminById(session.admin_id);
  if (!adminUser?.is_active) {
    return res.status(401).json({ error: "Session invalid." });
  }
  setRefreshCookie(res, rotated.token);
  return res.json({ access: signAccessToken(adminUser) });
});

adminAuthRouter.post("/logout", async (req, res) => {
  const old = req.cookies?.[REFRESH_COOKIE];
  if (old) await revokeRefreshToken(old);
  res.clearCookie(REFRESH_COOKIE, { path: "/admin" });
  return res.json({ ok: true });
});

adminAuthRouter.get("/me", requireAdminAuth, (req, res) => {
  res.json({
    id: req.admin.id,
    email: req.admin.email,
    role: req.admin.role,
    totp_enabled: req.admin.totp_enabled
  });
});

adminAuthRouter.post("/setup-2fa", requireAdminAuth, async (req, res) => {
  const out = await setup2fa(req.admin.id);
  res.json({ otpauth_uri: out.uri, secret: out.secret });
});

adminAuthRouter.post("/confirm-2fa", requireAdminAuth, async (req, res) => {
  const { code } = req.body || {};
  const result = await confirm2fa(req.admin.id, code);
  if (!result.ok) return res.status(400).json({ error: result.error });
  res.json({ ok: true });
});
