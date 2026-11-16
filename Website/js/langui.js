// Language picker + the loading screen shown while a language is applied.
import { $, esc, icon, openModal, closeModal, toast, sleep } from "./ui.js";
import { LANGS, lang, langMeta, setLang, announceLang, t } from "./i18n.js";
import { S } from "./state.js";
import { F, db } from "./fb.js";

function render(q = "") {
  const s = q.trim().toLowerCase();
  const items = LANGS.filter(l => !s || l.native.toLowerCase().includes(s) || l.name.toLowerCase().includes(s) || l.code === s);
  $("#langList").innerHTML = items.map(l =>
    `<button type="button" role="option" data-lang="${l.code}" ${l.code === lang() ? 'aria-current="true"' : ""}><span><b>${esc(l.native)}</b><br><span>${esc(l.name)}</span></span>${l.code === lang() ? icon("check") : ""}</button>`).join("");
}
export function refreshLangLabels() {
  $("#langCur").textContent = langMeta().native;
  $("#authLangName").textContent = langMeta().native;
}
function openPicker() {
  $("#langSearch").value = ""; render(); openModal($("#langModal"));
  if (!matchMedia("(pointer: coarse)").matches) setTimeout(() => $("#langSearch").focus(), 40);
}

export async function changeLanguage(code) {
  closeModal($("#langModal"));
  if (code === lang()) return;
  const L = $("#langLoader");
  $("#llName").textContent = langMeta(code).native;
  L.hidden = false; L.classList.remove("out", "run"); void L.offsetWidth; L.classList.add("run");
  const t0 = Date.now();
  try { await setLang(code); }
  catch { L.hidden = true; toast(t("err_generic"), "bad"); return; }
  await sleep(Math.max(0, 1700 - (Date.now() - t0)));       // the loading screen always plays out
  announceLang(); refreshLangLabels();
  L.classList.add("out"); await sleep(320); L.hidden = true; L.classList.remove("out", "run");
  toast(t("lang_done"));
  if (S.user) F.updateDoc(F.doc(db, "users", S.user.uid), { lang: code }).catch(() => {});
}

export function initLangUI() {
  $("#authLang").onclick = openPicker;
  $("#langRow").onclick = openPicker;
  $("#langSearch").addEventListener("input", e => render(e.target.value));
  $("#langList").addEventListener("click", e => { const b = e.target.closest("[data-lang]"); if (b) changeLanguage(b.dataset.lang); });
  refreshLangLabels();
}
