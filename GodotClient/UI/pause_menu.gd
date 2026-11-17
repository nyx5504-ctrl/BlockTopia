class_name PauseMenu
extends CanvasLayer
## Roblox-style game menu: player list, character customization, reports, settings and help, Reset Character / Leave / Resume at the bottom.
## Players: add friend, mute, block, report. Report: pick a player and a reason, add details, send to the BlockTopia team.
## Settings: graphics, audio, camera, touch, fullscreen, FPS counter, name tags, reset. The header shows players, ping and FPS.
## Keys while the menu is open: Esc = resume, R = reset character, L = leave game (press twice).
signal leave_requested
signal respawn_requested
const REPORT_REASONS := [["Inappropriate chat", "inappropriate_chat"], ["Harassment or bullying", "abuse"], ["Inappropriate username", "inappropriate_name"], ["Cheating or exploiting", "cheating"], ["Spam", "spam"], ["Something else", "other"]]
const TABS := ["Players", "Customization", "Report", "Settings", "Help"]
var root: Control
var panel: PanelContainer
var pages := {}
var tab_btns := {}
var players_list: VBoxContainer
var info_label: Label
var _stats_t := 0.0
var leave_btn: Button
var _leave_armed := false
var _leave_token := 0
var _mobile := false
# report page
var custom_preview: Avatar
var custom_height: HSlider
var custom_body_type: OptionButton
var custom_sizes := {}
var custom_colors := {}
var custom_status: Label
var rep_player: OptionButton
var rep_ids: Array = []
var rep_reason: OptionButton
var rep_details: TextEdit
var rep_status: Label
var rep_send: Button
var _rep_pending := -1

func _ready() -> void:
	layer = 10; visible = false; _mobile = Settings.is_mobile()
	root = Control.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(root)
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.58); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_child(dim)
	panel = PanelContainer.new(); panel.set_anchors_preset(Control.PRESET_CENTER); root.add_child(panel)
	panel.add_theme_stylebox_override("panel", ThemeBuilder.box(Color(0.07, 0.07, 0.078, 0.98), Color(0.24, 0.24, 0.27), 16))
	var host := MarginContainer.new(); for s in ["left", "right", "top", "bottom"]: host.add_theme_constant_override("margin_" + s, 14 if _mobile else 18)
	panel.add_child(host)
	var stack := VBoxContainer.new(); stack.add_theme_constant_override("separation", 12); host.add_child(stack)
	# header
	var head := HBoxContainer.new(); head.add_theme_constant_override("separation", 10); stack.add_child(head)
	var title := Label.new(); title.text = "BlockTopia"; title.add_theme_font_size_override("font_size", 26); title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(title)
	info_label = Label.new(); info_label.modulate = Color(1, 1, 1, 0.55); info_label.add_theme_font_size_override("font_size", 15); head.add_child(info_label)
	var x := Button.new(); x.text = "X"; x.custom_minimum_size = Vector2(44, 44); x.pressed.connect(close); head.add_child(x)
	# tabs
	var tabs := GridContainer.new(); tabs.columns = 2 if _mobile else TABS.size(); tabs.add_theme_constant_override("h_separation", 6); tabs.add_theme_constant_override("v_separation", 6); stack.add_child(tabs)
	var group := ButtonGroup.new()
	for t in TABS:
		var b := Button.new(); b.text = t; b.toggle_mode = true; b.button_group = group; b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; b.custom_minimum_size = Vector2(0, 50 if _mobile else 44); b.add_theme_font_size_override("font_size", 16 if _mobile else 18); b.clip_text = true
		var on := ThemeBuilder.box(Color(0.93, 0.93, 0.95), Color(0.93, 0.93, 0.95)); b.add_theme_stylebox_override("pressed", on); b.add_theme_stylebox_override("hover_pressed", on)
		b.add_theme_color_override("font_pressed_color", Color(0.05, 0.05, 0.06)); b.add_theme_color_override("font_hover_pressed_color", Color(0.05, 0.05, 0.06))
		b.pressed.connect(show_page.bind(t)); tabs.add_child(b); tab_btns[t] = b
	# pages
	var area := ScrollContainer.new(); area.size_flags_vertical = Control.SIZE_EXPAND_FILL; area.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; stack.add_child(area)
	var pv := VBoxContainer.new(); pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; area.add_child(pv)
	_players_page(pv); _customization_page(pv); _report_page(pv); _settings_page(pv); _help_page(pv)
	# footer (Roblox order: Reset Character, Leave, Resume)
	var foot := HBoxContainer.new(); foot.add_theme_constant_override("separation", 8); stack.add_child(foot)
	_foot_btn(foot, "Reset Character", "R", func(): respawn_requested.emit(); close())
	leave_btn = _foot_btn(foot, "Leave Game", "L", _on_leave)
	var red := ThemeBuilder.box(Color(0.5, 0.13, 0.13), Color(0.68, 0.2, 0.2)); leave_btn.add_theme_stylebox_override("normal", red)
	leave_btn.add_theme_stylebox_override("hover", ThemeBuilder.box(Color(0.62, 0.16, 0.16), Color(0.8, 0.25, 0.25))); leave_btn.add_theme_stylebox_override("pressed", ThemeBuilder.box(Color(0.42, 0.1, 0.1), Color(0.68, 0.2, 0.2)))
	var resume := _foot_btn(foot, "Resume", "Esc", close)
	var white := ThemeBuilder.box(Color(0.93, 0.93, 0.95), Color(0.93, 0.93, 0.95)); resume.add_theme_stylebox_override("normal", white); resume.add_theme_stylebox_override("hover", ThemeBuilder.box(Color(1, 1, 1), Color(1, 1, 1)))
	resume.add_theme_stylebox_override("pressed", ThemeBuilder.box(Color(0.8, 0.8, 0.83), Color(0.8, 0.8, 0.83)))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: resume.add_theme_color_override(c, Color(0.05, 0.05, 0.06))
	get_viewport().size_changed.connect(_fit); _fit()
	Net.welcomed.connect(func(_m): _load_customization_controls())
	Net.character_save_result.connect(_on_character_save_result)
	Net.player_joined.connect(func(_p): _on_roster())
	Net.player_left.connect(func(_i, _n): _on_roster())
	Net.mute_changed.connect(func(_i, _o): if visible: _refresh_players())
	Net.report_done.connect(_on_report_done)
	show_page("Players")

func _foot_btn(parent: Node, text: String, key: String, cb: Callable) -> Button:
	var b := Button.new(); b.text = text if _mobile else "%s   [%s]" % [text, key]; b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; b.custom_minimum_size = Vector2(0, 58 if _mobile else 50); b.clip_text = true; b.pressed.connect(cb); parent.add_child(b); return b

func _fit() -> void:
	var vs := get_viewport().get_visible_rect().size
	var w := clampf(vs.x * 0.94, 320.0, 780.0); var h := clampf(vs.y * 0.92, 300.0, 660.0)
	panel.custom_minimum_size = Vector2(w, h); panel.size = Vector2(w, h)
	panel.position = (vs - panel.size) / 2.0

func _on_leave() -> void:        # two taps so a stray tap on a phone doesn't drop you out of the game
	if _leave_armed: _leave_armed = false; leave_requested.emit(); return
	_leave_armed = true; leave_btn.text = "Tap again to leave"; _leave_token += 1; var me := _leave_token
	await get_tree().create_timer(3.0).timeout
	if me == _leave_token: _leave_armed = false; leave_btn.text = "Leave Game" if _mobile else "Leave Game   [L]"

func _unhandled_key_input(e: InputEvent) -> void:
	if not visible or not (e is InputEventKey) or not e.pressed or e.echo: return
	if e.keycode == KEY_R: respawn_requested.emit(); close(); get_viewport().set_input_as_handled()
	elif e.keycode == KEY_L: _on_leave(); get_viewport().set_input_as_handled()

func _on_roster() -> void:
	if not visible: return
	if pages["Players"].visible: _refresh_players()
	if pages["Report"].visible: _refresh_report_players()

# ---------------- Players ----------------
func _players_page(parent: Node) -> void:
	var page := VBoxContainer.new(); page.add_theme_constant_override("separation", 10); page.size_flags_horizontal = Control.SIZE_EXPAND_FILL; parent.add_child(page); pages["Players"] = page
	players_list = VBoxContainer.new(); players_list.add_theme_constant_override("separation", 8); players_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; page.add_child(players_list)

func _customization_page(parent: Node) -> void:
	var page := VBoxContainer.new(); page.add_theme_constant_override("separation", 10); page.size_flags_horizontal = Control.SIZE_EXPAND_FILL; parent.add_child(page); pages["Customization"] = page
	var hint := Label.new(); hint.text = "Change your character, then save it to your BlockTopia profile."; hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; hint.modulate = Color(1, 1, 1, 0.65); page.add_child(hint)
	var holder := SubViewportContainer.new(); holder.stretch = true; holder.custom_minimum_size = Vector2(0, 180); holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL; page.add_child(holder)
	var view := SubViewport.new(); view.size = Vector2i(360, 190); view.transparent_bg = true; view.world_3d = World3D.new(); view.render_target_update_mode = SubViewport.UPDATE_ALWAYS; holder.add_child(view)
	var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-35, -25, 0); view.add_child(light)
	var camera := Camera3D.new(); camera.position = Vector3(0, 1.45, 3.8); camera.look_at(Vector3(0, 1.3, 0), Vector3.UP); camera.current = true; view.add_child(camera)
	custom_preview = Avatar.new(); custom_preview.setup(Net.my_name if Net.my_name != "" else "Player", Color(Net.my_color), Net.my_character, false); view.add_child(custom_preview)
	_section(page, "Height and body type")
	var height_label := Label.new(); height_label.text = "Height"; page.add_child(height_label)
	custom_height = HSlider.new(); custom_height.min_value = 0.75; custom_height.max_value = 1.25; custom_height.step = 0.05; custom_height.custom_minimum_size = Vector2(0, 36); page.add_child(custom_height)
	custom_body_type = OptionButton.new()
	for item in ["Classic", "Slim", "Broad"]: custom_body_type.add_item(item)
	custom_body_type.custom_minimum_size = Vector2(0, 44); page.add_child(custom_body_type)
	var names := {"head": "Head", "torso": "Torso", "leftArm": "Left arm", "rightArm": "Right arm", "leftLeg": "Left leg", "rightLeg": "Right leg"}
	_section(page, "Part size and color")
	for part in names:
		var card := PanelContainer.new(); card.add_theme_stylebox_override("panel", ThemeBuilder.box(Color(0.1, 0.1, 0.11), Color(0.19, 0.19, 0.21), 10)); page.add_child(card)
		var stack := VBoxContainer.new(); stack.add_theme_constant_override("separation", 4); card.add_child(stack)
		var label := Label.new(); label.text = names[part]; stack.add_child(label)
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8); stack.add_child(row)
		var slider := HSlider.new(); slider.min_value = 0.7; slider.max_value = 1.3; slider.step = 0.05; slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL; slider.custom_minimum_size = Vector2(0, 34); row.add_child(slider)
		var picker := ColorPickerButton.new(); picker.custom_minimum_size = Vector2(52, 40); row.add_child(picker)
		custom_sizes[part] = slider; custom_colors[part] = picker
		slider.value_changed.connect(func(_v): _update_customization_preview())
		picker.color_changed.connect(func(_c): _update_customization_preview())
	custom_height.value_changed.connect(func(_v): _update_customization_preview())
	custom_body_type.item_selected.connect(func(_i): _update_customization_preview())
	var save := Button.new(); save.text = "Save customization"; save.custom_minimum_size = Vector2(0, 50); save.pressed.connect(_save_customization); page.add_child(save)
	custom_status = Label.new(); custom_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; custom_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; page.add_child(custom_status)
	_load_customization_controls()

func _character_defaults() -> Dictionary:
	var value: Variant = Net.my_character.get("parts", {})
	var parts: Dictionary = value if value is Dictionary else {}
	var skin := str(Net.my_character.get("bodyColor", "#f2c744"))
	var defaults := {
		"head": {"size": 1.0, "color": skin}, "torso": {"size": 1.0, "color": "#2f6fd6"},
		"leftArm": {"size": 1.0, "color": skin}, "rightArm": {"size": 1.0, "color": skin},
		"leftLeg": {"size": 1.0, "color": "#3f9a52"}, "rightLeg": {"size": 1.0, "color": "#3f9a52"}
	}
	for key in defaults:
		var old: Variant = parts.get(key, {})
		if old is Dictionary:
			defaults[key].size = clampf(float(old.get("size", 1.0)), 0.7, 1.3)
			defaults[key].color = str(old.get("color", defaults[key].color))
	return defaults

func _load_customization_controls() -> void:
	if custom_height == null: return
	var c := Net.my_character
	custom_height.value = clampf(float(c.get("height", 1.0)), 0.75, 1.25)
	var types := ["classic", "slim", "broad"]; var index := types.find(str(c.get("bodyType", "classic")))
	custom_body_type.select(maxi(index, 0))
	var parts := _character_defaults()
	for part in custom_sizes:
		custom_sizes[part].value = float(parts[part].size)
		custom_colors[part].color = Color(str(parts[part].color))
	_update_customization_preview()

func _read_customization() -> Dictionary:
	var types := ["classic", "slim", "broad"]
	var parts := {}
	for part in custom_sizes:
		parts[part] = {"size": custom_sizes[part].value, "color": custom_colors[part].color.to_html(false)}
	return {"height": custom_height.value, "bodyType": types[custom_body_type.selected], "bodyColor": parts["head"]["color"], "parts": parts}

func _update_customization_preview() -> void:
	if custom_preview == null or not is_instance_valid(custom_preview) or custom_height == null: return
	custom_preview.apply_character(_read_customization())

func _save_customization() -> void:
	if Net.state != "online": custom_status.text = "Connect to a game before saving customization."; return
	custom_status.text = "Saving..."
	Net.save_character(_read_customization())

func _on_character_save_result(ok: bool) -> void:
	if custom_status: custom_status.text = "Customization saved to your profile." if ok else "Couldn't save your customization. Try again."

func _face_color(info: Dictionary) -> Color:
	var character: Variant = info.get("character", {})
	return Color(str(character.get("bodyColor", "#f2c744"))) if character is Dictionary else Color("f2c744")

func _small_btn(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new(); b.text = text; b.custom_minimum_size = Vector2(0, 40); b.add_theme_font_size_override("font_size", 16); b.pressed.connect(cb); parent.add_child(b); return b

func _refresh_players() -> void:
	for c in players_list.get_children(): c.queue_free()
	var ids := Net.players.keys()
	ids.sort()
	for id in ids:
		var info: Dictionary = Net.players[id]
		var card := PanelContainer.new(); card.add_theme_stylebox_override("panel", ThemeBuilder.box(Color(0.1, 0.1, 0.11), Color(0.19, 0.19, 0.21), 12)); players_list.add_child(card)
		var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 8); card.add_child(v)
		var top := HBoxContainer.new(); top.add_theme_constant_override("separation", 12); v.add_child(top)
		top.add_child(AvatarChip.new().setup(str(info.get("name", "?")), Color(str(info.get("color", "#ffffff"))), 40, _face_color(info)))
		var col := VBoxContainer.new(); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL; col.add_theme_constant_override("separation", 0); top.add_child(col)
		var n := Label.new(); n.text = str(info.get("name", "?")); n.clip_text = true; n.add_theme_font_size_override("font_size", 20)
		col.add_child(n)
		var sub := Label.new(); sub.add_theme_font_size_override("font_size", 13); sub.modulate = Color(1, 1, 1, 0.5)
		sub.visible = id != Net.my_id
		sub.text = ("Blocked" if Net.blocked.has(id) else ("Muted" if Net.muted.has(id) else "Player")); col.add_child(sub)
		if id == Net.my_id: continue
		var row := HFlowContainer.new(); row.add_theme_constant_override("h_separation", 8); row.add_theme_constant_override("v_separation", 8); v.add_child(row)
		_small_btn(row, "Add Friend", func(): Net.send_friend(id))
		_small_btn(row, "Unmute" if Net.muted.has(id) else "Mute", func(): Net.set_mute(id, not Net.muted.has(id)))
		_small_btn(row, "Unblock" if Net.blocked.has(id) else "Block", func(): Net.set_block(id, not Net.blocked.has(id)); _refresh_players())
		_small_btn(row, "Report", func(): open_report(id))

# ---------------- Report ----------------
func _report_page(parent: Node) -> void:
	var p := VBoxContainer.new(); p.add_theme_constant_override("separation", 8); p.size_flags_horizontal = Control.SIZE_EXPAND_FILL; parent.add_child(p); pages["Report"] = p
	var intro := Label.new(); intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; intro.modulate = Color(1, 1, 1, 0.65); intro.add_theme_font_size_override("font_size", 16)
	intro.text = "Report someone who is breaking the rules. The BlockTopia team reads every report. The latest chat messages from this server are attached automatically."
	p.add_child(intro)
	_section(p, "Who are you reporting?")
	rep_player = OptionButton.new(); rep_player.custom_minimum_size = Vector2(0, 46); p.add_child(rep_player)
	_section(p, "What happened?")
	rep_reason = OptionButton.new(); rep_reason.custom_minimum_size = Vector2(0, 46); for r in REPORT_REASONS: rep_reason.add_item(r[0])
	p.add_child(rep_reason)
	_section(p, "Details (optional)")
	rep_details = TextEdit.new(); rep_details.placeholder_text = "Tell us what happened (max 300 characters)"; rep_details.custom_minimum_size = Vector2(0, 92); rep_details.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	rep_details.text_changed.connect(func(): if rep_details.text.length() > 300: rep_details.text = rep_details.text.substr(0, 300); rep_details.set_caret_column(300))
	var tb := ThemeBuilder.box(Color(0.04, 0.04, 0.045)); rep_details.add_theme_stylebox_override("normal", tb); rep_details.add_theme_stylebox_override("focus", ThemeBuilder.box(Color(0.04, 0.04, 0.045), Color(0.5, 0.5, 0.55)))
	rep_details.add_theme_color_override("font_color", Color(0.95, 0.95, 0.96)); rep_details.add_theme_color_override("font_placeholder_color", Color(1, 1, 1, 0.35)); p.add_child(rep_details)
	rep_send = Button.new(); rep_send.text = "Send report"; rep_send.custom_minimum_size = Vector2(0, 52); rep_send.pressed.connect(_send_report); p.add_child(rep_send)
	rep_status = Label.new(); rep_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; rep_status.modulate = Color(1, 1, 1, 0.75); p.add_child(rep_status)

func _refresh_report_players() -> void:
	var keep := -1
	if rep_player.selected >= 0 and rep_player.selected < rep_ids.size(): keep = rep_ids[rep_player.selected]
	rep_player.clear(); rep_ids.clear()
	for id in Net.players.keys():
		if id == Net.my_id: continue
		rep_ids.append(id)
	rep_ids.sort_custom(func(a, b): return str(Net.players[a].get("name", "")).to_lower() < str(Net.players[b].get("name", "")).to_lower())
	for id in rep_ids: rep_player.add_item(str(Net.players[id].get("name", "?")))
	if rep_ids.is_empty(): rep_player.add_item("No other players here"); rep_player.disabled = true; rep_send.disabled = true
	else:
		rep_player.disabled = false; rep_send.disabled = false
		if keep != -1 and rep_ids.has(keep): rep_player.select(rep_ids.find(keep))

func open_report(id := -1) -> void:
	open("Report")
	if id != -1 and rep_ids.has(id): rep_player.select(rep_ids.find(id))
	rep_status.text = ""

func _send_report() -> void:
	if rep_ids.is_empty() or rep_player.selected < 0: rep_status.text = "Pick a player first."; return
	var id: int = rep_ids[rep_player.selected]
	var reason: Array = REPORT_REASONS[rep_reason.selected]
	_rep_pending = id; rep_send.disabled = true; rep_status.text = "Sending..."
	Net.report(id, reason[1], reason[0], rep_details.text.strip_edges())

func _on_report_done(duplicate: bool) -> void:
	if _rep_pending == -1: return
	_rep_pending = -1
	rep_status.text = "You already reported this player a moment ago. Thank you." if duplicate else "Thank you! Your report was sent to the BlockTopia team."
	if not duplicate: rep_details.text = ""
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(rep_send): rep_send.disabled = rep_ids.is_empty()

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
	var rows: Array = [["Left stick", "Move"], ["Jump button", "Jump"], ["Drag the right side", "Look around"], ["Chat button", "Open chat"], ["Menu button", "Open this menu"]] if _mobile else [["W A S D / arrows", "Move"], ["Space", "Jump"], ["F11", "Fullscreen on / off"], ["F12", "Start / stop recording (red outline)"], ["Hold right mouse", "Look around"], ["Mouse wheel", "Zoom in / out"], ["Enter or /", "Open chat"], ["Tab", "Show or hide the player list"], ["Esc", "Open or close this menu"]]
	_section(p, "Controls")
	for r in rows:
		var h := HBoxContainer.new(); p.add_child(h)
		var a := Label.new(); a.text = r[0]; a.size_flags_horizontal = Control.SIZE_EXPAND_FILL; a.add_theme_color_override("font_color", Color(0.9, 0.9, 0.93)); h.add_child(a)
		var b := Label.new(); b.text = r[1]; b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(b)
	_section(p, "Tips")
	var t := Label.new(); t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.text = "Click a name in the player list to add a friend, block or report them. When someone sends you a friend request, accept it from the card at the top of the screen.\nBe kind: the chat filter hides bad language and blocks personal info.\nStuck? Use Reset Character."
	t.modulate = Color(1, 1, 1, 0.75); p.add_child(t)

func show_page(n: String) -> void:
	for k in pages: pages[k].visible = (k == n)
	for k in tab_btns: tab_btns[k].button_pressed = (k == n)
	if n == "Players": _refresh_players()
	elif n == "Report": _refresh_report_players()

func _process(delta: float) -> void:
	if not visible: return
	_stats_t -= delta
	if _stats_t <= 0.0:
		_stats_t = 0.5
		var n := Net.players.size(); var ping := ("%d ms" % Net.ping_ms) if Net.ping_ms >= 0 else "-- ms"
		info_label.text = "%d player%s  |  %s  |  %d FPS" % [n, "" if n == 1 else "s", ping, Engine.get_frames_per_second()]

func open(page := "Players") -> void:
	_leave_armed = false; leave_btn.text = "Leave Game" if _mobile else "Leave Game   [L]"; show_page(page); _fit(); visible = true
func close() -> void: visible = false
func toggle() -> void:
	if visible: close()
	else: open()
