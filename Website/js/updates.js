// "BlockTopia has an update to share with you": the site publishes version.json on every GitHub deploy. When it changes, ask the person;
// Yes reloads right away, Later waits one hour and then updates by itself.
import { $, toast } from "./ui.js";
import { t } from "./i18n.js";

const KEY = "bt_update_snooze", HOUR = 3600000;
let baseline = null, shown = false;
const store = { get() { try { return JSON.parse(localStorage.getItem(KEY) || "null"); } catch { return null; } }, set(v) { try { v ? localStorage.setItem(KEY, JSON.stringify(v)) : localStorage.removeItem(KEY); } catch { /* private mode */ } } };
async function latest() {
  try { const r = await fetch("version.json?t=" + Date.now(), { cache: "no-store" }); return r.ok ? String((await r.json()).version || "") : ""; } catch { return ""; }
}
function reload() { store.set(null); location.reload(); }
async function check() {
  const v = await latest(); if (!v || baseline === null) return;
  if (v === baseline) return;
  const snooze = store.get();
  if (snooze && snooze.version === v) {
    if (Date.now() >= snooze.until) { toast(t("upd_auto")); setTimeout(reload, 2000); }
    return;
  }
  if (shown) return; shown = true;
  const ov = $("#updateOverlay"); ov.hidden = false;
  $("#updYes").onclick = reload;
  $("#updLater").onclick = () => { store.set({ version: v, until: Date.now() + HOUR }); ov.hidden = true; shown = false; toast(t("upd_later_ok")); };
}
export async function startUpdateWatcher() {
  baseline = await latest(); if (!baseline) return;
  const snooze = store.get(); if (snooze && snooze.version === baseline) store.set(null);   // already on the new version
  setInterval(check, 60000); document.addEventListener("visibilitychange", () => { if (!document.hidden) check(); });
}
