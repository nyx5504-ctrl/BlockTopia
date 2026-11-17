// BlockTopia — boots the single page: language -> auth state -> router.
import { auth, db, A, F } from "./fb.js";
import { S, on } from "./state.js";
import { $, $$, avatar, initModals, toast, esc } from "./ui.js";
import { initI18n, applyDom, onLangChange, t } from "./i18n.js";
import { initLangUI, refreshLangLabels } from "./langui.js";
import { initAuthUI, showAuthPane, createProfile, errKey } from "./auth.js";
import { initPlay, warmServer, showDownloads } from "./play.js";
import { initHome, renderHome, loadStats } from "./games.js";
import { initFriends, startFriends, renderFriends, stopListeners } from "./friends.js";
import { initAlerts, startAlerts, renderAlerts, renderBadges } from "./alerts.js";
import { initSettings, showSection, renderAccount, renderSecurity, applyTheme, stopSettings } from "./settings.js";
import { registerDevice, startHeartbeat, stopHeartbeat, watchSelf } from "./devices.js";

const ROUTES = ["home", "friends", "alerts", "settings"];

function route() {
  if (!S.user) return;
  const parts = location.hash.replace(/^#\/?/, "").split("/");
  const r = ROUTES.includes(parts[0]) ? parts[0] : "home";
  $$(".view").forEach(v => { v.hidden = v.id !== "v-" + r; });
  $$("[data-route]").forEach(a => { const on = a.dataset.route === r; a.classList.toggle("on", on); if (on) a.setAttribute("aria-current", "page"); else a.removeAttribute("aria-current"); });
  $("#searchWrap").hidden = r !== "home";
  if (r === "home") renderHome();
  if (r === "friends") renderFriends();
  if (r === "alerts") renderAlerts();
  if (r === "settings") { renderAccount(); showSection(parts[1]); }
  document.title = `${t("nav_" + r)} · BlockTopia`;
  window.scrollTo(0, 0);
}

function paintUser() {
  const p = S.profile || {};
  $("#meAv").outerHTML = avatar(p.username, p.avatarColor, "sm", p.character).replace("<span", '<span id="meAv"');
  $("#meName").textContent = p.username || "";
  const u = auth.currentUser;
  $("#verifyBar").hidden = !u || u.emailVerified;
}

async function loadProfile(u) {
  try {
    const s = await F.getDoc(F.doc(db, "users", u.uid));
    if (s.exists()) return s.data();
    // Account made before profiles existed: give it a username so it can use the site.
    const stem = (u.email || "player").split("@")[0].replace(/[^A-Za-z0-9_]/g, "").slice(0, 14) || "player";
    for (let i = 0; i < 6; i++) {
      const name = stem.length < 3 ? stem + "000" : stem + (i ? Math.floor(Math.random() * 900 + 100) : "");
      try { await createProfile(u, name); return (await F.getDoc(F.doc(db, "users", u.uid))).data(); } catch (e) { if (e?.key !== "user_taken") break; }
    }
  } catch (e) { console.warn("profile", e); }
  return { username: (u.email || "player").split("@")[0], avatarColor: "#f4f4f2" };
}

async function enter(u) {
  S.user = u;
  S.profile = await loadProfile(u);
  if (S.profile.theme) applyTheme(S.profile.theme);
  $("#auth").hidden = true; $("#app").hidden = false;
  paintUser(); applyDom();
  startFriends(); startAlerts();
  warmServer(); loadStats();
  try {
    if ((await registerDevice()) === "revoked") { toast(t("revoked_msg"), "bad"); await A.signOut(auth); return; }
    S.stops.push(watchSelf(() => { toast(t("revoked_msg"), "bad"); A.signOut(auth); }));
    startHeartbeat();
  } catch (e) { console.warn("device", e); }
  if (!location.hash || location.hash === "#/") location.hash = "#/home";
  route();
}

function leave() {
  stopListeners(); stopHeartbeat(); stopSettings();
  S.user = null; S.profile = null; S.friends = new Map(); S.incoming = []; S.outgoing = new Set(); S.presence = new Map(); S.notifs = []; S.fprof = new Map();
  $("#app").hidden = true; $("#auth").hidden = false;
  $("#formLogin").reset(); $("#formSignup").reset(); $("#suMeter").style.width = "0";
  showAuthPane("login"); applyDom(); document.title = "BlockTopia";
  history.replaceState(null, "", location.pathname);
}

async function main() {
  await initI18n();
  initModals(); initLangUI(); initPlay(); initHome(); initFriends(); initAlerts(); initSettings();
  initAuthUI({ onSignedUp: async u => { await enter(u); } });

  onLangChange(() => { paintUser(); if (S.user) { renderBadges(); route(); if (!$("#v-settings").hidden) renderSecurity(); } refreshLangLabels(); });
  document.addEventListener("profilechange", paintUser);
  window.addEventListener("hashchange", route);
  window.addEventListener("focus", async () => { const u = auth.currentUser; if (u && !u.emailVerified) { try { await u.reload(); paintUser(); } catch {} } });
  $$("[data-logout]").forEach(b => { b.onclick = () => A.signOut(auth); });
  $("#getApp").onclick = showDownloads;
  $("#resend").onclick = () => A.sendEmailVerification(auth.currentUser).then(() => toast(t("sent_ok")), e => toast(t(errKey(e)), "bad"));

  A.onAuthStateChanged(auth, async u => {
    if (S.signingUp) return;
    if (u) await enter(u); else leave();
    $("#boot")?.remove();
  });
}
main().catch(e => { console.error(e); const m = document.getElementById("bootMsg"); if (m) m.hidden = false; });
