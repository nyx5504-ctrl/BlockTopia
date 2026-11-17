class_name PlayerList
extends CanvasLayer
## Roblox-style player list (top-right): every player on its own translucent row with an avatar badge and name.
## Your own row is highlighted. Click a name to open a small tab beside it: Add Friend, Block, Report. Press Tab (or the - button) to hide the list.
signal report_requested(id: int)
const ROW_H := 38
var panel: PanelContainer
var rows: VBoxContainer
var title: Label
var collapse: Button
var popup: PanelContainer
var popup_chip_holder: HBoxContainer
var popup_name: Label
var popup_friend: Button
var popup_block: Button
var popup_report: Button
var target := -1
var _collapsed := false
var _row_nodes := {}

func _ready() -> void:
	layer = 4
	var root := Control.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(root)
	panel = PanelContainer.new(); panel.anchor_left = 1.0; panel.anchor_right = 1.0; panel.offset_left = -250; panel.offset_right = -12; panel.offset_top = 12
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0, 0, 0, 0); sb.set_content_margin_all(0); panel.add_theme_stylebox_override("panel", sb); root.add_child(panel)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 3); panel.add_child(v)
	var head := PanelContainer.new(); head.add_theme_stylebox_override("panel", _row_style(Color(0.04, 0.04, 0.05, 0.78), 10)); v.add_child(head)
	var hh := HBoxContainer.new(); head.add_child(hh)
	title = Label.new(); title.text = "Players"; title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; title.add_theme_font_size_override("font_size", 16); hh.add_child(title)
	collapse = Button.new(); collapse.text = "-"; collapse.flat = true; collapse.custom_minimum_size = Vector2(28, 24); collapse.focus_mode = Control.FOCUS_NONE; collapse.pressed.connect(toggle); hh.add_child(collapse)
	rows = VBoxContainer.new(); rows.add_theme_constant_override("separation", 3); v.add_child(rows)
	_build_popup(root)
	Net.welcomed.connect(func(_m): refresh()); Net.player_joined.connect(func(_p): refresh()); Net.player_left.connect(func(_i, _n): refresh())
Net.mute_changed.connect(func(_i, _o): refresh())
	if Settings.is_mobile(): panel.offset_left = -200; toggle()

func _row_style(c: Color, r := 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = c; s.set_corner_radius_all(r); s.content_margin_left = 10; s.content_margin_right = 8; s.content_margin_top = 5; s.content_margin_bottom = 5; return s

func toggle() -> void:
	_collapsed = not _collapsed; collapse.text = "+" if _collapsed else "-"; rows.visible = not _collapsed; popup.visible = false

func _build_popup(root: Control) -> void:
	popup = PanelContainer.new(); popup.visible = false; popup.custom_minimum_size = Vector2(180, 0)
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.07, 0.07, 0.085, 0.97); sb.set_corner_radius_all(12); sb.set_content_margin_all(8); sb.border_color = Color(0.27, 0.27, 0.32); sb.set_border_width_all(1)
	popup.add_theme_stylebox_override("panel", sb); root.add_child(popup)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 5); popup.add_child(v)
	popup_chip_holder = HBoxContainer.new(); popup_chip_holder.add_theme_constant_override("separation", 8); v.add_child(popup_chip_holder)
	popup_name = Label.new(); popup_name.add_theme_font_size_override("font_size", 17); popup_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER; popup_chip_holder.add_child(popup_name)
	popup_friend = Button.new(); popup_friend.text = "Add Friend"; popup_friend.pressed.connect(func(): Net.send_friend(target); popup.visible = false); v.add_child(popup_friend)
	popup_block = Button.new(); popup_block.pressed.connect(func(): Net.set_block(target, not Net.blocked.has(target)); popup.visible = false); v.add_child(popup_block)
	popup_report = Button.new(); popup_report.text = "Report"; popup_report.pressed.connect(func(): popup.visible = false; report_requested.emit(target)); v.add_child(popup_report)

func refresh() -> void:
	for c in rows.get_children(): c.queue_free()
	_row_nodes.clear()
	var ids := Net.players.keys()
	ids.sort()
	title.text = "Players (%d)" % ids.size()
	for id in ids:
		var info: Dictionary = Net.players[id]; var me: bool = id == Net.my_id
		var b := Button.new(); b.custom_minimum_size = Vector2(0, ROW_H); b.alignment = HORIZONTAL_ALIGNMENT_LEFT; b.focus_mode = Control.FOCUS_NONE
		var base := _row_style(Color(0.04, 0.04, 0.05, 0.62), 10)
		var hov := _row_style(Color(1, 1, 1, 0.22), 10)
		for st in ["normal", "disabled"]: b.add_theme_stylebox_override(st, base)
		for st in ["hover", "pressed", "focus"]: b.add_theme_stylebox_override(st, hov if not me else base)
		var h := HBoxContainer.new(); h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); h.offset_left = 6; h.offset_right = -10; h.mouse_filter = Control.MOUSE_FILTER_IGNORE; h.add_theme_constant_override("separation", 8); b.add_child(h)
		var chip := AvatarChip.new().setup(str(info.get("name", "?")), Color(str(info.get("color", "#ffffff"))), 26); h.add_child(chip)
		var n := Label.new(); n.text = str(info.get("name", "?")); n.size_flags_horizontal = Control.SIZE_EXPAND_FILL; n.clip_text = true; n.mouse_filter = Control.MOUSE_FILTER_IGNORE; n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if Net.blocked.has(id): n.modulate = Color(1, 1, 1, 0.4); n.text += " (blocked)"
		h.add_child(n)
		if not me: b.pressed.connect(func(): _open_popup(id, b))
		rows.add_child(b); _row_nodes[id] = b
	if target != -1 and not Net.players.has(target): popup.visible = false

func _open_popup(id: int, row: Control) -> void:
	if popup.visible and target == id: popup.visible = false; return
	target = id; popup.visible = true
	var info: Dictionary = Net.players[id]
	for c in popup_chip_holder.get_children():
		if c is AvatarChip: c.queue_free()
	var chip := AvatarChip.new().setup(str(info.get("name", "?")), Color(str(info.get("color", "#ffffff"))), 30); popup_chip_holder.add_child(chip); popup_chip_holder.move_child(chip, 0)
	popup_name.text = str(info.get("name", "?"))
	popup_block.text = "Unblock" if Net.blocked.has(id) else "Block"
	popup.reset_size()
	await get_tree().process_frame
	popup.position = Vector2(panel.global_position.x - popup.size.x - 8, row.global_position.y)

func _unhandled_key_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_TAB: toggle(); get_viewport().set_input_as_handled()

func _input(e: InputEvent) -> void:
	if popup.visible and e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = e.position
		if not popup.get_global_rect().has_point(p) and not (_row_nodes.has(target) and _row_nodes[target].get_global_rect().has_point(p)): popup.visible = false
