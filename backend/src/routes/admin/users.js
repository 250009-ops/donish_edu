import express from "express";
import { requireAdminAuth, requireRole } from "../../middlewares/adminAuth.js";
import { auditAdmin } from "../../middlewares/adminAudit.js";
import { query } from "../../db/pool.js";
import { resetTelegramUserPassword } from "../../services/botUserOperations.js";
import {
  getEffectiveLimits,
  getUserLimitsOverride,
  updateUserLimitsOverride
} from "../../services/limitsService.js";
import { buildSubscriptionPayload } from "../../services/subscriptionService.js";
import { listUserDevices, removeUserDevice } from "../../services/deviceService.js";

export const adminUsersRouter = express.Router();
adminUsersRouter.use(requireAdminAuth);

adminUsersRouter.get("/", async (req, res) => {
  const q = String(req.query.q || "").trim();
  const limit = Math.min(Number(req.query.limit) || 50, 100);
  const offset = Number(req.query.offset) || 0;
  const params = [];
  let where = "1=1";
  if (q) {
    params.push(`%${q}%`);
    where += ` and (
      cast(telegram_id as text) ilike $${params.length}
      or full_name ilike $${params.length}
      or email ilike $${params.length}
      or phone_e164 ilike $${params.length}
    )`;
  }
  params.push(limit, offset);
  const { rows } = await query(
    `select id, telegram_id, full_name, email, phone_e164, language, plan,
            subscription_status, created_at
     from users where ${where}
     order by created_at desc
     limit $${params.length - 1} offset $${params.length}`,
    params
  );
  res.json({ users: rows });
});

adminUsersRouter.get("/:id", async (req, res) => {
  const { rows } = await query(`select * from users where id = $1::uuid`, [
    req.params.id
  ]);
  const user = rows[0];
  if (!user) return res.status(404).json({ error: "Not found." });
  const subscription = await buildSubscriptionPayload(user.id);
  const limits = await getEffectiveLimits(user.id);
  const override = await getUserLimitsOverride(user.id);
  const devices = await listUserDevices(user.id);
  res.json({ user, subscription, limits, override, devices });
});

adminUsersRouter.post(
  "/:id/limits",
  requireRole("superadmin"),
  auditAdmin("set_user_limits"),
  async (req, res) => {
    req.auditTarget = req.params.id;
    const row = await updateUserLimitsOverride(
      req.params.id,
      req.body || {},
      req.admin.id
    );
    res.json({ override: row });
  }
);

adminUsersRouter.post(
  "/:id/ban",
  requireRole("superadmin"),
  auditAdmin("ban_user"),
  async (req, res) => {
    const blocked = req.body?.blocked === true;
    req.auditTarget = req.params.id;
    await updateUserLimitsOverride(
      req.params.id,
      { is_blocked: blocked },
      req.admin.id
    );
    res.json({ ok: true, blocked });
  }
);

adminUsersRouter.post(
  "/:id/reset-password",
  requireRole("superadmin"),
  auditAdmin("reset_user_password"),
  async (req, res) => {
    const { rows } = await query(
      `select telegram_id from users where id = $1::uuid`,
      [req.params.id]
    );
    const user = rows[0];
    if (!user) return res.status(404).json({ error: "Not found." });
    const password = req.body?.password;
    if (!password) {
      return res.status(400).json({ error: "password required." });
    }
    const result = await resetTelegramUserPassword(user.telegram_id, password);
    if (!result.ok) {
      return res.status(result.status).json({ error: result.error });
    }
    req.auditTarget = req.params.id;
    res.json({ ok: true });
  }
);

adminUsersRouter.delete("/:id/devices/:deviceId", async (req, res) => {
  const ok = await removeUserDevice(req.params.id, req.params.deviceId);
  res.json({ ok });
});
