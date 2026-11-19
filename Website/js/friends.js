// Friends: search, requests, friend list, who is in a game, join.
import { db, F } from "./fb.js";
import { S, on, emit } from "./state.js";
import { $, esc, avatar, avatarHead, icon, ms, toast } from "./ui.js";
import { hydrateHeads } from "./head3d.js";
import { t } from "./i18n.js";
import { play } from "./play.js";

export function stopListeners() { S.stops.forEach(f => { try { f(); } catch {} }); S.stops = []; }

export function startFriends() {
  const uid = S.user.uid, col = F.collection(db, "friendRequests"), warn = e => console.warn(e.code || e);
  S.stops.push(F.onSnapshot(F.collection(db, "friends", uid, "list"), s => { S.friends = new Map(s.docs.map(d => [d.id, d.data()])); emit("friends"); }, warn));
  S.stops.push(F.onSnapshot(F.query(col, F.where("to", "==", uid), F.where("status", "==", "pending")), s => { S.incoming = s.docs.map(d => ({ id: d.id, ...d.data() })); emit("friends"); emit("notifs"); }, warn));
  S.stops.push(F.onSnapshot(F.query(col, F.where("from", "==", uid), F.where("status", "==", "pending")), s => { S.outgoing = new Set(s.docs.map(d => d.data().to)); emit("friends"); }, warn));
  S.stops.push(F.onSnapshot(F.query(F.collection(db, "presence"), F.where("game", "==", "baseplate")), s => { S.presence = new Map(s.docs.map(d => [d.id, d.data()])); emit("friends"); }, warn));
}

export async function profiles() {   // fresh profile (for lastSeen) of every friend, cached for 45 s
  await Promise.all([...S.friends.keys()].map(async id => {
    const c = S.fprof.get(id);
    if (c && Date.now() - c.at < 45000) return;
    try { S.fprof.set(id, { at: Date.now(), data: (await F.getDoc(F.doc(db, "users", id))).data() || {} }); } catch {}
  }));
}

const statusOf = id => {
  const pr = S.presence.get(id), p = S.fprof.get(id)?.data;
  if (pr) return { on: true, text: t("in_game"), join: pr.joinable !== false };
  const online = p?.lastSeen && Date.now() - ms(p.lastSeen) < 180000;
  return { on: !!online, text: t(online ? "online" : "offline") };
};

export async function renderFriends() {
  await profiles();
  const reqs = S.incoming;
  $("#reqWrap").hidden = !reqs.length;
  $("#reqList").innerHTML = reqs.map(r => `<div class="row">${avatar(r.fromName, r.fromColor)}<div class="grow"><div class="name">${esc(r.fromName || "?")}</div></div>
    <div class="btns"><button class="btn primary sm" data-accept="${esc(r.id)}" type="button">${esc(t("accept"))}</button><button class="btn sm" data-decline="${esc(r.id)}" type="button">${esc(t("decline"))}</button></div></div>`).join("");
  const list = [...S.friends.entries()].map(([id, f]) => ({ id, f, s: statusOf(id) })).sort((a, b) => (b.s.on - a.s.on) || String(a.f.username).localeCompare(String(b.f.username)));
  $("#friendList").innerHTML = list.length ? list.map(({ id, f, s }) => `<div class="row">${avatarHead(f.username, S.fprof.get(id)?.data?.avatarColor || f.avatarColor, "", S.fprof.get(id)?.data?.character, statusOf(id).on)}
    <div class="grow"><div class="name">${esc(f.username)}</div><div class="sub"><span class="dot ${s.on ? "on" : ""}"></span>${esc(s.text)}</div></div>
    <div class="btns">${s.join ? `<button class="btn primary sm" data-join="${esc(id)}" type="button">${icon("play", "fill")} ${esc(t("join"))}</button>` : ""}<button class="btn ghost sm" data-remove="${esc(id)}" type="button">${esc(t("remove"))}</button></div></div>`).join("")
    : `<p class="empty">${esc(t("no_friends"))}</p>`;
  hydrateHeads($("#friendList"));
  if (!$("#fResults").hidden) searchNow();
}

// ---------- search ----------
let sTimer, sToken = 0;
async function searchNow() {
  const q = $("#fSearch").value.trim().toLowerCase(), box = $("#fResults"), my = ++sToken;
  if (q.length < 2) { box.hidden = true; return; }
  let docs = [];
  try { docs = (await F.getDocs(F.query(F.collection(db, "users"), F.where("usernameLower", ">=", q), F.where("usernameLower", "<=", q + ""), F.limit(8)))).docs; }
  catch { toast(t("err_network"), "bad"); return; }
  if (my !== sToken) return;
  docs = docs.filter(d => d.id !== S.user.uid);
  box.hidden = false;
  box.innerHTML = docs.length ? docs.map(d => {
    const u = d.data(), id = d.id, incoming = S.incoming.find(r => r.from === id);
    const act = S.friends.has(id) ? `<span class="tag">${esc(t("already_friends"))}</span>`
      : incoming ? `<button class="btn primary sm" data-accept="${esc(incoming.id)}" type="button">${esc(t("accept"))}</button>`
      : S.outgoing.has(id) ? `<button class="btn sm" data-cancel="${esc(id)}" type="button">${esc(t("pending"))} · ${esc(t("cancel"))}</button>`
      : `<button class="btn primary sm" data-add="${esc(id)}" data-name="${esc(u.username)}" type="button">${esc(t("add"))}</button>`;
    return `<div class="row">${avatar(u.username, u.avatarColor)}<div class="grow"><div class="name">${esc(u.username)}</div></div><div class="btns">${act}</div></div>`;
  }).join("") : `<p class="empty">${esc(t("no_results"))}</p>`;
}

// ---------- actions (used by Friends and Notifications) ----------
export async function sendRequest(other) {
  const me = S.user.uid, note = F.addDoc(F.collection(db, "notifications", other, "items"), { type: "friend_request", from: me, fromName: S.profile.username, read: false, createdAt: F.serverTimestamp() });
  try {
    await F.setDoc(F.doc(db, "friendRequests", `${me}_${other}`), { from: me, to: other, status: "pending", fromName: S.profile.username, fromColor: S.profile.avatarColor || "#f4f4f2", createdAt: F.serverTimestamp() });
    note.catch(() => {}); toast(t("req_sent"));
  } catch (e) { note.catch(() => {}); toast(t(e.code === "permission-denied" ? "req_blocked" : "err_generic"), "bad"); }
}
export async function acceptRequest(reqId) {
  const r = S.incoming.find(x => x.id === reqId); if (!r) return;
  const me = S.user.uid, other = r.from;
  try {
    await F.updateDoc(F.doc(db, "friendRequests", reqId), { status: "accepted" });
    const op = (await F.getDoc(F.doc(db, "users", other))).data() || {};
    await Promise.all([
      F.setDoc(F.doc(db, "friends", me, "list", other), { username: op.username || r.fromName || "?", avatarColor: op.avatarColor || "#f4f4f2", since: F.serverTimestamp() }),
      F.setDoc(F.doc(db, "friends", other, "list", me), { username: S.profile.username, avatarColor: S.profile.avatarColor || "#f4f4f2", since: F.serverTimestamp() }),
    ]);
    F.addDoc(F.collection(db, "notifications", other, "items"), { type: "friend_accepted", from: me, fromName: S.profile.username, read: false, createdAt: F.serverTimestamp() }).catch(() => {});
    toast(t("friend_added", { name: op.username || r.fromName }));
  } catch { toast(t("err_generic"), "bad"); }
}
export async function declineRequest(reqId) {
  try { await F.updateDoc(F.doc(db, "friendRequests", reqId), { status: "rejected" }); } catch { toast(t("err_generic"), "bad"); }
}
async function removeFriend(other) {
  const me = S.user.uid, d = x => F.deleteDoc(x).catch(() => {});
  await Promise.all([d(F.doc(db, "friends", me, "list", other)), d(F.doc(db, "friends", other, "list", me)), d(F.doc(db, "friendRequests", `${me}_${other}`)), d(F.doc(db, "friendRequests", `${other}_${me}`))]);
  toast(t("friend_removed"));
}

export function initFriends() {
  on("friends", () => { if (!$("#v-friends").hidden) renderFriends(); });
  $("#fSearch").addEventListener("input", () => { clearTimeout(sTimer); sTimer = setTimeout(searchNow, 300); });
  $("#v-friends").addEventListener("click", async e => {
    const b = e.target.closest("button"); if (!b) return;
    if (b.dataset.add) { b.disabled = true; await sendRequest(b.dataset.add); searchNow(); }
    else if (b.dataset.cancel) { await F.deleteDoc(F.doc(db, "friendRequests", `${S.user.uid}_${b.dataset.cancel}`)).catch(() => {}); searchNow(); }
    else if (b.dataset.accept) await acceptRequest(b.dataset.accept);
    else if (b.dataset.decline) await declineRequest(b.dataset.decline);
    else if (b.dataset.join) play({ joinUid: b.dataset.join });
    else if (b.dataset.remove) {
      if (b.dataset.armed) { await removeFriend(b.dataset.remove); }
      else { b.dataset.armed = "1"; b.textContent = t("remove_confirm"); b.classList.add("danger"); setTimeout(() => { b.dataset.armed = ""; b.textContent = t("remove"); b.classList.remove("danger"); }, 3000); }
    }
  });
}
