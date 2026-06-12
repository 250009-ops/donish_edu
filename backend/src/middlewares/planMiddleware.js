import { config } from "../config.js";
import { getEffectiveLimits } from "../services/limitsService.js";
import {
  countUserMaterials,
  getTotalTranslateUsage,
  getTranslateUsage,
  getUserBillingRow,
  incrementTranslateUsage,
  isPremiumUser
} from "../services/subscriptionService.js";

export async function requireMaterialUploadSlot(req, res, next) {
  if (!config.billingEnabled) {
    return next();
  }

  try {
    const limits = await getEffectiveLimits(req.user.id);
    if (limits.isBlocked) {
      return res.status(403).json({
        code: "account_blocked",
        error: "Your account is temporarily restricted. Contact support."
      });
    }

    const user = await getUserBillingRow(req.user.id);
    if (!user) {
      return res.status(404).json({ error: "User not found." });
    }
    if (isPremiumUser(user)) {
      return next();
    }

    const count = await countUserMaterials(req.user.id);
    if (count >= limits.freeMaxMaterials) {
      return res.status(403).json({
        code: "upgrade_required",
        error: `Free plan includes ${limits.freeMaxMaterials} PDF upload. Upgrade to Premium for unlimited uploads.`,
        limit: limits.freeMaxMaterials,
        usage: count
      });
    }
    return next();
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error("requireMaterialUploadSlot:", error);
    return res.status(500).json({ error: "Failed to verify plan limits." });
  }
}

export async function checkTranslateQuota(req, res, next) {
  if (!config.billingEnabled) {
    return next();
  }

  const localDate = req.body?.local_date;
  if (!localDate || !/^\d{4}-\d{2}-\d{2}$/.test(String(localDate))) {
    return next();
  }

  try {
    const limits = await getEffectiveLimits(req.user.id);
    if (limits.isBlocked) {
      return res.status(403).json({
        code: "account_blocked",
        error: "Your account is temporarily restricted. Contact support."
      });
    }

    const user = await getUserBillingRow(req.user.id);
    if (!user) {
      return res.status(404).json({ error: "User not found." });
    }

    if (isPremiumUser(user)) {
      const dailyLimit = limits.premiumMaxTranslatePerDay;
      const usedToday = await getTranslateUsage(req.user.id, localDate);
      if (usedToday >= dailyLimit) {
        return res.status(403).json({
          code: "upgrade_required",
          error: "Daily translation fair-use limit reached. Try again tomorrow.",
          limit: dailyLimit,
          usage: usedToday
        });
      }
      res.locals.translateQuota = {
        localDate,
        limit: dailyLimit,
        used: usedToday,
        mode: "daily"
      };
      return next();
    }

    const totalLimit = limits.freeMaxTranslateTotal;
    const usedTotal = await getTotalTranslateUsage(req.user.id);
    if (usedTotal >= totalLimit) {
      return res.status(403).json({
        code: "upgrade_required",
        error: `Free plan includes ${totalLimit} word taps. Upgrade to Premium for unlimited translations.`,
        limit: totalLimit,
        usage: usedTotal
      });
    }

    res.locals.translateQuota = {
      localDate,
      limit: totalLimit,
      used: usedTotal,
      mode: "total"
    };
    return next();
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error("checkTranslateQuota:", error);
    return res.status(500).json({ error: "Failed to verify plan limits." });
  }
}

export async function consumeTranslateQuota(res, fromCache) {
  if (fromCache) return;
  const quota = res.locals?.translateQuota;
  if (!quota?.localDate || !res.locals?.translateUserId) return;
  await incrementTranslateUsage(res.locals.translateUserId, quota.localDate);
}
