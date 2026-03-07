import express from "express";
import cors from "cors";
import helmet from "helmet";
import { config } from "./config.js";
import { authRouter } from "./routes/auth.js";
import { botRouter } from "./routes/bot.js";
import { materialsRouter } from "./routes/materials.js";
import { vocabRouter } from "./routes/vocab.js";
import { translateRouter } from "./routes/translate.js";

const app = express();

app.use(helmet());
app.use(
  cors({
    origin: "*"
  })
);
app.use(express.json());

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

app.listen(config.port, () => {
  // eslint-disable-next-line no-console
  console.log(`Donish backend listening on port ${config.port}`);
});

