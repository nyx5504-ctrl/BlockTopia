export const CFG = { MAX_PLAYERS: +process.env.MAX_PLAYERS || 16, HALF: 250, MAX_SPEED: 22, MAX_VSPEED: 70, GRACE_MS: 30000 };
const SPAWNS = Array.from({ length: 8 }, (_, i) => { const a = i / 8 * Math.PI * 2; return { x: +(Math.cos(a) * 20).toFixed(2), y: 3, z: +(Math.sin(a) * 20).toFixed(2) }; });
export const spawnPoint = () => ({ ...SPAWNS[Math.floor(Math.random() * SPAWNS.length)] });
const ANIMS = new Set(["idle", "run", "jump", "fall"]);
const r2 = n => Math.round(n * 100) / 100;

export class Room {
  constructor(id) { this.id = id; this.players = new Map(); this.history = []; this.nextId = 1; }
  get full() { return this.players.size >= CFG.MAX_PLAYERS; }
  add(p) { p.id = this.nextId++; Object.assign(p, spawnPoint(), { ry: 0, anim: "idle", epoch: 0, lastT: Date.now(), viol: 0 }); this.players.set(p.id, p); }
  remove(p) { this.players.delete(p.id); }
  live() { return [...this.players.values()].filter(p => p.ws); }
  send(p, m) { if (p.ws && p.ws.readyState === 1) p.ws.send(JSON.stringify(m)); }
  broadcast(m, except) { const s = JSON.stringify(m); for (const p of this.live()) if (p !== except && p.ws.readyState === 1) p.ws.send(s); }
  pub(p) { return { id: p.id, name: p.name, color: p.color, score: p.score || 0, x: r2(p.x), y: r2(p.y), z: r2(p.z), ry: r2(p.ry), anim: p.anim }; }
  teleportToSpawn(p) { Object.assign(p, spawnPoint()); p.epoch++; p.lastT = Date.now(); this.send(p, { t: "respawn", x: p.x, y: p.y, z: p.z, e: p.epoch }); }
  // Server-side validation of client-reported movement. Returns false if the update was rejected.
  applyPos(p, m) {
    if (m.e !== p.epoch) return true;                       // stale update from before a server teleport
    const { x, y, z, ry } = m;
    if (![x, y, z, ry].every(Number.isFinite)) return false;
    const now = Date.now(), dt = Math.min(Math.max((now - p.lastT) / 1000, 0.03), 1); p.lastT = now;
    const hd = Math.hypot(x - p.x, z - p.z), vd = Math.abs(y - p.y);
    if (Math.abs(x) > CFG.HALF || Math.abs(z) > CFG.HALF || y > 300 || hd > CFG.MAX_SPEED * dt + 1 || vd > CFG.MAX_VSPEED * dt + 1) {
      p.viol++; this.send(p, { t: "correct", x: p.x, y: p.y, z: p.z, e: p.epoch }); return false;
    }
    p.x = x; p.y = y; p.z = z; p.ry = ry; p.anim = ANIMS.has(m.a) ? m.a : "idle";
    if (p.viol > 0) p.viol -= 0.02;
    if (p.y < -50) this.teleportToSpawn(p);                 // fell off the world
    return true;
  }
  snapshot() { return { t: "snap", p: this.live().map(p => [p.id, r2(p.x), r2(p.y), r2(p.z), r2(p.ry), p.anim]) }; }
}
