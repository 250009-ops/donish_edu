import express from "express";
import { requireAdminAuth, requireRole } from "../../middlewares/adminAuth.js";
import { auditAdmin } from "../../middlewares/adminAudit.js";
import {
  createBroadcastJob,
  getBroadcastJob
} from "../../services/broadcastService.js";

export const adminBroadcastRouter = express.Router();
adminBroadcastRouter.use(requireAdminAuth);

adminBroadcastRouter.post(
  "/",
  requireRole("superadmin"),
  auditAdmin("broadcast"),
  async (req, res) => {
    const body = String(req.body?.body || "").trim();
    const audience = req.body?.audience || "all";
    if (!body) return res.status(400).json({ error: "body required." });
    const job = await createBroadcastJob({
      adminId: req.admin.id,
      body,
      audience
    });
    res.status(201).json({ job });
  }
);

adminBroadcastRouter.get("/:id", async (req, res) => {
  const job = await getBroadcastJob(Number(req.params.id));
  if (!job) return res.status(404).json({ error: "Not found." });
  res.json({ job });
});
