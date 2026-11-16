// "Which devices use my account": each browser registers itself under users/<uid>/devices/<id>.
import { db, F } from "./fb.js";
import { S } from "./state.js";
import { ms } from "./ui.js";

export function parseUA(ua = navigator.userAgent) {
  const touch = navigator.maxTouchPoints > 1;
  const os = /Windows/.test(ua) ? "Windows" : /Android/.test(ua) ? "Android" : /iPhone|iPod/.test(ua) ? "iOS" : /iPad/.test(ua) ? "iPadOS"
    : /Macintosh|Mac OS X/.test(ua) ? (touch ? "iPadOS" : "macOS") : /CrOS/.test(ua) ? "ChromeOS" : /Linux/.test(ua) ? "Linux" : "Unknown";
  const browser = /Edg\//.test(ua) ? "Edge" : /OPR\/|Opera/.test(ua) ? "Opera" : /SamsungBrowser/.test(ua) ? "Samsung Internet"
    : /Firefox|FxiOS/.test(ua) ? "Firefox" : /CriOS|Chrome/.test(ua) ? "Chrome" : /Safari/.test(ua) ? "Safari" : "Browser";
  const type = /iPhone|iPod|Mobi/.test(ua) ? "phone" : /iPad|Tablet/.test(ua) || os === "iPadOS" || (os === "Android" && !/Mobile/.test(ua)) ? "tablet" : "desktop";
  return { browser, os, type, name: `${browser} · ${os}` };
}

let memId = null;
export function deviceId() {
  let id = memId; try { id = id || localStorage.getItem("bt_device"); } catch {}
  if (!id) { id = (crypto.randomUUID ? crypto.randomUUID() : Date.now() + "-" + Math.random().toString(16).slice(2)); try { localStorage.setItem("bt_device", id); } catch {} }
  return (memId = id);
}
const ref = id => F.doc(db, "users", S.user.uid, "devices", id);

async function lookupCountry() {
  try { const c = sessionStorage.getItem("bt_cc"); if (c) return c; } catch {}
  const get = async (url, pick) => {
    const c = new AbortController(), to = setTimeout(() => c.abort(), 4000);
    try { const v = pick(await (await fetch(url, { signal: c.signal })).text()); return /^[A-Z]{2}$/.test(v) ? v : null; } catch { return null; } finally { clearTimeout(to); }
  };
  const cc = await get("https://get.geojs.io/v1/ip/country.json", x => { try { const j = JSON.parse(x); return (Array.isArray(j) ? j[0] : j).country; } catch { return ""; } })
    ?? await get("https://ipapi.co/country/", x => x.trim());
  try { if (cc) sessionStorage.setItem("bt_cc", cc); } catch {}
  return cc || null;
}

// Returns "revoked" if this device was signed out remotely and hasn't logged in again since.
export async function registerDevice() {
  const id = (S.deviceId = deviceId()), info = parseUA(), r = ref(id);
  const snap = await F.getDoc(r), old = snap.exists() ? snap.data() : null;
  if (old?.revoked) {
    const lastLogin = Date.parse(S.user.metadata?.lastSignInTime || "") || 0;
    if ((old.revokedAt || 0) > lastLogin) return "revoked";
  }
  await F.setDoc(r, { name: info.name, browser: info.browser, os: info.os, type: info.type, revoked: false, lastActive: F.serverTimestamp(), ...(old ? {} : { firstSeen: F.serverTimestamp() }) }, { merge: true });
  lookupCountry().then(cc => cc && F.updateDoc(r, { country: cc })).catch(() => {});
  return "ok";
}

let hb = null, vis = null;
export function startHeartbeat() {
  stopHeartbeat();
  const beat = () => {
    if (!S.user || !S.deviceId || document.hidden) return;
    F.updateDoc(ref(S.deviceId), { lastActive: F.serverTimestamp() }).catch(() => {});
    F.updateDoc(F.doc(db, "users", S.user.uid), { lastSeen: F.serverTimestamp() }).catch(() => {});
  };
  beat(); hb = setInterval(beat, 120000); vis = beat; document.addEventListener("visibilitychange", vis);
}
export function stopHeartbeat() { clearInterval(hb); if (vis) document.removeEventListener("visibilitychange", vis); hb = vis = null; }

export const watchSelf = onRevoked => F.onSnapshot(ref(S.deviceId), s => { if (s.exists() && s.data().revoked === true) onRevoked(); }, () => {});
export const watchDevices = cb => F.onSnapshot(F.query(F.collection(db, "users", S.user.uid, "devices"), F.orderBy("lastActive", "desc")),
  s => cb(s.docs.map(d => ({ id: d.id, ...d.data(), lastMs: ms(d.data().lastActive), firstMs: ms(d.data().firstSeen) }))), () => {});
export const revokeDevice = id => F.updateDoc(ref(id), { revoked: true, revokedAt: Date.now() });
export const removeDevice = id => F.deleteDoc(ref(id));
