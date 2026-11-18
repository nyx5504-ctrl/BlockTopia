// Log in / sign up / password reset screen.
import { auth, db, A, F } from "./fb.js";
import { S } from "./state.js";
import { $, $$, busy } from "./ui.js";
import { t } from "./i18n.js";
import { CONFIG } from "./config.js";

const USER_RE = /^[A-Za-z0-9_]{3,20}$/;
const CODES = {
  "auth/invalid-credential": "err_login", "auth/wrong-password": "err_login", "auth/user-not-found": "err_login", "auth/invalid-login-credentials": "err_login",
  "auth/email-already-in-use": "err_email_used", "auth/weak-password": "err_weak", "auth/invalid-email": "err_email",
  "auth/too-many-requests": "err_many", "auth/network-request-failed": "err_network", "auth/missing-password": "err_required",
};
export class AppErr extends Error { constructor(key) { super(key); this.key = key; } }
export const errKey = e => e?.key || CODES[e?.code] || "err_generic";
const setErr = (sel, key) => { $(sel).textContent = key ? t(key) : ""; };

export function showAuthPane(name) {   // login | signup | forgot | sent
  for (const [id, n] of [["formLogin", "login"], ["formSignup", "signup"], ["formForgot", "forgot"], ["formSent", "sent"]]) $("#" + id).hidden = n !== name;
  $("#authTabs").hidden = name === "forgot" || name === "sent";
  $("#tabLogin").classList.toggle("on", name === "login");
  $("#tabSignup").classList.toggle("on", name === "signup");
  $$(".err").forEach(e => { e.textContent = ""; });
}

export async function createProfile(user, username) {
  const lower = username.toLowerCase();
  await F.runTransaction(db, async tx => {
    const ref = F.doc(db, "usernames", lower);
    if ((await tx.get(ref)).exists()) throw new AppErr("user_taken");
    tx.set(ref, { uid: user.uid });
    tx.set(F.doc(db, "users", user.uid), {
      username, usernameLower: lower, avatarColor: "#f4f4f2", allowRequests: "everyone", allowJoin: "friends",
      recentGames: [], favorites: [], createdAt: F.serverTimestamp(),
    });
  });
}

export function initAuthUI({ onSignedUp }) {
  $("#tabLogin").onclick = () => showAuthPane("login");
  $("#tabSignup").onclick = () => showAuthPane("signup");
  $("#toForgot").onclick = () => { const value = $("#liEmail").value.trim(); $("#fgEmail").value = value.includes("@") ? value : ""; showAuthPane("forgot"); };
  $$("[data-back-login]").forEach(b => { b.onclick = () => showAuthPane("login"); });
  $$("[data-eye]").forEach(b => {
    b.onclick = () => {
      const inp = b.parentElement.querySelector("input"), show = inp.type === "password";
      inp.type = show ? "text" : "password";
      b.querySelector("use").setAttribute("href", show ? "#i-eyeoff" : "#i-eye");
      b.setAttribute("aria-label", t(show ? "hide_pw" : "show_pw"));
    };
  });

  // --- log in ---
  $("#formLogin").addEventListener("submit", async e => {
    e.preventDefault();
    const identifier = $("#liEmail").value.trim(), pw = $("#liPw").value, btn = $("#liBtn");
    if (!identifier || !pw) return setErr("#liErr", "err_required");
    setErr("#liErr"); busy(btn, true, t("busy"));
    try {
      await A.setPersistence(auth, $("#liRemember").checked ? A.browserLocalPersistence : A.browserSessionPersistence);
      if (identifier.includes("@")) {
        await A.signInWithEmailAndPassword(auth, identifier, pw);
      } else {
        let response;
        try {
          response = await fetch(CONFIG.BACKEND_URL + "/auth/username", {
            method: "POST", headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ username: identifier, password: pw })
          });
        } catch { throw new AppErr("err_network"); }
        const result = await response.json().catch(() => ({}));
        if (!response.ok || !result.customToken) throw new AppErr(response.status === 429 ? "err_many" : response.status >= 500 ? "err_network" : "err_login");
        await A.signInWithCustomToken(auth, result.customToken);
      }
    } catch (err) { setErr("#liErr", errKey(err)); }
    finally { busy(btn, false); }
  });

  // --- sign up ---
  let chk = 0, nameOk = false;
  const hint = (key, cls, vars) => { const h = $("#suUserHint"); h.textContent = t(key, vars); h.className = "hint " + (cls || ""); };
  $("#suUser").addEventListener("input", () => {
    const v = $("#suUser").value.trim(), my = ++chk; nameOk = false;
    if (!v) return hint("username_hint");
    if (!USER_RE.test(v)) return hint("user_bad", "bad");
    hint("username_hint");
    setTimeout(async () => {
      if (my !== chk) return;
      try {
        const taken = (await F.getDoc(F.doc(db, "usernames", v.toLowerCase()))).exists();
        if (my !== chk) return;
        nameOk = !taken; taken ? hint("user_taken", "bad") : hint("user_ok", "ok", { name: v });
      } catch { /* offline: the server rules still protect uniqueness */ }
    }, 350);
  });
  $("#suPw").addEventListener("input", () => {
    const v = $("#suPw").value; let s = 0;
    if (v.length >= 8) s++; if (v.length >= 12) s++; if (/[A-Z]/.test(v) && /[a-z]/.test(v)) s++; if (/\d/.test(v) && /[^A-Za-z0-9]/.test(v)) s++;
    const m = $("#suMeter"); m.style.width = (v ? 25 * Math.max(1, s) : 0) + "%"; m.style.background = ["", "var(--danger)", "#ffb347", "var(--ok)", "var(--ok)"][Math.max(1, s)] || "";
  });
  $("#formSignup").addEventListener("submit", async e => {
    e.preventDefault();
    const username = $("#suUser").value.trim(), email = $("#suEmail").value.trim(), pw = $("#suPw").value, btn = $("#suBtn");
    if (!username || !email || !pw) return setErr("#suErr", "err_required");
    if (!USER_RE.test(username)) return setErr("#suErr", "user_bad");
    if (pw.length < 8) return setErr("#suErr", "err_weak");
    setErr("#suErr"); busy(btn, true, t("busy")); S.signingUp = true;
    let created = null;
    try {
      if ((await F.getDoc(F.doc(db, "usernames", username.toLowerCase()))).exists()) throw new AppErr("user_taken");
      await A.setPersistence(auth, A.browserLocalPersistence);
      created = await A.createUserWithEmailAndPassword(auth, email, pw);
      try { await createProfile(created.user, username); }
      catch (err) { await created.user.delete().catch(() => {}); created = null; throw err; }
      A.sendEmailVerification(created.user).catch(() => {});
      S.signingUp = false;
      await onSignedUp(created.user);
    } catch (err) { S.signingUp = false; setErr("#suErr", errKey(err)); }
    finally { S.signingUp = false; busy(btn, false); }
  });

  // --- forgot password ---
  $("#formForgot").addEventListener("submit", async e => {
    e.preventDefault();
    const email = $("#fgEmail").value.trim(), btn = $("#fgBtn");
    if (!email) return setErr("#fgErr", "err_required");
    setErr("#fgErr"); busy(btn, true, t("busy"));
    try {
      await A.sendPasswordResetEmail(auth, email);
    } catch (err) {
      if (err?.code !== "auth/user-not-found") { setErr("#fgErr", errKey(err)); busy(btn, false); return; }   // don't reveal which emails exist
    }
    busy(btn, false);
    $("#sentText").textContent = t("sent_reset", { email });
    showAuthPane("sent");
  });
}
