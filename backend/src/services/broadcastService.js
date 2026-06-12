import { query } from "../db/pool.js";
import { getBotInstance } from "../telegram/botContext.js";
import { eventBus } from "../realtime/eventBus.js";

const DELAY_MS = 35;

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

export async function createBroadcastJob({ adminId, body, audience = "all" }) {
  let users;
  if (audience === "premium") {
    ({ rows: users } = await query(
      `select telegram_id from users where plan = 'premium'`
    ));
  } else if (audience === "free") {
    ({ rows: users } = await query(
      `select telegram_id from users where plan = 'free' or plan is null`
    ));
  } else if (audience.startsWith("lang:")) {
    const lang = audience.slice(5);
    if (!["uz", "ru", "en"].includes(lang)) {
      throw new Error("Invalid language audience.");
    }
    ({ rows: users } = await query(
      `select telegram_id from users where language = $1`,
      [lang]
    ));
  } else {
    ({ rows: users } = await query(`select telegram_id from users`));
  }

  const { rows } = await query(
    `insert into broadcast_jobs (admin_id, body, audience, status, total_count)
     values ($1, $2, $3, 'running', $4) returning *`,
    [adminId, body, audience, users.length]
  );
  const job = rows[0];
  runBroadcast(job.id, users.map((u) => u.telegram_id), body).catch((err) => {
    // eslint-disable-next-line no-console
    console.error("broadcast job:", err);
  });
  return job;
}

async function runBroadcast(jobId, telegramIds, body) {
  const bot = getBotInstance();
  let sent = 0;
  let failed = 0;
  for (const tid of telegramIds) {
    try {
      if (bot) {
        await bot.telegram.sendMessage(tid, body);
      }
      sent += 1;
    } catch {
      failed += 1;
    }
    if ((sent + failed) % 10 === 0) {
      await query(
        `update broadcast_jobs set sent_count = $2, failed_count = $3 where id = $1`,
        [jobId, sent, failed]
      );
      eventBus.emit("broadcast:progress", { jobId, sent, failed });
    }
    await sleep(DELAY_MS);
  }
  await query(
    `update broadcast_jobs set sent_count = $2, failed_count = $3, status = 'done', finished_at = now()
     where id = $1`,
    [jobId, sent, failed]
  );
  eventBus.emit("broadcast:progress", { jobId, sent, failed, done: true });
}

export async function getBroadcastJob(id) {
  const { rows } = await query(`select * from broadcast_jobs where id = $1`, [id]);
  return rows[0] || null;
}
