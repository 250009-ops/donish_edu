import { execFile } from "node:child_process";
import { mkdtemp, writeFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

const DEFAULT_MAX_PAGES = 30;
const DEFAULT_MAX_BYTES_PER_IMAGE = 10 * 1024 * 1024;

export class ImageExtractFailedError extends Error {
  /** @param {string} [message] */
  constructor(message) {
    super(message || "Could not read text from this image.");
    this.name = "ImageExtractFailedError";
  }
}

/**
 * OCR one image buffer with Tesseract (eng).
 * @param {Buffer} buffer
 * @param {string} workDir
 */
async function ocrImageBuffer(buffer, workDir) {
  const imgPath = join(workDir, "page.jpg");
  await writeFile(imgPath, buffer);

  const { stdout } = await execFileAsync(
    "tesseract",
    [imgPath, "stdout", "-l", "eng", "--psm", "6"],
    { timeout: 90_000, maxBuffer: 10 * 1024 * 1024 }
  );

  return String(stdout || "")
    .replace(/\u0000/g, "")
    .trim();
}

/**
 * @param {Buffer[]} buffers
 * @param {{ maxPages?: number, maxBytesPerImage?: number }} [limits]
 */
export async function extractTextFromImages(buffers, limits = {}) {
  const maxPages = limits.maxPages ?? DEFAULT_MAX_PAGES;
  const maxBytesPerImage =
    limits.maxBytesPerImage ?? DEFAULT_MAX_BYTES_PER_IMAGE;

  if (!Array.isArray(buffers) || buffers.length === 0) {
    throw new ImageExtractFailedError("No images provided.");
  }

  if (buffers.length > maxPages) {
    throw new ImageExtractFailedError(
      `Too many images (max ${maxPages}). Please upload fewer pages.`
    );
  }

  for (let i = 0; i < buffers.length; i += 1) {
    const buf = buffers[i];
    if (!buf?.length) {
      throw new ImageExtractFailedError(`Image ${i + 1} is empty.`);
    }
    if (buf.length > maxBytesPerImage) {
      throw new ImageExtractFailedError(
        `Image ${i + 1} is too large (max ${maxBytesPerImage / (1024 * 1024)} MB).`
      );
    }
  }

  const workDir = await mkdtemp(join(tmpdir(), "gotcha-img-"));
  const parts = [];

  try {
    for (let i = 0; i < buffers.length; i += 1) {
      try {
        const chunk = await ocrImageBuffer(buffers[i], workDir);
        if (chunk.length) parts.push(chunk);
      } catch (err) {
        // eslint-disable-next-line no-console
        console.warn(`OCR failed for image ${i + 1}:`, err?.message || err);
      }
    }
  } finally {
    await rm(workDir, { recursive: true, force: true }).catch(() => {});
  }

  const text = parts.join("\n\n").trim();
  if (!text.length) {
    throw new ImageExtractFailedError(
      "We could not find readable text in these photos. Try clearer lighting, a tighter crop, or another page."
    );
  }

  return {
    contentText: text,
    numPages: Math.max(1, parts.length)
  };
}
