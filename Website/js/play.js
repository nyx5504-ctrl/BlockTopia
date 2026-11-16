// Play button: wake the server -> get a one-time launch code -> open blocktopia:// -> always end on a screen that can't be a dead end.
import { CONFIG } from "./config.js";
import { auth } from "./fb.js";
import { t } from "./i18n.js";
import { $, esc, icon, sleep, openModal, closeModal, toast } from "./ui.js";

const OS_NAME = { windows: "Windows", android: "Android", macos: "macOS", linux: "Linux", ios: "iOS" };
export function platform() {
  const ua = navigator.userAgent;
  if (/Android/.test(ua)) return "android";
  if (/iPhone|iPad|iPod/.test(ua) || (/Macintosh/.test(ua) && navigator.maxTouchPoints > 1)) return "ios";
  if (/Windows/.test(ua)) return "windows";
  if (/Mac/.test(ua)) return "macos";
  if (/Linux|X11/.test(ua)) return "linux";
  return "windows";
}
const base = () => (CONFIG.BACKEND_URL || "").replace(/\/+$/, "");

// The free host sleeps when idle. Poking it as soon as the user is logged in means it's awake by the time they press Play.
export function warmServer() { if (base()) fetch(base() + "/health", { cache: "no-store" }).catch(() => {}); }

let run = 0, timer = null;
const body = html => { $("#playBody").innerHTML = html; };
const modal = () => $("#playModal");
const spinner = (key, sub) => body(`<div class="spin"></div><p class="big">${esc(t(key))}</p>${sub ? `<p>${esc(t(sub))}</p>` : ""}<div class="play-actions"><button class="btn ghost" data-act="cancel" type="button">${esc(t("cancel"))}</button></div>`);
const fail = (msgKey, text, opts) => {
  clearInterval(timer);
  body(`${icon("alert", "")}<p class="big">${esc(text || t(msgKey))}</p><div class="play-actions"><button class="btn primary" data-act="retry" type="button">${esc(t("retry"))}</button><button class="btn" data-close type="button">${esc(t("close"))}</button></div>`);
  $("#playBody").dataset.opts = JSON.stringify(opts || {});
};

function downloadsHtml() {
  const p = platform(), D = CONFIG.DOWNLOADS || {};
  const one = k => D[k] ? `<a class="btn ${k === p ? "primary" : ""}" href="${esc(D[k])}" rel="noopener">${icon("download")} ${esc(t("dl_for", { os: OS_NAME[k] }))}</a>` : "";
  let main = "";
  if (p === "ios") main = `<p>${esc(t("ios_soon"))}</p>`;
  else main = one(p) || `<p>${esc(t("dl_missing", { os: OS_NAME[p] }))}</p>`;
  const others = ["windows", "android", "macos", "linux"].filter(k => k !== p && D[k]).map(one).join("");
  return `<div class="play-sep"><p>${esc(t("no_app"))}</p><div class="play-actions">${main}</div>${others ? `<details><summary>${esc(t("other_platforms"))}</summary>${others}</details>` : ""}</div>`;
}

function ready(link, opts) {
  clearInterval(timer);
  const p = platform(), mobile = p === "android" || p === "ios", end = Date.now() + 60000;
  body(`
    <p class="big">${esc(t("play_ready_title"))}</p>
    <p>${esc(t("play_ready_text"))}</p>
    <div class="play-actions" id="playMain">
      ${mobile ? "" : `<a class="btn primary play" id="openApp" href="${esc(link)}">${icon("play", "fill")} ${esc(t("open_app"))}</a>`}
      <button class="btn ${mobile ? "primary play" : ""}" data-act="copy" type="button">${icon("copy")} ${esc(t("copy_link"))}</button>
    </div>
    ${mobile ? `<p>${esc(t("mobile_steps"))}</p>` : ""}
    <span class="exp" id="playExp"></span>
    ${downloadsHtml()}`);
  $("#playBody").dataset.link = link; $("#playBody").dataset.opts = JSON.stringify(opts || {});
  const tick = () => {
    const s = Math.max(0, Math.round((end - Date.now()) / 1000)), e = $("#playExp");
    if (!e) return clearInterval(timer);
    if (s > 0) { e.textContent = t("expires", { s }); return; }
    clearInterval(timer);
    $("#playMain").innerHTML = `<button class="btn primary play" data-act="again" type="button">${esc(t("new_link"))}</button>`;
    e.textContent = "";
  };
  tick(); timer = setInterval(tick, 1000);
}

async function start(opts, my) {
  const B = base();
  if (!B) return fail("play_err_cfg", "", opts);
  spinner("play_wake");
  const t0 = Date.now(); let slow = false;
  for (;;) {                                       // wait until the server answers /health
    if (my !== run) return;
    try {
      const c = new AbortController(), to = setTimeout(() => c.abort(), 7000);
      const r = await fetch(B + "/health", { cache: "no-store", signal: c.signal }); clearTimeout(to);
      if (r.ok && (await r.json()).ok) break;
    } catch {}
    if (Date.now() - t0 > 90000) return fail("play_err_server", "", opts);
    if (!slow && Date.now() - t0 > 5000) { slow = true; spinner("play_wake", "play_wake_slow"); }
    await sleep(1500);
  }
  if (my !== run) return;
  spinner("play_prep");
  let token;
  try { token = await auth.currentUser.getIdToken(true); } catch { return fail("play_err_auth", "", opts); }
  let res, data = {};
  try {
    res = await fetch(B + "/launch", { method: "POST", headers: { "Content-Type": "application/json", Authorization: "Bearer " + token }, body: JSON.stringify({ game: "baseplate", ...(opts.joinUid ? { joinUid: opts.joinUid } : {}) }) });
    data = await res.json().catch(() => ({}));
  } catch { return fail("play_err_server", "", opts); }
  if (my !== run) return;
  if (res.status === 401) return fail("play_err_auth", "", opts);
  if (!res.ok || !data.code) return fail("err_generic", data.error, opts);
  const link = `blocktopia://play?game=baseplate&code=${encodeURIComponent(data.code)}&ws=${encodeURIComponent(data.ws)}`;
  ready(link, opts);
  // Browsers only allow opening an app right after a click. If the server was already awake this works; otherwise the big button does it.
  const p = platform();
  if (p !== "android" && p !== "ios" && Date.now() - t0 < 4000) location.href = link;
}

export function play(opts = {}) {
  const my = ++run;
  $("#playTitle").textContent = "BlockTopia";
  openModal(modal());
  start(opts, my);
}
export function showDownloads() {
  run++; clearInterval(timer);
  $("#playTitle").textContent = t("get_app");
  body(downloadsHtml());
  openModal(modal());
}

export function initPlay() {
  modal().addEventListener("modalclose", () => { run++; clearInterval(timer); });
  $("#playBody").addEventListener("click", async e => {
    const b = e.target.closest("[data-act]"); if (!b) return;
    const opts = JSON.parse($("#playBody").dataset.opts || "{}");
    if (b.dataset.act === "cancel") closeModal(modal());
    else if (b.dataset.act === "retry" || b.dataset.act === "again") { const my = ++run; start(opts, my); }
    else if (b.dataset.act === "copy") {
      const link = $("#playBody").dataset.link || "";
      try { await navigator.clipboard.writeText(link); }
      catch { const ta = document.createElement("textarea"); ta.value = link; document.body.appendChild(ta); ta.select(); try { document.execCommand("copy"); } catch {} ta.remove(); }
      toast(t("copied"));
    }
  });
}
