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
  for (const bad of ["email me bob@gmail.com", "call 555 123 4567", "visit www.evil.com", "add me on snapchat", "my number is hi", "kill yourself"]) ok(!checkMessage(bad).ok, `blocks: ${bad}`);
  for (const bad of ["you are a f u c k", "fuuuck this", "sh1t", "ass!", "sh.it", "fvck you", "ｆｕｃｋ", "you sharmouta", "انت شرموطه", "ya kalb"]) { const r = checkMessage(bad); ok(r.ok && r.masked && /#/.test(r.text), `masks: ${bad} -> ${r.text}`); }
  for (const good of ["hello world", "Scunthorpe is a town", "my pen is blue", "pass the grass", "assassin creed", "class is fun", "a cocktail please", "pen is mine", "what a nice day!"]) { const r = checkMessage(good); ok(r.ok && !r.masked && r.text === good, `allows: ${good}`); }
  for (const bad of ["ꜰᴜᴄᴋ you", "fսck", "ꓑꓳꓣꓠ", "s𝐡ⅰt", "ꜰuϲk", "ƒսcƙ", "ⅼ", "bꓲtch".replace("ꓲ", "ꓲ")]) ok(checkMessage(bad).ok, `no crash on odd text: ${bad}`);
  for (const bad of ["𝐟𝐮𝐜𝐤 you", "🅵🆄🅲🅺", "ꜰᴜᴄᴋ", "f\u200bu\u200bc\u200bk", "ƒυск", "f-u-c-k", "yoush1ting", "ⓢⓗⓘⓣ", "f u c k"]) { const r = checkMessage(bad); ok(r.ok && r.masked && /#/.test(r.text), `masks fancy/hidden: ${bad} -> ${r.text}`); }
  ok(checkMessage("what the f*ck man").text === "what the #### man", "only the bad word is hidden");
  for (const good of ["hello everyone!", "I love this game", "assume the class passed", "Scunthorpe is a town"]) ok(checkMessage(good).ok, `allows: ${good}`);

  console.log("filter v1.6 additions");
  for (const bad of ["du arschloch", "you pedo", "hijueputa", "siktir git", "blyat", "madarchod", "قال خول"]) { const r = checkMessage(bad); ok(r.ok && r.masked && /#/.test(r.text), `masks: ${bad} -> ${r.text}`); }
  for (const bad of ["send nudes", "dont tell your mom", "are you home alone", "kms", "i hope you die", "meet me irl"]) ok(!checkMessage(bad).ok, `blocks: ${bad}`);
  for (const good of ["my pet is a pedometer", "how old is this game", "are you a good player", "pizza time", "see you later"]) { const r = checkMessage(good); ok(r.ok && !r.masked, `allows: ${good}`); }

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
  A.send({ t:"emote", e:"wave" }); await sleep(300); ok(!B.msgs.some(m => m.t === "emote"), "emotes are gone (server ignores them)");
  A.send({ t:"ping", n: 42 }); ok(await A.wait(m => m.t === "pong" && m.n === 42), "ping/pong");
  await sleep(450); A.send({ t:"chat", text:"you f u c k" }); ok(await B.wait(m => m.t === "chat" && m.text === "you # # # #"), "profanity is hidden with #### for everyone");
  ok(!B.msgs.some(m => m.t === "chat" && /f u c k/.test(m.text)), "original bad word never reaches others");
  ok(await A.wait(m => m.t === "sys" && /hidden/.test(m.text)), "sender gets a friendly note");
  await sleep(450); A.send({ t:"chat", text:"mail me x@y.com" }); ok(await A.wait(m => m.t === "chat_blocked" && m.reason === "personal"), "personal info blocked");
  B.send({ t:"mute", id: wa.id, on:true }); await sleep(150); const n = B.msgs.length;
  await sleep(450); A.send({ t:"chat", text:"are you there" }); await sleep(300);
  ok(!B.msgs.slice(n).some(m => m.t === "chat"), "muted player's chat not delivered");
  for (let i = 0; i < 7; i++) { A.send({ t:"chat", text:"spam "+i }); }
  ok(await A.wait(m => m.t === "chat_blocked" && m.reason === "rate"), "chat rate limit");
  B.send({ t:"report", id: wa.id, category:"abuse", reason:"test", details:"was rude" }); ok(await B.wait(m => m.t === "report_ok"), "report accepted");
  const n0 = B.msgs.filter(m => m.t === "report_ok").length; B.send({ t:"report", id: wa.id, category:"abuse" }); await sleep(300);
  ok(B.msgs.filter(m => m.t === "report_ok").length === n0 + 1 && B.msgs.filter(m => m.t === "report_ok").pop().dup === true, "same player can't be reported again within 10 minutes");

  console.log("friend + block");
  A.send({ t:"friend", id: wb.id }); const fr = await A.wait(m => m.t === "friend_result"); ok(fr && fr.ok, "in-game friend request accepted by server");
  ok(await B.wait(m => m.t === "friend_request" && m.id === wa.id), "bob is asked in-game to accept alice's request");
  A.send({ t:"friend", id: wb.id }); await sleep(100); ok(A.msgs.filter(m => m.t === "friend_result").some(m => !m.ok), "duplicate request rejected");
  B.send({ t:"friend_accept", id: wa.id }); ok(await B.wait(m => m.t === "friend_result" && m.friends) && await A.wait(m => m.t === "friend_result" && m.text.includes("accepted")), "bob accepts in-game and both are told");
  B.send({ t:"friend_accept", id: wa.id }); await sleep(150); ok(B.msgs.filter(m => m.t === "friend_result" && m.friends).length === 1, "accepting twice does nothing");
  B.send({ t:"block", id: wa.id, on:true }); ok(await B.wait(m => m.t === "mute_ok" && m.blocked && m.on), "block acknowledged");
  A.send({ t:"friend", id: wb.id }); await sleep(150); ok(A.msgs.filter(m => m.t === "friend_result").pop().text.includes("can't"), "blocked player can't send friend request");

  console.log("avatar sync");
  const blue = { height: 1.1, bodyType: "broad", parts: { torso: { size: 1, color: "#0d69ac" } } };
  A.msgs.length = 0; B.msgs.length = 0;
  A.send({ t:"character", character: blue });
  ok(await B.wait(m => m.t === "character" && m.id === wa.id && m.character.parts.torso.color === "#0d69ac"), "other players see a character change");
  ok(await A.wait(m => m.t === "character" && m.id === wa.id && m.saved && m.character.bodyType === "broad"), "you get your own change too");
  A.msgs.length = 0; B.msgs.length = 0;
  const viaWeb = await fetch(base + "/profile", { method:"POST", headers:{ Authorization:"Bearer dev:alice:alice", "Content-Type":"application/json" }, body: JSON.stringify({ character: { bodyType: "slim", parts: { head: { color: "#c4281c" } } } }) });
  ok(viaWeb.status === 200, "website/app profile save accepted");
  ok(await B.wait(m => m.t === "character" && m.id === wa.id && m.character.parts.head.color === "#c4281c"), "saving on the website updates everyone already in game");
  ok(await A.wait(m => m.t === "character" && m.id === wa.id && m.saved && m.character.bodyType === "slim"), "...including yourself");

  console.log("friends list, descriptions, friend chat");
  const call = async (path, body, uid) => { const r = await fetch(base + path, { method: "POST", headers: { "Content-Type": "application/json", Authorization: `Bearer dev:${uid}:${uid}` }, body: JSON.stringify(body) }); return { status: r.status, data: await r.json() }; };
  await call("/profile", { username: "bobby" }, "bob");
  const fl = await call("/friends", {}, "alice"); const bob = (fl.data.friends || []).find(f => f.uid === "bob");
  ok(fl.status === 200 && bob && bob.username && bob.character?.parts?.head && bob.online === true && bob.inGame === true, "friends list has bob with his character, online and in game");
  ok(bob.joinable === true, "bob is joinable");
  ok((await call("/profile", { description: "I love building!" }, "bob")).data.profile?.description === "I love building!", "description saved");
  for (const bad of ["email me bob@gmail.com", "you are a f u c k", "send nudes", "kill yourself"]) { const r = await call("/profile", { description: bad }, "bob"); ok(r.status === 400, `description rejected: ${bad}`); }
  ok((await call("/friends", {}, "alice")).data.friends.find(f => f.uid === "bob").description === "I love building!", "friends see the description");
  ok((await call("/friend-chat", { action: "send", with: "bob", text: "hi bob" }, "alice")).status === 403, "can't message someone who blocked you");
  B.send({ t:"block", id: wa.id, on:false }); await sleep(200);
  ok((await call("/friend-chat", { action: "send", with: "bob", text: "hi bob" }, "alice")).status === 200, "friend chat message sent");
  ok((await call("/friend-chat", { action: "list", with: "alice" }, "bob")).data.messages.some(m => m.text === "hi bob" && m.from === "alice"), "friend receives it");
  const masked = await call("/friend-chat", { action: "send", with: "bob", text: "what the f*ck" }, "alice");
  ok(masked.status === 200 && masked.data.message.text.includes("#") && !masked.data.message.text.includes("f*ck"), "friend chat is filtered like game chat");
  for (const bad of ["mail me x@y.com", "kill yourself", "dont tell your mom"]) ok((await call("/friend-chat", { action: "send", with: "bob", text: bad }, "alice")).status === 400, `friend chat blocks: ${bad}`);
  ok((await call("/friend-chat", { action: "send", with: "zed", text: "hello" }, "alice")).status === 403, "only friends can chat");
  B.send({ t:"block", id: wa.id, on:true }); await sleep(200);

  console.log("app sign-in link (Continue with Google in the native app)");
  const post = (path, body, tok) => fetch(base + path, { method: "POST", headers: { "Content-Type": "application/json", ...(tok ? { Authorization: "Bearer " + tok } : {}) }, body: JSON.stringify(body) });
  const st = await (await post("/auth/device/start", {})).json();
  ok(/^[0-9a-f]{32}$/.test(st.code) && /^[A-Z2-9]{3}-[A-Z2-9]{3}$/.test(st.userCode) && st.secret && st.secret !== st.code, "start returns a link code, a separate poll secret and a short confirm code");
  ok((await (await post("/auth/device/info", { code: st.code })).json()).userCode === st.userCode, "website can read the confirm code from the link code");
  ok((await (await post("/auth/device/poll", { secret: st.secret })).json()).status === "pending", "poll is pending before approval");
  ok((await post("/auth/device/poll", { secret: st.code })).status === 404, "the link code can't be used as the poll secret");
  ok((await post("/auth/device/approve", { code: st.code })).status === 401, "approve needs a signed-in user");
  ok((await post("/auth/device/approve", { code: "0".repeat(32) }, "dev:zed:zed")).status === 404, "approve with an unknown code fails");
  ok((await post("/auth/device/approve", { code: st.code }, "dev:zed:zed")).status === 200, "signed-in user approves the code");
  const done = await (await post("/auth/device/poll", { secret: st.secret })).json();
  ok(done.status === "ok" && done.customToken === "dev-custom:zed", "app collects the token for the approving user");
  ok((await post("/auth/device/poll", { secret: st.secret })).status === 404, "token can only be collected once");

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
