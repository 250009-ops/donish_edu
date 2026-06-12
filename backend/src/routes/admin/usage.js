import express from "express";
import { requireAdminAuth } from "../../middlewares/adminAuth.js";
import {
  getUsageByUser,
  getUsageSummary
} from "../../services/openaiUsageService.js";

export const adminUsageRouter = express.Router();
adminUsageRouter.use(requireAdminAuth);

adminUsageRouter.get("/summary", async (req, res) => {
  const summary = await getUsageSummary({
    from: req.query.from,
    to: req.query.to
  });
  res.json(summary);
});

adminUsageRouter.get("/users", async (req, res) => {
  const users = await getUsageByUser({
    from: req.query.from,
    to: req.query.to,
    limit: Number(req.query.limit) || 50
  });
  res.json({ users });
});
