import express from "express";
import axios from "axios";
import { requireAuth } from "../middlewares/authMiddleware.js";
import { config } from "../config.js";
import { translateLimiter } from "../middlewares/rateLimits.js";

export const translateRouter = express.Router();

translateRouter.use(requireAuth);
translateRouter.use(translateLimiter);

translateRouter.post("/", async (req, res) => {
  const { word, context_sentence } = req.body || {};

  if (!word || !context_sentence) {
    return res
      .status(400)
      .json({ error: "word and context_sentence are required." });
  }

  if (!config.openAiApiKey) {
    return res.status(500).json({ error: "OpenAI API key not configured." });
  }

  try {
    const systemPrompt =
      "You are a translation assistant. Translate the given English word or short phrase into natural Uzbek, taking into account the provided sentence context. Respond with a concise Uzbek translation only.";

    const userPrompt = `Word or phrase: ${word}\n\nContext sentence: ${context_sentence}\n\nReturn only the Uzbek translation.`;

    const response = await axios.post(
      "https://api.openai.com/v1/chat/completions",
      {
        model: "gpt-4.1-mini",
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userPrompt }
        ]
      },
      {
        headers: {
          Authorization: `Bearer ${config.openAiApiKey}`,
          "Content-Type": "application/json"
        }
      }
    );

    const translation =
      response.data.choices?.[0]?.message?.content?.trim() || "";

    return res.json({
      translation_uz: translation
    });
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error("POST /translate error:", error?.response?.data || error);
    return res.status(500).json({ error: "Failed to translate word." });
  }
});

