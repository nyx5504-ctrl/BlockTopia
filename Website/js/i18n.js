// Translations. English is always loaded as the fallback; other languages load on demand from js/lang/<code>.js.
// To add a language: copy lang/en.js to lang/xx.js, translate the values, and add a line to LANGS below.
export const LANGS = [
  { code: "en", native: "English", name: "English" },
  { code: "ar", native: "العربية", name: "Arabic", rtl: true },
  { code: "es", native: "Español", name: "Spanish" },
  { code: "fr", native: "Français", name: "French" },
  { code: "de", native: "Deutsch", name: "German" },
  { code: "pt", native: "Português", name: "Portuguese" },
  { code: "ru", native: "Русский", name: "Russian" },
  { code: "tr", native: "Türkçe", name: "Turkish" },
  { code: "zh", native: "简体中文", name: "Chinese (Simplified)" },
  { code: "ja", native: "日本語", name: "Japanese" },
  { code: "ko", native: "한국어", name: "Korean" },
  { code: "hi", native: "हिन्दी", name: "Hindi" },
];
let base = {}, dict = {}, cur = "en";
const subs = [];
const load = async c => (await import(`./lang/${c}.js`)).default;

export const lang = () => cur;
export const langMeta = (c = cur) => LANGS.find(l => l.code === c) || LANGS[0];
export const onLangChange = fn => subs.push(fn);

export function t(key, vars) {
  let s = dict[key] ?? base[key] ?? key;
  if (vars) s = s.replace(/\{(\w+)\}/g, (m, n) => (vars[n] ?? m));
  return s;
}

export function applyDom(root = document) {
  root.querySelectorAll("[data-i18n]").forEach(e => { e.textContent = t(e.dataset.i18n); });
  for (const a of ["placeholder", "aria-label", "title"])
    root.querySelectorAll(`[data-i18n-${a}]`).forEach(e => e.setAttribute(a, t(e.getAttribute(`data-i18n-${a}`))));
}

function pick() {
  try { const s = localStorage.getItem("bt_lang"); if (s && LANGS.some(l => l.code === s)) return s; } catch {}
  for (const l of navigator.languages || [navigator.language]) {
    const c = (l || "").slice(0, 2).toLowerCase();
    if (LANGS.some(x => x.code === c)) return c;
  }
  return "en";
}

export async function setLang(code) {
  const d = code === "en" ? {} : await load(code);
  dict = d; cur = code;
  document.documentElement.lang = code;
  document.documentElement.dir = langMeta(code).rtl ? "rtl" : "ltr";
  try { localStorage.setItem("bt_lang", code); } catch {}
  applyDom();
}
export const announceLang = () => subs.forEach(fn => { try { fn(); } catch (e) { console.error(e); } });

export async function initI18n() {
  base = await load("en");
  const c = pick();
  try { await setLang(c); } catch { await setLang("en"); }
}

// Dates, relative times and country names come from the browser's own Intl data, so they follow the language too.
export const fmtDate = v => (v ? new Intl.DateTimeFormat(cur, { dateStyle: "medium" }).format(v) : "—");
export function fmtRel(v, nowLabel = true) {
  if (!v) return "—";
  const d = v - Date.now(), a = Math.abs(d);
  if (nowLabel && a < 180e3) return t("active_now");
  if (a > 30 * 864e5) return fmtDate(v);
  const rtf = new Intl.RelativeTimeFormat(cur, { numeric: "auto" });
  for (const [u, s] of [["day", 864e5], ["hour", 36e5], ["minute", 6e4]]) if (a >= s || u === "minute") return rtf.format(Math.round(d / s), u);
}
export function countryName(code) {
  if (!code) return t("unknown");
  try { return new Intl.DisplayNames([cur], { type: "region" }).of(code) || code; } catch { return code; }
}
