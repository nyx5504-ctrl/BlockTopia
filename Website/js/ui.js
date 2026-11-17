// Small DOM helpers shared by every page.
export const $ = (s, r = document) => r.querySelector(s);
export const $$ = (s, r = document) => [...r.querySelectorAll(s)];
export const esc = s => String(s ?? "").replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
export const icon = (n, cls = "") => `<svg class="ic ${cls}" aria-hidden="true"><use href="#i-${n}"/></svg>`;
export const sleep = n => new Promise(r => setTimeout(r, n));
export const ms = v => v?.toMillis ? v.toMillis() : typeof v === "number" ? v : v?.seconds ? v.seconds * 1000 : 0;

const COLORS = ["#f4f4f2", "#7cc4ff", "#7ee0a6", "#ffd666", "#ff8f7a", "#b9a2ff", "#ff9ccc", "#b5b8c0"];
export const AVATAR_COLORS = COLORS;
export const safeColor = c => (/^#[0-9a-f]{6}$/i.test(c || "") ? c : COLORS[0]);
export const avatar = (name, color, cls = "", character = null) => {
  const face = safeColor(character?.bodyColor || "#f2c744");
  return '<span class="av ' + cls + '" style="--c:' + safeColor(color) + ';--face:' + face + '" role="img" aria-label="' + esc(name || "Player") + '"><svg viewBox="0 0 100 100" aria-hidden="true"><ellipse cx="50" cy="51" rx="36" ry="42" fill="var(--face)"/><ellipse cx="37" cy="42" rx="5.5" ry="9" fill="#101014"/><ellipse cx="64" cy="42" rx="5" ry="8" fill="#101014"/><path d="M30 62 Q50 87 71 61" fill="none" stroke="#101014" stroke-width="5" stroke-linecap="round"/></svg></span>';
};

let tt;
export function toast(msg, kind = "") {
  const el = $("#toast"); el.textContent = msg; el.className = "toast show " + kind;
  clearTimeout(tt); tt = setTimeout(() => { el.className = "toast"; }, 3200);
}

const stack = [];
export function openModal(el) {
  el.hidden = false; document.body.classList.add("noscroll");
  if (!stack.includes(el)) stack.push(el);
}
export function closeModal(el) {
  el.hidden = true; const i = stack.indexOf(el); if (i >= 0) stack.splice(i, 1);
  if (!stack.length) document.body.classList.remove("noscroll");
  el.dispatchEvent(new Event("modalclose"));
}
export function initModals() {
  document.addEventListener("click", e => {
    const m = e.target.closest(".modal");
    if (!m) return;
    if (e.target === m || e.target.closest("[data-close]")) closeModal(m);
  });
  document.addEventListener("keydown", e => { if (e.key === "Escape" && stack.length) closeModal(stack[stack.length - 1]); });
}

export function busy(btn, on, label) {
  if (on) { btn.dataset.label = btn.textContent; btn.disabled = true; if (label) btn.textContent = label; }
  else { btn.disabled = false; if (btn.dataset.label) btn.textContent = btn.dataset.label; }
}
