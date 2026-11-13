import { auth, db } from "./firebase-config.js";
import { createUserWithEmailAndPassword, signInWithEmailAndPassword, sendEmailVerification, sendPasswordResetEmail, onAuthStateChanged, setPersistence, browserLocalPersistence, deleteUser }
  from "https://www.gstatic.com/firebasejs/10.14.1/firebase-auth.js";
import { doc, runTransaction, serverTimestamp } from "https://www.gstatic.com/firebasejs/10.14.1/firebase-firestore.js";

const $ = id => document.getElementById(id);
let mode = "login", busy = false;
await setPersistence(auth, browserLocalPersistence); // persistent sessions
onAuthStateChanged(auth, u => { if (u && !busy) location.href = "pages/dashboard.html"; });

function say(t, ok){ const e=$("msg"); e.textContent=t; e.className="msg "+(t?(ok?"ok":"err"):""); }
function setMode(m){
  mode = m; $("tLogin").classList.toggle("on", m==="login"); $("tSign").classList.toggle("on", m==="signup");
  $("fUser").classList.toggle("hide", m!=="signup"); $("go").textContent = m==="login" ? "Log in" : "Create account";
  $("forgot").classList.toggle("hide", m!=="login"); $("password").autocomplete = m==="login" ? "current-password" : "new-password"; say("");
}
$("tLogin").onclick = () => setMode("login"); $("tSign").onclick = () => setMode("signup");

const errs = {"auth/invalid-credential":"Wrong email or password.","auth/email-already-in-use":"That email is already registered.","auth/weak-password":"Password must be at least 8 characters.","auth/invalid-email":"Enter a valid email.","auth/too-many-requests":"Too many attempts. Try again later.","auth/operation-not-allowed":"Email/Password sign-in isn't enabled in Firebase yet."};
const friendly = e => errs[e.code] || e.message || "Something went wrong.";

$("forgot").onclick = async () => {
  const email = $("email").value.trim(); if (!email) return say("Type your email first, then click Forgot password.");
  try { await sendPasswordResetEmail(auth, email); say(`If ${email} has an account, a reset link is on its way. Check your spam folder too.`, true); } catch(e){ say(friendly(e)); }
};

$("form").onsubmit = async ev => {
  ev.preventDefault(); const email=$("email").value.trim(), pw=$("password").value; busy = true; $("go").disabled = true; say("");
  try {
    if (mode==="login") { await signInWithEmailAndPassword(auth, email, pw); location.href="pages/dashboard.html"; return; }
    const name = $("username").value.trim();
    if (!/^[A-Za-z0-9_]{3,20}$/.test(name)) throw {message:"Username: 3-20 letters, numbers or underscore."};
    const cred = await createUserWithEmailAndPassword(auth, email, pw);
    try {
      await runTransaction(db, async tx => { // unique username reservation
        const ref = doc(db, "usernames", name.toLowerCase());
        if ((await tx.get(ref)).exists()) throw {message:"That username is taken."};
        tx.set(ref, {uid: cred.user.uid});
        tx.set(doc(db, "users", cred.user.uid), {username:name, usernameLower:name.toLowerCase(), bio:"", favorites:[], recentGames:[], createdAt:serverTimestamp()});
      });
    } catch(e){ await deleteUser(cred.user); throw e; }
    await sendEmailVerification(cred.user, { url: location.origin + location.pathname.replace(/index\.html$/, "") + "pages/dashboard.html" }).catch(() => {});
    location.href = "pages/verify.html";
  } catch(e){ say(friendly(e)); busy = false; $("go").disabled = false; }
};
setMode("login");
