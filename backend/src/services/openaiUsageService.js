import { query } from "../db/pool.js";
import { config } from "../config.js";

export function estimateCostUsd({ promptTokens = 0, completionTokens = 0 }) {
  const inCost = (promptTokens / 1000) * config.openAiPricePer1kInput;
  const outCost = (completionTokens / 1000) * config.openAiPricePer1kOutput;
  return Number((inCost + outCost).toFixed(5));
}

export async function recordOpenAiUsage({
  userId,
  action,
  model,
  usage
}) {
  const promptTokens = usage?.prompt_tokens ?? 0;
  const completionTokens = usage?.completion_tokens ?? 0;
  const totalTokens = usage?.total_tokens ?? promptTokens + completionTokens;
  const costUsd = estimateCostUsd({ promptTokens, completionTokens });

  await query(
    `insert into openai_usage_events
       (user_id, action, model, prompt_tokens, completion_tokens, total_tokens, cost_usd)
     values ($1::uuid, $2, $3, $4, $5, $6, $7)`,
    [userId, action, model, promptTokens, completionTokens, totalTokens, costUsd]
  );
}

export async function getUsageSummary({ from, to } = {}) {
  const params = [];
  let where = "1=1";
  if (from) {
    params.push(from);
    where += ` and created_at >= $${params.length}::timestamptz`;
  }
  if (to) {
    params.push(to);
    where += ` and created_at <= $${params.length}::timestamptz`;
  }
  const { rows } = await query(
    `select
       coalesce(sum(total_tokens), 0)::bigint as total_tokens,
       coalesce(sum(cost_usd), 0)::numeric as total_cost_usd,
       count(*)::int as call_count
     from openai_usage_events where ${where}`,
    params
  );
  const byAction = await query(
    `select action,
            coalesce(sum(total_tokens), 0)::bigint as tokens,
            coalesce(sum(cost_usd), 0)::numeric as cost_usd,
            count(*)::int as calls
     from openai_usage_events where ${where}
     group by action order by tokens desc`,
    params
  );
  return { totals: rows[0], by_action: byAction.rows };
}

export async function getUsageByUser({ from, to, limit = 50 } = {}) {
  const params = [];
  let where = "1=1";
  if (from) {
    params.push(from);
    where += ` and e.created_at >= $${params.length}::timestamptz`;
  }
  if (to) {
    params.push(to);
    where += ` and e.created_at <= $${params.length}::timestamptz`;
  }
  params.push(limit);
  const { rows } = await query(
    `select e.user_id, u.telegram_id, u.full_name, u.email,
            coalesce(sum(e.total_tokens), 0)::bigint as tokens,
            coalesce(sum(e.cost_usd), 0)::numeric as cost_usd,
            count(*)::int as calls
     from openai_usage_events e
     left join users u on u.id = e.user_id
     where ${where}
     group by e.user_id, u.telegram_id, u.full_name, u.email
     order by tokens desc
     limit $${params.length}`,
    params
  );
  return rows;
}
