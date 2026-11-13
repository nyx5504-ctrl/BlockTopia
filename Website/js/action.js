// Custom Firebase email-action page: verify email, reset password, recover email.
// Firebase Console > Authentication > Templates > (each template) > "Customize action URL" -> <your site>/pages/action.html
import { auth } from "./firebase-config.js";
import { applyActionCode, verifyPasswordResetCode, confirmPasswordReset, checkActionCode, sendPasswordResetEmail } from "https://www.gstatic.com/firebasejs/10.14.1/firebase-auth.js";
import { icon } from "./ui-icons.js";
const $ = id => document.getElementById(id), q = new URLSearchParams(location.search);
const mode = q.get("mode"), code = q.get("oobCode");
let next = "../index.html"; try { const c = new URL(q.get("continueUrl") || "", location.href); if (c.origin === location.origin) next = c.href; } catch {}
const view = html => { $("view").innerHTML = html; };
const fail = (title, msg) => view(`${icon("bad", "bad")}<h1>${title}</h1><p>${msg}</p><a class="btn" href="../index.html">Back to BlockTopia</a>`);
const why = e => ({ "auth/expired-action-code": "This link has expired. Request a new one and use it within an hour.", "auth/invalid-action-code": "This link was already used or isn't valid anymore.", "auth/user-disabled": "This account has been disabled.", "auth/user-not-found": "We couldn't find that account." })[e.code] || "Something went wrong. Please request a new link.";

async function verifyEmail() {
  try { await applyActionCode(auth, code); await auth.currentUser?.reload();
    view(`${icon("ok", "ok")}<h1>Email verified</h1><p>Your BlockTopia account is confirmed. You're all set.</p><a class="btn" href="${next}">Continue to BlockTopia</a>`);
  } catch (e) { fail("Couldn't verify your email", why(e)); }
}
async function resetPassword() {
  let email; try { email = await verifyPasswordResetCode(auth, code); } catch (e) { return fail("Reset link problem", why(e)); }
  view(`${icon("lock")}<h1>Choose a new password</h1><p>for <span class="email-pill">${email.replace(/[<>&"]/g, "")}</span></p>
    <form id="f" style="text-align:left"><label for="p1">New password</label><input id="p1" type="password" minlength="8" autocomplete="new-password" required><div class="meter"><i id="m"></i></div>
    <label for="p2">Confirm password</label><input id="p2" type="password" autocomplete="new-password" required><button class="btn" id="go">Save new password</button><div class="msg" id="msg"></div></form>`);
  $("p1").oninput = e => { const v = e.target.value; let s = Math.min(v.length / 12, 1) * 60 + (/[A-Z]/.test(v) ? 10 : 0) + (/\d/.test(v) ? 15 : 0) + (/[^A-Za-z0-9]/.test(v) ? 15 : 0);
    $("m").style.width = s + "%"; $("m").style.background = s < 40 ? "var(--err)" : s < 75 ? "#e8b33c" : "var(--ok)"; };
  $("f").onsubmit = async ev => { ev.preventDefault(); const m = $("msg"); m.className = "msg err";
    if ($("p1").value !== $("p2").value) return m.textContent = "Passwords don't match.";
    if ($("p1").value.length < 8) return m.textContent = "Use at least 8 characters.";
    $("go").disabled = true;
    try { await confirmPasswordReset(auth, code, $("p1").value);
      view(`${icon("ok", "ok")}<h1>Password updated</h1><p>You can now log in with your new password.</p><a class="btn" href="../index.html">Log in</a>`);
    } catch (e) { m.textContent = why(e); $("go").disabled = false; } };
}
async function recoverEmail() {
  try { const info = await checkActionCode(auth, code); const restored = info.data.email; await applyActionCode(auth, code);
    view(`${icon("ok", "ok")}<h1>Email restored</h1><p>Your account email is back to <span class="email-pill">${restored.replace(/[<>&"]/g, "")}</span>.</p><p>If you didn't make this change, reset your password now.</p>
      <button class="btn" id="rs">Email me a reset link</button><a class="btn ghost full" href="../index.html">Back to BlockTopia</a>`);
    $("rs").onclick = async () => { await sendPasswordResetEmail(auth, restored); $("rs").textContent = "Reset link sent"; $("rs").disabled = true; };
  } catch (e) { fail("Couldn't restore your email", why(e)); }
}
if (!code) fail("Nothing to do here", "This page is opened from the links in BlockTopia emails.");
else if (mode === "verifyEmail") verifyEmail(); else if (mode === "resetPassword") resetPassword(); else if (mode === "recoverEmail") recoverEmail();
else fail("Unknown link", "This email link isn't recognised.");
