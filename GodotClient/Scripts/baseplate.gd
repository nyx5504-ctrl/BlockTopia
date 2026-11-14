extends Node3D
## BASEPLATE: the one BlockTopia game. World is built in code; players and chat come from the server.
const HALF := 250.0
var local: LocalPlayer
var remotes := {}            # id -> {node: Avatar, target: Vector3, ry: float}
var chat: ChatUI
var pause: PauseMenu
var touch: TouchControls
var overlay: Label
var plist: PlayerList
var world: WorldBuilder
var sun: DirectionalLight3D
var toast: PanelContainer
var toast_label: Label
var _toast_id := 0
var _send_t := 0.0
var _leaving := false
var _selftest := "--selftest" in OS.get_cmdline_user_args() or "--selftest" in OS.get_cmdline_args()
var _fatal := false
var _shotdir := ""

func _ready() -> void:
	world = WorldBuilder.new(); add_child(world); world.build(); sun = world.sun
	_build_ui()
	Settings.changed.connect(_apply_quality); _apply_quality()
	Net.chat_received.connect(_on_chat_bubble); Net.friend_result.connect(func(ok, t): _toast(t); chat.system(t, "#8be28b" if ok else "#e8b33c"))
	Net.welcomed.connect(_on_welcome); Net.player_joined.connect(_add_remote)
	Net.player_left.connect(_on_left); Net.snapshot.connect(_on_snapshot)
	Net.respawned.connect(func(p, _e): local.teleport(p)); Net.corrected.connect(func(p, _e): local.teleport(p))
	Net.kicked.connect(func(r): _fatal = true; _show("You were removed from the game (%s)." % r))
	Net.disconnected.connect(_on_disconnected); Net.reconnecting.connect(func(a): _show("Connection lost. Reconnecting (%d)..." % a))
	if Net.state == "idle":
		if Settings.launch.has("code"): _show("Connecting to BlockTopia..."); Net.connect_with_code(Settings.launch.ws, Settings.launch.code)
		else: _show("No launch info. Press PLAY on the BlockTopia website."); _fatal = true

func _apply_quality() -> void:
	var q := Settings.quality
	sun.shadow_enabled = q >= 1
	get_viewport().msaa_3d = Viewport.MSAA_2X if q >= 2 else Viewport.MSAA_DISABLED
	sun.directional_shadow_max_distance = 140.0 if q >= 2 else 80.0

# ---------------- UI ----------------
func _build_ui() -> void:
	chat = ChatUI.new(); add_child(chat)
	pause = PauseMenu.new(); add_child(pause)
	plist = PlayerList.new(); add_child(plist)
	chat.menu_pressed.connect(func(): pause.toggle())
	pause.leave_requested.connect(_leave); pause.respawn_requested.connect(func(): Net.request_respawn())
	if Settings.is_mobile():
		var tl := CanvasLayer.new(); tl.layer = 3; add_child(tl); touch = TouchControls.new(); tl.add_child(touch)
		touch.is_ui = _touch_on_ui
	var hud := CanvasLayer.new(); hud.layer = 8; add_child(hud)
	toast = PanelContainer.new(); toast.set_anchors_preset(Control.PRESET_CENTER_TOP); toast.position = Vector2(-170, 16); toast.custom_minimum_size = Vector2(340, 0); toast.visible = false; toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_label = Label.new(); toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; toast.add_child(toast_label); hud.add_child(toast)
	var ol := CanvasLayer.new(); ol.layer = 20; add_child(ol)
	overlay = Label.new(); overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; overlay.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overlay.add_theme_font_size_override("font_size", 26); overlay.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var bg := ColorRect.new(); bg.color = Color(0.04, 0.04, 0.05, 0.92); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); overlay.add_child(bg); bg.show_behind_parent = true
	ol.add_child(overlay)

func _touch_on_ui(p: Vector2) -> bool:
	if pause.visible or overlay.visible or _leaving: return true
	for ctl in [chat.menu_btn, chat.chat_btn, chat.window, plist.panel, plist.popup]:
		if ctl != null and ctl.is_visible_in_tree() and ctl.get_global_rect().has_point(p): return true
	return false

func _toast(t: String) -> void:
	toast_label.text = t; toast.visible = true; _toast_id += 1; var me := _toast_id
	await get_tree().create_timer(3.2).timeout
	if me == _toast_id: toast.visible = false

func _show(t: String) -> void:
	overlay.text = t; overlay.visible = true
	if _fatal and not has_node("OverlayBack"):
		var b := Button.new(); b.name = "OverlayBack"; b.text = "Back to BlockTopia"; b.set_anchors_preset(Control.PRESET_CENTER); b.position = Vector2(-110, 70); b.custom_minimum_size = Vector2(220, 46)
		b.pressed.connect(_exit_game); overlay.add_child(b)

func _unhandled_input(e: InputEvent) -> void:
	if overlay.visible or _leaving: return
	if e.is_action_pressed("menu"): pause.toggle()
	elif e.is_action_pressed("chat") and not chat.typing and not pause.visible: chat.open(); get_viewport().set_input_as_handled()

# ---------------- network events ----------------
func _on_welcome(m: Dictionary) -> void:
	overlay.visible = false
	for id in remotes.keys(): remotes[id].node.queue_free()
	remotes.clear()
	if local == null:
		local = LocalPlayer.new(); add_child(local); local.setup(Net.my_name, Color(str(m.get("color", "#ffffff")))); local.touch = touch
	local.teleport(Vector3(m.x, m.y, m.z))
	for p in m.players: _add_remote(p)
	chat.system("Welcome to Baseplate, %s! %s" % [Net.my_name, "Drag the right side of the screen to look around." if Settings.is_mobile() else "Hold the right mouse button to look around. Click a name in the player list for options."])
	if _selftest: _run_selftest()

func _add_remote(p: Dictionary) -> void:
	var id := int(p.id)
	if id == Net.my_id or remotes.has(id): return
	var av := Avatar.new(); add_child(av); av.setup(str(p.name), Color(str(p.get("color", "#ffffff"))))
	var pos := Vector3(p.x, p.y, p.z); av.position = pos
	remotes[id] = {"node": av, "target": pos, "ry": float(p.get("ry", 0.0)), "speed": 0.0}
	chat.system("%s joined." % p.name)

func _on_chat_bubble(id: int, _n: String, text: String) -> void:
	if id == Net.my_id and local: local.avatar.say(text)
	elif remotes.has(id): remotes[id].node.say(text)

func _on_left(id: int, pname: String) -> void:
	if remotes.has(id): remotes[id].node.queue_free(); remotes.erase(id)
	if pname != "": chat.system("%s left." % pname)

func _on_snapshot(list: Array) -> void:
	for s in list:
		var id := int(s[0])
		if remotes.has(id):
			var r = remotes[id]; var nt := Vector3(s[1], s[2], s[3]); r.speed = lerpf(r.speed, Vector2(nt.x - r.target.x, nt.z - r.target.z).length() / 0.066, 0.5); r.target = nt; r.ry = float(s[4]); r.node.anim = str(s[5]); r.node.speed = r.speed

func _on_disconnected(reason: String) -> void:
	if _leaving: _exit_game(); return
	_fatal = true; _show(reason if reason != "" else "Disconnected.")

# ---------------- leaving ----------------
func _leave() -> void:
	if _leaving: return
	_leaving = true; pause.close(); _show("Leaving game..."); await Net.leave()

func _exit_game() -> void:
	Net.state = "idle"
	var was_protocol := Settings.protocol_launched
	Settings.launch = {}
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if was_protocol and not _selftest and (OS.has_feature("windows") or OS.has_feature("linux") or OS.has_feature("macos")):
		get_tree().quit()          # client was launched specifically for this session -> close it
	elif _selftest: get_tree().quit()
	else: get_tree().change_scene_to_file("res://Scenes/Home.tscn")

# ---------------- per-frame ----------------
func _process(delta: float) -> void:
	world.animate(delta)
	for id in remotes:
		var r = remotes[id]; var n: Avatar = r.node
		n.position = n.position.lerp(r.target, 1.0 - exp(-14.0 * delta)); n.rotation.y = lerp_angle(n.rotation.y, r.ry, 1.0 - exp(-14.0 * delta))
	if local == null: return
	local.blocked = pause.visible or chat.typing or overlay.visible or _leaving
	if local.blocked and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE; local.rmb = false
	if local.global_position.y < -50.0: Net.request_respawn()
	_send_t += delta
	if _send_t >= 0.066 and Net.state == "online": _send_t = 0.0; Net.send_pos(local.global_position, local.avatar.rotation.y, local.anim)

# ---------------- headless self-test (used by Backend/test and CI) ----------------
func _run_selftest() -> void:
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--shotdir="): _shotdir = str(a).substr(10)
	if _shotdir != "": await _run_shots(); return
	await get_tree().create_timer(0.5).timeout
	local.test_move = Vector2(0, -1)                       # walk forward
	await get_tree().create_timer(1.5).timeout
	local.test_move = Vector2.ZERO
	Net.send_chat("hello from godot")
	await get_tree().create_timer(1.0).timeout
	print("SELFTEST position=", local.global_position, " players=", Net.players.size())
	await _leave()

func _snap(name: String) -> void:
	await get_tree().process_frame; await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_shotdir, name]); print("SHOT ", name)

func _run_shots() -> void:      # used by Backend/test/shots.mjs to review visuals under xvfb
	await get_tree().create_timer(1.2).timeout
	chat.window.visible = true
	await _snap("1_spawn")
	local.test_move = Vector2(0, -1); await get_tree().create_timer(0.9).timeout
	await _snap("2_run")
	local.test_move = Vector2.ZERO; local.yaw = PI * 0.85; local.pitch = -0.05; Settings.cam_distance = 5.0; await get_tree().create_timer(0.6).timeout
	Net.send_chat("Hello from the Godot client!"); await get_tree().create_timer(0.8).timeout
	await _snap("3_closeup")
	Settings.cam_distance = 120.0; local.pitch = -0.75; local.yaw = 0.0; await get_tree().create_timer(0.8).timeout
	await _snap("4_overview")
	Settings.cam_distance = 150.0; local.yaw = 2.6; local.pitch = -0.35; await get_tree().create_timer(0.8).timeout
	await _snap("5_outer")
	Settings.cam_distance = 6.0; local.yaw = 2.585; local.pitch = 0.6; await get_tree().create_timer(0.8).timeout
	await _snap("6_sun")
	await _leave()
