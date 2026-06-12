import express from "express";
import { requireAdminAuth, requireRole } from "../../middlewares/adminAuth.js";
import { auditAdmin } from "../../middlewares/adminAudit.js";
import {
  getGlobalLimits,
  updateGlobalLimits
} from "../../services/limitsService.js";

export const adminLimitsRouter = express.Router();
adminLimitsRouter.use(requireAdminAuth);

adminLimitsRouter.get("/", async (_req, res) => {
  res.json(await getGlobalLimits());
});

adminLimitsRouter.put(
  "/",
  requireRole("superadmin"),
  auditAdmin("update_global_limits"),
  async (req, res) => {
    const updated = await updateGlobalLimits(req.body || {}, req.admin.id);
    res.json(updated);
  }
);
