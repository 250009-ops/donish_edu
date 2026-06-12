import { WebSocketServer } from "ws";
import jwt from "jsonwebtoken";
import { config } from "../config.js";
import { eventBus } from "../realtime/eventBus.js";
import { findAdminById } from "../services/adminAuthService.js";

/** @param {import('http').Server} server */
export function attachAdminWebSocket(server) {
  const wss = new WebSocketServer({ server, path: "/admin/ws" });

  wss.on("connection", async (ws, req) => {
    try {
      const url = new URL(req.url || "", "http://localhost");
      const ticket = url.searchParams.get("ticket");
      if (!ticket) {
        ws.close(4401, "Unauthorized");
        return;
      }
      const secret = config.adminJwtSecret || config.jwtSecret;
      const payload = jwt.verify(ticket, secret);
      if (payload.typ !== "admin_access") {
        ws.close(4401, "Unauthorized");
        return;
      }
      const admin = await findAdminById(Number(payload.sub));
      if (!admin?.is_active) {
        ws.close(4401, "Unauthorized");
        return;
      }

      const onSupport = (data) => {
        if (ws.readyState === 1) {
          ws.send(JSON.stringify({ type: "support:new", ...data }));
        }
      };
      const onBroadcast = (data) => {
        if (ws.readyState === 1) {
          ws.send(JSON.stringify({ type: "broadcast:progress", ...data }));
        }
      };
      eventBus.on("support:new", onSupport);
      eventBus.on("broadcast:progress", onBroadcast);
      ws.on("close", () => {
        eventBus.off("support:new", onSupport);
        eventBus.off("broadcast:progress", onBroadcast);
      });
      ws.send(JSON.stringify({ type: "connected" }));
    } catch {
      ws.close(4401, "Unauthorized");
    }
  });

  return wss;
}
