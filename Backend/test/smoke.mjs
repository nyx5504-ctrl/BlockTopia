// End-to-end smoke test against a locally spawned server (DEV_AUTH mode, no Firebase).
import { spawn } from "node:child_process"; import WebSocket from "ws"; import assert from "node:assert/strict";
import { checkMessage } from "../chat/filter.js";
const PORT = 8799, base = `http://localhost:${PORT}`;
const srv = spawn("node", ["servers/index.js"], { env: { ...process.env, PORT, DEV_AUTH: "1", MAX_PLAYERS: "2", PUBLIC_WS_URL: `ws://localhost:${PORT}` }, stdio: "inherit" });
const sleep = ms => new Promise(r => setTimeout(r, ms)); let pass = 0;
const ok = (c, name) => { assert.ok(c, name); pass++; console.log("  ok -", name); };
await sleep(1200);
const launch = async (uid, body = {}) => (await fetch(base + "/launch", { method:"POST", headers:{ Authorization:`Bearer dev:${uid}:${uid}`, "Content-Type":"application/json" }, body: JSON.stringify({ game:"baseplate", ...body }) })).json();
function client(code, session) {
  const ws = new WebSocket(`ws://localhost:${PORT}`), c = { ws, msgs: [], closed: null };
  ws.on("message", d => { const m = JSON.parse(d); c.msgs.push(m); });
  ws.on("close", (code, why) => { c.closed = code; });
  ws.on("open", () => ws.send(JSON.stringify({ t:"auth", code, session })));
  c.wait = async (f, ms = 2000) => { const t = Date.now(); while (Date.now() - t < ms) { const m = c.msgs.find(f); if (m) return m; await sleep(30); } return null; };
  c.send = o => ws.send(JSON.stringify(o)); return c;
}
try {
  console.log("filter unit checks");
  for (const bad of ["you are a f u c k", "fuuuck this", "sh1t", "email me bob@gmail.com", "call 555 123 4567", "visit www.evil.com", "add me on snapchat", "my number is hi"]) ok(!checkMessage(bad).ok, `blocks: ${bad}`);
  for (const good of ["hello everyone!", "I love this game", "assume the class passed", "Scunthorpe is a town"]) ok(checkMessage(good).ok, `allows: ${good}`);

  console.log("launch + auth");
  ok((await fetch(base + "/launch", { method:"POST", body:"{}" })).status === 401, "launch without token rejected");
  const l1 = await launch("alice"), l2 = await launch("bob");
  ok(l1.code && l1.ws, "launch returns one-time code");
  const A = client(l1.code), B = client(l2.code);
  const wa = await A.wait(m => m.t === "welcome"), wb = await B.wait(m => m.t === "welcome");
  ok(wa && wb && wa.room === wb.room, "two players join the same room");
  ok(wb.players.length === 1 && wb.players[0].name === "alice", "bob sees alice in player list");
  ok(await A.wait(m => m.t === "join" && m.player.name === "bob"), "alice notified of bob joining");
  const reuse = client(l1.code); await sleep(400); ok(reuse.closed === 4001, "launch code is single-use");

  console.log("movement validation");
  A.send({ t:"pos", x: wa.x + 1, y: wa.y, z: wa.z, ry: 1, a:"run", e: wa.e }); await sleep(250);
  ok(await B.wait(m => m.t === "snap" && m.p.some(p => p[0] === wa.id && Math.abs(p[1] - (wa.x + 1)) < 0.02)), "bob sees alice's valid move");
  A.send({ t:"pos", x: 240, y: wa.y, z: wa.z, ry: 0, a:"run", e: wa.e }); 
  ok(await A.wait(m => m.t === "correct"), "teleport/speed hack is corrected by server");
  A.send({ t:"pos", x: 0, y: -60, z: 0, ry: 0, a:"fall", e: wa.e }); await sleep(100);
  A.send({ t:"respawn" }); ok(await A.wait(m => m.t === "respawn"), "respawn returns a spawn point");

  console.log("chat");
  A.send({ t:"chat", text:"hello bob" }); ok(await B.wait(m => m.t === "chat" && m.text === "hello bob"), "chat delivered");
  await sleep(450); A.send({ t:"chat", text:"you f u c k" }); ok(await A.wait(m => m.t === "chat_blocked" && m.reason === "language"), "profanity blocked w/ friendly warning");
  ok(!B.msgs.some(m => m.t === "chat" && /f u c k/.test(m.text)), "blocked text never reaches others");
  await sleep(450); A.send({ t:"chat", text:"mail me x@y.com" }); ok(await A.wait(m => m.t === "chat_blocked" && m.reason === "personal"), "personal info blocked");
  B.send({ t:"mute", id: wa.id, on:true }); await sleep(150); const n = B.msgs.length;
  await sleep(450); A.send({ t:"chat", text:"are you there" }); await sleep(300);
  ok(!B.msgs.slice(n).some(m => m.t === "chat"), "muted player's chat not delivered");
  for (let i = 0; i < 7; i++) { A.send({ t:"chat", text:"spam "+i }); }
  ok(await A.wait(m => m.t === "chat_blocked" && m.reason === "rate"), "chat rate limit");
  B.send({ t:"report", id: wa.id, reason:"test" }); ok(await B.wait(m => m.t === "report_ok"), "report accepted");

  console.log("friend + block");
  A.send({ t:"friend", id: wb.id }); const fr = await A.wait(m => m.t === "friend_result"); ok(fr && fr.ok, "in-game friend request accepted by server");
  A.send({ t:"friend", id: wb.id }); await sleep(100); ok(A.msgs.filter(m => m.t === "friend_result").some(m => !m.ok), "duplicate request rejected");
  B.send({ t:"block", id: wa.id, on:true }); ok(await B.wait(m => m.t === "mute_ok" && m.blocked && m.on), "block acknowledged");
  A.send({ t:"friend", id: wb.id }); await sleep(150); ok(A.msgs.filter(m => m.t === "friend_result").pop().text.includes("can't"), "blocked player can't send friend request");
  const sc = await A.wait(m => m.t === "scores", 6000); ok(sc && sc.s.length >= 2, "live scores broadcast");

  console.log("capacity, reconnect, leave");
  const l3 = await launch("carol"); const C = client(l3.code); await C.wait(m => m.t === "welcome");
  ok(C.msgs.find(m => m.t === "welcome").room !== wa.room, "full room (max 2) overflows to a new room");
  A.ws.close(); await sleep(300);
  ok(await B.wait(m => m.t === "leave" && m.id === wa.id), "others told when a player drops");
  const A2 = client(null, wa.session); const re = await A2.wait(m => m.t === "welcome");
  ok(re && re.resume && re.id === wa.id, "reconnect with session restores the same player");
  B.send({ t:"leave" }); await sleep(300); ok(B.closed !== null, "leave closes the connection");
  console.log(`\nALL ${pass} CHECKS PASSED`);
} catch (e) { console.error("\nFAILED:", e.message); process.exitCode = 1; }
srv.kill(); process.exit(process.exitCode || 0);
