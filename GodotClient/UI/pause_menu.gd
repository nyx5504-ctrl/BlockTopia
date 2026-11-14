class_name PauseMenu
extends CanvasLayer
## Roblox-style game menu: tabs on top (Players / Chat / Emotes / Settings / Help), big Resume / Respawn / Leave buttons at the bottom.
## Players: add friend, mute, block, report. Chat: read and send messages without leaving the menu. Emotes: wave, dance, cheer, laugh.
## Settings: graphics, audio, camera, touch, fullscreen, FPS counter, name tags, reset. The header shows players, ping and FPS.
signal leave_requested
signal respawn_requested
signal emote_requested(emote: String)
const REASONS := ["Inappropriate chat", "Harassment", "Cheating", "Other"]
const TABS := ["Players", "Chat", "Emotes", "Settings", "Help"]
const EMOTES := [["Wave", "wave"], ["Dance", "dance"], ["Cheer", "cheer"], ["Laugh", "laugh"]]
var root: Control
var panel: PanelContainer
var pages := {}
var tab_btns := {}
var players_list: VBoxContainer
var info_label: Label
var chat_log: RichTextLabel
var chat_in: LineEdit
var _stats_t := 0.0
var leave_btn: Button
var _leave_armed := false
var _leave_token := 0
var _mobile := false

func _ready() -> void:
	layer = 10; visible = false; _mobile = Settings.is_mobile()
	root = Control.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(root)
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.62); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_child(dim)
	panel = PanelContainer.new(); panel.set_anchors_preset(Control.PRESET_CENTER); root.add_child(panel)
	panel.add_theme_stylebox_override("panel", ThemeBuilder.box(Color(0.075, 0.075, 0.082, 1.0), Color(0.22, 0.22, 0.25), 16))
	var host := MarginContainer.new(); for s in ["left", "right", "top", "bottom"]: host.add_theme_constant_override("margin_" + s, 16 if _mobile else 20)
	panel.add_child(host)
	var stack := VBoxContainer.new(); stack.add_theme_constant_override("separation", 12); host.add_child(stack)
	# header
	var head := HBoxContainer.new(); head.add_theme_constant_override("separation", 10); stack.add_child(head)
	var title := Label.new(); title.text = "BlockTopia"; title.add_theme_font_size_override("font_size", 28); title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(title)
	info_label = Label.new(); info_label.modulate = Color(1, 1, 1, 0.6); head.add_child(info_label)
	var x := Button.new(); x.text = "X"; x.custom_minimum_size = Vector2(46, 46); x.pressed.connect(close); head.add_child(x)
	# tabs
	var tabs := HBoxContainer.new(); tabs.add_theme_constant_override("separation", 6); stack.add_child(tabs)
	var group := ButtonGroup.new()
	for t in TABS:
		var b := Button.new(); b.text = t; b.toggle_mode = true; b.button_group = group; b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; b.custom_minimum_size = Vector2(0, 50 if _mobile else 44); b.add_theme_font_size_override("font_size", 16 if _mobile else 18); b.clip_text = true
		var on := ThemeBuilder.box(Color(0.92, 0.92, 0.94), Color(0.92, 0.92, 0.94)); b.add_theme_stylebox_override("pressed", on); b.add_theme_stylebox_override("hover_pressed", on)
		b.add_theme_color_override("font_pressed_color", Color(0.05, 0.05, 0.06)); b.add_theme_color_override("font_hover_pressed_color", Color(0.05, 0.05, 0.06))
		b.pressed.connect(show_page.bind(t)); tabs.add_child(b); tab_btns[t] = b
	# pages
	var area := ScrollContainer.new(); area.size_flags_vertical = Control.SIZE_EXPAND_FILL; area.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; stack.add_child(area)
	var pv := VBoxContainer.new(); pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; area.add_child(pv)
	_players_page(pv); _chat_page(pv); _emotes_page(pv); _settings_page(pv); _help_page(pv)
	# footer
	var foot := HBoxContainer.new(); foot.add_theme_constant_override("separation", 8); stack.add_child(foot)
	_foot_btn(foot, "Resume", close)
	_foot_btn(foot, "Respawn", func(): respawn_requested.emit(); close())
	leave_btn = _foot_btn(foot, "Leave Game", _on_leave)
	var red := ThemeBuilder.box(Color(0.55, 0.14, 0.14), Color(0.7, 0.2, 0.2)); leave_btn.add_theme_stylebox_override("normal", red)
	leave_btn.add_theme_stylebox_override("hover", ThemeBuilder.box(Color(0.66, 0.17, 0.17), Color(0.8, 0.25, 0.25))); leave_btn.add_theme_stylebox_override("pressed", ThemeBuilder.box(Color(0.45, 0.1, 0.1), Color(0.7, 0.2, 0.2)))
	get_viewport().size_changed.connect(_fit); _fit()
	Net.player_joined.connect(func(_p): if visible: _refresh_players())
	Net.player_left.connect(func(_i, _n): if visible: _refresh_players())
	Net.mute_changed.connect(func(_i, _o): if visible: _refresh_players())
	Net.scores_changed.connect(func(): if visible: _refresh_players())
	Net.report_done.connect(func(): if visible: _refresh_players())
	Net.chat_received.connect(_on_chat); Net.chat_blocked.connect(func(t): _log_line("[color=#e8b33c]%s[/color]" % _esc(t))); Net.system_message.connect(func(t): _log_line("[color=#9a9aa2]%s[/color]" % _esc(t)))
	show_page("Players")

func _foot_btn(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new(); b.text = text; b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; b.custom_minimum_size = Vector2(0, 58 if _mobile else 50); b.pressed.connect(cb); parent.add_child(b); return b

func _fit() -> void:
	var vs := get_viewport().get_visible_rect().size
	var w := clampf(vs.x * 0.94, 320.0, 760.0); var h := clampf(vs.y * 0.92, 300.0, 640.0)
	panel.custom_minimum_size = Vector2(w, h); panel.size = Vector2(w, h)
	panel.position = (vs - panel.size) / 2.0

func _on_leave() -> void:        # two taps so a stray tap on a phone doesn't drop you out of the game
	if _leave_armed: _leave_armed = false; leave_requested.emit(); return
	_leave_armed = true; leave_btn.text = "Tap again to leave"; _leave_token += 1; var me := _leave_token
	await get_tree().create_timer(3.0).timeout
	if me == _leave_token: _leave_armed = false; leave_btn.text = "Leave Game"

# ---------------- Players ----------------
func _players_page(parent: Node) -> void:
	players_list = VBoxContainer.new(); players_list.add_theme_constant_override("separation", 8); players_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; parent.add_child(players_list); pages["Players"] = players_list

func _small_btn(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new(); b.text = text; b.custom_minimum_size = Vector2(0, 42); b.add_theme_font_size_override("font_size", 16); b.pressed.connect(cb); parent.add_child(b); return b

func _refresh_players() -> void:
	for c in players_list.get_children(): c.queue_free()
	var ids := Net.players.keys()
	ids.sort_custom(func(a, b): return Net.scores.get(a, 0) > Net.scores.get(b, 0) or (Net.scores.get(a, 0) == Net.scores.get(b, 0) and a < b))
	for id in ids:
		var info: Dictionary = Net.players[id]
		var card := PanelContainer.new(); card.add_theme_stylebox_override("panel", ThemeBuilder.box(Color(0.105, 0.105, 0.115), Color(0.2, 0.2, 0.22), 12)); players_list.add_child(card)
		var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 8); card.add_child(v)
		var top := HBoxContainer.new(); top.add_theme_constant_override("separation", 10); v.add_child(top)
		var sw := ColorRect.new(); sw.color = Color(str(info.get("color", "#ffffff"))); sw.custom_minimum_size = Vector2(16, 16); sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER; top.add_child(sw)
		var n := Label.new(); n.text = str(info.get("name", "?")) + ("  (you)" if id == Net.my_id else ""); n.size_flags_horizontal = Control.SIZE_EXPAND_FILL; n.clip_text = true; n.add_theme_font_size_override("font_size", 20)
		if id == Net.my_id: n.add_theme_color_override("font_color", Color("ffe27a"))
		top.add_child(n)
		var sc := Label.new(); sc.text = "Score %d" % Net.scores.get(id, 0); sc.modulate = Color(1, 1, 1, 0.6); top.add_child(sc)
		if id == Net.my_id: continue
		var row := HFlowContainer.new(); row.add_theme_constant_override("h_separation", 8); row.add_theme_constant_override("v_separation", 8); v.add_child(row)
		_small_btn(row, "Add Friend", func(): Net.send_friend(id))
		_small_btn(row, "Unmute" if Net.muted.has(id) else "Mute", func(): Net.set_mute(id, not Net.muted.has(id)))
		_small_btn(row, "Unblock" if Net.blocked.has(id) else "Block", func(): Net.set_block(id, not Net.blocked.has(id)); _refresh_players())
		var rep := MenuButton.new(); rep.text = "Report"; rep.flat = false; rep.custom_minimum_size = Vector2(0, 42); rep.add_theme_font_size_override("font_size", 16)
		var pop := rep.get_popup(); for r in REASONS: pop.add_item(r)
		pop.id_pressed.connect(func(i): Net.report(id, REASONS[i]); rep.text = "Reported"); row.add_child(rep)

# ---------------- Chat ----------------
const NAME_COLORS := ["#fd7b7b", "#ffb86b", "#f7e26b", "#8be28b", "#6bd6e8", "#7aa7ff", "#c58bff", "#ff8bd0"]
func _esc(t: String) -> String: return t.replace("[", "[lb]")
func _log_line(bb: String) -> void:
	if chat_log: chat_log.append_text(bb + "\n")
func _on_chat(_id: int, pname: String, text: String) -> void:
	var col: String = NAME_COLORS[abs(pname.hash()) % NAME_COLORS.size()]
	_log_line("[color=%s][b]%s[/b][/color]: %s" % [col, _esc(pname), _esc(text)])

func _chat_page(parent: Node) -> void:
	var p := VBoxContainer.new(); p.add_theme_constant_override("separation", 8); p.size_flags_horizontal = Control.SIZE_EXPAND_FILL; p.custom_minimum_size = Vector2(0, 250 if _mobile else 330); parent.add_child(p); pages["Chat"] = p
	var bg := PanelContainer.new(); bg.size_flags_vertical = Control.SIZE_EXPAND_FILL; bg.add_theme_stylebox_override("panel", ThemeBuilder.box(Color(0.105, 0.105, 0.115), Color(0.2, 0.2, 0.22), 12)); p.add_child(bg)
	chat_log = RichTextLabel.new(); chat_log.bbcode_enabled = true; chat_log.scroll_following = true; chat_log.add_theme_font_size_override("normal_font_size", 17); chat_log.add_theme_font_size_override("bold_font_size", 17); bg.add_child(chat_log)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 6); p.add_child(row)
	chat_in = LineEdit.new(); chat_in.placeholder_text = "Type a message..."; chat_in.max_length = 150; chat_in.size_flags_horizontal = Control.SIZE_EXPAND_FILL; chat_in.custom_minimum_size = Vector2(0, 48)
	chat_in.text_submitted.connect(_send_chat); row.add_child(chat_in)
	var send := Button.new(); send.text = "Send"; send.custom_minimum_size = Vector2(90, 48); send.pressed.connect(func(): _send_chat(chat_in.text)); row.add_child(send)

func _send_chat(text: String) -> void:
	chat_in.clear()
	if text.strip_edges() != "": Net.send_chat(text)

# ---------------- Emotes ----------------
func _emotes_page(parent: Node) -> void:
	var p := VBoxContainer.new(); p.add_theme_constant_override("separation", 10); p.size_flags_horizontal = Control.SIZE_EXPAND_FILL; parent.add_child(p); pages["Emotes"] = p
	_section(p, "Emotes")
	var g := GridContainer.new(); g.columns = 2; g.add_theme_constant_override("h_separation", 10); g.add_theme_constant_override("v_separation", 10); g.size_flags_horizontal = Control.SIZE_EXPAND_FILL; p.add_child(g)
	for e in EMOTES:
		var b := Button.new(); b.text = e[0]; b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; b.custom_minimum_size = Vector2(0, 72 if _mobile else 64); b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(func(): emote_requested.emit(e[1]); close()); g.add_child(b)
	var t := Label.new(); t.text = "Everyone nearby sees your emote. Move to stop it."; t.modulate = Color(1, 1, 1, 0.55); t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; p.add_child(t)

# ---------------- Settings ----------------
func _section(parent: Node, text: String) -> void:
	var l := Label.new(); l.text = text.to_upper(); l.modulate = Color(1, 1, 1, 0.5); l.add_theme_font_size_override("font_size", 14); parent.add_child(l)

func _slider(parent: Node, label: String, lo: float, hi: float, step: float, val: float, cb: Callable) -> void:
	var l := Label.new(); l.text = label; parent.add_child(l)
	var s := HSlider.new(); s.min_value = lo; s.max_value = hi; s.step = step; s.value = val; s.custom_minimum_size = Vector2(0, 34 if _mobile else 26)
	s.value_changed.connect(func(v): cb.call(v); Settings.save_cfg(); Settings.changed.emit()); parent.add_child(s)

func _check(parent: Node, text: String, val: bool, cb: Callable) -> void:
	var c := CheckButton.new(); c.text = text; c.button_pressed = val; c.custom_minimum_size = Vector2(0, 46)
	c.toggled.connect(func(on): cb.call(on); Settings.save_cfg(); Settings.changed.emit()); parent.add_child(c)

func _settings_page(parent: Node) -> void:
	var p := VBoxContainer.new(); p.add_theme_constant_override("separation", 8); p.size_flags_horizontal = Control.SIZE_EXPAND_FILL; parent.add_child(p); pages["Settings"] = p
	_section(p, "Graphics")
	var o := OptionButton.new(); for q in ["Low", "Medium", "High"]: o.add_item("Graphics quality: " + q)
	o.selected = Settings.quality; o.custom_minimum_size = Vector2(0, 46); o.item_selected.connect(func(i): Settings.quality = i; Settings.save_cfg(); Settings.changed.emit()); p.add_child(o)
	if not _mobile: _check(p, "Fullscreen", Settings.fullscreen, func(on): Settings.fullscreen = on; Settings.apply_window())
	_check(p, "Show FPS", Settings.show_fps, func(on): Settings.show_fps = on)
	_check(p, "Show player names", Settings.show_names, func(on): Settings.show_names = on)
	_section(p, "Audio")
	_slider(p, "Volume", 0.0, 1.0, 0.01, Settings.volume, func(v): Settings.volume = v)
	_section(p, "Camera")
	if not _mobile: _slider(p, "Mouse sensitivity", 0.001, 0.008, 0.0002, Settings.sensitivity, func(v): Settings.sensitivity = v)
	else: _slider(p, "Look sensitivity", 0.001, 0.008, 0.0002, Settings.sensitivity, func(v): Settings.sensitivity = v)
	_slider(p, "Field of view", 50.0, 100.0, 1.0, Settings.fov, func(v): Settings.fov = v)
	_slider(p, "Camera distance", 3.0, 12.0, 0.5, Settings.cam_distance, func(v): Settings.cam_distance = v)
	if _mobile:
		_section(p, "Touch controls")
		_slider(p, "Controls opacity", 0.2, 1.0, 0.05, Settings.touch_opacity, func(v): Settings.touch_opacity = v)
		_slider(p, "Controls size", 0.7, 1.5, 0.05, Settings.touch_size, func(v): Settings.touch_size = v)
	var r := Button.new(); r.text = "Reset to defaults"; r.custom_minimum_size = Vector2(0, 48)
	r.pressed.connect(func(): Settings.reset_defaults(); get_tree().create_timer(0.0).timeout.connect(_rebuild_settings)); p.add_child(r)

func _rebuild_settings() -> void:         # sliders keep their own value, so rebuild the page after a reset
	var old: Control = pages["Settings"]; var parent := old.get_parent(); var vis := old.visible
	var idx := old.get_index(); parent.remove_child(old); old.queue_free(); _settings_page(parent); parent.move_child(pages["Settings"], idx); pages["Settings"].visible = vis

# ---------------- Help ----------------
func _help_page(parent: Node) -> void:
	var p := VBoxContainer.new(); p.add_theme_constant_override("separation", 6); p.size_flags_horizontal = Control.SIZE_EXPAND_FILL; parent.add_child(p); pages["Help"] = p
	var rows: Array = [["Left stick", "Move"], ["Jump button", "Jump"], ["Drag the right side", "Look around"], ["Chat button", "Open chat"], ["Menu button", "Open this menu"]] if _mobile else [["W A S D / arrows", "Move"], ["Space", "Jump"], ["Hold right mouse", "Look around"], ["Mouse wheel", "Zoom in / out"], ["Enter or /", "Open chat"], ["Esc", "Open or close this menu"]]
	_section(p, "Controls")
	for r in rows:
		var h := HBoxContainer.new(); p.add_child(h)
		var a := Label.new(); a.text = r[0]; a.size_flags_horizontal = Control.SIZE_EXPAND_FILL; a.add_theme_color_override("font_color", Color("ffe27a")); h.add_child(a)
		var b := Label.new(); b.text = r[1]; b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(b)
	_section(p, "Tips")
	var t := Label.new(); t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.text = "Open the Chat tab to read and send messages, or the Emotes tab to wave and dance.\nBe kind: the chat filter hides bad language and blocks personal info.\nStuck? Use Respawn."
	t.modulate = Color(1, 1, 1, 0.75); p.add_child(t)

func show_page(n: String) -> void:
	for k in pages: pages[k].visible = (k == n)
	for k in tab_btns: tab_btns[k].button_pressed = (k == n)
	if n == "Players": _refresh_players()

func _process(delta: float) -> void:
	if not visible: return
	_stats_t -= delta
	if _stats_t <= 0.0:
		_stats_t = 0.5
		var n := Net.players.size(); var ping := ("%d ms" % Net.ping_ms) if Net.ping_ms >= 0 else "-- ms"
		info_label.text = "%d player%s  |  %s  |  %d FPS" % [n, "" if n == 1 else "s", ping, Engine.get_frames_per_second()]

func open(page := "Players") -> void: _leave_armed = false; leave_btn.text = "Leave Game"; show_page(page); _fit(); visible = true
func close() -> void: visible = false
func toggle() -> void:
	if visible: close()
	else: open()
