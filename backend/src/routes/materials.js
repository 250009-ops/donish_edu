import express from "express";
import multer from "multer";
import { supabaseAdmin } from "../supabaseClient.js";
import { requireAuth } from "../middlewares/authMiddleware.js";
import {
  authenticatedApiLimiter,
  extractPreviewLimiter
} from "../middlewares/rateLimits.js";
import {
  extractTextFromPdfWithTextract,
  TextractJobFailedError,
  TextractNotConfiguredError,
  TextractTimeoutError
} from "../services/textractExtract.js";

export const materialsRouter = express.Router();

/** Reject PDFs with more than this many pages (Textract async). */
const MAX_PDF_PAGES = 30;

/** Max decoded PDF size. Base64 upload needs ~4/3× this in JSON body limit. */
const MAX_FILE_BYTES = 10 * 1024 * 1024;

/** Stored reader text upper bound (characters). */
const MAX_CONTENT_TEXT_CHARS = 800_000;

const ALLOWED_TYPES = new Set([
  "Article",
  "Short Story",
  "Book",
  "Document",
  "Other"
]);

const ALLOWED_LEVELS = new Set(["A1", "A2", "B1", "B2", "C1", "C2"]);

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_FILE_BYTES },
  fileFilter: (_req, file, cb) => {
    const ok =
      file.mimetype === "application/pdf" ||
      (file.originalname || "").toLowerCase().endsWith(".pdf");
    if (ok) {
      cb(null, true);
    } else {
      cb(new Error("Only PDF files are allowed."));
    }
  }
});

materialsRouter.use(requireAuth);
materialsRouter.use(authenticatedApiLimiter);

function parseMaterialsListQuery(req) {
  let limit = parseInt(String(req.query.limit ?? "50"), 10);
  if (!Number.isFinite(limit) || limit < 1) limit = 50;
  if (limit > 100) limit = 100;

  let offset = parseInt(String(req.query.offset ?? "0"), 10);
  if (!Number.isFinite(offset) || offset < 0) offset = 0;
  if (offset > 1_000_000) offset = 1_000_000;

  const materialType =
    typeof req.query.material_type === "string"
      ? req.query.material_type.trim()
      : "";
  const englishLevel =
    typeof req.query.english_level === "string"
      ? req.query.english_level.trim()
      : "";
  const qRaw =
    typeof req.query.q === "string" ? req.query.q.trim().slice(0, 200) : "";

  return { limit, offset, materialType, englishLevel, qRaw };
}

/**
 * @param {Buffer} buffer
 * @returns {Promise<{ ok: true, contentText: string, numPages: number } | { ok: false, status: number, json: object }>}
 */
async function extractTextFromPdfBuffer(buffer) {
  if (!buffer?.length) {
    return {
      ok: false,
      status: 400,
      json: { error: "Decoded PDF is empty." }
    };
  }

  try {
    const { contentText, numPages } = await extractTextFromPdfWithTextract(
      buffer,
      { maxPages: MAX_PDF_PAGES, maxBytes: MAX_FILE_BYTES }
    );
    return { ok: true, contentText, numPages };
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error("Textract extract error:", e);

    if (e instanceof TextractNotConfiguredError) {
      return {
        ok: false,
        status: 503,
        json: {
          code: "textract_not_configured",
          error:
            "PDF text extraction is temporarily unavailable. Please try again later."
        }
      };
    }

    if (e instanceof TextractTimeoutError) {
      return {
        ok: false,
        status: 504,
        json: {
          code: "textract_timeout",
          error: e.message
        }
      };
    }

    if (e instanceof TextractJobFailedError) {
      return {
        ok: false,
        status: 400,
        json: {
          code: "pdf_unreadable",
          error:
            "Could not read this PDF. The file may be corrupted, encrypted, password-protected, or not a valid PDF. Try another file."
        }
      };
    }

    const msg = e instanceof Error ? e.message : String(e);

    if (msg.includes("too large")) {
      return {
        ok: false,
        status: 400,
        json: { error: msg }
      };
    }

    if (msg.includes("pages. Please upload")) {
      return {
        ok: false,
        status: 400,
        json: { error: msg }
      };
    }

    if (msg.includes("ENOTFOUND") || msg.includes("getaddrinfo")) {
      return {
        ok: false,
        status: 503,
        json: {
          code: "textract_not_configured",
          error:
            "PDF extraction region is misconfigured. Set AWS_REGION to a Textract region (e.g. eu-west-1) and use an S3 bucket in the same region."
        }
      };
    }

    if (msg === "NO_EXTRACTABLE_TEXT") {
      return {
        ok: false,
        status: 400,
        json: {
          code: "pdf_no_extractable_text",
          error:
            "We could not find readable text in this PDF. Try a clearer scan, a different export, or another file."
        }
      };
    }

    return {
      ok: false,
      status: 400,
      json: {
        code: "pdf_unreadable",
        error:
          "Could not extract text from this PDF. Try another file or a clearer document."
      }
    };
  }
}

function safeFileName(originalName) {
  return (originalName || "document.pdf").replace(/[^\w.\- ()]+/g, "_");
}

function validateMaterialMeta(title, materialType, englishLevel, res) {
  if (!title || !materialType || !englishLevel) {
    res.status(400).json({
      error: "Please provide title, material type, and English level."
    });
    return false;
  }
  if (!ALLOWED_TYPES.has(materialType)) {
    res.status(400).json({ error: "Invalid material_type." });
    return false;
  }
  if (!ALLOWED_LEVELS.has(englishLevel)) {
    res.status(400).json({ error: "Invalid english_level." });
    return false;
  }
  return true;
}

/** JSON: pdf_base64 — parse only, no DB row. Client edits text then POST /materials with content_text. */
materialsRouter.post("/extract-preview", extractPreviewLimiter, async (req, res) => {
  const b64 = req.body?.pdf_base64;
  if (typeof b64 !== "string" || !b64.trim()) {
    return res.status(400).json({ error: "pdf_base64 is required." });
  }

  let buffer;
  try {
    buffer = Buffer.from(b64, "base64");
  } catch {
    return res.status(400).json({ error: "Invalid pdf_base64 encoding." });
  }

  const result = await extractTextFromPdfBuffer(buffer);
  if (!result.ok) {
    return res.status(result.status).json(result.json);
  }

  return res.json({
    extracted_text: result.contentText,
    page_count: result.numPages
  });
});

materialsRouter.get("/", async (req, res) => {
  const { limit, offset, materialType, englishLevel, qRaw } =
    parseMaterialsListQuery(req);

  const fetchSize = limit + 1;
  const rangeEnd = offset + fetchSize - 1;

  let query = supabaseAdmin
    .from("materials")
    .select(
      "id, title, file_path, page_count, material_type, english_level, created_at"
    )
    .eq("user_id", req.user.id);

  if (materialType && ALLOWED_TYPES.has(materialType)) {
    query = query.eq("material_type", materialType);
  }
  if (englishLevel && ALLOWED_LEVELS.has(englishLevel)) {
    query = query.eq("english_level", englishLevel);
  }

  const safeQ = qRaw.replace(/[%_\\]/g, " ").trim();
  if (safeQ.length > 0) {
    query = query.ilike("title", `%${safeQ}%`);
  }

  const { data, error } = await query
    .order("created_at", { ascending: false })
    .range(offset, rangeEnd);

  if (error) {
    // eslint-disable-next-line no-console
    console.error("GET /materials error:", error);
    return res.status(500).json({ error: "Failed to load materials." });
  }

  const rows = data || [];
  const hasMore = rows.length > limit;
  const items = hasMore ? rows.slice(0, limit) : rows;

  return res.json({ items, has_more: hasMore });
});

materialsRouter.get("/:id", async (req, res) => {
  const { id } = req.params;
  if (!UUID_RE.test(id)) {
    return res.status(400).json({ error: "Invalid material id." });
  }

  const { data, error } = await supabaseAdmin
    .from("materials")
    .select(
      "id, user_id, title, file_path, page_count, material_type, english_level, content_text, created_at"
    )
    .eq("id", id)
    .eq("user_id", req.user.id)
    .maybeSingle();

  if (error) {
    // eslint-disable-next-line no-console
    console.error("GET /materials/:id error:", error);
    return res.status(500).json({ error: "Failed to load material." });
  }

  if (!data) {
    return res.status(404).json({ error: "Material not found." });
  }

  return res.json(data);
});

materialsRouter.delete("/:id", async (req, res) => {
  const { id } = req.params;
  if (!UUID_RE.test(id)) {
    return res.status(400).json({ error: "Invalid material id." });
  }

  const { data: row, error: findErr } = await supabaseAdmin
    .from("materials")
    .select("id")
    .eq("id", id)
    .eq("user_id", req.user.id)
    .maybeSingle();

  if (findErr) {
    // eslint-disable-next-line no-console
    console.error("DELETE /materials/:id lookup error:", findErr);
    return res.status(500).json({ error: "Failed to verify material." });
  }
  if (!row) {
    return res.status(404).json({ error: "Material not found." });
  }

  const { error: delErr } = await supabaseAdmin
    .from("materials")
    .delete()
    .eq("id", id)
    .eq("user_id", req.user.id);

  if (delErr) {
    // eslint-disable-next-line no-console
    console.error("DELETE /materials/:id error:", delErr);
    return res.status(500).json({ error: "Failed to delete material." });
  }

  return res.status(204).send();
});

function handleMulter(req, res, next) {
  upload.single("file")(req, res, (err) => {
    if (err) {
      if (err.code === "LIMIT_FILE_SIZE") {
        return res.status(400).json({
          error: `PDF file is too large (max ${MAX_FILE_BYTES / (1024 * 1024)} MB).`
        });
      }
      return res.status(400).json({ error: err.message || "Upload failed." });
    }
    next();
  });
}

/**
 * POST /materials
 * - JSON with non-empty content_text: save edited extract (no PDF re-upload).
 * - JSON with pdf_base64 or multipart file: parse PDF and save.
 */
materialsRouter.post(
  "/",
  (req, res, next) => {
    const ct = req.headers["content-type"] || "";
    if (ct.includes("multipart/form-data")) {
      return handleMulter(req, res, next);
    }
    return next();
  },
  async (req, res) => {
    const title =
      typeof req.body?.title === "string" ? req.body.title.trim() : "";
    const materialType =
      typeof req.body?.material_type === "string"
        ? req.body.material_type.trim()
        : "";
    const englishLevel =
      typeof req.body?.english_level === "string"
        ? req.body.english_level.trim()
        : "";

    if (!validateMaterialMeta(title, materialType, englishLevel, res)) {
      return;
    }

    const ct = req.headers["content-type"] || "";

    const contentTextRaw = req.body?.content_text;
    const trimmedClientText =
      typeof contentTextRaw === "string"
        ? contentTextRaw.replace(/\u0000/g, "").trim()
        : "";

    if (trimmedClientText.length > 0) {
      if (ct.includes("multipart/form-data")) {
        return res.status(400).json({
          error:
            "Use JSON with content_text to save edited text, not multipart."
        });
      }
      if (trimmedClientText.length > MAX_CONTENT_TEXT_CHARS) {
        return res.status(400).json({
          error: `Text is too long (max ${MAX_CONTENT_TEXT_CHARS} characters).`
        });
      }

      let pageCount = 0;
      const pc = req.body?.page_count;
      if (pc != null && Number.isFinite(Number(pc))) {
        const n = Math.floor(Number(pc));
        if (n > 0 && n <= MAX_PDF_PAGES) pageCount = n;
      }

      const originalName =
        typeof req.body?.file_name === "string" && req.body.file_name.trim()
          ? req.body.file_name.trim()
          : "document.pdf";
      const safeName = safeFileName(originalName);

      const { data, error } = await supabaseAdmin
        .from("materials")
        .insert({
          user_id: req.user.id,
          title,
          file_path: safeName,
          page_count: pageCount,
          material_type: materialType,
          english_level: englishLevel,
          content_text: trimmedClientText
        })
        .select(
          "id, title, file_path, page_count, material_type, english_level, created_at"
        )
        .single();

      if (error) {
        // eslint-disable-next-line no-console
        console.error("POST /materials (content_text) error:", error);
        return res.status(500).json({ error: "Failed to save material." });
      }

      return res.status(201).json(data);
    }

    let buffer;
    let originalName = "document.pdf";

    if (ct.includes("application/json")) {
      const b64 = req.body?.pdf_base64;
      if (typeof b64 !== "string" || !b64.trim()) {
        return res.status(400).json({
          error:
            "Provide pdf_base64 to upload a PDF, or content_text with your edited extract."
        });
      }
      try {
        buffer = Buffer.from(b64, "base64");
      } catch {
        return res.status(400).json({ error: "Invalid pdf_base64 encoding." });
      }
      if (typeof req.body.file_name === "string" && req.body.file_name.trim()) {
        originalName = req.body.file_name.trim();
      }
    } else {
      const file = req.file;
      if (!file || !file.buffer?.length) {
        return res.status(400).json({
          error:
            "PDF file is required. Send multipart/form-data with field \"file\", or application/json with pdf_base64 or content_text."
        });
      }
      buffer = file.buffer;
      originalName = file.originalname || "document.pdf";
    }

    const result = await extractTextFromPdfBuffer(buffer);
    if (!result.ok) {
      return res.status(result.status).json(result.json);
    }

    const safeName = safeFileName(originalName);

    const { data, error } = await supabaseAdmin
      .from("materials")
      .insert({
        user_id: req.user.id,
        title,
        file_path: safeName,
        page_count: result.numPages,
        material_type: materialType,
        english_level: englishLevel,
        content_text: result.contentText
      })
      .select(
        "id, title, file_path, page_count, material_type, english_level, created_at"
      )
      .single();

    if (error) {
      // eslint-disable-next-line no-console
      console.error("POST /materials error:", error);
      return res.status(500).json({ error: "Failed to save material." });
    }

    return res.status(201).json(data);
  }
);
