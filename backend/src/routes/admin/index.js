import express from "express";
import { adminAuthRouter } from "./auth.js";
import { adminThreadsRouter } from "./threads.js";
import { adminUsersRouter } from "./users.js";
import { adminLimitsRouter } from "./limits.js";
import { adminUsageRouter } from "./usage.js";
import { adminBroadcastRouter } from "./broadcast.js";

export const adminRouter = express.Router();

adminRouter.use("/auth", adminAuthRouter);
adminRouter.use("/threads", adminThreadsRouter);
adminRouter.use("/users", adminUsersRouter);
adminRouter.use("/limits", adminLimitsRouter);
adminRouter.use("/usage", adminUsageRouter);
adminRouter.use("/broadcast", adminBroadcastRouter);
