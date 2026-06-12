import express from "express";
import { requireAdminAuth } from "../../middlewares/adminAuth.js";
import { auditAdmin } from "../../middlewares/adminAudit.js";
import {
  getThreadMessages,
  listThreads,
  markThreadRead,
  storeOutboundMessage
} from "../../services/supportService.js";
import { getBotInstance } from "../../telegram/botContext.js";
import { query } from "../../db/pool.js";

export const adminThreadsRouter = express.Router();
adminThreadsRouter.use(requireAdminAuth);

adminThreadsRouter.get("/", async (req, res) => {
  const threads = await listThreads({
    q: req.query.q,
    unreadOnly: req.query.unread === "1",
    limit: Number(req.query.limit) || 50,
    offset: Number(req.query.offset) || 0
  });
  res.json({ threads });
});

adminThreadsRouter.get("/:telegramId/messages", async (req, res) => {
  const tid = Number(req.params.telegramId);
  if (!Number.isInteger(tid)) {
    return res.status(400).json({ error: "Invalid telegram id." });
  }
  const messages = await getThreadMessages(tid, {
    before: req.query.before ? Number(req.query.before) : undefined,
    limit: Number(req.query.limit) || 50
  });
  await markThreadRead(tid);
  res.json({ messages });
});

adminThreadsRouter.post(
  "/:telegramId/reply",
  auditAdmin("support_reply"),
  async (req, res) => {
    const tid = Number(req.params.telegramId);
    const body = String(req.body?.body || "").trim();
    if (!Number.isInteger(tid) || !body) {
      return res.status(400).json({ error: "telegram_id and body required." });
    }
    const { rows } = await query(
      `select id from users where telegram_id = $1 limit 1`,
      [tid]
    );
    const userId = rows[0]?.id || null;
    const msg = await storeOutboundMessage({
      telegramId: tid,
      userId,
      body,
      adminId: req.admin.id
    });
    req.auditTarget = String(tid);
    const bot = getBotInstance();
    if (bot) {
      await bot.telegram.sendMessage(tid, `💬 Support: ${body}`);
    }
    res.json({ message: msg });
  }
);

adminThreadsRouter.post("/:telegramId/read", async (req, res) => {
  const tid = Number(req.params.telegramId);
  if (!Number.isInteger(tid)) {
    return res.status(400).json({ error: "Invalid telegram id." });
  }
  await markThreadRead(tid);
  res.json({ ok: true });
});
