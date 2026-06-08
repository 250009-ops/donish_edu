import express from "express";
import multer from "multer";
import { query } from "../db/pool.js";
import {
  requireAuth,
  requireRegisteredDevice
} from "../middlewares/authMiddleware.js";
import { requireMaterialUploadSlot } from "../middlewares/planMiddleware.js";
import {
  authenticatedApiLimiter,
  extractPreviewLimiter
} from "../middlewares/rateLimits.js";
import {
  extractTextFromPdf,
  PdfExtractFailedError,
  PdfExtractTimeoutError
} from "../services/pdfExtract.js";

export const materialsRouter = express.Router();

const MAX_PDF_PAGES = 30;
const MAX_FILE_BYTES = 10 * 1024 * 1024;
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
materialsRouter.use(requireRegisteredDevice);
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

async function extractTextFromPdfBuffer(buffer) {
  if (!buffer?.length) {
    return {
      ok: false,
      status: 400,
      json: { error: "Decoded PDF is empty." }
    };
  }

  try {
    const { contentText, numPages } = await extractTextFromPdf(buffer, {
      maxPages: MAX_PDF_PAGES,
      maxBytes: MAX_FILE_BYTES
    });
    return { ok: true, contentText, numPages };
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error("PDF extract error:", e);

    if (e instanceof PdfExtractTimeoutError) {
      return {
        ok: false,
        status: 504,
        json: {
          code: "textract_timeout",
          error: e.message
        }
      };
    }

    if (e instanceof PdfExtractFailedError) {
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
      return { ok: false, status: 400, json: { error: msg } };
    }

    if (msg.includes("pages. Please upload")) {
      return { ok: false, status: 400, json: { error: msg } };
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

  const params = [req.user.id];
  let sql = `select id, title, file_path, page_count, material_type, english_level, created_at
             from materials where user_id = $1::uuid`;
  let n = 2;

  if (materialType && ALLOWED_TYPES.has(materialType)) {
    sql += ` and material_type = $${n}`;
    params.push(materialType);
    n += 1;
  }
  if (englishLevel && ALLOWED_LEVELS.has(englishLevel)) {
    sql += ` and english_level = $${n}`;
    params.push(englishLevel);
    n += 1;
  }

  const safeQ = qRaw.replace(/[%_\\]/g, " ").trim();
  if (safeQ.length > 0) {
    sql += ` and title ilike $${n}`;
    params.push(`%${safeQ}%`);
    n += 1;
  }

  sql += ` order by created_at desc limit $${n} offset $${n + 1}`;
  params.push(limit + 1, offset);

  try {
    const { rows } = await query(sql, params);
    const hasMore = rows.length > limit;
    const items = hasMore ? rows.slice(0, limit) : rows;
    return res.json({ items, has_more: hasMore });
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error("GET /materials error:", error);
    return res.status(500).json({ error: "Failed to load materials." });
  }
});

materialsRouter.get("/:id", async (req, res) => {
  const { id } = req.params;
  if (!UUID_RE.test(id)) {
    return res.status(400).json({ error: "Invalid material id." });
  }

  try {
    const { rows } = await query(
      `select id, user_id, title, file_path, page_count, material_type, english_level, content_text, created_at
       from materials where id = $1::uuid and user_id = $2::uuid`,
      [id, req.user.id]
    );
    if (!rows[0]) {
      return res.status(404).json({ error: "Material not found." });
    }
    return res.json(rows[0]);
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error("GET /materials/:id error:", error);
    return res.status(500).json({ error: "Failed to load material." });
  }
});

materialsRouter.delete("/:id", async (req, res) => {
  const { id } = req.params;
  if (!UUID_RE.test(id)) {
    return res.status(400).json({ error: "Invalid material id." });
  }

  try {
    const { rowCount } = await query(
      `delete from materials where id = $1::uuid and user_id = $2::uuid`,
      [id, req.user.id]
    );
    if (!rowCount) {
      return res.status(404).json({ error: "Material not found." });
    }
    return res.status(204).send();
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error("DELETE /materials/:id error:", error);
    return res.status(500).json({ error: "Failed to delete material." });
  }
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

materialsRouter.post(
  "/",
  requireMaterialUploadSlot,
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

      try {
        const { rows } = await query(
          `insert into materials (
             user_id, title, file_path, page_count, material_type, english_level, content_text
           ) values ($1::uuid, $2, $3, $4, $5, $6, $7)
           returning id, title, file_path, page_count, material_type, english_level, created_at`,
          [
            req.user.id,
            title,
            safeName,
            pageCount,
            materialType,
            englishLevel,
            trimmedClientText
          ]
        );
        return res.status(201).json(rows[0]);
      } catch (error) {
        // eslint-disable-next-line no-console
        console.error("POST /materials (content_text) error:", error);
        return res.status(500).json({ error: "Failed to save material." });
      }
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
            'PDF file is required. Send multipart/form-data with field "file", or application/json with pdf_base64 or content_text.'
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

    try {
      const { rows } = await query(
        `insert into materials (
           user_id, title, file_path, page_count, material_type, english_level, content_text
         ) values ($1::uuid, $2, $3, $4, $5, $6, $7)
         returning id, title, file_path, page_count, material_type, english_level, created_at`,
        [
          req.user.id,
          title,
          safeName,
          result.numPages,
          materialType,
          englishLevel,
          result.contentText
        ]
      );
      return res.status(201).json(rows[0]);
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error("POST /materials error:", error);
      return res.status(500).json({ error: "Failed to save material." });
    }
  }
);
