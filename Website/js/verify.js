// "Verify your email" pop-up: the link must be opened within 35 seconds. The server keeps the clock (Backend /verify/*) and revokes
// a verification that arrives late, so an old link can't be used afterwards. Resolves true when verified, false if the user goes back.
import { auth, A } from "./fb.js";
import { $ } from "./ui.js";
import { CONFIG } from "./config.js";
import { t } from "./i18n.js";

const base = () => (CONFIG.BACKEND_URL || "").replace(/\/+$/, "");
async function call(user, path) {
  try {
    const r = await fetch(base() + path, { method: "POST", headers: { "Content-Type": "application/json", Authorization: "Bearer " + await user.getIdToken() }, body: "{}" });
    return r.ok ? await r.json() : null;
  } catch { return null; }
}

export async function ensureVerified(user) {
  try { await user.reload(); } catch { /* offline: use what we have */ }
  const st = (await call(user, "/verify/check"))?.status;
  if (st === "verified" || (!st && user.emailVerified)) return true;
  return runGate(user);
}

function runGate(user) {
  return new Promise(resolve => {
    const ov = $("#verifyOverlay"), ring = $("#vfRing"), C = 2 * Math.PI * 52;
    let state = "sending", end = 0, total = 35000, tick = 0, poll = 0, busyPoll = false;
    ring.style.strokeDasharray = String(C);
    const show = (cls, key, vars) => { const s = $("#vfState"); s.className = "vf-state " + cls; s.textContent = key ? t(key, vars) : ""; };
    const done = ok => { clearInterval(tick); clearInterval(poll); ov.hidden = true; document.body.classList.remove("noscroll"); resolve(ok); };
    const expire = () => {
      if (state === "expired") return;
      state = "expired"; clearInterval(poll); $("#vfNum").textContent = "0"; ring.style.strokeDashoffset = String(C);
      $("#vfResend").hidden = false; $("#vfResend").disabled = false; show("bad", "vf_expired");
    };
    const render = () => {
      if (state !== "wait") return;
      const left = Math.max(0, end - performance.now());
      $("#vfNum").textContent = String(Math.ceil(left / 1000)); ring.style.strokeDashoffset = String(C * (1 - left / total));
      if (left <= 0) expire();
    };
    const checkNow = async () => {
      if (busyPoll || state !== "wait") return; busyPoll = true;
      const st = (await call(user, "/verify/check"))?.status; busyPoll = false;
      if (state !== "wait") return;
      if (st === "verified") { try { await user.reload(); await user.getIdToken(true); } catch { /* ignore */ } done(true); }
      else if (st === "expired") expire();
    };
    const start = async () => {
      state = "sending"; $("#vfResend").hidden = true; $("#vfNum").textContent = "…"; ring.style.strokeDashoffset = String(C * 0.0); show("", "vf_sending");
      try { await A.sendEmailVerification(user); }
      catch (e) { state = "expired"; $("#vfResend").hidden = false; show("bad", e?.code === "auth/too-many-requests" ? "err_many" : "vf_send_fail"); return; }
      const w = await call(user, "/verify/start");
      if (!w) { state = "expired"; $("#vfResend").hidden = false; show("bad", "err_network"); return; }
      total = w.remainingMs || 35000; end = performance.now() + total; state = "wait"; show("", "vf_waiting");
      clearInterval(tick); clearInterval(poll); tick = setInterval(render, 250); poll = setInterval(checkNow, 1500); render();
    };
    $("#vfMail").textContent = user.email || "";
    $("#vfResend").onclick = start;
    $("#vfBack").onclick = async () => { try { await A.signOut(auth); } catch { /* ignore */ } done(false); };
    ov.hidden = false; document.body.classList.add("noscroll");
    start();
  });
}
