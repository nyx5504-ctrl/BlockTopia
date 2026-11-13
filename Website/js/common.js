import { auth, db } from "./firebase-config.js";
import { onAuthStateChanged, signOut } from "https://www.gstatic.com/firebasejs/10.14.1/firebase-auth.js";
import { doc, getDoc, setDoc, addDoc, collection, query, where, onSnapshot, serverTimestamp } from "https://www.gstatic.com/firebasejs/10.14.1/firebase-firestore.js";

export const $ = id => document.getElementById(id);
export const esc = s => String(s ?? "").replace(/[&<>"']/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
export function toast(t){ let e=$("toast"); if(!e){ e=document.createElement("div"); e.id="toast"; e.className="toast hide"; document.body.appendChild(e);} e.textContent=t; e.classList.remove("hide"); clearTimeout(e._t); e._t=setTimeout(()=>e.classList.add("hide"),2600); }
export const COLORS = ["#ffffff","#bdbdc2","#8a8a90","#5b8def","#e5604d","#4cc38a","#e8b33c","#a06be0"];
export const avatar = (name="?", color="#ffffff", size=38) => `<div class="av" style="width:${size}px;height:${size}px;background:${esc(color)};color:#0b0b0c;font-size:${Math.round(size/2.2)}px">${esc(name[0]||"?").toUpperCase()}</div>`;
export const isOnline = p => !!(p && p.online && p.updatedAt && Date.now() - p.updatedAt.toMillis() < 90000);
export const fmtTime = s => { s = Math.floor(s||0); const h=Math.floor(s/3600), m=Math.floor(s%3600/60); return h ? `${h}h ${m}m` : `${m}m ${s%60}s`; };

export const ready = new Promise(res => onAuthStateChanged(auth, async u => {
  if (!u) return location.href = "../index.html";
  const s = await getDoc(doc(db, "users", u.uid));
  res({ user:u, profile: s.exists() ? s.data() : { username:u.email.split("@")[0] } });
}));

export function shell(active, title){
  const L = [["dashboard","Home"],["friends","Friends"],["profile","Profile"],["settings","Settings"]];
  document.body.innerHTML = `<div class="app"><nav class="side"><div class="brand"><img src="../assets/logo.svg" alt="">BlockTopia</div>
  ${L.map(([k,n]) => `<a class="nav ${k===active?"on":""}" href="${k}.html">${n}</a>`).join("")}
  <div class="grow"></div><button class="nav" id="logout">Log out</button></nav>
  <main class="main"><div class="top"><h1 style="margin:0;font-size:22px">${esc(title)}</h1><div class="sp"></div><a class="btn ghost" href="notifications.html" style="text-decoration:none">Notifications <b id="badge"></b></a></div><div id="page"></div></main></div>`;
  $("logout").onclick = async () => { await signOut(auth); location.href = "../index.html"; };
  ready.then(({user}) => onSnapshot(query(collection(db,"notifications",user.uid,"items"), where("read","==",false)), s => { $("badge").textContent = s.size ? `(${s.size})` : ""; }));
}

export async function sendFriendRequest(me, meProfile, target){ // target: {uid, username, notifFriendRequests}
  if (target.uid === me.uid) throw new Error("You can't add yourself.");
  if ((await getDoc(doc(db,"friends",me.uid,"list",target.uid))).exists()) throw new Error("Already friends.");
  const rev = await getDoc(doc(db,"friendRequests",`${target.uid}_${me.uid}`));
  if (rev.exists() && rev.data().status === "pending") throw new Error(`${target.username} already sent you a request. Check Friends.`);
  try { await setDoc(doc(db,"friendRequests",`${me.uid}_${target.uid}`), { from:me.uid, to:target.uid, fromName:meProfile.username, toName:target.username, status:"pending", createdAt:serverTimestamp() }); }
  catch { throw new Error(`${target.username} isn't accepting friend requests.`); }
  if (target.notifFriendRequests !== false)
    await addDoc(collection(db,"notifications",target.uid,"items"), { type:"friend_request", from:me.uid, text:`${meProfile.username} sent you a friend request`, read:false, createdAt:serverTimestamp() });
}
