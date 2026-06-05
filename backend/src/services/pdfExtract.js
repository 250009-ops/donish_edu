import { execFile } from "node:child_process";
import { mkdtemp, writeFile, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { promisify } from "node:util";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const pdfParse = require("pdf-parse");

const execFileAsync = promisify(execFile);

const MIN_CHARS_PER_PAGE = 40;

export class PdfExtractTimeoutError extends Error {
  constructor() {
    super("Text extraction timed out. Try a smaller PDF or try again.");
    this.name = "PdfExtractTimeoutError";
  }
}

export class PdfExtractFailedError extends Error {
  /** @param {string} [message] */
  constructor(message) {
    super(message || "Could not process this document.");
    this.name = "PdfExtractFailedError";
  }
}

/**
 * @param {Buffer} buffer
 * @returns {Promise<{ text: string, numPages: number }>}
 */
async function extractWithPdfParse(buffer) {
  const data = await pdfParse(buffer);
  const text = String(data.text || "")
    .replace(/\u0000/g, "")
    .trim();
  const numPages = Math.max(1, data.numpages || 1);
  return { text, numPages };
}

/**
 * @param {string} pdfPath
 * @param {string} workDir
 * @param {number} maxPages
 */
async function extractWithPdftotext(pdfPath, workDir, maxPages) {
  const outPath = join(workDir, "out.txt");
  await execFileAsync(
    "pdftotext",
    ["-enc", "UTF-8", "-l", String(maxPages), pdfPath, outPath],
    { timeout: 120_000, maxBuffer: 20 * 1024 * 1024 }
  );
  const text = (await readFile(outPath, "utf8")).replace(/\u0000/g, "").trim();
  const info = await execFileAsync("pdfinfo", [pdfPath], {
    timeout: 15_000,
    maxBuffer: 1024 * 1024
  }).catch(() => ({ stdout: "" }));
  const pagesMatch = String(info.stdout || "").match(/Pages:\s+(\d+)/i);
  const numPages = pagesMatch
    ? Math.min(maxPages, parseInt(pagesMatch[1], 10) || 1)
    : maxPages;
  return { text, numPages };
}

/**
 * OCR scanned PDFs page-by-page (requires poppler + tesseract).
 * @param {string} pdfPath
 * @param {string} workDir
 * @param {number} maxPages
 */
async function extractWithTesseract(pdfPath, workDir, maxPages) {
  const prefix = join(workDir, "page");
  await execFileAsync(
    "pdftoppm",
    ["-png", "-r", "150", "-l", String(maxPages), pdfPath, prefix],
    { timeout: 180_000, maxBuffer: 1024 * 1024 }
  );

  const parts = [];
  for (let p = 1; p <= maxPages; p++) {
    const imgPath = `${prefix}-${p}.png`;
    try {
      const { stdout } = await execFileAsync(
        "tesseract",
        [imgPath, "stdout", "-l", "eng"],
        { timeout: 90_000, maxBuffer: 10 * 1024 * 1024 }
      );
      const chunk = String(stdout || "").trim();
      if (chunk.length) parts.push(chunk);
    } catch {
      break;
    }
  }

  return {
    text: parts.join("\n\n").trim(),
    numPages: Math.max(1, parts.length)
  };
}

/**
 * @param {Buffer} buffer
 * @param {{ maxPages: number, maxBytes: number }} limits
 */
export async function extractTextFromPdf(buffer, limits) {
  if (!buffer?.length) {
    throw new Error("PDF buffer is empty.");
  }
  if (buffer.length > limits.maxBytes) {
    throw new Error(
      `PDF file is too large (max ${limits.maxBytes / (1024 * 1024)} MB).`
    );
  }

  let parsed;
  try {
    parsed = await extractWithPdfParse(buffer);
  } catch (err) {
    throw new PdfExtractFailedError(
      err instanceof Error ? err.message : "Invalid PDF."
    );
  }

  let { text, numPages } = parsed;
  if (numPages > limits.maxPages) {
    throw new Error(
      `This PDF has about ${numPages} pages. Please upload a PDF with at most ${limits.maxPages} pages.`
    );
  }

  const charsPerPage = text.length / Math.max(1, numPages);
  if (text.length >= MIN_CHARS_PER_PAGE * numPages && charsPerPage >= MIN_CHARS_PER_PAGE) {
    return { contentText: text, numPages };
  }

  const workDir = await mkdtemp(join(tmpdir(), "donish-pdf-"));
  const pdfPath = join(workDir, "input.pdf");
  try {
    await writeFile(pdfPath, buffer);

    try {
      const poppler = await extractWithPdftotext(pdfPath, workDir, limits.maxPages);
      if (poppler.text.length > text.length) {
        text = poppler.text;
        numPages = poppler.numPages;
      }
    } catch {
      /* pdftotext optional */
    }

    const charsAfterPoppler = text.length / Math.max(1, numPages);
    if (
      text.length < MIN_CHARS_PER_PAGE * numPages ||
      charsAfterPoppler < MIN_CHARS_PER_PAGE
    ) {
      try {
        const ocr = await extractWithTesseract(pdfPath, workDir, limits.maxPages);
        if (ocr.text.length > text.length) {
          text = ocr.text;
          numPages = ocr.numPages;
        }
      } catch {
        /* tesseract optional */
      }
    }
  } finally {
    await rm(workDir, { recursive: true, force: true }).catch(() => {});
  }

  if (numPages > limits.maxPages) {
    throw new Error(
      `This PDF has about ${numPages} pages. Please upload a PDF with at most ${limits.maxPages} pages.`
    );
  }

  if (!text.length) {
    throw new Error("NO_EXTRACTABLE_TEXT");
  }

  return { contentText: text, numPages };
}
