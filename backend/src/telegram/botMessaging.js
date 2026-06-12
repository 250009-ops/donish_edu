/**
 * Track bot prompt message IDs and delete them when the user sends the next message.
 */

/** @param {object} session */
export function getTrackedIds(session) {
  const ids = session?.data?.bot_msg_ids;
  return Array.isArray(ids) ? ids : [];
}

/**
 * Delete previously tracked bot messages, then clear the list.
 * @param {import('telegraf').Context} ctx
 */
export async function clearTrackedBotMessages(ctx, getSess, setSess) {
  const chatId = ctx.chat?.id;
  if (!chatId) return;
  const sess = await getSess(chatId);
  const ids = getTrackedIds(sess);
  if (!ids.length) return;

  for (const messageId of ids) {
    try {
      await ctx.telegram.deleteMessage(chatId, messageId);
    } catch (_) {
      // Message may already be gone or too old.
    }
  }

  await setSess(chatId, {
    mergeData: true,
    data: { bot_msg_ids: [] }
  });
}

/**
 * @param {import('telegraf').Context} ctx
 * @param {number} messageId
 */
export async function trackBotMessage(ctx, getSess, setSess, messageId) {
  const chatId = ctx.chat?.id;
  if (!chatId || !messageId) return;
  const sess = await getSess(chatId);
  const ids = [...getTrackedIds(sess), messageId].slice(-12);
  await setSess(chatId, {
    mergeData: true,
    data: { bot_msg_ids: ids }
  });
}

/**
 * Send a tracked text reply (deleted on the user's next message).
 * @param {import('telegraf').Context} ctx
 * @param {string} text
 * @param {object} [extra]
 */
export async function replyTracked(ctx, getSess, setSess, text, extra) {
  const msg = await ctx.reply(text, extra);
  await trackBotMessage(ctx, getSess, setSess, msg.message_id);
  return msg;
}

/**
 * Call at the start of a user text/contact handler turn.
 */
export async function onUserTurn(ctx, getSess, setSess) {
  await clearTrackedBotMessages(ctx, getSess, setSess);
}
