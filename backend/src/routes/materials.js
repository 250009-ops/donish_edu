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

materialsRouter.post("/", handleMulter, async (req, res) => {
  const title = typeof req.body.title === "string" ? req.body.title.trim() : "";
  const materialType =
    typeof req.body.material_type === "string"
      ? req.body.material_type.trim()
      : "";
  const englishLevel =
    typeof req.body.english_level === "string"
      ? req.body.english_level.trim()
      : "";

  if (!title || !materialType || !englishLevel) {
    return res.status(400).json({
      error: "title, material_type, and english_level are required."
    });
  }

  if (!ALLOWED_TYPES.has(materialType)) {
    return res.status(400).json({ error: "Invalid material_type." });
  }

  if (!ALLOWED_LEVELS.has(englishLevel)) {
    return res.status(400).json({ error: "Invalid english_level." });
  }

  const file = req.file;
  if (!file || !file.buffer?.length) {
    return res.status(400).json({ error: "PDF file is required." });
  }

  let parsed;
  try {
    parsed = await pdfParse(file.buffer);
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error("PDF parse error:", e);
    return res.status(400).json({
      error: "Could not read this PDF. Try a different file or a text-based PDF."
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

  const safeName = (file.originalname || "document.pdf").replace(
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
});
