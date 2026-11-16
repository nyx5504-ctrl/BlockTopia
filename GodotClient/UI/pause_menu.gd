class_name PauseMenu
extends CanvasLayer
## ESC menu: Resume, Respawn, Settings, Players (mute/report), Leave Game.
signal leave_requested
signal respawn_requested
var root: Control
var pages := {}
var players_list: VBoxContainer
const REASONS := ["Inappropriate chat", "Harassment", "Cheating", "Other"]

func _ready() -> void:
	layer = 10; visible = false
	root = Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(root)
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.6); dim.set_anchors_preset(Control.PRESET_FULL_RECT); root.add_child(dim)
	var center := CenterContainer.new(); center.set_anchors_preset(Control.PRESET_FULL_RECT); root.add_child(center)
	var panel := PanelContainer.new(); panel.custom_minimum_size = Vector2(440, 0); center.add_child(panel)
	var host := MarginContainer.new(); for s in ["left", "right", "top", "bottom"]: host.add_theme_constant_override("margin_" + s, 18)
	panel.add_child(host)
	var stack := VBoxContainer.new(); host.add_child(stack)
	var title := Label.new(); title.text = "BlockTopia"; title.add_theme_font_size_override("font_size", 30); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; stack.add_child(title)
	_main_page(stack); _settings_page(stack); _players_page(stack); show_page("main")
	Net.player_joined.connect(func(_p): if visible: _refresh_players())
	Net.player_left.connect(func(_i, _n): if visible: _refresh_players())
	Net.mute_changed.connect(func(_i, _o): if visible: _refresh_players())
	Net.report_done.connect(func(): _refresh_players())

func _btn(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new(); b.text = text; b.custom_minimum_size = Vector2(0, 46); b.pressed.connect(cb); parent.add_child(b); return b

func _main_page(stack: Node) -> void:
	var p := VBoxContainer.new(); p.add_theme_constant_override("separation", 8); stack.add_child(p); pages["main"] = p
	_btn(p, "Resume", close)
	_btn(p, "Respawn", func(): respawn_requested.emit(); close())
	_btn(p, "Settings", func(): show_page("settings"))
	_btn(p, "Players", func(): _refresh_players(); show_page("players"))
	_btn(p, "Leave Game", func(): leave_requested.emit())

func _slider(parent: Node, label: String, lo: float, hi: float, step: float, val: float, cb: Callable) -> void:
	var l := Label.new(); l.text = label; parent.add_child(l)
	var s := HSlider.new(); s.min_value = lo; s.max_value = hi; s.step = step; s.value = val; s.custom_minimum_size = Vector2(0, 26)
	s.value_changed.connect(func(v): cb.call(v); Settings.save_cfg()); parent.add_child(s)

func _settings_page(stack: Node) -> void:
	var p := VBoxContainer.new(); p.add_theme_constant_override("separation", 6); stack.add_child(p); pages["settings"] = p
	var l := Label.new(); l.text = "Graphics quality"; p.add_child(l)
	var o := OptionButton.new(); for q in ["Low", "Medium", "High"]: o.add_item(q)
	o.selected = Settings.quality; o.item_selected.connect(func(i): Settings.quality = i; Settings.save_cfg()); p.add_child(o)
	_slider(p, "Audio volume", 0.0, 1.0, 0.01, Settings.volume, func(v): Settings.volume = v)
	_slider(p, "Mouse sensitivity", 0.001, 0.008, 0.0002, Settings.sensitivity, func(v): Settings.sensitivity = v)
	_slider(p, "Camera field of view", 50.0, 100.0, 1.0, Settings.fov, func(v): Settings.fov = v)
	_slider(p, "Camera distance", 3.0, 12.0, 0.5, Settings.cam_distance, func(v): Settings.cam_distance = v)
	_slider(p, "Mobile controls opacity", 0.2, 1.0, 0.05, Settings.touch_opacity, func(v): Settings.touch_opacity = v)
	_slider(p, "Mobile controls size", 0.7, 1.5, 0.05, Settings.touch_size, func(v): Settings.touch_size = v)
	_btn(p, "Back", func(): show_page("main"))

func _players_page(stack: Node) -> void:
	var p := VBoxContainer.new(); p.add_theme_constant_override("separation", 8); stack.add_child(p); pages["players"] = p
	var sc := ScrollContainer.new(); sc.custom_minimum_size = Vector2(0, 260); p.add_child(sc)
	players_list = VBoxContainer.new(); players_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; sc.add_child(players_list)
	_btn(p, "Back", func(): show_page("main"))

func _refresh_players() -> void:
	for c in players_list.get_children(): c.queue_free()
	var ids := Net.players.keys(); ids.sort()
	for id in ids:
		var info: Dictionary = Net.players[id]
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 6); players_list.add_child(row)
		var n := Label.new(); n.text = str(info.get("name", "?")) + ("  (you)" if id == Net.my_id else ""); n.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(n)
		if id == Net.my_id: continue
		var mute := Button.new(); mute.text = "Unmute" if Net.muted.has(id) else "Mute"
		mute.pressed.connect(func(): Net.set_mute(id, not Net.muted.has(id))); row.add_child(mute)
		var rep := MenuButton.new(); rep.text = "Report"; rep.flat = false
		var pop := rep.get_popup(); for r in REASONS: pop.add_item(r)
		pop.id_pressed.connect(func(i): Net.report(id, REASONS[i]); rep.text = "Sent"); row.add_child(rep)

func show_page(n: String) -> void:
	for k in pages: pages[k].visible = (k == n)

func open() -> void: show_page("main"); visible = true
func close() -> void: visible = false
func toggle() -> void:
	if visible: close()
	else: open()
