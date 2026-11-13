// Runs the REAL Godot client headless against the REAL server and watches it from a second player.
// Usage: GODOT=/path/to/godot node test/godot_e2e.mjs
import { spawn } from "node:child_process"; import WebSocket from "ws";
const PORT = 8798, GODOT = process.env.GODOT || "godot", sleep = ms => new Promise(r => setTimeout(r, ms));
const srv = spawn("node", ["servers/index.js"], { env: { ...process.env, PORT, DEV_AUTH: "1", PUBLIC_WS_URL: `ws://localhost:${PORT}` }, stdio: "ignore" });
await sleep(1200);
const launch = async uid => (await fetch(`http://localhost:${PORT}/launch`, { method:"POST", headers:{ Authorization:`Bearer dev:${uid}:${uid}`, "Content-Type":"application/json" }, body: JSON.stringify({ game:"baseplate" }) })).json();
const obs = await launch("observer"), gd = await launch("GodotBot");
const seen = { joined:false, moved:false, chat:false, left:false }; let start = null, myId = null;
const ws = new WebSocket(`ws://localhost:${PORT}`);
ws.on("open", () => ws.send(JSON.stringify({ t:"auth", code: obs.code })));
ws.on("message", d => { const m = JSON.parse(d);
  if (m.t === "welcome") myId = m.id;
  if (m.t === "join" && m.player.name === "GodotBot") { seen.joined = true; start = m.player; }
  if (m.t === "snap") for (const p of m.p) if (p[0] !== myId && start && p[0] === start.id && Math.hypot(p[1]-start.x, p[3]-start.z) > 5) seen.moved = true;
  if (m.t === "chat" && m.text === "hello from godot") seen.chat = true;
  if (m.t === "leave" && start && m.id === start.id) seen.left = true; });
const g = spawn(GODOT, ["--headless", "--path", "../GodotClient", "--", `--code=${gd.code}`, `--ws=${gd.ws}`, "--selftest"]);
let out = ""; g.stdout.on("data", d => out += d); g.stderr.on("data", d => out += d);
const exit = await Promise.race([new Promise(r => g.on("exit", r)), sleep(25000).then(() => "timeout")]);
await sleep(300); g.kill(); srv.kill();
console.log(out.split("\n").filter(l => /SELFTEST|ERROR|SCRIPT|Parse/.test(l)).join("\n"));
console.log("godot exit:", exit, seen);
const ok = Object.values(seen).every(Boolean) && !/SCRIPT ERROR|Parse Error/.test(out);
console.log(ok ? "GODOT E2E PASSED" : "GODOT E2E FAILED"); process.exit(ok ? 0 : 1);
