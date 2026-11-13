import { auth, db } from "./firebase-config.js";
import { onAuthStateChanged, signOut, sendEmailVerification } from "https://www.gstatic.com/firebasejs/10.14.1/firebase-auth.js";
import { doc, getDoc, setDoc, deleteDoc, updateDoc, arrayUnion, arrayRemove, collection, query, where, getCountFromServer, serverTimestamp } from "https://www.gstatic.com/firebasejs/10.14.1/firebase-firestore.js";
import { GAMES, thumbSVG } from "./games.js";
import { launchGame, showInstall } from "./launch.js";

const $ = id => document.getElementById(id);
const toast = t => { const e=$("toast"); e.textContent=t; e.classList.remove("hide"); setTimeout(()=>e.classList.add("hide"),2600); };
const esc = s => String(s).replace(/[&<>"']/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
let me, profile;

onAuthStateChanged(auth, async u => {
  if (!u) return location.href = "../index.html";
  me = u; const snap = await getDoc(doc(db,"users",u.uid));
  profile = snap.exists() ? snap.data() : {username:u.email.split("@")[0], favorites:[], recentGames:[]};
  $("uname").textContent = profile.username; $("av").textContent = profile.username[0].toUpperCase();
  if (!u.emailVerified) $("verifyBar").classList.remove("hide");
  render();
});

async function stats(id){
  const likes = (await getCountFromServer(collection(db,"games",id,"likes"))).data().count;
  const playing = (await getCountFromServer(query(collection(db,"presence"), where("game","==",id)))).data().count;
  const liked = (await getDoc(doc(db,"games",id,"likes",me.uid))).exists();
  return {likes, playing, liked};
}

const card = g => `<div class="gcard"><div class="thumb">${thumbSVG}</div><b>${esc(g.name)}</b></div>`;
async function render(filter=""){
  const g = GAMES[0], s = await stats(g.id), fav = (profile.favorites||[]).includes(g.id);
  $("featured").innerHTML = `<div class="feat"><div class="thumb">${thumbSVG}</div><div><h3>${esc(g.name)}</h3><div>${esc(g.description)}</div>
  <div class="meta"><span>${s.playing} playing</span><span>${s.likes} likes</span><span>By ${esc(g.creator)}</span></div>
  <div class="row"><button class="btn" id="play">Play</button><button class="btn ghost" id="like">${s.liked?"Liked":"Like"}</button><button class="btn ghost" id="fav">${fav?"Favorited":"Favorite"}</button></div></div></div>`;
  const rec = (profile.recentGames||[]).map(id => GAMES.find(x=>x.id===id)).filter(Boolean);
  $("recent").innerHTML = rec.length ? `<div class="grid">${rec.map(card).join("")}</div>` : `<div class="empty">You haven't played anything yet.</div>`;
  const list = GAMES.filter(x => x.name.toLowerCase().includes(filter.toLowerCase()));
  $("popular").innerHTML = list.length ? list.map(card).join("") : `<div class="empty" style="grid-column:1/-1">No games match "${esc(filter)}".</div>`;
  $("play").onclick = () => launchGame(g.id, null, toast);
  $("like").onclick = async () => { const r = doc(db,"games",g.id,"likes",me.uid);
    if (s.liked) await deleteDoc(r); else await setDoc(r,{at:serverTimestamp()}); render($("search").value); };
  $("fav").onclick = async () => { await updateDoc(doc(db,"users",me.uid),{favorites: fav?arrayRemove(g.id):arrayUnion(g.id)});
    profile.favorites = fav ? profile.favorites.filter(x=>x!==g.id) : [...(profile.favorites||[]),g.id]; render($("search").value); };
}
$("search").oninput = e => render(e.target.value);
$("logout").onclick = async () => { await signOut(auth); location.href = "../index.html"; };
$("dl").onclick = () => showInstall();
$("bell").onclick = () => location.href = "notifications.html";
