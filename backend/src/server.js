import express from "express";
import cors from "cors";
import helmet from "helmet";
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
import { trustProxy } from "./middlewares/rateLimits.js";

validateDeploymentConfig();

const app = express();
trustProxy(app);

app.use(helmet());
app.use(
  cors({
    origin: "*"
  })
);
app.use("/webhooks", lemonWebhookRouter);
/** Base64 PDF uploads: allow ~10 MB file + encoding overhead. */
app.use(express.json({ limit: "14mb" }));

app.get("/", (req, res) => {
  res.json({
    service: "donish-backend",
    message: `${APP_DISPLAY_NAME} API. Use /health for status.`,
    endpoints: [
      "/health",
      "/auth",
      "/bot",
      "/bot/lookup-user (POST, bot)",
      "/bot/reset-password (POST, bot)",
      "/bot/telegram-webhook (POST, Telegram updates — setWebhook URL here)",
      "/materials (GET paginated: ?limit&offset&q&material_type&english_level)",
      "/materials/extract-preview (POST, JSON pdf_base64)",
      "/materials/:id (GET, DELETE)",
      "/vocab",
      "/vocab/days",
      "/vocab/lexicon",
      "/vocab/practice",
      "/translate",
      "/billing/subscription (GET)",
      "/billing/checkout (POST)",
      "/billing/devices/revoke-others (POST)",
      "/webhooks/lemon-squeezy (POST)"
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
        "PDF upload is too large. Use a PDF up to about 10 MB, or fewer pages with smaller images."
    });
  }
  res.status(500).json({ error: "Internal server error" });
});

app.listen(config.port, () => {
  // eslint-disable-next-line no-console
  console.log(`${APP_DISPLAY_NAME} backend listening on port ${config.port}`);
});

export default app;

