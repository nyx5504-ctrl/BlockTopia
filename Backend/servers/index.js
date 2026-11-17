import http from "node:http";
import crypto from "node:crypto";
import { fileURLToPath } from "node:url";
import { WebSocketServer } from "ws";
import { verifyToken } from "../auth/verify.js";
import * as store from "../users/store.js";
import { checkMessage, checkSplit, FRIENDLY } from "../chat/filter.js";
import { Room, CFG } from "../games/baseplate.js";
import { flushStats } from "../leaderboards/stats.js";

const PORT = +process.env.PORT || 8787;
const ORIGINS = (process.env.ALLOWED_ORIGINS || "http://localhost:8000").split(",").map(s => s.trim());
const WS_URL = process.env.PUBLIC_WS_URL || `ws://localhost:${PORT}`;
const rooms = new Map(), codes = new Map(), sessions = new Map(), byUid = new Map(), launchHits = new Map(), feedbackHits = new Map(), gameReportHits = new Map();
let roomSeq = 1;
const rnd = n => crypto.randomBytes(n).toString("hex");
const normalizeCharacter = (raw, fallback = "#f2c744") => {
  const c = raw && typeof raw === "object" ? raw : {};
  const height = Number(c.height);
  const bodyType = ["classic", "slim", "broad"].includes(c.bodyType) ? c.bodyType : "classic";
  const bodyColor = /^#[0-9a-f]{6}$/i.test(String(c.bodyColor || "")) ? String(c.bodyColor).toLowerCase() : (/^#[0-9a-f]{6}$/i.test(fallback) ? fallback.toLowerCase() : "#f2c744");
  return { height: Number.isFinite(height) ? Math.min(1.25, Math.max(0.75, height)) : 1, bodyType, bodyColor };
};
const tooMany = (map, key, max, ms) => { const now = Date.now(), a = (map.get(key) || []).filter(t => now - t < ms); a.push(now); map.set(key, a); return a.length > max; };

function pickRoom(joinRoomId) {
  const want = joinRoomId && rooms.get(joinRoomId); if (want && !want.full) return want;
  for (const r of rooms.values()) if (!r.full) return r;
  const r = new Room("bp-" + roomSeq++); rooms.set(r.id, r); return r;
}

// ---------- HTTP: /launch mints a single-use code the client trades for a session ----------
const server = http.createServer(async (req, res) => {
  const origin = req.headers.origin, okOrigin = origin && ORIGINS.includes(origin);
  const hdr = { "Content-Type": "application/json", ...(okOrigin ? { "Access-Control-Allow-Origin": origin, Vary: "Origin", "Access-Control-Allow-Headers": "Content-Type, Authorization", "Access-Control-Allow-Methods": "POST, OPTIONS" } : {}) };
  const out = (c, o) => { res.writeHead(c, hdr); res.end(JSON.stringify(o)); };
  if (req.method === "OPTIONS") return out(204, {});
  if (req.url === "/health") return out(200, { ok: true, rooms: rooms.size, players: [...rooms.values()].reduce((n, r) => n + r.live().length, 0) });
  if (req.method !== "POST") return out(404, { error: "not found" });
  if (origin && !okOrigin) return out(403, { error: "origin not allowed" });
  const readBody = async () => {
    let raw = ""; for await (const c of req) { raw += c; if (raw.length > 2048) { const e = new Error("too large"); e.status = 413; throw e; } }
    return JSON.parse(raw || "{}");
  };
  if (req.url === "/profile" || req.url === "/game-feedback") {
    try {
      const body = await readBody();
      const tok = (req.headers.authorization || "").replace(/^Bearer /, "");
      let u; try { u = await verifyToken(tok); } catch { return out(401, { error: "not signed in" }); }
      if (req.url === "/profile") {
        let profile = await store.getUser(u.uid);
        if (body.username !== undefined) {
          const username = String(body.username || "").trim();
          if (!/^[A-Za-z0-9_]{3,20}$/.test(username)) return out(400, { error: "Choose a username of 3-20 letters, numbers or underscores." });
          try { profile = await store.createProfile(u.uid, username); }
          catch (e) { return out(e.message === "USERNAME_TAKEN" ? 409 : 400, { error: e.message === "USERNAME_TAKEN" ? "That username is already taken." : "Could not save your profile." }); }
        }
        if (body.character !== undefined) {
          profile = await store.updateProfile(u.uid, { character: normalizeCharacter(body.character, profile.avatarColor) });
        }
        if (!profile.username) return out(200, { needsUsername: true });
        return out(200, { profile: { username: profile.username, avatarColor: profile.avatarColor || "#f4f4f2", character: normalizeCharacter(profile.character, profile.avatarColor) } });
      }
      const { game, action } = body;
      if (game !== "baseplate") return out(400, { error: "unknown game" });
      if (tooMany(feedbackHits, u.uid, 20, 60000)) return out(429, { error: "Please wait before sending more game feedback." });
      if (action === "report" && tooMany(gameReportHits, u.uid, 3, 60000)) return out(429, { error: "Please wait before sending another game report." });
      if (action === "get-reaction") {
        const reaction = await store.getGameReaction(u.uid, game);
        return out(200, { reaction });
      }
      if (action === "reaction") {
        if (!["like", "dislike"].includes(body.reaction)) return out(400, { error: "Choose like or dislike." });
        const reaction = await store.toggleGameReaction(u.uid, game, body.reaction);
        return out(200, { reaction });
      }
      if (action === "report") {
        const profile = await store.getUser(u.uid);
        const details = String(body.details || "").trim().slice(0, 500);
        if (!details) return out(400, { error: "Add a short reason for the report." });
        const reason = ["inappropriate_content", "abuse", "spam", "other"].includes(body.reason) ? body.reason : "other";
        await store.saveReport({ type: "game", game, reporterUid: u.uid, reporterName: profile.username || u.name || "Player", reason, details });
        return out(200, { ok: true });
      }
      return out(400, { error: "unknown action" });
    } catch (e) { return out(e.status || 400, { error: e.status === 413 ? "too large" : "bad request" }); }
  }
  if (req.url !== "/launch") return out(404, { error: "not found" });
  try {
    const body = await readBody();
    const { game, joinUid } = body;
    const tok = (req.headers.authorization || "").replace(/^Bearer /, "");
    let u; try { u = await verifyToken(tok); } catch { return out(401, { error: "not signed in" }); }
    if (game !== "baseplate") return out(400, { error: "unknown game" });
    if (tooMany(launchHits, u.uid, 10, 60000)) return out(429, { error: "Too many launches, wait a minute." });
    let joinRoom = null;
    if (joinUid) {
      const target = byUid.get(String(joinUid));
      if (!target || !target.ws) return out(404, { error: "That friend isn't in a game right now." });
      const tu = await store.getUser(target.uid);
      if (tu.allowJoin === "nobody" || !(await store.isFriend(target.uid, u.uid))) return out(403, { error: "You can't join that player." });
      joinRoom = target.room.id;
    }
    const code = rnd(24); codes.set(code, { uid: u.uid, name: u.name, joinRoom, exp: Date.now() + 60000 });
    out(200, { code, ws: WS_URL });
  } catch { out(400, { error: "bad request" }); }
});
setInterval(() => { const n = Date.now(); for (const [k, v] of codes) if (v.exp < n) codes.delete(k); }, 15000).unref();

// ---------- WebSocket game protocol ----------
const wss = new WebSocketServer({ server, maxPayload: 2048 });
function leaveRoom(p, why) {
  if (!p || p.gone) return; p.gone = true; clearTimeout(p.graceTimer);
  p.room.remove(p); sessions.delete(p.session); if (byUid.get(p.uid) === p) byUid.delete(p.uid);
  p.room.broadcast({ t: "leave", id: p.id, name: p.name });
  flushStats(p).catch(() => {}); store.clearPresence(p.uid);
  if (p.room.players.size === 0) rooms.delete(p.room.id);
  if (p.ws) { p.ws.p = null; if (why) p.room.send(p, { t: "kicked", reason: why }); try { p.ws.close(); } catch {} p.ws = null; }
}
function welcome(p, resume) {
  const r = p.room;
  r.send(p, { t: "welcome", id: p.id, name: p.name, color: p.color, character: p.character, room: r.id, session: p.session, resume: !!resume, e: p.epoch, x: p.x, y: p.y, z: p.z, max: CFG.MAX_PLAYERS, players: r.live().filter(o => o !== p).map(o => r.pub(o)) });
  r.broadcast({ t: "join", player: r.pub(p) }, p);
}
async function handleAuth(ws, m) {
  if (typeof m.session === "string" && sessions.has(m.session)) {                // reconnect within grace window
    const p = sessions.get(m.session); clearTimeout(p.graceTimer); p.graceTimer = null;
    if (p.ws && p.ws !== ws) { p.ws.p = null; try { p.ws.close(); } catch {} }
    p.ws = ws; ws.p = p; return welcome(p, true);
  }
  const c = codes.get(m.code); if (!c || c.exp < Date.now()) return ws.close(4001, "invalid or expired launch code");
  codes.delete(m.code);                                                           // single use
  const old = byUid.get(c.uid); if (old) leaveRoom(old, "other_login");
  const [profile, blocked] = await Promise.all([store.getUser(c.uid), store.getBlocks(c.uid)]); if (ws.readyState !== 1) return;
  const room = pickRoom(c.joinRoom); rooms.set(room.id, room);
  const character = normalizeCharacter(profile.character, profile.avatarColor);
  const p = { uid: c.uid, name: (profile.username || c.name || "Player").slice(0, 20), color: profile.avatarColor || "#ffffff", character, profile: { username: profile.username || c.name, avatarColor: profile.avatarColor, character },
    ws, room, session: rnd(16), muted: new Set(), blocked, joinedAt: Date.now(), friendTimes: [], chatTimes: [], strikes: [], lastMsg: "", lastMsgAt: 0, lastOkAt: 0, cooldownUntil: 0, msgCount: 0, secCarry: 0, lastFlush: Date.now(), msgBudget: [], reportTimes: [] };
  room.add(p); ws.p = p; sessions.set(p.session, p); byUid.set(p.uid, p);
  store.addRecent(p.uid, "baseplate"); presence(p, profile.allowJoin !== "nobody"); p.joinable = profile.allowJoin !== "nobody";
  welcome(p, false); notifyBlocks(p);
}
function notifyBlocks(p) {   // tell clients about block relationships so the UI can show them
  for (const o of p.room.live()) { if (o === p) continue;
    if (p.blocked.has(o.uid)) p.room.send(p, { t: "mute_ok", id: o.id, on: true, blocked: true });
    if (o.blocked.has(p.uid)) p.room.send(o, { t: "mute_ok", id: p.id, on: true, blocked: true }); }
}
const presence = (p, joinable) => store.setPresence(p.uid, { game: "baseplate", server: p.room.id, joinable, username: p.name });

const REPORT_CATEGORIES = new Set(["abuse", "inappropriate_chat", "inappropriate_name", "cheating", "spam", "other"]);
function handleChat(p, m) {
  const now = Date.now(), r = p.room, warn = reason => r.send(p, { t: "chat_blocked", reason, text: FRIENDLY[reason] || "" });
  if (now < p.cooldownUntil) return warn("cooldown");
  p.chatTimes = p.chatTimes.filter(t => now - t < 10000);
  if (p.chatTimes.length >= 5 || now - p.lastMsgAt < 400) return warn("rate");
  p.chatTimes.push(now); p.lastMsgAt = now;
  const v = checkMessage(m.text);
  if (v.ok && p.lastRaw && now - p.lastRawAt < 8000 && checkSplit(p.lastRaw, m.text)) { v.ok = false; v.reason = "language"; }   // "fu" ... "ck" in two quick messages
  p.lastRaw = typeof m.text === "string" ? m.text.slice(0, 40) : ""; p.lastRawAt = now;
  if (v.ok && v.text.toLowerCase() === p.lastMsg && now - p.lastOkAt < 15000) { v.ok = false; v.reason = "spam"; }
  if (v.ok && v.masked) {              // bad words were hidden with ####: the message still goes out, but it counts as a strike
    p.strikes = p.strikes.filter(t => now - t < 300000); p.strikes.push(now);
    if (p.strikes.length >= 5) { p.cooldownUntil = now + 60000; p.strikes = []; }
    if (now - (p.lastMaskNote || 0) > 30000) { p.lastMaskNote = now; r.send(p, { t: "sys", text: "Some words were hidden. Let's keep BlockTopia friendly!" }); }
  }
  if (!v.ok) {
    if (v.reason === "language" || v.reason === "personal") { p.strikes = p.strikes.filter(t => now - t < 300000); p.strikes.push(now); if (p.strikes.length >= 5) { p.cooldownUntil = now + 60000; p.strikes = []; return warn("cooldown"); } }
    return warn(v.reason);
  }
  p.lastMsg = v.text.toLowerCase(); p.lastOkAt = now; p.msgCount++;
  const line = { t: "chat", id: p.id, name: p.name, text: v.text };
  r.history.push({ id: p.id, uid: p.uid, name: p.name, text: v.text, ts: now }); if (r.history.length > 30) r.history.shift();
  const s = JSON.stringify(line);
  for (const o of r.live()) if (!o.muted.has(p.uid) && !o.blocked.has(p.uid) && o.ws.readyState === 1) o.ws.send(s);   // recipients' mutes honored server-side
}
function handle(ws, m) {
  const p = ws.p, r = p.room;
  switch (m.t) {
    case "pos": r.applyPos(p, m); if (p.viol > 60) leaveRoom(p, "invalid_movement"); break;
    case "respawn": r.teleportToSpawn(p); break;
    case "chat": handleChat(p, m); break;
    case "ping": r.send(p, { t: "pong", n: Number(m.n) || 0 }); break;
    case "mute": { const t = r.players.get(m.id); if (t && t !== p) { m.on ? p.muted.add(t.uid) : p.muted.delete(t.uid); r.send(p, { t: "mute_ok", id: t.id, on: !!m.on }); } break; }
    case "report": {
      const t = r.players.get(m.id), now = Date.now(); if (!t || t === p) break;
      p.reportTimes = p.reportTimes.filter(x => now - x < 60000); if (p.reportTimes.length >= 3) return r.send(p, { t: "sys", text: "Slow down on reports." }); p.reportTimes.push(now);
      p.reported ??= new Map(); if (now - (p.reported.get(t.uid) || 0) < 600000) return r.send(p, { t: "report_ok", dup: true });   // one report per player per 10 minutes
      p.reported.set(t.uid, now);
      const category = REPORT_CATEGORIES.has(m.category) ? m.category : "other";
      store.saveReport({ reporterUid: p.uid, reporterName: p.name, targetUid: t.uid, targetName: t.name, category, reason: String(m.reason || "").slice(0, 100), details: String(m.details || "").slice(0, 300), room: r.id, chat: r.history.slice(-10) }).then(() => r.send(p, { t: "report_ok" })).catch(() => r.send(p, { t: "sys", text: "Report failed, try again." })); break; }
    case "block": {
      const t = r.players.get(m.id); if (!t || t === p) break; const on = !!m.on;
      on ? p.blocked.add(t.uid) : p.blocked.delete(t.uid); store.setBlock(p.uid, t.uid, on).catch(() => {});
      r.send(p, { t: "mute_ok", id: t.id, on, blocked: true }); break; }
    case "friend": {
      const t = r.players.get(m.id), now = Date.now(); if (!t || t === p) break;
      p.friendTimes = p.friendTimes.filter(x => now - x < 60000); if (p.friendTimes.length >= 8) return r.send(p, { t: "friend_result", ok: false, text: "Slow down on friend requests." }); p.friendTimes.push(now);
      if (t.blocked.has(p.uid) || p.blocked.has(t.uid)) return r.send(p, { t: "friend_result", ok: false, text: `You can't send ${t.name} a friend request.` });
      const fromU = { uid: p.uid, name: p.name }, toU = { uid: t.uid, name: t.name };
      const made = () => { r.send(p, { t: "friend_result", ok: true, friends: true, text: `You and ${t.name} are now friends!` }); r.send(t, { t: "friend_result", ok: true, friends: true, text: `You and ${p.name} are now friends!` }); };
      store.requestFriend(fromU, toU).then(async res => {
        if (res.ok) { t.incoming ??= new Map(); t.incoming.set(p.uid, { id: p.id, name: p.name, at: Date.now() }); r.send(t, { t: "friend_request", id: p.id, name: p.name }); }
        else if (res.theirs && await store.acceptFriend(toU, fromU)) { t.incoming?.delete?.(p.uid); p.incoming?.delete?.(t.uid); return made(); }   // they had already asked you: that makes you friends
        r.send(p, { t: "friend_result", ok: res.ok, text: res.text });
      }).catch(() => r.send(p, { t: "friend_result", ok: false, text: "Couldn't send the request. Try again." })); break; }
    case "friend_accept": case "friend_decline": {
      const entry = [...(p.incoming || new Map())].find(([, v]) => v.id === m.id); if (!entry) break;
      const [fuid, info] = entry; p.incoming.delete(fuid); const from = { uid: fuid, name: info.name }, me = { uid: p.uid, name: p.name };
      if (m.t === "friend_decline") { store.declineFriend(from, me).catch(() => {}); break; }
      const sender = r.players.get(info.id);
      store.acceptFriend(from, me).then(okk => {
        if (!okk) return r.send(p, { t: "friend_result", ok: false, text: "That request is no longer valid." });
        r.send(p, { t: "friend_result", ok: true, friends: true, text: `You and ${info.name} are now friends!` });
        if (sender && sender.uid === fuid) r.send(sender, { t: "friend_result", ok: true, friends: true, text: `${p.name} accepted your friend request!` });
      }).catch(() => r.send(p, { t: "friend_result", ok: false, text: "Couldn't accept right now. Try again." })); break; }
    case "leave": leaveRoom(p); break;
  }
}
wss.on("connection", ws => {
  ws.alive = true; ws.on("pong", () => { ws.alive = true; }); ws.hits = 0;
  const authTimer = setTimeout(() => { if (!ws.p) ws.close(4002, "auth timeout"); }, 10000);
  const rate = setInterval(() => { ws.hits = 0; }, 1000);
  ws.on("message", async data => {
    if (++ws.hits > 40) return ws.close(4008, "rate limit");
    let m; try { m = JSON.parse(data.toString()); } catch { return; }
    if (!m || typeof m !== "object") return;
    try { if (!ws.p) { if (m.t === "auth" && !ws.authing) { ws.authing = true; await handleAuth(ws, m); ws.authing = false; } return; } handle(ws, m); } catch (e) { console.error("msg error", e.message); }
  });
  ws.on("close", () => {
    clearTimeout(authTimer); clearInterval(rate); const p = ws.p; if (!p || p.ws !== ws || p.gone) return;
    p.ws = null; p.room.broadcast({ t: "leave", id: p.id, name: p.name });
    p.graceTimer = setTimeout(() => leaveRoom(p), CFG.GRACE_MS);                  // keep slot for reconnection
  });
  ws.on("error", () => {});
});
setInterval(() => { for (const r of rooms.values()) { const s = JSON.stringify(r.snapshot()); for (const p of r.live()) if (p.ws.readyState === 1) p.ws.send(s); } }, 66);
setInterval(() => { for (const ws of wss.clients) { if (!ws.alive) { ws.terminate(); continue; } ws.alive = false; ws.ping(); } }, 20000);
setInterval(() => { for (const r of rooms.values()) for (const p of r.live()) { flushStats(p).catch(() => {}); presence(p, p.joinable !== false); } }, 30000);

export async function start(port = PORT) {
  await store.clearInstance(); await new Promise(r => server.listen(port, r)); console.log(`BlockTopia server on :${port}`);
}
export async function stop() { for (const r of rooms.values()) for (const p of [...r.players.values()]) leaveRoom(p); await new Promise(r => { wss.close(); server.close(r); }); }
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  start();
  for (const s of ["SIGINT", "SIGTERM"]) process.on(s, async () => { await stop(); process.exit(0); });
}
