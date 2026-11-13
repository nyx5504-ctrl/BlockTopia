import { db } from "./firebase-config.js";
import { doc, getDoc, setDoc, updateDoc, deleteDoc, addDoc, collection, query, where, orderBy, startAt, endAt, limit, getDocs, onSnapshot, serverTimestamp } from "https://www.gstatic.com/firebasejs/10.14.1/firebase-firestore.js";
import { $, esc, toast, shell, ready, avatar, isOnline, sendFriendRequest } from "./common.js";
import { launchGame } from "./launch.js";

shell("friends", "Friends");
const { user: me, profile } = await ready;
$("page").innerHTML = `<input id="q" placeholder="Search users by username" style="max-width:420px"><div id="results" class="list" style="margin:10px 0 0"></div>
<h2>Requests</h2><div id="reqs" class="list"></div><h2>Your friends</h2><div id="friends" class="list"></div>`;

$("q").oninput = async e => {
  const t = e.target.value.trim().toLowerCase(); if (t.length < 2) return $("results").innerHTML = "";
  const s = await getDocs(query(collection(db,"users"), orderBy("usernameLower"), startAt(t), endAt(t+"\uf8ff"), limit(8)));
  const rows = s.docs.filter(d => d.id !== me.uid);
  $("results").innerHTML = rows.length ? rows.map(d => { const u = d.data(); return `<div class="item">${avatar(u.username,u.avatarColor)}<a class="grow" href="profile.html?u=${encodeURIComponent(u.username)}">${esc(u.username)}</a><button class="btn ghost" data-add="${d.id}">Add friend</button></div>`; }).join("") : `<div class="empty">No users found.</div>`;
  $("results").querySelectorAll("[data-add]").forEach(b => b.onclick = async () => {
    const u = rows.find(d => d.id === b.dataset.add).data();
    try { await sendFriendRequest(me, profile, { uid:b.dataset.add, ...u }); b.textContent = "Sent"; b.disabled = true; } catch(err){ toast(err.message); }
  });
};

onSnapshot(query(collection(db,"friendRequests"), where("to","==",me.uid), where("status","==","pending")), s => {
  $("reqs").innerHTML = s.empty ? `<div class="empty">No pending requests.</div>` : s.docs.map(d => `<div class="item"><div class="grow"><a href="profile.html?u=${encodeURIComponent(d.data().fromName)}">${esc(d.data().fromName)}</a><br><small>wants to be friends</small></div><button class="btn ghost" data-ok="${d.id}">Accept</button><button class="btn ghost" data-no="${d.id}">Reject</button></div>`).join("");
  s.docs.forEach(d => {
    const r = d.data(), ok = document.querySelector(`[data-ok="${d.id}"]`), no = document.querySelector(`[data-no="${d.id}"]`);
    ok.onclick = async () => { try {
      await updateDoc(d.ref, { status:"accepted" });
      await setDoc(doc(db,"friends",me.uid,"list",r.from), { username:r.fromName, since:serverTimestamp() });
      await setDoc(doc(db,"friends",r.from,"list",me.uid), { username:profile.username, since:serverTimestamp() });
      await addDoc(collection(db,"notifications",r.from,"items"), { type:"friend_accepted", from:me.uid, text:`${profile.username} accepted your friend request`, read:false, createdAt:serverTimestamp() });
    } catch(e){ toast("Couldn't accept: " + e.message); } };
    no.onclick = () => updateDoc(d.ref, { status:"rejected" });
  });
});

const unsubs = {};
onSnapshot(collection(db,"friends",me.uid,"list"), s => {
  const el = $("friends");
  if (s.empty) { el.innerHTML = `<div class="empty">No friends yet. Search for someone above.</div>`; return; }
  const ids = s.docs.map(d => d.id);
  Object.keys(unsubs).filter(k => !ids.includes(k)).forEach(k => { unsubs[k](); delete unsubs[k]; document.getElementById("f"+k)?.remove(); });
  s.docs.forEach(d => {
    if (!document.getElementById("f"+d.id)) { const row = document.createElement("div"); row.className = "item"; row.id = "f"+d.id; el.appendChild(row); }
    if (unsubs[d.id]) return;
    unsubs[d.id] = onSnapshot(doc(db,"presence",d.id), async p => {
      const pr = p.exists() ? p.data() : null, on = isOnline(pr), row = document.getElementById("f"+d.id); if (!row) return;
      const u = (await getDoc(doc(db,"users",d.id))).data() || {};
      row.innerHTML = `${avatar(d.data().username,u.avatarColor)}<div class="grow"><a href="profile.html?u=${encodeURIComponent(d.data().username)}">${esc(d.data().username)}</a><br><small><span class="dot ${on?"on":""}"></span>${on ? (pr.game ? "Playing " + esc(pr.game) : "Online") : "Offline"}</small></div>
      ${on && pr.game && pr.joinable ? `<button class="btn ghost" data-join>Join</button>` : ""}<button class="btn ghost" data-rm>Remove</button>`;
      row.querySelector("[data-join]")?.addEventListener("click", () => launchGame(pr.game, d.id, toast));
      row.querySelector("[data-rm]").onclick = async () => { if (!confirm("Remove " + d.data().username + "?")) return;
        await deleteDoc(doc(db,"friends",me.uid,"list",d.id)); await deleteDoc(doc(db,"friends",d.id,"list",me.uid)).catch(()=>{});
        await deleteDoc(doc(db,"friendRequests",`${me.uid}_${d.id}`)).catch(()=>{}); await deleteDoc(doc(db,"friendRequests",`${d.id}_${me.uid}`)).catch(()=>{}); };
    });
  });
});
