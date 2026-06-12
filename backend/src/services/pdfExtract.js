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
function needsBetterExtraction(text, numPages) {
  const pages = Math.max(1, numPages);
  const charsPerPage = text.length / pages;
  return (
    text.length < MIN_CHARS_PER_PAGE * pages ||
    charsPerPage < MIN_CHARS_PER_PAGE
  );
}

async function readPageCountFromPdfInfo(pdfPath, fallback = 1) {
  try {
    const info = await execFileAsync("pdfinfo", [pdfPath], {
      timeout: 15_000,
      maxBuffer: 1024 * 1024
    });
    const pagesMatch = String(info.stdout || "").match(/Pages:\s+(\d+)/i);
    if (pagesMatch) {
      return parseInt(pagesMatch[1], 10) || fallback;
    }
  } catch {
    /* optional */
  }
  return fallback;
}

export async function extractTextFromPdf(buffer, limits) {
  if (!buffer?.length) {
    throw new Error("PDF buffer is empty.");
  }
  if (buffer.length > limits.maxBytes) {
    throw new Error(
      `PDF file is too large (max ${limits.maxBytes / (1024 * 1024)} MB).`
    );
  }

  let text = "";
  let numPages = 1;
  let pdfParseFailed = false;

  try {
    const parsed = await extractWithPdfParse(buffer);
    text = parsed.text;
    numPages = parsed.numPages;
  } catch (err) {
    pdfParseFailed = true;
    // eslint-disable-next-line no-console
    console.warn(
      "pdf-parse failed, trying poppler/OCR:",
      err instanceof Error ? err.message : err
    );
  }

  if (!text.length || needsBetterExtraction(text, numPages)) {
    const workDir = await mkdtemp(join(tmpdir(), "donish-pdf-"));
    const pdfPath = join(workDir, "input.pdf");
    let popplerWorked = false;
    try {
      await writeFile(pdfPath, buffer);

      if (pdfParseFailed || numPages <= 1) {
        numPages = await readPageCountFromPdfInfo(pdfPath, numPages);
      }

      if (numPages > limits.maxPages) {
        throw new Error(
          `This PDF has about ${numPages} pages. Please upload a PDF with at most ${limits.maxPages} pages.`
        );
      }

      try {
        const poppler = await extractWithPdftotext(
          pdfPath,
          workDir,
          limits.maxPages
        );
        popplerWorked = true;
        if (poppler.text.length > text.length) {
          text = poppler.text;
          numPages = poppler.numPages;
        }
      } catch (popErr) {
        // eslint-disable-next-line no-console
        console.warn("pdftotext failed:", popErr?.message || popErr);
      }

      if (needsBetterExtraction(text, numPages)) {
        try {
          const ocr = await extractWithTesseract(pdfPath, workDir, limits.maxPages);
          if (ocr.text.length > text.length) {
            text = ocr.text;
            numPages = ocr.numPages;
          }
        } catch (ocrErr) {
          // eslint-disable-next-line no-console
          console.warn("tesseract failed:", ocrErr?.message || ocrErr);
        }
      }

      if (pdfParseFailed && !text.length && !popplerWorked) {
        throw new PdfExtractFailedError();
      }
    } finally {
      await rm(workDir, { recursive: true, force: true }).catch(() => {});
    }
  } else if (numPages > limits.maxPages) {
    throw new Error(
      `This PDF has about ${numPages} pages. Please upload a PDF with at most ${limits.maxPages} pages.`
    );
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
