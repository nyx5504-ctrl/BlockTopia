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

export const mem = { users: new Map(), friends: new Set(), stats: new Map(), reports: [], presence: new Map(), blocks: new Map(), requests: new Map(), gameReactions: new Map() };
const TS = () => admin.firestore.FieldValue.serverTimestamp();
const INC = n => admin.firestore.FieldValue.increment(n);

export async function getUser(uid) { if (!db) return mem.users.get(uid) || {}; const s = await db.doc("users/" + uid).get(); return s.exists ? s.data() : {}; }
export async function updateProfile(uid, patch) {
  if (!db) { const user = mem.users.get(uid) || {}; Object.assign(user, patch); mem.users.set(uid, user); return user; }
  await db.doc("users/" + uid).set(patch, { merge: true });
  return getUser(uid);
}
export async function createProfile(uid, username) {
  const usernameLower = username.toLowerCase();
  if (!db) {
    for (const [otherUid, user] of mem.users) if (otherUid !== uid && user.usernameLower === usernameLower) throw new Error("USERNAME_TAKEN");
    const old = mem.users.get(uid) || {};
    if (old.username) return old;
    const profile = { username, usernameLower, avatarColor: "#f4f4f2", character: { height: 1, bodyType: "classic", bodyColor: "#f2c744" }, allowRequests: "everyone", allowJoin: "friends", recentGames: [], favorites: [], createdAt: new Date().toISOString() };
    mem.users.set(uid, profile); return profile;
  }
  const userRef = db.doc(`users/${uid}`), nameRef = db.doc(`usernames/${usernameLower}`);
  await db.runTransaction(async tx => {
    const [userSnap, nameSnap] = await Promise.all([tx.get(userRef), tx.get(nameRef)]);
    if (userSnap.exists && userSnap.data().username) return;
    if (nameSnap.exists && nameSnap.data().uid !== uid) throw new Error("USERNAME_TAKEN");
    if (!nameSnap.exists) tx.create(nameRef, { uid });
    tx.set(userRef, { username, usernameLower, avatarColor: "#f4f4f2", character: { height: 1, bodyType: "classic", bodyColor: "#f2c744" }, allowRequests: "everyone", allowJoin: "friends", recentGames: [], favorites: [], createdAt: TS() }, { merge: true });
  });
  return await getUser(uid);
}
export async function findUidByUsername(username) {
  const usernameLower = String(username || "").trim().toLowerCase();
  if (!/^[a-z0-9_]{3,20}$/.test(usernameLower)) return "";
  if (!db) {
    for (const [uid, user] of mem.users) if (user.usernameLower === usernameLower) return uid;
    return "";
  }
  const snap = await db.doc("usernames/" + usernameLower).get();
  return snap.exists ? String(snap.data().uid || "") : "";
}

export async function createUserCustomToken(uid) {
  if (process.env.DEV_AUTH === "1" && !admin.apps.length) return "dev-custom:" + uid;   // local tests only
  return admin.auth().createCustomToken(uid);
}

export async function listNotifications(uid) {
  if (!db) return [];
  const snap = await db.collection("notifications/" + uid + "/items").orderBy("createdAt", "desc").limit(30).get();
  return snap.docs.map(doc => ({ id: doc.id, ...doc.data() }));
}

export async function markNotificationsRead(uid) {
  if (!db) return;
  const collection = db.collection("notifications/" + uid + "/items");
  while (true) {
    const snap = await collection.where("read", "==", false).limit(400).get();
    if (snap.empty) return;
    const batch = db.batch();
    for (const doc of snap.docs) batch.update(doc.ref, { read: true });
    await batch.commit();
  }
}

export async function getGameReaction(uid, game) {
  if (!db) return mem.gameReactions.get(`${game}:${uid}`) || "";
  const ref = db.doc(`games/${game}/reactions/${uid}`), likeRef = db.doc(`games/${game}/likes/${uid}`);
  const [snap, likeSnap] = await Promise.all([ref.get(), likeRef.get()]);
  return likeSnap.exists ? "like" : (snap.exists ? String(snap.data().reaction || "") : "");
}
export async function toggleGameReaction(uid, game, reaction) {
  const key = `${game}:${uid}`;
  if (!db) {
    const old = mem.gameReactions.get(key) || "";
    const next = old === reaction ? "" : reaction;
    if (next) mem.gameReactions.set(key, next); else mem.gameReactions.delete(key);
    return next;
  }
  const ref = db.doc(`games/${game}/reactions/${uid}`), likeRef = db.doc(`games/${game}/likes/${uid}`);
  let next = reaction;
  await db.runTransaction(async tx => {
    const [snap, likeSnap] = await Promise.all([tx.get(ref), tx.get(likeRef)]);
    const old = likeSnap.exists ? "like" : (snap.exists ? String(snap.data().reaction || "") : "");
    if (old === reaction) {
      tx.delete(ref); if (likeSnap.exists) tx.delete(likeRef); next = "";
    } else {
      tx.set(ref, { uid, reaction, updatedAt: TS() });
      if (reaction === "like") tx.set(likeRef, { at: TS() });
      else if (likeSnap.exists) tx.delete(likeRef);
    }
  });
  return next;
}

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
  const theirs = { ok: false, theirs: true, text: `${to.name} already sent you a request.` };
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

// In-game accept / decline of a request that `from` sent to `me` (same documents the website writes, so both places stay in sync).
export async function acceptFriend(from, me) {
  if (!db) {
    if (mem.requests.get(`${from.uid}_${me.uid}`) !== "pending") return false;
    mem.requests.set(`${from.uid}_${me.uid}`, "accepted"); mem.friends.add(`${from.uid}|${me.uid}`); mem.friends.add(`${me.uid}|${from.uid}`); return true;
  }
  const ref = db.doc(`friendRequests/${from.uid}_${me.uid}`), cur = await ref.get();
  if (!cur.exists || cur.data().status !== "pending") return false;
  const [fu, mu] = await Promise.all([getUser(from.uid), getUser(me.uid)]);
  await ref.update({ status: "accepted" });
  await Promise.all([
    db.doc(`friends/${me.uid}/list/${from.uid}`).set({ username: fu.username || from.name, avatarColor: fu.avatarColor || "#f4f4f2", since: TS() }),
    db.doc(`friends/${from.uid}/list/${me.uid}`).set({ username: mu.username || me.name, avatarColor: mu.avatarColor || "#f4f4f2", since: TS() }),
  ]);
  await db.collection(`notifications/${from.uid}/items`).add({ type: "friend_accepted", from: me.uid, fromName: me.name, read: false, createdAt: TS() }).catch(() => {});
  return true;
}
export async function declineFriend(from, me) {
  if (!db) { if (mem.requests.get(`${from.uid}_${me.uid}`) === "pending") mem.requests.set(`${from.uid}_${me.uid}`, "rejected"); return; }
  const ref = db.doc(`friendRequests/${from.uid}_${me.uid}`), cur = await ref.get();
  if (cur.exists && cur.data().status === "pending") await ref.update({ status: "rejected" });
}
