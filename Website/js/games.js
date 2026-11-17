// Home: the game list (only Baseplate for now), likes, favorites and live player counts.
import { db, F } from "./fb.js";
import { S } from "./state.js";
import { $, esc, icon, toast } from "./ui.js";
import { t } from "./i18n.js";
import { play } from "./play.js";

export const GAMES = [{ id: "baseplate", name: "Baseplate", descKey: "game_baseplate_desc", creator: "BlockTopia" }];
const stats = {};     // id -> {playing, likes, liked}
let query = "";

const THUMB = `<svg class="thumb" viewBox="0 0 320 190" role="img" aria-hidden="true">
  <polygon class="tp-top" points="160,52 300,104 160,156 20,104"/>
  <polygon class="tp-a" points="20,104 160,156 160,174 20,122"/><polygon class="tp-b" points="160,156 300,104 300,122 160,174"/>
  <g class="tp-grid"><path d="M55,91 195,143 M90,78 230,130 M125,65 265,117 M90,130 230,78 M125,143 265,91 M55,117 195,65 M160,52 160,156 M20,104 300,104"/></g>
  <ellipse class="tp-shadow" cx="160" cy="112" rx="16" ry="6"/>
  <rect class="tp-body" x="150" y="78" width="20" height="26" rx="3"/><rect class="tp-head" x="152" y="60" width="16" height="16" rx="3"/>
</svg>`;

const st = id => (stats[id] ||= { playing: 0, likes: 0, liked: false });
const isFav = id => (S.profile?.favorites || []).includes(id);

export async function loadStats() {
  for (const g of GAMES) {
    const s = st(g.id);
    try { s.likes = (await F.getCountFromServer(F.collection(db, "games", g.id, "likes"))).data().count; } catch {}
    try { s.liked = (await F.getDoc(F.doc(db, "games", g.id, "likes", S.user.uid))).exists(); } catch {}
    try { s.playing = (await F.getCountFromServer(F.query(F.collection(db, "presence"), F.where("game", "==", g.id)))).data().count; } catch {}
  }
  renderHome();
}

function featured(g) {
  const s = st(g.id);
  return `<article class="card hero"><div class="art">${THUMB}</div><div class="info">
    <h3>${esc(g.name)}</h3><p class="desc">${esc(t(g.descKey))}</p>
    <div class="stats"><span>${esc(t("playing", { n: s.playing }))}</span><span>${esc(t("likes", { n: s.likes }))}</span><span>${esc(t("by", { name: g.creator }))}</span></div>
    <div class="actions">
      <button class="btn primary play" data-play="${g.id}" type="button">${icon("play", "fill")} ${esc(t("play"))}</button>
      <button class="btn sq ${s.liked ? "on" : ""}" data-like="${g.id}" type="button" aria-pressed="${s.liked}" aria-label="${esc(t(s.liked ? "liked" : "like"))}" title="${esc(t(s.liked ? "liked" : "like"))}">${icon("heart")}</button>
      <button class="btn sq ${isFav(g.id) ? "on" : ""}" data-fav="${g.id}" type="button" aria-pressed="${isFav(g.id)}" aria-label="${esc(t(isFav(g.id) ? "favorited" : "favorite"))}" title="${esc(t(isFav(g.id) ? "favorited" : "favorite"))}">${icon("star")}</button>
    </div></div></article>`;
}
const card = g => `<button class="card gcard" data-play="${g.id}" type="button"><div class="art">${THUMB}</div><div class="meta"><b>${esc(g.name)}</b><span>${esc(t("playing", { n: st(g.id).playing }))}</span></div></button>`;

export function renderHome(q = query) {
  query = q;
  const s = q.trim().toLowerCase(), list = GAMES.filter(g => !s || g.name.toLowerCase().includes(s));
  $("#homeFeatured").hidden = !!s;
  $("#featured").innerHTML = GAMES.length ? featured(GAMES[0]) : "";
  const recent = (S.profile?.recentGames || []).map(id => GAMES.find(g => g.id === id)).filter(Boolean);
  $("#recentWrap").hidden = !!s || !recent.length;
  $("#recent").innerHTML = recent.map(card).join("");
  $("#popTitle").textContent = s ? t("search_results") : t("popular");
  $("#popular").innerHTML = list.length ? list.map(card).join("") : `<p class="empty" style="grid-column:1/-1">${esc(t("no_games", { q: q.trim() }))}</p>`;
}

export function initHome() {
  $("#v-home").addEventListener("click", async e => {
    const p = e.target.closest("[data-play]"), l = e.target.closest("[data-like]"), f = e.target.closest("[data-fav]");
    if (p) return play();
    if (l) {
      const id = l.dataset.like, s = st(id), ref = F.doc(db, "games", id, "likes", S.user.uid);
      try { if (s.liked) { await F.deleteDoc(ref); s.liked = false; s.likes = Math.max(0, s.likes - 1); } else { await F.setDoc(ref, { at: F.serverTimestamp() }); s.liked = true; s.likes++; } renderHome(); }
      catch { toast(t("err_generic"), "bad"); }
    }
    if (f) {
      const id = f.dataset.fav, on = isFav(id);
      try {
        await F.updateDoc(F.doc(db, "users", S.user.uid), { favorites: on ? F.arrayRemove(id) : F.arrayUnion(id) });
        const a = new Set(S.profile.favorites || []); on ? a.delete(id) : a.add(id); S.profile.favorites = [...a]; renderHome();
      } catch { toast(t("err_generic"), "bad"); }
    }
  });
  $("#search").addEventListener("input", e => renderHome(e.target.value));
}
