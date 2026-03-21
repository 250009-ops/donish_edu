import { createRequire } from "node:module";
import express from "express";
import multer from "multer";
import { supabaseAdmin } from "../supabaseClient.js";
import { requireAuth } from "../middlewares/authMiddleware.js";

const require = createRequire(import.meta.url);
const pdfParse = require("pdf-parse");

export const materialsRouter = express.Router();

/** Approximate product limit: reject PDFs with more than this many pages. */
const MAX_PDF_PAGES = 10;

/** Stay under typical serverless body limits (~4.5 MB on Vercel hobby). */
const MAX_FILE_BYTES = 4 * 1024 * 1024;

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

materialsRouter.get("/", async (req, res) => {
  const { data, error } = await supabaseAdmin
    .from("materials")
    .select(
      "id, title, file_path, page_count, material_type, english_level, created_at"
    )
    .eq("user_id", req.user.id)
    .order("created_at", { ascending: false });

  if (error) {
    // eslint-disable-next-line no-console
    console.error("GET /materials error:", error);
    return res.status(500).json({ error: "Failed to load materials." });
  }

  return res.json(data || []);
});

materialsRouter.get("/:id", async (req, res) => {
  const { id } = req.params;
  if (!UUID_RE.test(id)) {
    return res.status(400).json({ error: "Invalid material id." });
  }

  const { data, error } = await supabaseAdmin
    .from("materials")
    .select("*")
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
 * Multipart is unreliable on some serverless hosts (empty req.body). The app
 * sends application/json with pdf_base64 instead.
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

    if (!title || !materialType || !englishLevel) {
      return res.status(400).json({
        error: "Please provide title, material type, and English level."
      });
    }

    if (!ALLOWED_TYPES.has(materialType)) {
      return res.status(400).json({ error: "Invalid material_type." });
    }

    if (!ALLOWED_LEVELS.has(englishLevel)) {
      return res.status(400).json({ error: "Invalid english_level." });
    }

    const ct = req.headers["content-type"] || "";
    let buffer;
    let originalName = "document.pdf";

    if (ct.includes("application/json")) {
      const b64 = req.body?.pdf_base64;
      if (typeof b64 !== "string" || !b64.trim()) {
        return res.status(400).json({
          error: "pdf_base64 is required when uploading as JSON."
        });
      }
      try {
        buffer = Buffer.from(b64, "base64");
      } catch {
        return res.status(400).json({ error: "Invalid pdf_base64 encoding." });
      }
      if (!buffer.length) {
        return res.status(400).json({ error: "Decoded PDF is empty." });
      }
      if (buffer.length > MAX_FILE_BYTES) {
        return res.status(400).json({
          error: `PDF file is too large (max ${MAX_FILE_BYTES / (1024 * 1024)} MB).`
        });
      }
      if (typeof req.body.file_name === "string" && req.body.file_name.trim()) {
        originalName = req.body.file_name.trim();
      }
    } else {
      const file = req.file;
      if (!file || !file.buffer?.length) {
        return res.status(400).json({
          error:
            "PDF file is required. Send multipart/form-data with field \"file\", or application/json with pdf_base64."
        });
      }
      buffer = file.buffer;
      originalName = file.originalname || "document.pdf";
    }

    let parsed;
    try {
      parsed = await pdfParse(buffer);
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error("PDF parse error:", e);
      return res.status(400).json({
        error:
          "Could not read this PDF. Try a different file or a text-based PDF."
      });
    }

    const numPages = parsed.numpages || 0;
    if (numPages > MAX_PDF_PAGES) {
      return res.status(400).json({
        error: `This PDF has about ${numPages} pages. Please upload a PDF with at most ${MAX_PDF_PAGES} pages.`
      });
    }

    const rawText = typeof parsed.text === "string" ? parsed.text : "";
    const contentText = rawText.replace(/\u0000/g, "").trim();

    if (!contentText.length) {
      return res.status(400).json({
        error:
          "No readable text was found in this PDF. Scanned pages need OCR, which is not supported yet—try a text-based PDF."
      });
    }

    const safeName = (originalName || "document.pdf").replace(
      /[^\w.\- ()]+/g,
      "_"
    );

    const { data, error } = await supabaseAdmin
      .from("materials")
      .insert({
        user_id: req.user.id,
        title,
        file_path: safeName,
        page_count: numPages,
        material_type: materialType,
        english_level: englishLevel,
        content_text: contentText
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
