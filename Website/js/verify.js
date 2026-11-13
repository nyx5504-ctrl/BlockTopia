import { auth } from "./firebase-config.js";
import { onAuthStateChanged, sendEmailVerification, signOut } from "https://www.gstatic.com/firebasejs/10.14.1/firebase-auth.js";
import { icon } from "./ui-icons.js";
const $ = id => document.getElementById(id), esc = s => String(s).replace(/[<>&"']/g, "");
let cooling = 0, timer;
onAuthStateChanged(auth, user => {
  if (!user) return location.href = "../index.html";
  if (user.emailVerified) return location.href = "dashboard.html";
  $("view").innerHTML = `${icon("mail")}<h1>Check your inbox</h1><p>We sent a verification link to</p><span class="email-pill">${esc(user.email)}</span>
    <p style="margin-top:10px">Open it on any device, then come back. This page continues automatically. Don't see it? Check spam.</p>
    <button class="btn" id="chk">I've verified my email</button><button class="btn ghost full" id="re">Resend email</button><button class="link" id="out">Wrong account? Log out</button><div class="msg" id="msg"></div>`;
  const say = (t, ok) => { $("msg").textContent = t; $("msg").className = "msg " + (ok ? "ok" : "err"); };
  const check = async quiet => { await user.reload(); if (auth.currentUser.emailVerified) location.href = "dashboard.html"; else if (!quiet) say("Not verified yet. Open the link in the email, then try again."); };
  $("chk").onclick = () => check(false);
  $("re").onclick = async () => { try { await sendEmailVerification(user); say("Sent! Check your inbox.", true); cooling = 30; $("re").disabled = true;
      timer = setInterval(() => { cooling--; $("re").textContent = cooling > 0 ? `Resend in ${cooling}s` : "Resend email"; if (cooling <= 0) { $("re").disabled = false; clearInterval(timer); } }, 1000);
    } catch (e) { say(e.code === "auth/too-many-requests" ? "Too many requests. Wait a few minutes." : "Couldn't send. Try again shortly."); } };
  $("out").onclick = async () => { await signOut(auth); location.href = "../index.html"; };
  setInterval(() => check(true), 4000);
});
