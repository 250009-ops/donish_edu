import express from "express";
import { config } from "../config.js";
import { requireAuth, requireRegisteredDevice } from "../middlewares/authMiddleware.js";
import { authenticatedApiLimiter } from "../middlewares/rateLimits.js";
import {
  buildSubscriptionPayload,
  createCheckoutForUser
} from "../services/subscriptionService.js";
import {
  normalizeDeviceId,
  revokeOtherDevices
} from "../services/deviceService.js";

export const billingRouter = express.Router();

billingRouter.use(requireAuth);
billingRouter.use(requireRegisteredDevice);
billingRouter.use(authenticatedApiLimiter);

billingRouter.get("/subscription", async (req, res) => {
  try {
    const payload = await buildSubscriptionPayload(req.user.id);
    if (!payload) {
      return res.status(404).json({ error: "User not found." });
    }
    return res.json(payload);
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error("GET /billing/subscription:", error);
    return res.status(500).json({ error: "Failed to load subscription." });
  }
});

billingRouter.post("/checkout", async (req, res) => {
  if (!config.billingEnabled) {
    return res.status(503).json({
      error: "Premium billing is not available right now."
    });
  }

  try {
    const result = await createCheckoutForUser(req.user.id);
    return res.json({
      checkout_url: result.url,
      source: result.source
    });
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error("POST /billing/checkout:", error?.response?.data || error);
    return res.status(500).json({
      error: "Could not start checkout. Try again or contact support."
    });
  }
});

billingRouter.post("/devices/revoke-others", async (req, res) => {
  const deviceId = normalizeDeviceId(req.deviceId);
  if (!deviceId) {
    return res.status(400).json({ error: "Valid device id is required." });
  }

  try {
    const removed = await revokeOtherDevices(req.user.id, deviceId);
    return res.json({
      ok: true,
      removed_count: removed
    });
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error("POST /billing/devices/revoke-others:", error);
    return res.status(500).json({ error: "Failed to revoke other devices." });
  }
});
