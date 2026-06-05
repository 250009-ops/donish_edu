import express from "express";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import { query } from "../db/pool.js";
import { config } from "../config.js";
import { loginLimiter } from "../middlewares/rateLimits.js";

export const authRouter = express.Router();

authRouter.post("/login", loginLimiter, async (req, res) => {
  const { id, password } = req.body || {};
  const telegramId = id !== undefined && id !== null ? Number(id) : NaN;

  if (!Number.isInteger(telegramId) || !password) {
    return res.status(400).json({ error: "ID and password are required." });
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

    const token = jwt.sign(
      { sub: user.id, telegram_id: user.telegram_id },
      config.jwtSecret,
      { expiresIn: config.jwtExpiresIn }
    );

    const responseTelegramId = Number(user.telegram_id);
    return res.json({
      token,
      user: {
        id: user.id,
        telegram_id: Number.isFinite(responseTelegramId)
          ? responseTelegramId
          : user.telegram_id,
        created_at: user.created_at
      }
    });
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error("Login DB error:", error);
    return res.status(500).json({ error: "Failed to query user." });
  }
});
