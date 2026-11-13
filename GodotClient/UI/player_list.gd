class_name PlayerList
extends CanvasLayer
## In-game player list / leaderboard (top-right). Click a name to open a tab beside it: Add Friend, Block, Report.
const REASONS := ["Inappropriate chat", "Harassment", "Cheating", "Other"]
var panel: PanelContainer
var rows: VBoxContainer
var title: Label
var collapse: Button
var popup: PanelContainer
var popup_name: Label
var popup_friend: Button
var popup_block: Button
var popup_report: MenuButton
var target := -1
var _collapsed := false
var _row_nodes := {}

func _ready() -> void:
	layer = 4
	var root := Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(root)
	panel = PanelContainer.new(); panel.anchor_left = 1.0; panel.anchor_right = 1.0; panel.offset_left = -246; panel.offset_right = -12; panel.offset_top = 12
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.04, 0.04, 0.05, 0.66); sb.set_corner_radius_all(12); sb.set_content_margin_all(8); panel.add_theme_stylebox_override("panel", sb); root.add_child(panel)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 4); panel.add_child(v)
	var head := HBoxContainer.new(); v.add_child(head)
	title = Label.new(); title.text = "Players"; title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; title.add_theme_font_size_override("font_size", 17); head.add_child(title)
	collapse = Button.new(); collapse.text = "-"; collapse.flat = true; collapse.custom_minimum_size = Vector2(30, 26); collapse.pressed.connect(func(): _collapsed = not _collapsed; collapse.text = "+" if _collapsed else "-"; rows.visible = _collapsed == false; popup.visible = false); head.add_child(collapse)
	rows = VBoxContainer.new(); rows.add_theme_constant_override("separation", 2); v.add_child(rows)
	_build_popup(root)
	Net.welcomed.connect(func(_m): refresh()); Net.player_joined.connect(func(_p): refresh()); Net.player_left.connect(func(_i, _n): refresh())
	Net.scores_changed.connect(refresh); Net.mute_changed.connect(func(_i, _o): refresh())
	if Settings.is_mobile(): panel.offset_left = -190; collapse.pressed.emit()

func _build_popup(root: Control) -> void:
	popup = PanelContainer.new(); popup.visible = false; popup.custom_minimum_size = Vector2(170, 0)
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.08, 0.08, 0.1, 0.96); sb.set_corner_radius_all(12); sb.set_content_margin_all(8); sb.border_color = Color(0.25, 0.25, 0.3); sb.set_border_width_all(1)
	popup.add_theme_stylebox_override("panel", sb); root.add_child(popup)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 4); popup.add_child(v)
	popup_name = Label.new(); popup_name.add_theme_font_size_override("font_size", 16); popup_name.modulate = Color(1, 1, 1, 0.65); v.add_child(popup_name)
	popup_friend = Button.new(); popup_friend.text = "Add Friend"; popup_friend.pressed.connect(func(): Net.send_friend(target); popup.visible = false); v.add_child(popup_friend)
	popup_block = Button.new(); popup_block.pressed.connect(func(): Net.set_block(target, not Net.blocked.has(target)); popup.visible = false); v.add_child(popup_block)
	popup_report = MenuButton.new(); popup_report.text = "Report"; popup_report.flat = false
	var pm := popup_report.get_popup(); for r in REASONS: pm.add_item(r)
	pm.id_pressed.connect(func(i): Net.report(target, REASONS[i]); popup.visible = false); v.add_child(popup_report)

func refresh() -> void:
	for c in rows.get_children(): c.queue_free()
	_row_nodes.clear()
	var ids := Net.players.keys()
	ids.sort_custom(func(a, b): return Net.scores.get(a, 0) > Net.scores.get(b, 0) or (Net.scores.get(a, 0) == Net.scores.get(b, 0) and a < b))
	title.text = "Players (%d)" % ids.size()
	for id in ids:
		var info: Dictionary = Net.players[id]
		var b := Button.new(); b.flat = true; b.custom_minimum_size = Vector2(0, 34); b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var sb := StyleBoxFlat.new(); sb.bg_color = Color(1, 1, 1, 0.14); sb.set_corner_radius_all(8); b.add_theme_stylebox_override("hover", sb)
		var h := HBoxContainer.new(); h.set_anchors_preset(Control.PRESET_FULL_RECT); h.mouse_filter = Control.MOUSE_FILTER_IGNORE; h.add_theme_constant_override("separation", 8); b.add_child(h)
		var sw := ColorRect.new(); sw.color = Color(str(info.get("color", "#ffffff"))); sw.custom_minimum_size = Vector2(10, 10); sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER; sw.mouse_filter = Control.MOUSE_FILTER_IGNORE; h.add_child(sw)
		var n := Label.new(); n.text = str(info.get("name", "?")); n.size_flags_horizontal = Control.SIZE_EXPAND_FILL; n.clip_text = true; n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if Net.blocked.has(id): n.modulate = Color(1, 1, 1, 0.4); n.text += " (blocked)"
		if id == Net.my_id: n.add_theme_color_override("font_color", Color("ffe27a"))
		h.add_child(n)
		var sc := Label.new(); sc.text = str(Net.scores.get(id, 0)); sc.modulate = Color(1, 1, 1, 0.6); sc.mouse_filter = Control.MOUSE_FILTER_IGNORE; h.add_child(sc)
		if id != Net.my_id: b.pressed.connect(func(): _open_popup(id, b))
		rows.add_child(b); _row_nodes[id] = b
	if target != -1 and not Net.players.has(target): popup.visible = false

func _open_popup(id: int, row: Control) -> void:
	if popup.visible and target == id: popup.visible = false; return
	target = id; popup.visible = true
	popup_name.text = str(Net.players[id].get("name", "?"))
	popup_block.text = "Unblock" if Net.blocked.has(id) else "Block"
	popup.reset_size()
	await get_tree().process_frame
	popup.position = Vector2(panel.global_position.x - popup.size.x - 8, row.global_position.y)

func _input(e: InputEvent) -> void:
	if popup.visible and e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = e.position
		var hit: bool = popup.get_global_rect().has_point(p) or popup_report.get_popup().visible
		if not hit and not (_row_nodes.has(target) and _row_nodes[target].get_global_rect().has_point(p)): popup.visible = false
