import { config } from "../config.js";
import { findAdminById, verifyToken } from "../services/adminAuthService.js";

export async function requireAdminAuth(req, res, next) {
  const header = req.get("Authorization") || "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : "";
  if (!token) {
    return res.status(401).json({ error: "Unauthorized." });
  }
  try {
    const payload = verifyToken(token, "admin_access");
    const admin = await findAdminById(Number(payload.sub));
    if (!admin || !admin.is_active) {
      return res.status(401).json({ error: "Unauthorized." });
    }
    if (
      config.adminIpAllowlist.length &&
      !config.adminIpAllowlist.includes(req.ip)
    ) {
      return res.status(403).json({ error: "IP not allowed." });
    }
    req.admin = admin;
    next();
  } catch {
    return res.status(401).json({ error: "Unauthorized." });
  }
}

export function requireRole(...roles) {
  return (req, res, next) => {
    if (!req.admin || !roles.includes(req.admin.role)) {
      return res.status(403).json({ error: "Forbidden." });
    }
    next();
  };
}
