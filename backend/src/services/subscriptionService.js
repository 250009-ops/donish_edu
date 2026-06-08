import axios from "axios";
import { query } from "../db/pool.js";
import { config } from "../config.js";

export const PLAN_FREE = "free";
export const PLAN_PREMIUM = "premium";

const ACTIVE_SUBSCRIPTION_STATUSES = new Set([
  "active",
  "on_trial",
  "past_due"
]);

export function isPremiumUser(user) {
  if (!user) return false;
  if (user.plan === PLAN_PREMIUM) {
    if (user.premium_until) {
      return new Date(user.premium_until).getTime() > Date.now();
    }
    return ACTIVE_SUBSCRIPTION_STATUSES.has(user.subscription_status);
  }
  return false;
}

export async function getUserBillingRow(userId) {
  const { rows } = await query(
    `select id, plan, subscription_status, lemon_subscription_id, lemon_customer_id,
            premium_until, subscription_renews_at, created_at
     from users where id = $1::uuid limit 1`,
    [userId]
  );
  return rows[0] || null;
}

export async function countUserMaterials(userId) {
  const { rows } = await query(
    `select count(*)::int as n from materials where user_id = $1::uuid`,
    [userId]
  );
  return rows[0]?.n ?? 0;
}

export async function getTranslateUsage(userId, localDate) {
  const { rows } = await query(
    `select translate_count from usage_daily
     where user_id = $1::uuid and local_date = $2::date`,
    [userId, localDate]
  );
  return rows[0]?.translate_count ?? 0;
}

export async function getTotalTranslateUsage(userId) {
  const { rows } = await query(
    `select coalesce(sum(translate_count), 0)::int as total
     from usage_daily where user_id = $1::uuid`,
    [userId]
  );
  return rows[0]?.total ?? 0;
}

export async function incrementTranslateUsage(userId, localDate) {
  await query(
    `insert into usage_daily (user_id, local_date, translate_count)
     values ($1::uuid, $2::date, 1)
     on conflict (user_id, local_date) do update
     set translate_count = usage_daily.translate_count + 1`,
    [userId, localDate]
  );
}

export async function buildSubscriptionPayload(userId) {
  const user = await getUserBillingRow(userId);
  if (!user) return null;

  const premium = isPremiumUser(user);
  const materialCount = await countUserMaterials(userId);
  const translateTotal = await getTotalTranslateUsage(userId);

  const { rows: deviceRows } = await query(
    `select device_id, device_label, last_seen_at, created_at
     from user_devices where user_id = $1::uuid
     order by last_seen_at desc`,
    [userId]
  );

  return {
    billing_enabled: config.billingEnabled,
    plan: premium ? PLAN_PREMIUM : PLAN_FREE,
    is_premium: premium,
    subscription_status: user.subscription_status,
    renews_at: user.subscription_renews_at,
    premium_until: user.premium_until,
    price_uzs: config.premiumPriceUzs,
    limits: {
      max_devices: config.maxDevicesPerUser,
      free_max_materials: config.freeMaxMaterials,
      free_max_translate_total: config.freeMaxTranslateTotal,
      premium_fair_use_translate_per_day: config.premiumMaxTranslatePerDay
    },
    usage: {
      materials_count: materialCount,
      devices_count: deviceRows.length,
      translate_total: translateTotal
    },
    devices: deviceRows.map((d) => ({
      device_id: d.device_id,
      device_label: d.device_label,
      last_seen_at: d.last_seen_at,
      created_at: d.created_at
    }))
  };
}

export async function recordSubscriptionEvent({
  userId,
  eventName,
  eventId,
  payload
}) {
  try {
    await query(
      `insert into subscription_events (user_id, lemon_event_name, lemon_event_id, payload)
       values ($1::uuid, $2, $3, $4::jsonb)
       on conflict (lemon_event_id) do nothing`,
      [userId, eventName, eventId || null, JSON.stringify(payload ?? {})]
    );
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error("recordSubscriptionEvent:", err.message);
  }
}

function parseCustomUserId(customData) {
  if (!customData || typeof customData !== "object") return null;
  const raw = customData.user_id ?? customData.userId;
  if (typeof raw !== "string" || !raw.trim()) return null;
  return raw.trim();
}

export async function applySubscriptionFromWebhook({
  eventName,
  eventId,
  attributes,
  customData,
  resourceId,
  resourceType
}) {
  let userId = parseCustomUserId(customData);
  const subscriptionId =
    resourceType === "subscriptions"
      ? String(resourceId || "")
      : String(attributes?.subscription_id || attributes?.id || "");
  const customerId = attributes?.customer_id
    ? String(attributes.customer_id)
    : null;
  const status = String(attributes?.status || "").toLowerCase();
  const renewsAt = attributes?.renews_at || attributes?.billing_anchor || null;
  const endsAt = attributes?.ends_at || null;

  if (!userId && subscriptionId) {
    const { rows } = await query(
      `select id from users where lemon_subscription_id = $1 limit 1`,
      [subscriptionId]
    );
    userId = rows[0]?.id || null;
  }

  if (!userId) {
    // eslint-disable-next-line no-console
    console.warn(`[lemon] ${eventName}: no user_id in custom data`);
    return;
  }

  await recordSubscriptionEvent({
    userId,
    eventName,
    eventId,
    payload: { attributes, customData }
  });

  const activate = [
    "subscription_created",
    "subscription_updated",
    "subscription_payment_success"
  ].includes(eventName);

  const deactivate = [
    "subscription_cancelled",
    "subscription_expired"
  ].includes(eventName);

  if (activate && ACTIVE_SUBSCRIPTION_STATUSES.has(status)) {
    await query(
      `update users set
         plan = $2,
         subscription_status = $3,
         lemon_subscription_id = coalesce($4, lemon_subscription_id),
         lemon_customer_id = coalesce($5, lemon_customer_id),
         subscription_renews_at = $6::timestamptz,
         premium_until = coalesce($7::timestamptz, premium_until)
       where id = $1::uuid`,
      [
        userId,
        PLAN_PREMIUM,
        status,
        subscriptionId || null,
        customerId,
        renewsAt,
        endsAt
      ]
    );
    return;
  }

  if (
    deactivate ||
    (activate && ["cancelled", "expired", "unpaid"].includes(status))
  ) {
    const premiumUntil = endsAt || new Date().toISOString();
    const stillActive = new Date(premiumUntil).getTime() > Date.now();
    await query(
      `update users set
         subscription_status = $2,
         premium_until = $3::timestamptz,
         plan = $4
       where id = $1::uuid`,
      [
        userId,
        status || "cancelled",
        premiumUntil,
        stillActive ? PLAN_PREMIUM : PLAN_FREE
      ]
    );
  }
}

export async function createCheckoutForUser(userId) {
  const apiKey = config.lemonSqueezyApiKey;
  const storeId = config.lemonSqueezyStoreId;
  const variantId = config.lemonSqueezyVariantId;

  if (!apiKey || !storeId || !variantId) {
    if (config.lemonSqueezyCheckoutUrl) {
      return { url: config.lemonSqueezyCheckoutUrl, source: "static" };
    }
    throw new Error("Lemon Squeezy is not configured.");
  }

  const response = await axios.post(
    "https://api.lemonsqueezy.com/v1/checkouts",
    {
      data: {
        type: "checkouts",
        attributes: {
          checkout_data: {
            custom: {
              user_id: userId
            }
          },
          product_options: {
            redirect_url: config.premiumRedirectUrl
          }
        },
        relationships: {
          store: {
            data: { type: "stores", id: String(storeId) }
          },
          variant: {
            data: { type: "variants", id: String(variantId) }
          }
        }
      }
    },
    {
      headers: {
        Authorization: `Bearer ${apiKey}`,
        Accept: "application/vnd.api+json",
        "Content-Type": "application/vnd.api+json"
      },
      timeout: 20000
    }
  );

  const url = response.data?.data?.attributes?.url;
  if (!url) {
    throw new Error("Checkout URL missing from Lemon Squeezy response.");
  }
  return { url, source: "api" };
}
