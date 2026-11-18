class_name IconButton
extends Button
## Rounded HUD button with a drawn icon ("menu", "chat" or "lock"), hover / press feedback, a lit "on" state and an optional unread dot.
var kind := "menu"
var badge := false:
	set(v): badge = v; queue_redraw()
var active := false:
	set(v): active = v; _restyle(); queue_redraw()
const TIPS := {"menu": "Menu  (Esc)", "chat": "Chat  ( / )", "lock": "Shift Lock  (Shift)"}

func _init(k := "menu") -> void:
	kind = k; focus_mode = Control.FOCUS_NONE; mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var s := 56.0 if Settings.is_mobile() else 46.0
	custom_minimum_size = Vector2(s, s); tooltip_text = TIPS.get(k, "")
	resized.connect(func(): pivot_offset = size / 2.0)
	button_down.connect(func(): scale = Vector2(0.92, 0.92))
	button_up.connect(func(): scale = Vector2.ONE)
	mouse_exited.connect(func(): scale = Vector2.ONE)
	_restyle()

func _style(bg: Color, border: Color) -> StyleBoxFlat:
	var b := StyleBoxFlat.new(); b.set_corner_radius_all(13); b.bg_color = bg; b.border_color = border; b.set_border_width_all(1)
	b.shadow_color = Color(0, 0, 0, 0.3); b.shadow_size = 4; return b

func _restyle() -> void:
	var lit := Color(0.95, 0.95, 0.97, 0.96)
	add_theme_stylebox_override("normal", _style(lit if active else Color(0.06, 0.06, 0.075, 0.72), Color(1, 1, 1, 0.14)))
	add_theme_stylebox_override("hover", _style(Color(1, 1, 1, 1.0) if active else Color(0.2, 0.2, 0.24, 0.9), Color(1, 1, 1, 0.3)))
	add_theme_stylebox_override("pressed", _style(Color(0.8, 0.8, 0.84, 1.0) if active else Color(0.3, 0.3, 0.35, 0.95), Color(1, 1, 1, 0.35)))
	add_theme_stylebox_override("focus", _style(lit if active else Color(0.06, 0.06, 0.075, 0.72), Color(1, 1, 1, 0.14)))

func _draw() -> void:
	var c := size / 2.0; var col := Color(0.07, 0.07, 0.09) if active else Color(1, 1, 1, 0.96)
	match kind:
		"menu":
			for i in 3:
				var r := StyleBoxFlat.new(); r.bg_color = col; r.set_corner_radius_all(2)
				draw_style_box(r, Rect2(c.x - 10, c.y - 8 + i * 7, 20, 3.5))
		"chat":
			var bub := StyleBoxFlat.new(); bub.bg_color = col; bub.set_corner_radius_all(6)
			draw_style_box(bub, Rect2(c.x - 12, c.y - 11, 24, 17))
			draw_colored_polygon(PackedVector2Array([Vector2(c.x - 7, c.y + 5), Vector2(c.x - 8, c.y + 12), Vector2(c.x + 1, c.y + 5)]), col)
			var dot := Color(1, 1, 1, 0.95) if active else Color(0.08, 0.08, 0.1)
			for i in 3: draw_circle(Vector2(c.x - 6 + i * 6, c.y - 2.5), 1.8, dot)
		"lock":
			var body := StyleBoxFlat.new(); body.bg_color = col; body.set_corner_radius_all(3)
			draw_style_box(body, Rect2(c.x - 9, c.y - 1, 18, 13))
			var open := not active                      # open padlock when shift lock is off, closed when on
			var cx := c.x - 3.5 if open else c.x
			draw_arc(Vector2(cx, c.y - 1), 6.0, PI, TAU, 14, col, 2.6)
			draw_line(Vector2(cx - 6, c.y - 1), Vector2(cx - 6, c.y + 2), col, 2.6)
			if not open: draw_line(Vector2(cx + 6, c.y - 1), Vector2(cx + 6, c.y + 2), col, 2.6)
			draw_circle(Vector2(c.x, c.y + 5), 1.8, Color(1, 1, 1, 0.95) if active else Color(0.08, 0.08, 0.1))
	if badge: draw_circle(Vector2(size.x - 8, 8), 6, Color(0.92, 0.28, 0.28)); draw_arc(Vector2(size.x - 8, 8), 6, 0, TAU, 14, Color(0.06, 0.06, 0.075), 1.5)
