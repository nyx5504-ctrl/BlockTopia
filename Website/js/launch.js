import { auth } from "./firebase-config.js";
import { CONFIG } from "./config.js";

export function detectDevice(){
  const ua = navigator.userAgent, p = navigator.platform || "";
  if (/Android/i.test(ua)) return "android";
  if (/iPhone|iPad|iPod/i.test(ua) || (p === "MacIntel" && navigator.maxTouchPoints > 1)) return "ios";
  if (/Win/i.test(p) || /Windows/i.test(ua)) return "windows";
  if (/Mac/i.test(p)) return "macos";
  if (/Linux|X11/i.test(p + ua)) return "linux";
  return "unknown";
}
const NAMES = {windows:"Windows", android:"Android", ios:"iPhone / iPad", macos:"macOS", linux:"Linux", unknown:"your device"};
const HELP = {
  windows:"Download BlockTopia-Windows.zip, extract it and run BlockTopia.exe once so the blocktopia:// link is registered, then press Play again.",
  android:"Download the BlockTopia APK, open it and allow installing from this source, then press Play again.",
  ios:"Install BlockTopia from TestFlight / the App Store, then press Play again.",
  macos:"Download BlockTopia-macOS.zip, move BlockTopia.app to Applications, open it once (right-click > Open), then press Play again.",
  linux:"Download BlockTopia-Linux.zip, extract it, make BlockTopia.x86_64 executable and run the included register-protocol.sh once, then press Play again.",
  unknown:"BlockTopia supports Windows, Android, iOS, macOS and Linux."
};
function modal(html){
  const m = document.createElement("div"); m.className = "modal";
  m.innerHTML = `<div class="mbox">${html}<button class="btn ghost" style="margin-top:14px">Close</button></div>`;
  m.onclick = e => { if (e.target === m || e.target.tagName === "BUTTON" && e.target.classList.contains("ghost")) m.remove(); };
  document.body.appendChild(m); return m;
}
export function showInstall(dev = detectDevice()){
  const link = CONFIG.DOWNLOADS[dev];
  modal(`<h3 style="margin:0 0 8px">Get BlockTopia for ${NAMES[dev]}</h3><p style="color:var(--mute)">${HELP[dev]}</p>` +
    (link ? `<a class="btn" style="display:block;text-align:center;text-decoration:none" href="${link}">Download for ${NAMES[dev]}</a>`
          : `<p class="msg err">No ${NAMES[dev]} build has been published yet (set it in js/config.js).</p>`));
}
export async function launchGame(gameId, joinUid, toast = alert){
  if (!CONFIG.BACKEND_URL) return toast("Backend URL isn't configured yet (js/config.js).");
  let data;
  try {
    const token = await auth.currentUser.getIdToken();
    const r = await fetch(CONFIG.BACKEND_URL + "/launch", { method:"POST", headers:{ "Content-Type":"application/json", Authorization:"Bearer " + token }, body: JSON.stringify({ game:gameId, joinUid }) });
    data = await r.json(); if (!r.ok) throw new Error(data.error || "Launch failed");
  } catch(e){ return toast(e.message || "Couldn't reach the game server."); }
  let left = false; const mark = () => { left = true; };
  window.addEventListener("blur", mark); document.addEventListener("visibilitychange", mark);
  // one-time code, valid ~60s and usable once. No passwords/permanent tokens ever go in the URL.
  location.href = `blocktopia://play?game=${encodeURIComponent(gameId)}&code=${encodeURIComponent(data.code)}&ws=${encodeURIComponent(data.ws)}`;
  setTimeout(() => { window.removeEventListener("blur", mark); document.removeEventListener("visibilitychange", mark); if (!left) showInstall(); }, 2500);
}
