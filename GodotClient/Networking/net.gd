extends Node
## WebSocket client for the BlockTopia game server (see /Backend). Handles auth, reconnects and messages.
signal welcomed(msg: Dictionary)
signal player_joined(p: Dictionary)
signal player_left(id: int, pname: String)
signal snapshot(list: Array)
signal chat_received(id: int, pname: String, text: String)
signal chat_blocked(text: String)
signal respawned(pos: Vector3, epoch: int)
signal corrected(pos: Vector3, epoch: int)
signal kicked(reason: String)
signal disconnected(reason: String)
signal reconnecting(attempt: int)
signal system_message(text: String)
signal mute_changed(id: int, on: bool)
signal report_done
signal friend_result(ok: bool, text: String)
signal scores_changed

var ws := WebSocketPeer.new()
var url := ""
var code := ""
var session := ""
var my_id := -1
var my_name := ""
var epoch := 0
var players := {}     # id -> {id, name, color}
var muted := {}       # id -> true (session mute)
var blocked := {}     # id -> true (persistent block)
var scores := {}      # id -> score
var state := "idle"   # idle | connecting | online | reconnecting
var intentional := false
var _attempt := 0
var _retry_at := 0.0
var _auth_sent := false
var _t0 := 0.0

func connect_with_code(u: String, c: String) -> void:
	url = u; code = c; session = ""; intentional = false; _attempt = 0
	players = {}; muted = {}; blocked = {}; scores = {}; state = "connecting"
	_open()

func _open() -> void:
	ws = WebSocketPeer.new()
	_auth_sent = false; _t0 = Time.get_ticks_msec() / 1000.0
	if ws.connect_to_url(url) != OK:
		_closed("Couldn't connect to the server.")

func _process(_d: float) -> void:
	if state == "idle": return
	if state == "reconnecting" and ws.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		if Time.get_ticks_msec() / 1000.0 >= _retry_at: _open(); state = "reconnecting"
		return
	ws.poll()
	match ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not _auth_sent:
				_auth_sent = true
				_send({"t": "auth", "session": session} if session != "" else {"t": "auth", "code": code})
			while ws.get_available_packet_count() > 0:
				_handle(ws.get_packet().get_string_from_utf8())
		WebSocketPeer.STATE_CONNECTING:
			if Time.get_ticks_msec() / 1000.0 - _t0 > 12.0: ws.close(); _closed("Connection timed out.")
		WebSocketPeer.STATE_CLOSED:
			_closed(ws.get_close_reason())

func _closed(reason: String) -> void:
	if state == "idle": return
	var was_online := state == "online" or state == "reconnecting"
	var cc := ws.get_close_code()
	if intentional or not was_online or cc == 4001 or session == "":
		state = "idle"
		disconnected.emit(reason if reason != "" else ("Disconnected." if intentional else "Couldn't connect to the server."))
		return
	_attempt += 1
	if _attempt > 6:
		state = "idle"; disconnected.emit("Connection lost."); return
	state = "reconnecting"; _retry_at = Time.get_ticks_msec() / 1000.0 + minf(_attempt * 1.0, 5.0)
	reconnecting.emit(_attempt)

func _send(d: Dictionary) -> void:
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN: ws.send_text(JSON.stringify(d))

func _handle(txt: String) -> void:
	var m = JSON.parse_string(txt)
	if typeof(m) != TYPE_DICTIONARY: return
	match str(m.get("t", "")):
		"welcome":
			state = "online"; _attempt = 0
			my_id = int(m.id); my_name = str(m.get("name", "")); session = str(m.session); epoch = int(m.e)
			players = {my_id: {"id": my_id, "name": my_name, "color": m.get("color", "#ffffff")}}
			for p in m.players: players[int(p.id)] = p
			for id in players: scores[id] = int(players[id].get("score", 0))
			welcomed.emit(m)
		"join":
			var p: Dictionary = m.player; players[int(p.id)] = p; scores[int(p.id)] = int(p.get("score", 0)); player_joined.emit(p)
		"leave":
			players.erase(int(m.id)); scores.erase(int(m.id)); muted.erase(int(m.id)); blocked.erase(int(m.id)); player_left.emit(int(m.id), str(m.get("name", "")))
		"snap": snapshot.emit(m.p)
		"chat": chat_received.emit(int(m.id), str(m.name), str(m.text))
		"chat_blocked":
			if str(m.get("text", "")) != "": chat_blocked.emit(str(m.text))
		"respawn":
			epoch = int(m.e); respawned.emit(Vector3(m.x, m.y, m.z), epoch)
		"correct":
			corrected.emit(Vector3(m.x, m.y, m.z), epoch)
		"kicked":
			intentional = true; kicked.emit(str(m.get("reason", "")))
		"sys": system_message.emit(str(m.get("text", "")))
		"mute_ok":
			var d := blocked if m.get("blocked", false) else muted
			if m.on: d[int(m.id)] = true
			else: d.erase(int(m.id))
			mute_changed.emit(int(m.id), bool(m.on))
		"scores":
			for s in m.s: scores[int(s[0])] = int(s[1])
			scores_changed.emit()
		"friend_result": friend_result.emit(bool(m.get("ok", false)), str(m.get("text", "")))
		"report_ok": report_done.emit()

func send_pos(p: Vector3, ry: float, anim: String) -> void:
	if state == "online": _send({"t": "pos", "x": p.x, "y": p.y, "z": p.z, "ry": ry, "a": anim, "e": epoch})
func send_chat(text: String) -> void: _send({"t": "chat", "text": text})
func request_respawn() -> void: _send({"t": "respawn"})
func set_mute(id: int, on: bool) -> void: _send({"t": "mute", "id": id, "on": on})
func send_friend(id: int) -> void: _send({"t": "friend", "id": id})
func set_block(id: int, on: bool) -> void: _send({"t": "block", "id": id, "on": on})
func report(id: int, reason: String) -> void: _send({"t": "report", "id": id, "reason": reason})

func leave() -> void:
	intentional = true
	_send({"t": "leave"})
	await get_tree().create_timer(0.25).timeout
	if state != "idle":
		ws.close(); state = "idle"; disconnected.emit("Left the game.")
