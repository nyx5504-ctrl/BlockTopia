// Notifications list + unread badges.
import { db, F } from "./fb.js";
import { S, on, emit } from "./state.js";
import { $, $$, esc, avatar, ms, toast } from "./ui.js";
import { t, fmtRel } from "./i18n.js";
import { acceptRequest, declineRequest } from "./friends.js";

export function startAlerts() {
  S.stops.push(F.onSnapshot(F.query(F.collection(db, "notifications", S.user.uid, "items"), F.orderBy("createdAt", "desc"), F.limit(40)),
    s => { S.notifs = s.docs.map(d => ({ id: d.id, ...d.data() })); emit("notifs"); }, e => console.warn(e.code || e)));
}

export function renderBadges() {
  const unread = S.notifs.filter(n => !n.read).length, reqs = S.incoming.length;
  $$("[data-alert-badge]").forEach(b => { b.hidden = !unread; b.textContent = unread > 9 ? "9+" : unread; });
  $$("[data-req-badge]").forEach(b => { b.hidden = !reqs; b.textContent = reqs > 9 ? "9+" : reqs; });
}

export function renderAlerts() {
  renderBadges();
  const box = $("#alertList");
  $("#markRead").hidden = !S.notifs.some(n => !n.read);
  if (!S.notifs.length) { box.innerHTML = `<p class="empty">${esc(t("alerts_empty"))}</p>`; return; }
  box.innerHTML = S.notifs.map(n => {
    const text = n.type === "friend_accepted" ? t("n_acc", { name: n.fromName || "?" }) : t("n_req", { name: n.fromName || "?" });
    const req = n.type === "friend_request" ? S.incoming.find(r => r.from === n.from) : null;
    return `<div class="row click ${n.read ? "" : "unread"}" data-n="${esc(n.id)}">${avatar(n.fromName, "")}<div class="grow"><div class="name" style="white-space:normal">${esc(text)}</div><div class="sub">${esc(fmtRel(ms(n.createdAt), false))}</div></div>
      ${req ? `<div class="btns"><button class="btn primary sm" data-accept="${esc(req.id)}" type="button">${esc(t("accept"))}</button><button class="btn sm" data-decline="${esc(req.id)}" type="button">${esc(t("decline"))}</button></div>` : ""}</div>`;
  }).join("");
}

const markRead = id => F.updateDoc(F.doc(db, "notifications", S.user.uid, "items", id), { read: true }).catch(() => {});

export function initAlerts() {
  on("notifs", renderAlerts);
  $("#alertList").addEventListener("click", async e => {
    const b = e.target.closest("button"), row = e.target.closest("[data-n]");
    if (b?.dataset.accept) { await acceptRequest(b.dataset.accept); if (row) markRead(row.dataset.n); return; }
    if (b?.dataset.decline) { await declineRequest(b.dataset.decline); if (row) markRead(row.dataset.n); return; }
    if (row && !S.notifs.find(n => n.id === row.dataset.n)?.read) markRead(row.dataset.n);
  });
  $("#markRead").onclick = async () => { await Promise.all(S.notifs.filter(n => !n.read).map(n => markRead(n.id))); toast(t("saved")); };
}
