import express from "express";
import {
  createTelegramUser,
  lookupTelegramUser,
  resetTelegramUserPassword
} from "../services/botUserOperations.js";
import {
  botAccountLimiter,
  botCreateUserLimiter
} from "../middlewares/rateLimits.js";
import { requireBotSharedSecret } from "../middlewares/botSecretMiddleware.js";

export const botRouter = express.Router();

botRouter.post(
  "/lookup-user",
  botAccountLimiter,
  requireBotSharedSecret,
  async (req, res) => {
    const { telegram_id } = req.body || {};
    const tid =
      telegram_id !== undefined && telegram_id !== null
        ? Number(telegram_id)
        : NaN;

    const result = await lookupTelegramUser(tid);
    if (!result.ok) {
      const status = result.error === "telegram_id is required." ? 400 : 500;
      return res.status(status).json({ error: result.error });
    }

    if (!result.registered) {
      return res.json({ registered: false });
    }

    return res.json({
      registered: true,
      telegram_id: result.telegram_id
    });
  }
);

botRouter.post(
  "/reset-password",
  botAccountLimiter,
  requireBotSharedSecret,
  async (req, res) => {
    const { telegram_id, password } = req.body || {};
    const tid =
      telegram_id !== undefined && telegram_id !== null
        ? Number(telegram_id)
        : NaN;

    const result = await resetTelegramUserPassword(tid, password);
    if (!result.ok) {
      return res.status(result.status).json({ error: result.error });
    }

    return res.json({
      ok: true,
      telegram_id: result.telegram_id,
      message:
        "Password updated. Sign in to the app with your ID and new password."
    });
  }
);

botRouter.post(
  "/create-user",
  botCreateUserLimiter,
  requireBotSharedSecret,
  async (req, res) => {
    const { telegram_id, password } = req.body || {};
    const tid =
      telegram_id !== undefined && telegram_id !== null
        ? Number(telegram_id)
        : NaN;

    const result = await createTelegramUser(tid, password);
    if (!result.ok) {
      return res.status(result.status).json({ error: result.error });
    }

    return res.status(201).json({
      id: result.id,
      telegram_id: result.telegram_id
    });
  }
);
