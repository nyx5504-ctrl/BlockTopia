import { auth, db } from "./firebase-config.js";
import { EmailAuthProvider, reauthenticateWithCredential, updatePassword, sendPasswordResetEmail, sendEmailVerification, signOut } from "https://www.gstatic.com/firebasejs/10.14.1/firebase-auth.js";
import { doc, updateDoc } from "https://www.gstatic.com/firebasejs/10.14.1/firebase-firestore.js";
import { $, esc, toast, shell, ready, COLORS } from "./common.js";
shell("settings", "Settings");
const { user, profile: p } = await ready;
const sel = (id, val, opts) => `<select id="${id}">${opts.map(([v,n]) => `<option value="${v}" ${v===val?"selected":""}>${n}</option>`).join("")}</select>`;
let color = p.avatarColor || COLORS[0];
$("page").innerHTML = `
<div class="sec"><h3>Account</h3><label>Username</label><input value="${esc(p.username)}" disabled><label>Email ${user.emailVerified ? "(verified)" : "(not verified)"}</label><input value="${esc(user.email)}" disabled>
<label>Avatar color</label><div class="swatches" id="sw">${COLORS.map(c => `<i data-c="${c}" class="${c===color?"on":""}" style="background:${c}"></i>`).join("")}</div>
<button class="btn" id="saveAcc" style="margin-top:14px">Save</button></div>
<div class="sec"><h3>Change password</h3><label>Current password</label><input id="cur" type="password" autocomplete="current-password"><label>New password (8+ characters)</label><input id="nw" type="password" autocomplete="new-password"><button class="btn" id="chg" style="margin-top:14px">Change password</button><div class="msg" id="pm"></div></div>
<div class="sec"><h3>Privacy</h3><label>Profile visibility</label>${sel("vis", p.profileVisibility||"public", [["public","Everyone"],["friends","Friends only"]])}
<label>Who can send friend requests</label>${sel("req", p.allowRequests||"everyone", [["everyone","Everyone"],["none","No one"]])}
<label>Who can join me in games</label>${sel("join", p.allowJoin||"friends", [["friends","Friends"],["nobody","Nobody"]])}<button class="btn" id="savePriv" style="margin-top:14px">Save</button></div>
<div class="sec"><h3>Notifications</h3><label class="chk"><input type="checkbox" id="nf" ${p.notifFriendRequests!==false?"checked":""}>Friend request notifications</label><button class="btn" id="saveN" style="margin-top:14px">Save</button></div>
<div class="sec"><h3>Security</h3>${user.emailVerified ? "" : `<button class="btn ghost" id="ver">Resend verification email</button> `}<button class="btn ghost" id="rst">Email me a password reset link</button><br><br><button class="btn" id="out">Log out</button></div>`;
const save = async (data, msg="Saved.") => { try { await updateDoc(doc(db,"users",user.uid), data); toast(msg); } catch(e){ toast("Couldn't save: " + e.message); } };
$("sw").onclick = e => { if (!e.target.dataset.c) return; color = e.target.dataset.c; $("sw").querySelectorAll("i").forEach(i => i.classList.toggle("on", i.dataset.c === color)); };
$("saveAcc").onclick = () => save({ avatarColor: color });
$("savePriv").onclick = () => save({ profileVisibility:$("vis").value, allowRequests:$("req").value, allowJoin:$("join").value });
$("saveN").onclick = () => save({ notifFriendRequests: $("nf").checked });
$("chg").onclick = async () => { const m = $("pm"); m.className = "msg err";
  if ($("nw").value.length < 8) return m.textContent = "New password must be 8+ characters.";
  try { await reauthenticateWithCredential(user, EmailAuthProvider.credential(user.email, $("cur").value)); await updatePassword(user, $("nw").value); m.className = "msg ok"; m.textContent = "Password changed."; $("cur").value = $("nw").value = ""; }
  catch(e){ m.textContent = e.code === "auth/invalid-credential" || e.code === "auth/wrong-password" ? "Current password is wrong." : e.message; } };
$("ver")?.addEventListener("click", async () => { await sendEmailVerification(user).catch(()=>toast("Try again in a minute.")); toast("Verification email sent."); });
$("rst").onclick = async () => { await sendPasswordResetEmail(auth, user.email); toast("Reset link sent."); };
$("out").onclick = async () => { await signOut(auth); location.href = "../index.html"; };
