class_name IconButton
extends Button
## Round translucent HUD button with a drawn icon ("menu" or "chat") and an optional unread dot.
var kind := "menu"
var badge := false:
	set(v): badge = v; queue_redraw()
var active := false:
	set(v): active = v; queue_redraw()

func _init(k := "menu") -> void:
	kind = k; custom_minimum_size = Vector2(48, 48); focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "focus"]:
		var b := StyleBoxFlat.new(); b.set_corner_radius_all(24)
		b.bg_color = Color(0.06, 0.06, 0.07, 0.72) if st == "normal" else Color(0.2, 0.2, 0.23, 0.9)
		add_theme_stylebox_override(st, b)

func _draw() -> void:
	var c := size / 2.0; var col := Color(1, 1, 1, 0.95 if not active else 1.0)
	if kind == "menu":
		for i in 3: draw_rect(Rect2(c.x - 10, c.y - 9 + i * 8, 20, 3), col, true)
	else:
		draw_rect(Rect2(c.x - 12, c.y - 11, 24, 17), col, true)
		draw_colored_polygon(PackedVector2Array([Vector2(c.x - 7, c.y + 5), Vector2(c.x - 9, c.y + 13), Vector2(c.x + 1, c.y + 5)]), col)
		for i in 3: draw_circle(Vector2(c.x - 6 + i * 6, c.y - 3), 1.7, Color(0.08, 0.08, 0.1))
	if badge: draw_circle(Vector2(size.x - 9, 9), 6, Color(0.92, 0.28, 0.28))
