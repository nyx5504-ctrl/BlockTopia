// Renders the real Godot client under xvfb (software GL) and saves screenshots. Dev tool: GODOT=... node test/shots.mjs
import { spawn } from "node:child_process"; import WebSocket from "ws"; import fs from "node:fs";
const PORT = 8797, GODOT = process.env.GODOT || "godot", DIR = process.env.SHOTS || "/tmp/shots", sleep = ms => new Promise(r => setTimeout(r, ms));
fs.mkdirSync(DIR, { recursive: true });
const srv = spawn("node", ["servers/index.js"], { env: { ...process.env, PORT, DEV_AUTH: "1", PUBLIC_WS_URL: `ws://localhost:${PORT}` }, stdio: "ignore" }); await sleep(1200);
const launch = async uid => (await fetch(`http://localhost:${PORT}/launch`, { method:"POST", headers:{ Authorization:`Bearer dev:${uid}:${uid}`, "Content-Type":"application/json" }, body: JSON.stringify({ game:"baseplate" }) })).json();
const others = [];
for (const [name, say] of [["Alice", "Welcome to Baseplate!"], ["Bob_the_Builder", "anyone want to try the parkour?"]]) {
  const l = await launch(name); const ws = new WebSocket(`ws://localhost:${PORT}`); let me;
  ws.on("open", () => ws.send(JSON.stringify({ t:"auth", code:l.code })));
  ws.on("message", d => { const m = JSON.parse(d); if (m.t === "welcome") { me = m; setTimeout(() => ws.send(JSON.stringify({ t:"chat", text: say })), 2500);
    // walk a little so remote avatars animate
    let x = m.x, z = m.z, i = 0; const iv = setInterval(() => { if (ws.readyState !== 1) return clearInterval(iv); x += 0.9; z += 0.3; ws.send(JSON.stringify({ t:"pos", x, y:0, z, ry: 1.2, a: "run", e: me.e })); }, 66); } });
  others.push(ws); await sleep(300);
}
const gd = await launch("GodotBot");
const g = spawn("xvfb-run", ["-a", "-s", "-screen 0 1280x720x24", GODOT, "--rendering-driver", "opengl3", "--resolution", "1280x720", "--path", "../GodotClient", "--", `--code=${gd.code}`, `--ws=${gd.ws}`, "--selftest", `--shotdir=${DIR}`]);
let out = ""; g.stdout.on("data", d => out += d); g.stderr.on("data", d => out += d);
await Promise.race([new Promise(r => g.on("exit", r)), sleep(90000)]);
others.forEach(w => w.close()); srv.kill(); g.kill();
console.log(out.split("\n").filter(l => /SHOT|SCRIPT ERROR|Parse Error|SELFTEST/.test(l)).join("\n"));
