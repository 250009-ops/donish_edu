import jwt from "jsonwebtoken";
import { config } from "../config.js";
import {
  isDeviceRegistered,
  normalizeDeviceId
} from "../services/deviceService.js";

export function requireAuth(req, res, next) {
  const header = req.headers.authorization || "";
  const [, token] = header.split(" ");

  if (!token) {
    return res.status(401).json({ error: "Missing authorization token." });
  }

  try {
    const payload = jwt.verify(token, config.jwtSecret);
    req.user = { id: payload.sub, telegram_id: payload.telegram_id };
    req.deviceId = normalizeDeviceId(payload.device_id);
    return next();
  } catch {
    return res.status(401).json({ error: "Invalid or expired token." });
  }
}

export async function requireRegisteredDevice(req, res, next) {
  const headerDeviceId = normalizeDeviceId(req.headers["x-device-id"]);
  const tokenDeviceId = req.deviceId;

  if (!headerDeviceId || !tokenDeviceId || headerDeviceId !== tokenDeviceId) {
    return res.status(401).json({
      code: "device_mismatch",
      error: "Device verification failed. Please sign in again."
    });
  }

  try {
    const ok = await isDeviceRegistered(req.user.id, headerDeviceId);
    if (!ok) {
      return res.status(401).json({
        code: "device_not_registered",
        error:
          "This device is no longer authorized. Sign in again or free a device slot from another device."
      });
    }
    req.deviceId = headerDeviceId;
    return next();
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error("requireRegisteredDevice:", error);
    return res.status(500).json({ error: "Device verification failed." });
  }
}

