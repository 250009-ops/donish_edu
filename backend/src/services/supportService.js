import { query } from "../db/pool.js";
import { eventBus } from "../realtime/eventBus.js";

export async function storeInboundMessage({ telegramId, userId, body }) {
  const { rows } = await query(
    `insert into support_messages (telegram_id, user_id, direction, body)
     values ($1, $2::uuid, 'in', $3)
     returning *`,
    [telegramId, userId || null, body]
  );
  const msg = rows[0];
  eventBus.emit("support:new", { message: msg });
  return msg;
}

export async function storeOutboundMessage({ telegramId, userId, body, adminId }) {
  const { rows } = await query(
    `insert into support_messages (telegram_id, user_id, direction, body, admin_id)
     values ($1, $2::uuid, 'out', $3, $4)
     returning *`,
    [telegramId, userId || null, body, adminId]
  );
  return rows[0];
}

export async function listThreads({ q, unreadOnly, limit = 50, offset = 0 } = {}) {
  const params = [];
  let where = "1=1";
  if (unreadOnly) {
    where += ` and exists (
      select 1 from support_messages sm2
      where sm2.telegram_id = t.telegram_id and sm2.direction = 'in' and sm2.read_at is null
    )`;
  }
  if (q) {
    params.push(`%${q}%`);
    where += ` and (cast(t.telegram_id as text) ilike $${params.length} or t.last_body ilike $${params.length})`;
  }
  params.push(limit, offset);
  const { rows } = await query(
    `with threads as (
       select telegram_id,
              max(created_at) as last_at,
              (array_agg(body order by created_at desc))[1] as last_body,
              (array_agg(direction order by created_at desc))[1] as last_direction,
              count(*) filter (where direction = 'in' and read_at is null)::int as unread_count
       from support_messages
       group by telegram_id
     )
     select t.*, u.full_name, u.email
     from threads t
     left join users u on u.telegram_id = t.telegram_id
     where ${where}
     order by t.last_at desc
     limit $${params.length - 1} offset $${params.length}`,
    params
  );
  return rows;
}

export async function getThreadMessages(telegramId, { before, limit = 50 } = {}) {
  const params = [telegramId];
  let sql = `select * from support_messages where telegram_id = $1`;
  if (before) {
    params.push(before);
    sql += ` and id < $${params.length}`;
  }
  params.push(limit);
  sql += ` order by id desc limit $${params.length}`;
  const { rows } = await query(sql, params);
  return rows.reverse();
}

export async function markThreadRead(telegramId) {
  await query(
    `update support_messages set read_at = now()
     where telegram_id = $1 and direction = 'in' and read_at is null`,
    [telegramId]
  );
}
