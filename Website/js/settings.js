// Settings: Account (username, password, background), Security (devices), Privacy, Language.
import { auth, db, A, F } from "./fb.js";
import { S } from "./state.js";
import { $, $$, esc, icon, avatar, AVATAR_COLORS, safeColor, toast, busy } from "./ui.js";
import { t, fmtDate, fmtRel, countryName } from "./i18n.js";
import { watchDevices, revokeDevice, removeDevice } from "./devices.js";
import { errKey } from "./auth.js";

const SECTIONS = ["account", "security", "privacy", "language"];
let stopDevices = null, devices = [];

const save = patch => F.updateDoc(F.doc(db, "users", S.user.uid), patch).then(() => { Object.assign(S.profile, patch); return true; }).catch(() => { toast(t("err_generic"), "bad"); return false; });
const characterOf = p => { const c = p?.character || {}; return { height: Math.min(1.25, Math.max(0.75, Number(c.height) || 1)), bodyType: ["classic", "slim", "broad"].includes(c.bodyType) ? c.bodyType : "classic", bodyColor: safeColor(c.bodyColor || "#f2c744") }; };
function readCharacterControls() { return { height: Number($("#characterHeight").value), bodyType: $("#characterBodyType").value, bodyColor: safeColor($("#characterBodyColor").value) }; }
function paintCharacterPreview() { const c = readCharacterControls(); $("#characterHeightValue").textContent = Math.round(c.height * 100) + "%"; $("#characterPreview").innerHTML = avatar(S.profile?.username, S.profile?.avatarColor, "lg", c); }

export function applyTheme(theme) {
  const th = theme === "light" ? "light" : "dark";
  document.documentElement.dataset.theme = th;
  try { localStorage.setItem("bt_theme", th); } catch {}
  document.querySelector('meta[name="theme-color"]').content = th === "light" ? "#f1f1ef" : "#0c0c0e";
  $$("[data-theme-pick]").forEach(b => b.setAttribute("aria-checked", String(b.dataset.themePick === th)));
}

export function showSection(id) {
  if (!SECTIONS.includes(id)) id = "account";
  $$("[data-sec]").forEach(b => b.setAttribute("aria-selected", String(b.dataset.sec === id)));
  $$("[data-panel]").forEach(p => { p.hidden = p.dataset.panel !== id; });
  if (id === "security") startDevices(); else { stopDevices?.(); stopDevices = null; }
  if (location.hash !== "#/settings/" + id) history.replaceState(null, "", "#/settings/" + id);
}

function startDevices() {
  if (stopDevices) return;
  stopDevices = watchDevices(list => { devices = list; renderSecurity(); });
}

export function renderAccount() {
  const p = S.profile || {}, u = auth.currentUser; if (!u) return;
  const character = characterOf(p);
  $("#setAv").outerHTML = avatar(p.username, p.avatarColor, "lg", character).replace("<span", '<span id="setAv"');
  $("#characterHeight").value = String(character.height);
  $("#characterBodyType").value = character.bodyType;
  $("#characterBodyColor").value = character.bodyColor;
  paintCharacterPreview();
  $("#setName").textContent = p.username || "";
  $("#setUser").textContent = p.username || "";
  $("#setEmail").textContent = u.email || "";
  $("#setVerified").textContent = t(u.emailVerified ? "verified" : "unverified");
  $("#resend2").hidden = u.emailVerified;
  const cur = safeColor(p.avatarColor);
  $("#swatches").innerHTML = AVATAR_COLORS.map(c => `<button class="sw" type="button" role="radio" style="--c:${c}" data-color="${c}" aria-checked="${c === cur}" aria-label="${c}">${icon("check")}</button>`).join("");
  $("#selReq").value = p.allowRequests === "none" ? "none" : "everyone";
  $("#selJoin").value = p.allowJoin === "nobody" ? "nobody" : "friends";
  applyTheme(document.documentElement.dataset.theme);
}

export function renderSecurity() {
  const u = auth.currentUser; if (!u) return;
  $("#tDevices").textContent = devices.filter(d => !d.revoked).length;
  $("#tCreated").textContent = fmtDate(Date.parse(u.metadata?.creationTime || "") || 0);
  $("#tSignin").textContent = fmtDate(Date.parse(u.metadata?.lastSignInTime || "") || 0);
  $("#devList").innerHTML = devices.length ? devices.map(d => {
    const me = d.id === S.deviceId, icn = d.type === "desktop" ? "monitor" : "phone";
    const live = !d.revoked && Date.now() - d.lastMs < 180e3;
    const where = `${countryName(d.country)} · ${d.revoked ? t("dev_revoked") : live ? t("active_now") : t("last_active_at", { when: fmtRel(d.lastMs, false) })}`;
    const act = me ? `<span class="tag">${esc(t("this_device"))}</span>`
      : d.revoked ? `<button class="btn ghost sm" data-dev-remove="${esc(d.id)}" type="button">${esc(t("remove"))}</button>`
      : `<button class="btn sm" data-dev-out="${esc(d.id)}" type="button">${esc(t("sign_out_dev"))}</button>`;
    return `<div class="row dev"><span class="ic-box">${icon(icn)}</span><div class="grow"><div class="name">${esc(d.name || "?")}</div><div class="sub">${esc(where)}</div><div class="sub">${esc(t("first_seen", { date: fmtDate(d.firstMs) }))}</div></div><div class="btns">${act}</div></div>`;
  }).join("") : `<p class="empty">…</p>`;
}

export function initSettings() {
  $$("[data-sec]").forEach(b => { b.onclick = () => showSection(b.dataset.sec); });

  // password
  const form = $("#pwForm");
  $("#pwOpen").onclick = () => { form.hidden = !form.hidden; if (!form.hidden) $("#pwCur").focus(); };
  $("#pwCancel").onclick = () => { form.hidden = true; form.reset(); $("#pwErr").textContent = ""; };
  form.addEventListener("submit", async e => {
    e.preventDefault();
    const cur = $("#pwCur").value, nw = $("#pwNew").value, conf = $("#pwConf").value, err = k => { $("#pwErr").textContent = k ? t(k) : ""; }, btn = form.querySelector("[type=submit]");
    if (!cur || !nw || !conf) return err("err_required");
    if (nw.length < 8) return err("err_weak");
    if (nw !== conf) return err("err_pw_match");
    err(""); busy(btn, true, t("busy"));
    try {
      const u = auth.currentUser;
      await A.reauthenticateWithCredential(u, A.EmailAuthProvider.credential(u.email, cur));
      await A.updatePassword(u, nw);
      form.hidden = true; form.reset(); toast(t("pw_saved"));
    } catch (e2) { err(["auth/wrong-password", "auth/invalid-credential", "auth/invalid-login-credentials"].includes(e2?.code) ? "err_pw_current" : errKey(e2)); }
    finally { busy(btn, false); }
  });

  $("#resend2").onclick = () => A.sendEmailVerification(auth.currentUser).then(() => toast(t("sent_ok")), e => toast(t(errKey(e)), "bad"));

  // Character controls preview locally and save the shared profile for web and app.
  $("#characterEditor").addEventListener("input", paintCharacterPreview);
  $("#characterEditor").addEventListener("change", async () => {
    const character = readCharacterControls();
    if (await save({ character })) {
      renderAccount(); document.dispatchEvent(new Event("profilechange")); toast(t("saved"));
    }
  });
  // Outfit color
  $("#swatches").addEventListener("click", async e => {
    const b = e.target.closest("[data-color]"); if (!b) return;
    if (await save({ avatarColor: b.dataset.color })) { renderAccount(); document.dispatchEvent(new Event("profilechange")); toast(t("saved")); }
  });
  // privacy
  $("#selReq").onchange = async e => { if (await save({ allowRequests: e.target.value })) toast(t("saved")); };
  $("#selJoin").onchange = async e => { if (await save({ allowJoin: e.target.value })) toast(t("saved")); };
  // theme
  $$("[data-theme-pick]").forEach(b => {
    b.onclick = async () => { applyTheme(b.dataset.themePick); if (await save({ theme: b.dataset.themePick })) toast(t("saved")); };
  });
  // devices
  $("#devList").addEventListener("click", async e => {
    const o = e.target.closest("[data-dev-out]"), r = e.target.closest("[data-dev-remove]");
    try {
      if (o) { await revokeDevice(o.dataset.devOut); toast(t("dev_signed_out")); }
      if (r) await removeDevice(r.dataset.devRemove);
    } catch { toast(t("err_generic"), "bad"); }
  });
}

export function stopSettings() { stopDevices?.(); stopDevices = null; devices = []; }
