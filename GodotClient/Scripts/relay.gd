class_name Relay
extends Node
## One BlockTopia client at a time (desktop). The first client listens on 127.0.0.1:PORT. When you press Play on the website the OS starts
## the registered exe with a blocktopia:// link; if a client is already open, that new process hands the link over to it (see try_forward)
## and quits, and the open client joins the game. Only loopback connections are accepted and only a valid blocktopia:// play link is acted on
## (the same single-use launch code as before), so web pages cannot trigger anything.
const PORT := 47651
var server := TCPServer.new()
var _clients: Array = []       # [{peer, buf, t}]

## Called by a freshly started client holding a link. Returns true when an already-open client accepted it (then this process should quit).
static func try_forward(link: String) -> bool:
	var peer := StreamPeerTCP.new()
	if peer.connect_to_host("127.0.0.1", PORT) != OK: return false
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 700:
		peer.poll()
		if peer.get_status() == StreamPeerTCP.STATUS_CONNECTED: break
		if peer.get_status() == StreamPeerTCP.STATUS_ERROR: return false
		OS.delay_msec(10)
	if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED: return false
	peer.put_data((link + "\n").to_utf8_buffer())
	start = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 1500:
		peer.poll()
		if peer.get_available_bytes() > 0:
			var reply := peer.get_utf8_string(peer.get_available_bytes())
			peer.disconnect_from_host()
			return reply.begins_with("ok")
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED: return false
		OS.delay_msec(10)
	return false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if server.listen(PORT, "127.0.0.1") != OK: set_process(false)      # port busy: just run without the hand-over

func _process(_d: float) -> void:
	while server.is_connection_available():
		_clients.append({"peer": server.take_connection(), "buf": "", "t": Time.get_ticks_msec()})
	for c in _clients.duplicate():
		var peer: StreamPeerTCP = c.peer
		peer.poll()
		if peer.get_available_bytes() > 0:
			c.buf += peer.get_utf8_string(mini(peer.get_available_bytes(), 4096))
		var done: bool = "\n" in c.buf or c.buf.length() >= 2048 or peer.get_status() != StreamPeerTCP.STATUS_CONNECTED or Time.get_ticks_msec() - c.t > 3000
		if not done: continue
		var link := str(c.buf).split("\n")[0].strip_edges()
		var ok := link.begins_with("blocktopia://") and Settings.parse_link(link)
		if peer.get_status() == StreamPeerTCP.STATUS_CONNECTED: peer.put_data(("ok\n" if ok else "no\n").to_utf8_buffer())
		peer.disconnect_from_host(); _clients.erase(c)
		if ok: _join_launch()

func _join_launch() -> void:
	DisplayServer.window_move_to_foreground()
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	if Net.state != "idle":                        # already in a game: drop it quietly and join the new one
		Net.intentional = true
		if Net.ws != null: Net.ws.close()
		Net.state = "idle"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://Scenes/Baseplate.tscn")
