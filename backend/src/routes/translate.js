import express from "express";
import axios from "axios";
import { requireAuth } from "../middlewares/authMiddleware.js";
import { config } from "../config.js";
import { translateLimiter } from "../middlewares/rateLimits.js";
import {
  getUserWordCache,
  isValidLocalDate,
  normalizeWord,
  pruneOlderThanRetention,
  recordTapForLocalDate,
  upsertUserWordCache
} from "../services/wordCache.js";

export const translateRouter = express.Router();

translateRouter.use(requireAuth);
translateRouter.use(translateLimiter);

function normalizeContext(input) {
  return String(input || "").trim().replace(/\s+/g, " ");
}

function cleanText(value) {
  return String(value || "")
    .trim()
    .replace(/^["'`]+|["'`]+$/g, "")
    .replace(/\s+/g, " ");
}

function parseTranslationPayload(rawContent) {
  const text = String(rawContent || "").trim();
  if (!text) {
    return { context: "", base: "" };
  }

  let parsed = null;
  try {
    parsed = JSON.parse(text);
  } catch (_) {
    const match = text.match(/\{[\s\S]*\}/);
    if (match) {
      try {
        parsed = JSON.parse(match[0]);
      } catch (_) {}
    }
  }

  if (parsed && typeof parsed === "object") {
    const context = cleanText(
      parsed.translation_context_uz || parsed.translation_uz || ""
    );
    const base = cleanText(
      parsed.translation_base_uz || parsed.base_translation_uz || context
    );
    return { context, base };
  }

  const fallback = cleanText(text);
  return { context: fallback, base: fallback };
}

function isLikelyContextualUzbek(text) {
  const t = cleanText(text).toLowerCase();
  if (!t) return true;

  const phraseMarkers = [
    " bo'lgan",
    " bo‘lgan",
    " jarayonida",
    " paytida",
    " davomida",
    " holatida",
    " uchun",
    " bilan",
    " haqida",
    " kabi",
    " tomon",
    " ustida",
    " ostida",
    " oldin",
    " keyin"
  ];
  if (phraseMarkers.some((m) => t.includes(m))) return true;

  const words = t.split(/\s+/).filter(Boolean);
  return words.length >= 4;
}

async function requestTranslationPair(normalizedWord, normalizedContext) {
  const systemPrompt =
    "You are a translation assistant. Return only valid JSON with keys translation_context_uz and translation_base_uz. translation_context_uz must be context-aware Uzbek meaning for the sentence. translation_base_uz must be the dictionary/base Uzbek meaning of only the selected word, without extra particles, prepositions, or sentence fragments.";

  const userPrompt =
    `Selected English word: ${normalizedWord}\n\n` +
    `Context sentence: ${normalizedContext}\n\n` +
    "Rules:\n" +
    "- Keep output concise.\n" +
    "- translation_base_uz must be a clean base meaning for memorization.\n" +
    '- Do not include explanations.\n' +
    '- Output strictly as JSON: {"translation_context_uz":"...","translation_base_uz":"..."}';

  const response = await axios.post(
    "https://api.openai.com/v1/chat/completions",
    {
      model: "gpt-4.1-mini",
      temperature: 0,
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: userPrompt }
      ]
    },
    {
      headers: {
        Authorization: `Bearer ${config.openAiApiKey}`,
        "Content-Type": "application/json"
      },
      timeout: 15000
    }
  );

  const raw = response.data.choices?.[0]?.message?.content?.trim() || "";
  return parseTranslationPayload(raw);
}

async function requestStrictBaseOnly(normalizedWord) {
  const systemPrompt =
    "You are a bilingual dictionary assistant. Return only Uzbek base/dictionary meaning for one English word. No context phrases, no explanations, no punctuation.";
  const userPrompt =
    `English word: ${normalizedWord}\n\n` +
    'Return JSON only: {"translation_base_uz":"..."}';

  const response = await axios.post(
    "https://api.openai.com/v1/chat/completions",
    {
      model: "gpt-4.1-mini",
      temperature: 0,
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: userPrompt }
      ]
    },
    {
      headers: {
        Authorization: `Bearer ${config.openAiApiKey}`,
        "Content-Type": "application/json"
      },
      timeout: 15000
    }
  );

  const raw = response.data.choices?.[0]?.message?.content?.trim() || "";
  const parsed = parseTranslationPayload(raw);
  return cleanText(parsed.base || parsed.context);
}

function buildPayload({
  word,
  baseTranslation,
  contextTranslation,
  fromCache,
  savedForPractice,
  vocabEntryId
}) {
  return {
    word,
    translation_uz: baseTranslation,
    translation_base_uz: baseTranslation,
    translation_context_uz: fromCache ? "" : contextTranslation,
    from_cache: fromCache,
    saved_for_practice: savedForPractice === true,
    vocab_entry_id: vocabEntryId || null
  };
}

translateRouter.post("/", async (req, res) => {
  const {
    word,
    context_sentence,
    local_date: localDate,
    material_id: materialId
  } = req.body || {};
  const normalizedWord = normalizeWord(word);
  const normalizedContext = normalizeContext(context_sentence);

  if (!normalizedWord || !normalizedContext) {
    return res
      .status(400)
      .json({ error: "word and context_sentence are required." });
  }

  if (!localDate || !isValidLocalDate(localDate)) {
    return res.status(400).json({
      error: "local_date is required (YYYY-MM-DD, device local calendar day)."
    });
  }

  const userId = req.user.id;

  const pruneErr = await pruneOlderThanRetention(userId);
  if (pruneErr) {
    // eslint-disable-next-line no-console
    console.error("POST /translate prune error:", pruneErr);
  }

  const { row: cachedRow, error: cacheLookupErr } = await getUserWordCache(
    userId,
    normalizedWord
  );
  if (cacheLookupErr) {
    // eslint-disable-next-line no-console
    console.error("POST /translate cache lookup:", cacheLookupErr);
    return res.status(500).json({ error: "Failed to load word cache." });
  }

  if (cachedRow) {
    const base = cleanText(cachedRow.translation_base_uz);
    const { entry, error: tapErr } = await recordTapForLocalDate(userId, {
      word: normalizedWord,
      localDate,
      translationBaseUz: base,
      contextSentence: normalizedContext,
      materialId: materialId || null,
      savedForPractice: cachedRow.saved_for_practice === true
    });
    if (tapErr) {
      // eslint-disable-next-line no-console
      console.error("POST /translate tap record:", tapErr);
    }

    return res.json(
      buildPayload({
        word: normalizedWord,
        baseTranslation: base,
        contextTranslation: "",
        fromCache: true,
        savedForPractice: cachedRow.saved_for_practice === true,
        vocabEntryId: entry?.id
      })
    );
  }

  if (!config.openAiApiKey) {
    return res.status(500).json({ error: "OpenAI API key not configured." });
  }

  try {
    const parsed = await requestTranslationPair(
      normalizedWord,
      normalizedContext
    );
    const contextTranslation = parsed.context || parsed.base;
    let baseTranslation = parsed.base || contextTranslation;

    if (isLikelyContextualUzbek(baseTranslation)) {
      const strictBase = await requestStrictBaseOnly(normalizedWord);
      if (strictBase) {
        baseTranslation = strictBase;
      }
    }

    if (!baseTranslation) {
      baseTranslation = contextTranslation;
    }

    const { error: upsertErr } = await upsertUserWordCache(userId, {
      word: normalizedWord,
      translationBaseUz: baseTranslation,
      translationContextUz: contextTranslation,
      savedForPractice: false
    });
    if (upsertErr) {
      // eslint-disable-next-line no-console
      console.error("POST /translate cache upsert:", upsertErr);
    }

    const { entry, error: tapErr } = await recordTapForLocalDate(userId, {
      word: normalizedWord,
      localDate,
      translationBaseUz: baseTranslation,
      contextSentence: normalizedContext,
      materialId: materialId || null,
      savedForPractice: false
    });
    if (tapErr) {
      // eslint-disable-next-line no-console
      console.error("POST /translate tap record:", tapErr);
    }

    return res.json(
      buildPayload({
        word: normalizedWord,
        baseTranslation,
        contextTranslation,
        fromCache: false,
        savedForPractice: false,
        vocabEntryId: entry?.id
      })
    );
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error("POST /translate error:", error?.response?.data || error);
    return res.status(500).json({ error: "Failed to translate word." });
  }
});
