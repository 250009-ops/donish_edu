import { randomUUID } from "node:crypto";
import {
  TextractClient,
  StartDocumentTextDetectionCommand,
  GetDocumentTextDetectionCommand
} from "@aws-sdk/client-textract";
import {
  S3Client,
  PutObjectCommand,
  DeleteObjectCommand
} from "@aws-sdk/client-s3";
import { config } from "../config.js";

const POLL_INTERVAL_MS = 1500;
const MAX_POLL_ROUNDS = 120;

export class TextractNotConfiguredError extends Error {
  constructor() {
    super("Amazon Textract is not configured on the server.");
    this.name = "TextractNotConfiguredError";
  }
}

export class TextractJobFailedError extends Error {
  /** @param {string} [message] */
  constructor(message) {
    super(message || "Textract could not process this document.");
    this.name = "TextractJobFailedError";
  }
}

export class TextractTimeoutError extends Error {
  constructor() {
    super("Text extraction timed out. Try a smaller PDF or try again.");
    this.name = "TextractTimeoutError";
  }
}

/** @param {unknown} err */
function mapAwsError(err) {
  const name = err && typeof err === "object" && "name" in err ? err.name : "";
  if (
    name === "AccessDeniedException" ||
    name === "CredentialsProviderError" ||
    name === "UnrecognizedClientException"
  ) {
    throw new TextractNotConfiguredError();
  }
  if (
    name === "InvalidS3ObjectException" ||
    name === "InvalidParameterException" ||
    name === "UnsupportedDocumentException" ||
    name === "BadDocumentException" ||
    name === "DocumentTooLargeException"
  ) {
    throw new TextractJobFailedError(
      err && typeof err === "object" && "message" in err && typeof err.message === "string"
        ? err.message
        : undefined
    );
  }
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function assertTextractConfigured() {
  if (!config.awsRegion?.trim() || !config.textractS3Bucket?.trim()) {
    throw new TextractNotConfiguredError();
  }
}

/**
 * @param {import("@aws-sdk/client-textract").Block[]} blocks
 * @returns {string}
 */
function blocksToText(blocks) {
  const lines = blocks.filter(
    (b) => b.BlockType === "LINE" && typeof b.Text === "string" && b.Text.length
  );
  if (!lines.length) return "";

  /** @type {Map<number, { text: string, top: number, left: number }[]>} */
  const byPage = new Map();
  for (const line of lines) {
    const page = line.Page ?? 1;
    const top = line.Geometry?.BoundingBox?.Top ?? 0;
    const left = line.Geometry?.BoundingBox?.Left ?? 0;
    if (!byPage.has(page)) byPage.set(page, []);
    byPage.get(page).push({ text: line.Text, top, left });
  }

  const pageNums = [...byPage.keys()].sort((a, b) => a - b);
  return pageNums
    .map((p) => {
      const sorted = byPage
        .get(p)
        .sort((a, b) => a.top - b.top || a.left - b.left);
      return sorted.map((l) => l.text).join("\n");
    })
    .join("\n\n")
    .replace(/\u0000/g, "")
    .trim();
}

/**
 * @param {import("@aws-sdk/client-textract").Block[]} blocks
 * @param {number | undefined} metadataPages
 */
function resolvePageCount(blocks, metadataPages) {
  if (typeof metadataPages === "number" && metadataPages > 0) {
    return metadataPages;
  }
  let maxPage = 0;
  for (const b of blocks) {
    if (typeof b.Page === "number" && b.Page > maxPage) maxPage = b.Page;
  }
  return maxPage > 0 ? maxPage : 1;
}

/**
 * Extract text from a PDF using Amazon Textract (async, via S3).
 *
 * @param {Buffer} buffer
 * @param {{ maxPages: number, maxBytes: number }} limits
 * @returns {Promise<{ contentText: string, numPages: number }>}
 */
export async function extractTextFromPdfWithTextract(buffer, limits) {
  assertTextractConfigured();

  if (!buffer?.length) {
    throw new Error("PDF buffer is empty.");
  }
  if (buffer.length > limits.maxBytes) {
    throw new Error(
      `PDF file is too large (max ${limits.maxBytes / (1024 * 1024)} MB).`
    );
  }

  const region = config.awsRegion.trim();
  const bucket = config.textractS3Bucket.trim();
  const s3Key = `textract-uploads/${randomUUID()}.pdf`;

  const textract = new TextractClient({ region });
  const s3 = new S3Client({ region });

  try {
    try {
      await s3.send(
        new PutObjectCommand({
          Bucket: bucket,
          Key: s3Key,
          Body: buffer,
          ContentType: "application/pdf"
        })
      );
    } catch (err) {
      mapAwsError(err);
      throw err;
    }

    let startRes;
    try {
      startRes = await textract.send(
        new StartDocumentTextDetectionCommand({
          DocumentLocation: {
            S3Object: { Bucket: bucket, Name: s3Key }
          }
        })
      );
    } catch (err) {
      mapAwsError(err);
      throw err;
    }

    const jobId = startRes.JobId;
    if (!jobId) {
      throw new TextractJobFailedError("Textract did not return a job id.");
    }

    /** @type {import("@aws-sdk/client-textract").Block[]} */
    const allBlocks = [];
    let metadataPages;
    let jobDone = false;
    /** @type {string | undefined} */
    let nextToken;

    for (let round = 0; round < MAX_POLL_ROUNDS; round++) {
      do {
        const res = await textract.send(
          new GetDocumentTextDetectionCommand({
            JobId: jobId,
            NextToken: nextToken
          })
        );

        nextToken = res.NextToken;

        if (res.JobStatus === "FAILED") {
          throw new TextractJobFailedError(
            res.StatusMessage || "Textract job failed."
          );
        }

        if (res.JobStatus === "SUCCEEDED") {
          jobDone = true;
        }

        if (res.DocumentMetadata?.Pages != null) {
          metadataPages = res.DocumentMetadata.Pages;
        }
        if (res.Blocks?.length) {
          allBlocks.push(...res.Blocks);
        }
      } while (nextToken);

      if (jobDone) break;
      await sleep(POLL_INTERVAL_MS);
    }

    if (!jobDone) {
      throw new TextractTimeoutError();
    }

    const contentText = blocksToText(allBlocks);
    const numPages = resolvePageCount(allBlocks, metadataPages);

    if (numPages > limits.maxPages) {
      throw new Error(
        `This PDF has about ${numPages} pages. Please upload a PDF with at most ${limits.maxPages} pages.`
      );
    }

    if (!contentText.length) {
      throw new Error("NO_EXTRACTABLE_TEXT");
    }

    return { contentText, numPages };
  } finally {
    try {
      await s3.send(
        new DeleteObjectCommand({ Bucket: bucket, Key: s3Key })
      );
    } catch (delErr) {
      // eslint-disable-next-line no-console
      console.error("Textract S3 cleanup failed:", delErr);
    }
  }
}
