import { db } from "./firebase-config.js";
import { doc, getDoc, updateDoc, collection, getCountFromServer } from "https://www.gstatic.com/firebasejs/10.14.1/firebase-firestore.js";
import { $, esc, toast, shell, ready, avatar, isOnline, fmtTime, sendFriendRequest } from "./common.js";
import { GAMES } from "./games.js";
shell("profile", "Profile");
const { user: me, profile: mine } = await ready;
const name = new URLSearchParams(location.search).get("u");
let uid = me.uid;
if (name && name.toLowerCase() !== mine.username?.toLowerCase()) {
  const n = await getDoc(doc(db,"usernames",name.toLowerCase()));
  if (!n.exists()) { $("page").innerHTML = `<div class="empty">User "${esc(name)}" not found.</div>`; throw 0; }
  uid = n.data().uid;
}
const self = uid === me.uid;
const [u, st, pr, isFriend, fc] = await Promise.all([
  getDoc(doc(db,"users",uid)).then(s => s.data()), getDoc(doc(db,"stats",uid)).then(s => s.data() || {}), getDoc(doc(db,"presence",uid)).then(s => s.exists() ? s.data() : null),
  getDoc(doc(db,"friends",me.uid,"list",uid)).then(s => s.exists()), getCountFromServer(collection(db,"friends",uid,"list")).then(s => s.data().count) ]);
const hidden = !self && !isFriend && u.profileVisibility === "friends";
const on = isOnline(pr);
const ach = [["First Steps", (st.playtime||0) >= 60], ["Regular", (st.playtime||0) >= 3600], ["Veteran", (st.playtime||0) >= 36000], ["Chatterbox", (st.messages||0) >= 50], ["Social", fc >= 1]].filter(a => a[1]).map(a => a[0]);
const recent = (u.recentGames||[]).map(id => GAMES.find(g => g.id === id)?.name).filter(Boolean);
$("page").innerHTML = `<div class="sec" style="max-width:720px"><div style="display:flex;gap:16px;align-items:center">${avatar(u.username,u.avatarColor,72)}<div class="grow"><h2 style="margin:0;color:var(--text);text-transform:none;font-size:22px">${esc(u.username)}</h2>
<span class="sub"><span class="dot ${on?"on":""}"></span>${hidden ? "" : on ? (pr.game ? "Playing " + esc(pr.game) : "Online") : "Offline"}</span></div>
${self ? "" : isFriend ? `<span class="sub">Friends</span>` : `<button class="btn ghost" id="add">Add friend</button>`}</div>
${hidden ? `<p class="sub">This profile is only visible to friends.</p>` : `
<p id="bio">${esc(u.bio || (self ? "Add a description in the box below." : "No description."))}</p>
${self ? `<textarea id="bioIn" maxlength="160" rows="2" placeholder="Describe yourself (160 chars)">${esc(u.bio||"")}</textarea><button class="btn" id="saveBio" style="margin-top:8px">Save description</button>` : ""}
<div class="stats"><div class="stat"><b>${fc}</b>Friends</div><div class="stat"><b>${st.score||0}</b>Score</div><div class="stat"><b>${st.wins||0}</b>Wins</div><div class="stat"><b>${fmtTime(st.playtime)}</b>Playtime</div></div>
<h2>Achievements</h2>${ach.length ? `<div class="badges">${ach.map(a=>`<span>${a}</span>`).join("")}</div>` : `<div class="sub">None yet.</div>`}
<h2>Recently played</h2>${recent.length ? `<div class="badges">${recent.map(r=>`<span>${esc(r)}</span>`).join("")}</div>` : `<div class="sub">Nothing yet.</div>`}`}</div>`;
$("add")?.addEventListener("click", async e => { try { await sendFriendRequest(me, mine, { uid, ...u }); e.target.textContent = "Sent"; e.target.disabled = true; } catch(err){ toast(err.message); } });
$("saveBio")?.addEventListener("click", async () => { await updateDoc(doc(db,"users",me.uid), { bio: $("bioIn").value.trim().slice(0,160) }); toast("Saved."); });
