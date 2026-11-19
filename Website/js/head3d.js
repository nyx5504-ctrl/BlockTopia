// Friend badges: a live 3D head-and-shoulders of the friend's character (the same R6 rig the game uses), so it changes when they customize.
// Each badge is its own tiny WebGL view, so only the first MAX get one; the rest keep the flat face.
const MAX = 10, live = new Set();
let mod = null;
const load = () => mod || (mod = import("./rig.bundle.js"));

export function hydrateHeads(root = document) {
  root.querySelectorAll("[data-head]:not([data-hydrated])").forEach(el => {
    el.dataset.hydrated = "1";
    for (const e of live) if (!e.el.isConnected) { try { e.rig?.dispose(); } catch { /* ignore */ } live.delete(e); }   // badges that left the page
    if (live.size >= MAX) return;
    let character; try { character = JSON.parse(el.dataset.head); } catch { return; }
    const h = Math.min(1.25, Math.max(0.75, Number(character?.height) || 1));
    el.style.setProperty("--hy", (-55 + (h - 1) * 100).toFixed(1) + "px");      // taller characters have their head higher up
    const stage = document.createElement("div"); stage.className = "head3d"; el.appendChild(stage);
    const entry = { el, rig: null }; live.add(entry);
    load().then(m => m.createRig(stage, "assets/roblox-r6.glb")).then(rig => {
      if (!el.isConnected) { rig.dispose(); live.delete(entry); return; }
      entry.rig = rig; if (character && typeof character === "object") rig.set(character); el.classList.add("is-3d");
    }).catch(() => { live.delete(entry); stage.remove(); });
  });
}
