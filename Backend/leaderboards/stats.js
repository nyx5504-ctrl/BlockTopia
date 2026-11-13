import { addStats } from "../users/store.js";
// Server-authoritative stats: 1 score per 10 s connected, plus playtime and message count.
export async function flushStats(p) {
  const now = Date.now(); p.secCarry += (now - p.lastFlush) / 1000; p.lastFlush = now;
  const sec = Math.floor(p.secCarry); p.secCarry -= sec; p.scoreCarry += sec;
  const pts = Math.floor(p.scoreCarry / 10); p.scoreCarry -= pts * 10;
  const msgs = p.msgCount; p.msgCount = 0;
  if (sec || msgs) await addStats(p.uid, { playtime: sec, score: pts, messages: msgs }, p.profile);
}
