import express from "express";
import crypto from "node:crypto";
import { config } from "../config.js";
import { applySubscriptionFromWebhook } from "../services/subscriptionService.js";

export const lemonWebhookRouter = express.Router();

function verifySignature(rawBody, signatureHeader) {
  const secret = config.lemonSqueezyWebhookSecret;
  if (!secret) return process.env.NODE_ENV !== "production";
  if (!signatureHeader || !rawBody) return false;

  const digest = crypto
    .createHmac("sha256", secret)
    .update(rawBody)
    .digest("hex");
  try {
    return crypto.timingSafeEqual(
      Buffer.from(digest, "utf8"),
      Buffer.from(String(signatureHeader), "utf8")
    );
  } catch {
    return false;
  }
}

lemonWebhookRouter.post(
  "/lemon-squeezy",
  express.raw({ type: "application/json" }),
  async (req, res) => {
    const rawBody = req.body;
    const signature =
      req.headers["x-signature"] || req.headers["x-event-signature"];

    if (!verifySignature(rawBody, signature)) {
      return res.status(401).json({ error: "Invalid webhook signature." });
    }

    let payload;
    try {
      payload = JSON.parse(rawBody.toString("utf8"));
    } catch {
      return res.status(400).json({ error: "Invalid JSON payload." });
    }

    const eventName = payload?.meta?.event_name || "";
    const eventId = String(
      payload?.meta?.webhook_id || `${eventName}:${payload?.data?.id || ""}`
    );
    const attributes = payload?.data?.attributes || {};
    const customData =
      payload?.meta?.custom_data ||
      attributes?.custom_data ||
      attributes?.checkout_data?.custom ||
      {};

    try {
      await applySubscriptionFromWebhook({
        eventName,
        eventId,
        attributes,
        customData,
        resourceId: payload?.data?.id,
        resourceType: payload?.data?.type
      });
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error("lemon webhook handler:", error);
      return res.status(500).json({ error: "Webhook handler failed." });
    }

    return res.json({ received: true });
  }
);
