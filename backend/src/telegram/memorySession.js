/** In-memory session for long-running polling bot (local / VPS). */

const state = new Map();

export const memorySession = {
  /** @param {number} chatId */
  async getStep(chatId) {
    return state.get(chatId) || "idle";
  },
  /**
   * @param {number} chatId
   * @param {string} step
   */
  async setStep(chatId, step) {
    state.set(chatId, step);
    return true;
  }
};
