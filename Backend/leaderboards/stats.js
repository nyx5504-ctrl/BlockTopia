import { addStats } from "../users/store.js";
// Server-authoritative stats: playtime and message count.
export async function flushStats(p) {
  const now = Date.now(); p.secCarry += (now - p.lastFlush) / 1000; p.lastFlush = now;
  const sec = Math.floor(p.secCarry); p.secCarry -= sec;
  const msgs = p.msgCount; p.msgCount = 0;
  if (sec || msgs) await addStats(p.uid, { playtime: sec, messages: msgs }, p.profile);
}
