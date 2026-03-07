import express from "express";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import { supabaseAdmin } from "../supabaseClient.js";
import { config } from "../config.js";

export const authRouter = express.Router();

authRouter.post("/login", async (req, res) => {
  const { username, password } = req.body || {};

  if (!username || !password) {
    return res.status(400).json({ error: "Username and password are required." });
  }

  const { data: users, error } = await supabaseAdmin
    .from("users")
    .select("*")
    .eq("username", username)
    .limit(1);

  if (error) {
    // eslint-disable-next-line no-console
    console.error("Login DB error:", error);
    return res.status(500).json({ error: "Failed to query user." });
  }

  const user = users?.[0];
  if (!user) {
    return res.status(401).json({ error: "Invalid credentials." });
  }

  const ok = await bcrypt.compare(password, user.password_hash);
  if (!ok) {
    return res.status(401).json({ error: "Invalid credentials." });
  }

  const token = jwt.sign(
    { sub: user.id, username: user.username },
    config.jwtSecret,
    { expiresIn: config.jwtExpiresIn }
  );

  return res.json({
    token,
    user: {
      id: user.id,
      username: user.username
    }
  });
});

