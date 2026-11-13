// Firestore access for the game server (Admin SDK). Falls back to in-memory only when DEV_AUTH=1.
import admin from "firebase-admin";
export const INSTANCE = process.env.INSTANCE_ID || "main";
let db = null;
try {
  if (process.env.FIREBASE_SERVICE_ACCOUNT) admin.initializeApp({ credential: admin.credential.cert(JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)) });
  else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) admin.initializeApp({ credential: admin.credential.applicationDefault() });
  if (admin.apps.length) db = admin.firestore();
} catch (e) { console.error("Firebase init failed:", e.message); }
if (!db && process.env.DEV_AUTH !== "1") { console.error("No Firebase credentials. Set FIREBASE_SERVICE_ACCOUNT (or DEV_AUTH=1 for local tests)."); process.exit(1); }
if (!db) console.warn("[dev] running without Firestore: data is kept in memory only");

export const mem = { users: new Map(), friends: new Set(), stats: new Map(), reports: [], presence: new Map(), blocks: new Map(), requests: new Map() };
const TS = () => admin.firestore.FieldValue.serverTimestamp();
const INC = n => admin.firestore.FieldValue.increment(n);

export async function getUser(uid) { if (!db) return mem.users.get(uid) || {}; const s = await db.doc(`users/${uid}`).get(); return s.exists ? s.data() : {}; }
export async function isFriend(a, b) { if (!db) return mem.friends.has(`${a}|${b}`); return (await db.doc(`friends/${a}/list/${b}`).get()).exists; }
export async function setPresence(uid, d) {
  if (!db) return void mem.presence.set(uid, d);
  await db.doc(`presence/${uid}`).set({ ...d, online: true, instance: INSTANCE, updatedAt: TS() }).catch(e => console.error("presence", e.message));
}
export async function clearPresence(uid) { if (!db) return void mem.presence.delete(uid); await db.doc(`presence/${uid}`).delete().catch(() => {}); }
export async function clearInstance() {
  if (!db) return; const s = await db.collection("presence").where("instance", "==", INSTANCE).get(); await Promise.all(s.docs.map(d => d.ref.delete()));
}
export async function addRecent(uid, game) { if (!db) return; await db.doc(`users/${uid}`).set({ recentGames: admin.firestore.FieldValue.arrayUnion(game) }, { merge: true }).catch(() => {}); }
export async function addStats(uid, inc, who) {
  if (!db) { const s = mem.stats.get(uid) || { playtime: 0, score: 0, wins: 0, messages: 0 }; for (const k in inc) s[k] = (s[k] || 0) + inc[k]; mem.stats.set(uid, s); return; }
  const data = { username: who.username, avatarColor: who.avatarColor || "#ffffff", updatedAt: TS() };
  for (const k of ["score", "wins", "playtime", "messages"]) data[k] = INC(inc[k] || 0);
  await db.doc(`stats/${uid}`).set(data, { merge: true }).catch(e => console.error("stats", e.message));
}
export async function saveReport(r) { if (!db) return void mem.reports.push(r); await db.collection("reports").add({ ...r, createdAt: TS() }); }

export async function getStats(uid) { if (!db) return mem.stats.get(uid) || {}; const s = await db.doc(`stats/${uid}`).get(); return s.exists ? s.data() : {}; }
export async function getBlocks(uid) {
  if (!db) return new Set(mem.blocks.get(uid) || []);
  const s = await db.collection(`blocks/${uid}/list`).get(); return new Set(s.docs.map(d => d.id));
}
export async function setBlock(uid, target, on) {
  if (!db) { const s = mem.blocks.get(uid) || new Set(); on ? s.add(target) : s.delete(target); mem.blocks.set(uid, s); return; }
  const r = db.doc(`blocks/${uid}/list/${target}`); if (on) await r.set({ at: TS() }); else await r.delete();
}
// In-game "Add Friend": writes the same friendRequests doc the website uses, so it shows up under Friends > Requests.
export async function requestFriend(from, to) {
  const already = { ok: false, text: `You're already friends with ${to.name}.` }, sent = { ok: false, text: `You already sent ${to.name} a request.` };
  const theirs = { ok: false, text: `${to.name} already sent you a request. Accept it on the website (Friends).` };
  if (!db) {
    if (mem.friends.has(`${from.uid}|${to.uid}`)) return already;
    if (mem.requests.get(`${to.uid}_${from.uid}`) === "pending") return theirs;
    if (mem.requests.get(`${from.uid}_${to.uid}`) === "pending") return sent;
    mem.requests.set(`${from.uid}_${to.uid}`, "pending"); return { ok: true, text: `Friend request sent to ${to.name}.` };
  }
  if ((await db.doc(`friends/${from.uid}/list/${to.uid}`).get()).exists) return already;
  const tu = (await db.doc(`users/${to.uid}`).get()).data() || {};
  if (tu.allowRequests === "none") return { ok: false, text: `${to.name} isn't accepting friend requests.` };
  const rev = await db.doc(`friendRequests/${to.uid}_${from.uid}`).get(); if (rev.exists && rev.data().status === "pending") return theirs;
  const ref = db.doc(`friendRequests/${from.uid}_${to.uid}`), cur = await ref.get(); if (cur.exists && cur.data().status === "pending") return sent;
  await ref.set({ from: from.uid, to: to.uid, fromName: from.name, toName: to.name, status: "pending", createdAt: TS() });
  if (tu.notifFriendRequests !== false) await db.collection(`notifications/${to.uid}/items`).add({ type: "friend_request", from: from.uid, text: `${from.name} sent you a friend request`, read: false, createdAt: TS() });
  return { ok: true, text: `Friend request sent to ${to.name}.` };
}
