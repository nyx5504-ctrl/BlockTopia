import { db } from "./firebase-config.js";
import { collection, query, orderBy, limit, onSnapshot, updateDoc, deleteDoc, getDocs } from "https://www.gstatic.com/firebasejs/10.14.1/firebase-firestore.js";
import { $, esc, shell, ready } from "./common.js";
shell("", "Notifications");
const { user } = await ready;
$("page").innerHTML = `<button class="btn ghost" id="clr" style="margin-bottom:12px">Clear all</button><div id="list" class="list"></div>`;
const col = collection(db,"notifications",user.uid,"items");
onSnapshot(query(col, orderBy("createdAt","desc"), limit(50)), s => {
  $("list").innerHTML = s.empty ? `<div class="empty">You're all caught up.</div>` : s.docs.map(d => { const n = d.data(); return `<div class="item"><span class="dot ${n.read?"":"on"}"></span><a class="grow" href="${n.type.startsWith("friend")?"friends.html":"#"}">${esc(n.text)}</a><small>${n.createdAt ? n.createdAt.toDate().toLocaleString() : ""}</small></div>`; }).join("");
  s.docs.filter(d => !d.data().read).forEach(d => updateDoc(d.ref, { read:true }));
});
$("clr").onclick = async () => { (await getDocs(col)).forEach(d => deleteDoc(d.ref)); };
