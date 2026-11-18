extends Node3D
## BASEPLATE: the one BlockTopia game. World is built in code; players and chat come from the server.
const HALF := 250.0
var local: LocalPlayer
var remotes := {}            # id -> {node: Avatar, target: Vector3, ry: float}
var chat: ChatUI
var pause: PauseMenu
var touch: TouchControls
var fprompt: FriendPrompt
var overlay: Control
var overlay_text: Label
var overlay_back: Button
var plist: PlayerList
var perf: PerfPanel
var hud: CanvasLayer
var world: WorldBuilder
var sun: DirectionalLight3D
var toast: PanelContainer
var toast_label: Label
var update_notice: Button
var _toast_id := 0
var _send_t := 0.0
var _leaving := false
var _selftest := "--selftest" in OS.get_cmdline_user_args() or "--selftest" in OS.get_cmdline_args()
var _fatal := false
var _shotdir := ""

func _ready() -> void:
	ThemeBuilder.apply_to(get_tree(), false)       # the game always stays dark
	world = WorldBuilder.new(); add_child(world); world.build(); sun = world.sun
	_build_ui()
	Settings.changed.connect(_apply_quality); _apply_quality()
	Settings.changed.connect(func(): if local != null and not Settings.shift_lock_enabled and local.shift_lock: local.set_shift_lock(false))
	Settings.app_update_available.connect(_on_app_update_available)
	if Settings.update_available: _on_app_update_available(Settings.update_version)
	Settings.check_for_app_update()
	Net.chat_received.connect(_on_chat_bubble); Net.friend_result.connect(func(ok, t): _toast(t); chat.system(t, "#8be28b" if ok else "#e8b33c"))
	Net.welcomed.connect(_on_welcome); Net.player_joined.connect(_add_remote)
	Net.player_left.connect(_on_left); Net.snapshot.connect(_on_snapshot)
	Net.character_updated.connect(_on_character_updated); Net.player_character_changed.connect(_on_player_character_changed)
	Net.respawned.connect(func(p, _e): local.teleport(p)); Net.corrected.connect(func(p, _e): local.teleport(p))
	Net.kicked.connect(func(r): _fatal = true; _show("You were removed from the game (%s)." % r))
	Net.disconnected.connect(_on_disconnected); Net.reconnecting.connect(func(a): _show("Connection lost. Reconnecting (%d)..." % a))
	if Net.state == "idle":
		if Settings.launch.has("code"): _show("Connecting to BlockTopia..."); Net.connect_with_code(Settings.launch.ws, Settings.launch.code)
		else: _fatal = true; _show("Sign in and choose Play from the dashboard.")

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
	fprompt = FriendPrompt.new(); add_child(fprompt)
	chat.menu_pressed.connect(func(): pause.toggle())
	pause.leave_requested.connect(_leave); pause.respawn_requested.connect(func(): Net.request_respawn())
	plist.report_requested.connect(func(id): pause.open_report(id))
	if Settings.is_mobile():
		var tl := CanvasLayer.new(); tl.layer = 3; add_child(tl); touch = TouchControls.new(); tl.add_child(touch)
		touch.is_ui = _touch_on_ui
	hud = CanvasLayer.new(); hud.layer = 8; add_child(hud)
	if Settings.is_pc():
		perf = PerfPanel.new(); perf.position = Vector2(12, 66); hud.add_child(perf)
	toast = PanelContainer.new(); toast.set_anchors_preset(Control.PRESET_CENTER_TOP); toast.position = Vector2(-170, 16); toast.custom_minimum_size = Vector2(340, 0); toast.visible = false; toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_label = Label.new(); toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; toast.add_child(toast_label); hud.add_child(toast)
	update_notice = Button.new(); update_notice.text = "Update available — tap to download"; update_notice.set_anchors_preset(Control.PRESET_TOP_RIGHT); update_notice.position = Vector2(-342, 18); update_notice.custom_minimum_size = Vector2(324, 46); update_notice.visible = false; update_notice.pressed.connect(func(): OS.shell_open(Settings.update_url)); hud.add_child(update_notice)
	var ol := CanvasLayer.new(); ol.layer = 20; add_child(ol)
	overlay = Control.new(); overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); ol.add_child(overlay)
	var background := TextureRect.new(); background.texture = load("res://Assets/baseplate.png"); background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); background.mouse_filter = Control.MOUSE_FILTER_IGNORE; overlay.add_child(background)
	var shade := ColorRect.new(); shade.color = Color(0.025, 0.03, 0.05, 0.72); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); shade.mouse_filter = Control.MOUSE_FILTER_IGNORE; overlay.add_child(shade)
	var center := CenterContainer.new(); center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); overlay.add_child(center)
	var stack := VBoxContainer.new(); stack.add_theme_constant_override("separation", 12); stack.custom_minimum_size = Vector2(280, 0); stack.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; center.add_child(stack)
	var game_icon := TextureRect.new(); game_icon.texture = load("res://Assets/icon.svg"); game_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; game_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; game_icon.custom_minimum_size = Vector2(104, 104); game_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; stack.add_child(game_icon)
	var game_name := Label.new(); game_name.text = "BASEPLATE"; game_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; game_name.add_theme_font_size_override("font_size", 30); stack.add_child(game_name)
	var creator := Label.new(); creator.text = "By BlockTopia"; creator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; creator.modulate = Color(1, 1, 1, 0.72); creator.add_theme_font_size_override("font_size", 17); stack.add_child(creator)
	overlay_text = Label.new(); overlay_text.text = "Loading game…"; overlay_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; overlay_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; overlay_text.add_theme_font_size_override("font_size", 18); stack.add_child(overlay_text)

func _on_app_update_available(version: String) -> void:
	if update_notice == null: return
	update_notice.text = "Update %s available — tap to download" % version
	update_notice.visible = true

func _touch_on_ui(p: Vector2) -> bool:
	if pause.visible or overlay.visible or _leaving: return true
	if fprompt != null and fprompt.covers(p): return true
	for ctl in [chat.menu_btn, chat.chat_btn, chat.window, plist.panel, plist.popup, update_notice, perf]:
		if ctl != null and ctl.is_visible_in_tree() and ctl.get_global_rect().has_point(p): return true
	return false

func _toast(t: String) -> void:
	toast_label.text = t; toast.visible = true; _toast_id += 1; var me := _toast_id
	await get_tree().create_timer(3.2).timeout
	if me == _toast_id: toast.visible = false

func _show(t: String) -> void:
	overlay_text.text = t; overlay.visible = true
	if _fatal:
		if overlay_back == null:
			overlay_back = Button.new(); overlay_back.text = "Back to dashboard"; overlay_back.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
			overlay_back.position = Vector2(-120, -28); overlay_back.custom_minimum_size = Vector2(240, 50); overlay_back.pressed.connect(_exit_game); overlay.add_child(overlay_back)
		overlay_back.visible = true
	elif overlay_back != null:
		overlay_back.visible = false

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
		local = LocalPlayer.new(); add_child(local); local.setup(Net.my_name, Color(str(m.get("color", "#ffffff"))), m.get("character", {})); local.touch = touch
		local.shift_lock_changed.connect(func(on): _toast("Shift Lock on" if on else "Shift Lock off"))
	local.teleport(Vector3(m.x, m.y, m.z))
	for p in m.players: _add_remote(p)
	chat.system("Welcome to Baseplate, %s! %s" % [Net.my_name, "Drag the right side of the screen to look around." if Settings.is_mobile() else "Hold the right mouse button to look around. Click a name in the player list for options."])
	if _selftest: _run_selftest()

func _add_remote(p: Dictionary) -> void:
	var id := int(p.id)
	if id == Net.my_id or remotes.has(id): return
	var av := Avatar.new(); add_child(av); av.setup(str(p.name), Color(str(p.get("color", "#ffffff"))), p.get("character", {}))
	var pos := Vector3(p.x, p.y, p.z); av.position = pos
	remotes[id] = {"node": av, "target": pos, "ry": float(p.get("ry", 0.0)), "speed": 0.0}
	chat.system("%s joined." % p.name)

func _on_chat_bubble(id: int, _n: String, text: String) -> void:
	if id == Net.my_id and local: local.avatar.say(text)
	elif remotes.has(id): remotes[id].node.say(text)

func _on_character_updated(character: Dictionary) -> void:
	if local != null and local.avatar != null: local.avatar.apply_character(character)
	if plist != null: plist.refresh()

func _on_player_character_changed(id: int, character: Dictionary) -> void:
	if remotes.has(id): remotes[id].node.apply_character(character)
	if plist != null: plist.refresh()

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
	if perf != null:       # sits under the menu/chat buttons, and under the chat window while that is open
		perf.visible = Settings.performance
		perf.position = Vector2(12, (chat.window.position.y + chat.window.size.y + 8.0) if chat.window.visible else 66.0)
	for id in remotes:
		var r = remotes[id]; var n: Avatar = r.node
		n.position = n.position.lerp(r.target, 1.0 - exp(-14.0 * delta)); n.rotation.y = lerp_angle(n.rotation.y, r.ry, 1.0 - exp(-14.0 * delta))
	if local == null: return
	local.blocked = pause.visible or chat.typing or overlay.visible or _leaving
	if local.blocked: local.rmb = false
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
	Settings.performance = true; await get_tree().create_timer(5.0).timeout
	perf._toggle("mem"); await _snap("1b_perf_memory"); perf._toggle("cpu"); await _snap("1c_perf_cpu"); perf._toggle("cpu")
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
	Settings.cam_distance = 6.0; local.yaw = 0.0; local.pitch = -0.25; Settings.performance = true; Settings.shift_lock_enabled = true
	plist._open_popup(Net.players.keys().filter(func(i): return i != Net.my_id)[0], plist._row_nodes[Net.players.keys().filter(func(i): return i != Net.my_id)[0]]); await _snap("6b_leaderboard_popup"); plist.popup.visible = false
	fprompt._on_request(Net.players.keys().filter(func(i): return i != Net.my_id)[0], "Alice"); fprompt._on_request(99, "Bob_the_Builder"); await get_tree().create_timer(0.3).timeout; await _snap("6c_friend_request")
	local.set_shift_lock(true); local.yaw = 0.4; Settings.cam_distance = 7.0; await get_tree().create_timer(0.8).timeout; await _snap("6d_shift_lock"); local.set_shift_lock(false)
	pause.open(); await _snap("7_menu_players")
	pause.open_report(Net.players.keys().filter(func(i): return i != Net.my_id)[0]); await _snap("8_menu_report")
	pause.show_page("Settings"); await _snap("10_menu_settings")
	pause.show_page("Help"); await _snap("11_menu_help")
	pause.close()
	await _leave()
