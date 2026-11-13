const P = {
  mail: '<path d="M3 6h18v12H3z"/><path d="m3 7 9 6 9-6"/>',
  ok: '<path class="draw" d="m5 12.5 4.5 4.5L19 7.5"/>',
  bad: '<path class="draw" d="M6 6l12 12M18 6 6 18"/>',
  lock: '<rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>'
};
export const icon = (k, cls = "") => `<div class="badge-icon pop ${cls}"><svg viewBox="0 0 24 24">${P[k]}</svg></div>`;
