import express from "express";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import { query } from "../db/pool.js";
import { config } from "../config.js";
import { loginLimiter } from "../middlewares/rateLimits.js";
import { requireAuth } from "../middlewares/authMiddleware.js";
import {
  ensureDeviceSlot,
  normalizeDeviceId,
  removeUserDevice
} from "../services/deviceService.js";
import { buildSubscriptionPayload } from "../services/subscriptionService.js";

export const authRouter = express.Router();

authRouter.post("/login", loginLimiter, async (req, res) => {
  const { id, password, device_id: deviceIdRaw, device_label: deviceLabel } =
    req.body || {};
  const telegramId = id !== undefined && id !== null ? Number(id) : NaN;
  const deviceId = normalizeDeviceId(deviceIdRaw);

  if (!Number.isInteger(telegramId) || !password) {
    return res.status(400).json({ error: "ID and password are required." });
  }
  if (!deviceId) {
    return res.status(400).json({
      code: "device_id_required",
      error: "A valid device id is required."
    });
  }

  try {
    const { rows } = await query(
      `select * from users where telegram_id = $1 limit 1`,
      [telegramId]
    );
    const user = rows[0];
    if (!user) {
      return res.status(401).json({ error: "Invalid credentials." });
    }

    const ok = await bcrypt.compare(password, user.password_hash);
    if (!ok) {
      return res.status(401).json({ error: "Invalid credentials." });
    }

    const slot = await ensureDeviceSlot(user.id, deviceId, deviceLabel);
    if (!slot.ok) {
      return res.status(403).json({
        code: slot.code,
        error: slot.message,
        devices: slot.devices
      });
    }

    const token = jwt.sign(
      {
        sub: user.id,
        telegram_id: user.telegram_id,
        device_id: deviceId
      },
      config.jwtSecret,
      { expiresIn: config.jwtExpiresIn }
    );

    const subscription = await buildSubscriptionPayload(user.id);
    const responseTelegramId = Number(user.telegram_id);
    return res.json({
      token,
      user: {
        id: user.id,
        telegram_id: Number.isFinite(responseTelegramId)
          ? responseTelegramId
          : user.telegram_id,
        created_at: user.created_at
      },
      subscription
    });
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error("Login DB error:", error);
    return res.status(500).json({ error: "Failed to query user." });
  }
});

authRouter.post("/logout", requireAuth, async (req, res) => {
  const deviceId = req.deviceId || normalizeDeviceId(req.headers["x-device-id"]);
  if (!deviceId) {
    return res.status(400).json({ error: "Device id is required." });
  }

  try {
    await removeUserDevice(req.user.id, deviceId);
    return res.json({ ok: true });
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error("Logout device removal:", error);
    return res.status(500).json({ error: "Failed to log out." });
  }
});
