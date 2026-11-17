class_name FriendPrompt
extends CanvasLayer
## In-game friend request card (top-centre, under the toast): "<name> sent you a friend request" with Accept / Decline.
## Several requests queue up one under another. A card goes away by itself after 40 seconds (the request stays valid on the website).
var box: VBoxContainer
var _cards := {}   # sender id -> card

func _ready() -> void:
	layer = 9
	var root := Control.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(root)
	box = VBoxContainer.new(); box.anchor_left = 0.5; box.anchor_right = 0.5; box.offset_left = -190; box.offset_right = 190; box.offset_top = 70
	box.add_theme_constant_override("separation", 8); box.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(box)
	Net.friend_request.connect(_on_request)

func _on_request(id: int, pname: String) -> void:
	if _cards.has(id): _cards[id].queue_free()
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.07, 0.07, 0.085, 0.97); sb.set_corner_radius_all(14); sb.set_content_margin_all(12); sb.border_color = Color(0.3, 0.3, 0.36); sb.set_border_width_all(1)
	card.add_theme_stylebox_override("panel", sb); box.add_child(card); _cards[id] = card
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 10); card.add_child(v)
	var top := HBoxContainer.new(); top.add_theme_constant_override("separation", 10); v.add_child(top)
	var info: Dictionary = Net.players.get(id, {})
	top.add_child(AvatarChip.new().setup(pname, Color(str(info.get("color", "#ffffff"))), 40))
	var l := Label.new(); l.text = "%s sent you a friend request" % pname; l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; top.add_child(l)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8); v.add_child(row)
	var no := Button.new(); no.text = "Decline"; no.size_flags_horizontal = Control.SIZE_EXPAND_FILL; no.custom_minimum_size = Vector2(0, 42); row.add_child(no)
	var yes := Button.new(); yes.text = "Accept"; yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL; yes.custom_minimum_size = Vector2(0, 42); row.add_child(yes)
	var ys := StyleBoxFlat.new(); ys.bg_color = Color(0.93, 0.93, 0.96); ys.set_corner_radius_all(8)
	for st in ["normal", "hover", "pressed", "focus"]: yes.add_theme_stylebox_override(st, ys)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: yes.add_theme_color_override(c, Color(0.08, 0.08, 0.1))
	yes.pressed.connect(func(): Net.answer_friend(id, true); _close(id))
	no.pressed.connect(func(): Net.answer_friend(id, false); _close(id))
	await get_tree().create_timer(40.0).timeout
	if _cards.get(id) == card: _close(id)

func _close(id: int) -> void:
	if _cards.has(id): _cards[id].queue_free(); _cards.erase(id)

func covers(p: Vector2) -> bool:
	for c in _cards.values():
		if is_instance_valid(c) and c.get_global_rect().has_point(p): return true
	return false
