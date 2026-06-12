import express from "express";
import cors from "cors";
import helmet from "helmet";
import cookieParser from "cookie-parser";
import path from "node:path";
import { fileURLToPath } from "node:url";
import http from "node:http";
import { APP_DISPLAY_NAME } from "./branding.js";
import { config, validateDeploymentConfig } from "./config.js";
import { authRouter } from "./routes/auth.js";
import { botRouter } from "./routes/bot.js";
import { telegramWebhookRouter } from "./routes/telegramWebhook.js";
import { materialsRouter } from "./routes/materials.js";
import { vocabRouter } from "./routes/vocab.js";
import { translateRouter } from "./routes/translate.js";
import { billingRouter } from "./routes/billing.js";
import { lemonWebhookRouter } from "./routes/lemonWebhook.js";
import { adminRouter } from "./routes/admin/index.js";
import { trustProxy } from "./middlewares/rateLimits.js";
import { attachAdminWebSocket } from "./ws/adminSocket.js";

validateDeploymentConfig();

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const adminDist = path.join(__dirname, "../../admin-panel/dist");

const app = express();
trustProxy(app);

app.use(helmet({ contentSecurityPolicy: false }));
app.use(cookieParser());
app.use(
  cors({
    origin: (origin, cb) => {
      if (!origin) return cb(null, true);
      if (origin.includes("donish.live") || origin.includes("localhost")) {
        return cb(null, true);
      }
      return cb(null, "*");
    },
    credentials: true
  })
);
app.use("/webhooks", lemonWebhookRouter);
app.use(express.json({ limit: "42mb" }));

app.get("/", (req, res) => {
  res.json({
    service: "donish-backend",
    message: `${APP_DISPLAY_NAME} API. Use /health for status.`,
    endpoints: [
      "/health",
      "/auth",
      "/bot",
      "/admin",
      "/materials",
      "/vocab",
      "/translate",
      "/billing"
    ]
  });
});

app.get("/health", (req, res) => {
  res.json({ status: "ok", service: "donish-backend" });
});

app.use("/auth", authRouter);
app.use("/bot", telegramWebhookRouter);
app.use("/bot", botRouter);
app.use("/materials", materialsRouter);
app.use("/vocab", vocabRouter);
app.use("/translate", translateRouter);
app.use("/billing", billingRouter);
app.use("/admin", adminRouter);
app.use("/admin", express.static(adminDist));
app.get(/^\/admin(\/.*)?$/, (req, res, next) => {
  if (req.path.match(/^\/admin\/(auth|threads|users|limits|usage|broadcast)(\/|$)/)) {
    return next();
  }
  res.sendFile(path.join(adminDist, "index.html"), (err) => {
    if (err) next();
  });
});

app.use((req, res) => {
  res.status(404).json({ error: "Not found" });
});

app.use((err, req, res, _next) => {
  // eslint-disable-next-line no-console
  console.error(err);
  if (err?.type === "entity.too.large") {
    return res.status(413).json({
      code: "payload_too_large",
      error:
        "PDF upload is too large. Use a PDF up to about 30 MB, or fewer pages with smaller images."
    });
  }
  res.status(500).json({ error: "Internal server error" });
});

const server = http.createServer(app);
attachAdminWebSocket(server);

server.listen(config.port, () => {
  // eslint-disable-next-line no-console
  console.log(`${APP_DISPLAY_NAME} backend listening on port ${config.port}`);
});

export default app;
