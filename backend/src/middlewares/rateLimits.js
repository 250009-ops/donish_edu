import rateLimit from "express-rate-limit";

/** Vercel sits behind a proxy; required for per-IP limits. */
export function trustProxy(app) {
  app.set("trust proxy", 1);
}

export const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 25,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: "Too many sign-in attempts. Try again in a few minutes." }
});

export const botCreateUserLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 40,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: "Too many registration attempts. Try again later." }
});

/** Authenticated JSON APIs (materials list, vocab, etc.). */
export const authenticatedApiLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 180,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: "Too many requests. Please slow down." }
});

export const translateLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 45,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    error: "Too many translation requests. Wait a moment and try again."
  }
});

export const extractPreviewLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 12,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    error: "Too many PDF previews. Wait a minute before trying another file."
  }
});
