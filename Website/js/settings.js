// Settings: Account (username, password, background), Security (devices), Privacy, Language.
import { auth, db, A, F } from "./fb.js";
import { S } from "./state.js";
import { $, $$, esc, icon, avatar, AVATAR_COLORS, safeColor, toast, busy } from "./ui.js";
import { t, fmtDate, fmtRel, countryName } from "./i18n.js";
import { watchDevices, revokeDevice, removeDevice } from "./devices.js";
import { errKey } from "./auth.js";
import { PALETTE, PART_DEFAULTS } from "./palette.js";
import { CONFIG } from "./config.js";

const SECTIONS = ["account", "security", "privacy", "language"];
let stopDevices = null, devices = [], blocks = [];

const save = patch => F.updateDoc(F.doc(db, "users", S.user.uid), patch).then(() => { Object.assign(S.profile, patch); return true; }).catch(() => { toast(t("err_generic"), "bad"); return false; });
const validHex = value => /^#[0-9a-f]{6}$/i.test(String(value || ""));
const clamp = (value, min, max, fallback) => Number.isFinite(Number(value)) ? Math.min(max, Math.max(min, Number(value))) : fallback;
const characterOf = p => {
  const c = p?.character || {}, legacySkin = validHex(c.bodyColor) ? c.bodyColor.toLowerCase() : "#f2c744", source = c.parts || {}, parts = {};
  for (const [name, base] of Object.entries(PART_DEFAULTS)) {
    const item = source[name] || {}, skinPart = ["head", "leftArm", "rightArm"].includes(name);
    parts[name] = { size: clamp(item.size, 0.7, 1.3, 1), color: validHex(item.color) ? item.color.toLowerCase() : skinPart ? legacySkin : base.color };
  }
  return { height: clamp(c.height, 0.75, 1.25, 1), bodyType: ["classic", "slim", "broad"].includes(c.bodyType) ? c.bodyType : "classic", bodyColor: parts.head.color, parts };
};
function readCharacterControls() {
  const parts = {};
  for (const name of Object.keys(PART_DEFAULTS)) parts[name] = {
    size: clamp(Number($('[data-part-size="' + name + '"]').value), 0.7, 1.3, 1),
    color: safeColor($('[data-part-color="' + name + '"]').value)
  };
  return { height: clamp(Number($("#characterHeight").value), 0.75, 1.25, 1), bodyType: $("#characterBodyType").value, bodyColor: parts.head.color, parts };
}
let rig = null, rigLoading = false;
// Loads the real R6 rig (same model the game uses). If WebGL or the model can't load, the flat SVG preview stays as the fallback.
function loadRig() {
  if (rig || rigLoading) return;
  const box = $("#characterPreview"); if (!box) return;
  rigLoading = true;
  import("./rig.bundle.js").then(m => m.createRig(box, "assets/roblox-r6.glb")).then(r => { rig = r; box.classList.add("is-3d"); paintCharacterPreview(); })
    .catch(() => { rigLoading = false; box.classList.remove("is-3d"); });
}
function paintCharacterPreview() {
  const c = readCharacterControls(), size = (part, base) => base * c.parts[part].size;
  $("#characterHeightValue").textContent = Math.round(c.height * 100) + "%";
  document.querySelectorAll("[data-size-value]").forEach(el => { el.textContent = Math.round(c.parts[el.dataset.sizeValue].size * 100) + "%"; });
  const bodyWidth = c.bodyType === "slim" ? 0.84 : c.bodyType === "broad" ? 1.16 : 1;
  const headW = size("head", 42), headH = size("head", 42), torsoW = size("torso", 50) * bodyWidth, torsoH = size("torso", 62);
  const leftArmW = size("leftArm", 20), leftArmH = size("leftArm", 58), rightArmW = size("rightArm", 20), rightArmH = size("rightArm", 58);
  const leftLegW = size("leftLeg", 22), leftLegH = size("leftLeg", 60), rightLegW = size("rightLeg", 22), rightLegH = size("rightLeg", 60);
  const yHead = 18, xTorso = 90 - torsoW / 2, yTorso = 67;
  const svg = '<svg viewBox="0 0 180 240" aria-hidden="true"><g transform="translate(0 240) scale(1 ' + c.height + ') translate(0 -240)">' +
    '<rect x="' + (58-leftArmW/2) + '" y="72" width="' + leftArmW + '" height="' + leftArmH + '" rx="3" fill="' + c.parts.leftArm.color + '"/>' +
    '<rect x="' + (122-rightArmW/2) + '" y="72" width="' + rightArmW + '" height="' + rightArmH + '" rx="3" fill="' + c.parts.rightArm.color + '"/>' +
    '<rect x="' + (78-leftLegW/2) + '" y="130" width="' + leftLegW + '" height="' + leftLegH + '" rx="2" fill="' + c.parts.leftLeg.color + '"/>' +
    '<rect x="' + (102-rightLegW/2) + '" y="130" width="' + rightLegW + '" height="' + rightLegH + '" rx="2" fill="' + c.parts.rightLeg.color + '"/>' +
    '<rect x="' + xTorso + '" y="' + yTorso + '" width="' + torsoW + '" height="' + torsoH + '" rx="4" fill="' + c.parts.torso.color + '"/>' +
    '<ellipse cx="90" cy="' + (yHead+headH/2) + '" rx="' + (headW/2) + '" ry="' + (headH/2) + '" fill="' + c.parts.head.color + '"/>' +
    '<ellipse cx="82" cy="' + (yHead+headH*.42) + '" rx="2.8" ry="4.5" fill="#111"/><ellipse cx="98" cy="' + (yHead+headH*.42) + '" rx="2.8" ry="4.5" fill="#111"/>' +
    '<path d="M78 ' + (yHead+headH*.62) + ' Q90 ' + (yHead+headH*.92) + ' 102 ' + (yHead+headH*.62) + '" fill="none" stroke="#111" stroke-width="2.4" stroke-linecap="round"/></g></svg>';
  if (rig) { rig.set(c); return; }
  $("#characterPreview").innerHTML = svg;
}
function syncSwatches() {
  $$("[data-swatch-for]").forEach(b => { const v = $('[data-part-color="' + b.dataset.swatchFor + '"]').value; b.style.setProperty("--c", v); });
}
let popFor = null;
function closePalette() { const pop = $("#palettePop"); if (pop) pop.hidden = true; popFor = null; }
function openPalette(btn) {
  const pop = $("#palettePop"), part = btn.dataset.swatchFor, cur = $('[data-part-color="' + part + '"]').value.toLowerCase();
  if (popFor === part && !pop.hidden) return closePalette();
  popFor = part;
  pop.innerHTML = PALETTE.map(c => '<button type="button" class="sw" role="option" style="--c:' + c + '" data-pick="' + c + '" aria-selected="' + (c === cur) + '" aria-label="' + c + '">' + icon("check") + '</button>').join("");
  const hb = $("#v-customize").getBoundingClientRect(), bb = btn.getBoundingClientRect();
  pop.hidden = false;
  const w = pop.offsetWidth; pop.style.top = (bb.bottom - hb.top + 8) + "px"; pop.style.left = Math.max(8, Math.min(bb.right - hb.left - w, hb.width - w - 8)) + "px";
}
function renderCustomization() {
  const c = characterOf(S.profile || {});
  $("#characterHeight").value = String(c.height);
  $("#characterBodyType").value = c.bodyType;
  for (const name of Object.keys(PART_DEFAULTS)) {
    $('[data-part-size="' + name + '"]').value = String(c.parts[name].size);
    $('[data-part-color="' + name + '"]').value = c.parts[name].color;
  }
  syncSwatches();
  paintCharacterPreview();
}
export function renderCustomize() { renderCustomization(); loadRig(); }

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
  if (id === "privacy") loadBlocks();
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
  $("#setName").textContent = p.username || "";
  $("#setUser").textContent = p.username || "";
  $("#setEmail").textContent = u.email || "";
  $("#setVerified").textContent = t(u.emailVerified ? "verified" : "unverified");
  $("#resend2").hidden = u.emailVerified;
  $("#descInput").value = S.profile?.description || "";
  $("#pwOpen").closest(".srow").hidden = !u.providerData.some(x => x.providerId === "password");   // Google-only accounts have no password to change
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

// If you're already in a game, the server updates your character for everyone (including you) the moment this arrives. Best effort: the Firestore save above is what makes it permanent.
async function pushToGame(character) {
  try {
    const token = await auth.currentUser.getIdToken();
    await fetch((CONFIG.BACKEND_URL || "").replace(/\/+$/, "") + "/profile", { method: "POST", headers: { "Content-Type": "application/json", Authorization: "Bearer " + token }, body: JSON.stringify({ character }) });
  } catch {}
}

// Blocked players (Privacy). The game server writes the list; the owner can read it and unblock here.
async function loadBlocks() {
  if (!S.user) return;
  try {
    const snap = await F.getDocs(F.collection(db, "blocks", S.user.uid, "list"));
    blocks = await Promise.all(snap.docs.map(async d => {
      try { const u = await F.getDoc(F.doc(db, "users", d.id)); return { id: d.id, ...(u.exists() ? u.data() : {}) }; } catch { return { id: d.id }; }
    }));
    blocks.sort((a, b) => String(a.username || "~").localeCompare(String(b.username || "~")));
  } catch { blocks = []; $("#blockList").innerHTML = `<p class="empty">${esc(t("err_generic"))}</p>`; return; }
  renderBlocks();
}
export function renderBlocks() {
  const box = $("#blockList"); if (!box) return;
  box.innerHTML = blocks.length ? blocks.map(b => `<div class="row"><div class="grow" style="display:flex;align-items:center;gap:12px">${avatar(b.username, b.avatarColor, "sm", b.character)}<div class="name">${esc(b.username || "?")}</div></div><button class="btn sm" data-unblock="${esc(b.id)}" type="button">${esc(t("unblock"))}</button></div>`).join("") : `<p class="empty">${esc(t("blocked_none"))}</p>`;
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
  const persistCharacter = async () => {
    const button = $("#saveCharacter"), status = $("#characterStatus"), character = readCharacterControls();
    busy(button, true, "Saving…"); status.textContent = "Saving customization…";
    if (await save({ character })) {
      renderAccount(); document.dispatchEvent(new Event("profilechange")); status.textContent = "Saved. Changes show up in game right away."; toast(t("saved"));
      pushToGame(character);
    } else status.textContent = "Couldn't save customization. Try again.";
    busy(button, false);
  };
  $("#resetCharacter").addEventListener("click", () => {
    $("#characterHeight").value = "1";
    $("#characterBodyType").value = "classic";
    for (const [name, defaults] of Object.entries(PART_DEFAULTS)) {
      $('[data-part-size="' + name + '"]').value = "1";
      $('[data-part-color="' + name + '"]').value = defaults.color;
    }
    syncSwatches(); paintCharacterPreview();
    persistCharacter();
  });
  $("#characterEditor").addEventListener("input", paintCharacterPreview);
  $("#characterEditor").addEventListener("click", e => { const b = e.target.closest("[data-swatch-for]"); if (b) openPalette(b); });
  $("#palettePop").addEventListener("click", e => {
    const b = e.target.closest("[data-pick]"); if (!b || !popFor) return;
    $('[data-part-color="' + popFor + '"]').value = b.dataset.pick; closePalette(); syncSwatches();
    $("#characterEditor").dispatchEvent(new Event("input")); $("#characterEditor").dispatchEvent(new Event("change"));
  });
  document.addEventListener("click", e => { if (!e.target.closest("#palettePop, [data-swatch-for]")) closePalette(); });
  document.addEventListener("keydown", e => { if (e.key === "Escape") closePalette(); });
  $("#characterEditor").addEventListener("change", persistCharacter);
  $("#saveCharacter").addEventListener("click", persistCharacter);
  // privacy
  $("#selReq").onchange = async e => { if (await save({ allowRequests: e.target.value })) toast(t("saved")); };
  $("#selJoin").onchange = async e => { if (await save({ allowJoin: e.target.value })) toast(t("saved")); };
  // theme
  $$("[data-theme-pick]").forEach(b => {
    b.onclick = async () => { applyTheme(b.dataset.themePick); if (await save({ theme: b.dataset.themePick })) toast(t("saved")); };
  });
  // devices
  $("#descSave").addEventListener("click", async () => {      // saved through the server so the description is filtered like chat
    const btn = $("#descSave"); $("#descErr").textContent = ""; busy(btn, true, t("busy"));
    try {
      const r = await fetch((CONFIG.BACKEND_URL || "").replace(/\/+$/, "") + "/profile", { method: "POST", headers: { "Content-Type": "application/json", Authorization: "Bearer " + await auth.currentUser.getIdToken() }, body: JSON.stringify({ description: $("#descInput").value }) });
      const data = await r.json().catch(() => ({}));
      if (!r.ok) { $("#descErr").textContent = data.error || t("err_generic"); return; }
      S.profile.description = data.profile?.description || ""; toast(t("desc_saved"));
    } catch { $("#descErr").textContent = t("err_generic"); }
    finally { busy(btn, false); }
  });
  $("#blockList").addEventListener("click", async e => {
    const b = e.target.closest("[data-unblock]"); if (!b) return;
    try { await F.deleteDoc(F.doc(db, "blocks", S.user.uid, "list", b.dataset.unblock)); blocks = blocks.filter(x => x.id !== b.dataset.unblock); renderBlocks(); toast(t("unblocked_ok")); }
    catch { toast(t("err_generic"), "bad"); }
  });
  $("#devList").addEventListener("click", async e => {
    const o = e.target.closest("[data-dev-out]"), r = e.target.closest("[data-dev-remove]");
    try {
      if (o) { await revokeDevice(o.dataset.devOut); toast(t("dev_signed_out")); }
      if (r) await removeDevice(r.dataset.devRemove);
    } catch { toast(t("err_generic"), "bad"); }
  });
}

export function stopSettings() { stopDevices?.(); stopDevices = null; devices = []; blocks = []; }
