import express from "express";
import cors from "cors";
import helmet from "helmet";
import { config, validateDeploymentConfig } from "./config.js";
import { authRouter } from "./routes/auth.js";
import { botRouter } from "./routes/bot.js";
import { materialsRouter } from "./routes/materials.js";
import { vocabRouter } from "./routes/vocab.js";
import { translateRouter } from "./routes/translate.js";
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
app.use(express.json({ limit: "8mb" }));

app.get("/", (req, res) => {
  res.json({
    service: "donish-backend",
    message: "Donish API. Use /health for status.",
    endpoints: [
      "/health",
      "/auth",
      "/bot",
      "/materials (GET paginated: ?limit&offset&q&material_type&english_level)",
      "/materials/extract-preview (POST, JSON pdf_base64)",
      "/materials/:id (GET, DELETE)",
      "/vocab",
      "/vocab/practice",
      "/translate"
    ]
  });
});

app.get("/health", (req, res) => {
  res.json({ status: "ok", service: "donish-backend" });
});

app.use("/auth", authRouter);
app.use("/bot", botRouter);
app.use("/materials", materialsRouter);
app.use("/vocab", vocabRouter);
app.use("/translate", translateRouter);

app.use((req, res) => {
  res.status(404).json({ error: "Not found" });
});

app.use((err, req, res, next) => {
  // eslint-disable-next-line no-console
  console.error(err);
  res.status(500).json({ error: "Internal server error" });
});

// On Vercel, the app is used as a serverless handler; do not call listen.
if (!process.env.VERCEL) {
  app.listen(config.port, () => {
    // eslint-disable-next-line no-console
    console.log(`Donish backend listening on port ${config.port}`);
  });
}

export default app;

