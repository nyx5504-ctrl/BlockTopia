class_name IconButton
extends Button
## Flat HUD button with a drawn icon: "app" (the BlockTopia icon), "chat", "list" (leaderboard), "lock" or "menu".
## Solid fill, thin border, no shadow. Black on the black theme, white on the white theme (Settings > Account > Background).
var kind := "app"
var badge := false:
	set(v): badge = v; queue_redraw()
var active := false:
	set(v): active = v; _restyle(); queue_redraw()
const TIPS := {"app": "Menu  (Esc)", "menu": "Menu  (Esc)", "chat": "Chat  ( / )", "list": "Leaderboard  (Tab)", "lock": "Shift Lock  (Shift)"}

func _init(k := "app") -> void:
	kind = k; focus_mode = Control.FOCUS_NONE; mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var s := 56.0 if Settings.is_mobile() else 46.0
	custom_minimum_size = Vector2(s, s); tooltip_text = TIPS.get(k, "")
	resized.connect(_center_pivot)
	button_down.connect(_press_in)
	button_up.connect(_press_out)
	mouse_exited.connect(_press_out)
	_restyle()

func _center_pivot() -> void:
	pivot_offset = size / 2.0

func _press_in() -> void:
	scale = Vector2(0.94, 0.94)

func _press_out() -> void:
	scale = Vector2.ONE

func _style(bg: Color, border: Color) -> StyleBoxFlat:
	var b := StyleBoxFlat.new(); b.set_corner_radius_all(10); b.bg_color = bg; b.border_color = border; b.set_border_width_all(2)    # flat: no shadow, no glow
	return b

func _restyle() -> void:
	var c := ThemeBuilder.c
	var base_bg := c.call(Color(0.09, 0.09, 0.1)) as Color
	var line := c.call(Color(0.3, 0.3, 0.34)) as Color
	var lit := c.call(Color(0.95, 0.95, 0.97)) as Color
	add_theme_stylebox_override("normal", _style(lit if active else base_bg, line))
	add_theme_stylebox_override("hover", _style(c.call(Color(1, 1, 1)) if active else c.call(Color(0.18, 0.18, 0.2)), c.call(Color(0.55, 0.55, 0.6))))
	add_theme_stylebox_override("pressed", _style(c.call(Color(0.8, 0.8, 0.84)) if active else c.call(Color(0.26, 0.26, 0.29)), c.call(Color(0.6, 0.6, 0.65))))
	add_theme_stylebox_override("focus", _style(lit if active else base_bg, line))

func _draw() -> void:
	var c := size / 2.0
	var col: Color = ThemeBuilder.c(Color(0.07, 0.07, 0.09)) if active else ThemeBuilder.c(Color(0.96, 0.96, 0.97))
	var soft := Color(col.r, col.g, col.b, 0.45)
	match kind:
		"app":        # the BlockTopia icon: four blocks
			for i in 4:
				var r := StyleBoxFlat.new(); r.bg_color = col if (i == 0 or i == 3) else soft; r.set_corner_radius_all(3)
				draw_style_box(r, Rect2(c.x - 11 + (i % 2) * 12.5, c.y - 11 + (i / 2) * 12.5, 9.5, 9.5))
		"menu":
			for i in 3:
				var r := StyleBoxFlat.new(); r.bg_color = col; r.set_corner_radius_all(2)
				draw_style_box(r, Rect2(c.x - 10, c.y - 8 + i * 7, 20, 3.5))
		"list":       # leaderboard: three rows, each with a small picture and a name bar
			for i in 3:
				var y := c.y - 10 + i * 9.0
				var pic := StyleBoxFlat.new(); pic.bg_color = col; pic.set_corner_radius_all(2)
				draw_style_box(pic, Rect2(c.x - 12, y, 6, 6))
				var bar := StyleBoxFlat.new(); bar.bg_color = soft if i > 0 else col; bar.set_corner_radius_all(2)
				draw_style_box(bar, Rect2(c.x - 3, y + 1, 15, 4))
		"chat":
			var bub := StyleBoxFlat.new(); bub.bg_color = col; bub.set_corner_radius_all(6)
			draw_style_box(bub, Rect2(c.x - 12, c.y - 11, 24, 17))
			draw_colored_polygon(PackedVector2Array([Vector2(c.x - 7, c.y + 5), Vector2(c.x - 8, c.y + 12), Vector2(c.x + 1, c.y + 5)]), col)
			var dot: Color = ThemeBuilder.c(Color(1, 1, 1, 0.95)) if active else ThemeBuilder.c(Color(0.08, 0.08, 0.1))
			for i in 3: draw_circle(Vector2(c.x - 6 + i * 6, c.y - 2.5), 1.8, dot)
		"lock":
			var body := StyleBoxFlat.new(); body.bg_color = col; body.set_corner_radius_all(3)
			draw_style_box(body, Rect2(c.x - 9, c.y - 1, 18, 13))
			var open := not active                      # open padlock when shift lock is off, closed when on
			var cx := c.x - 3.5 if open else c.x
			draw_arc(Vector2(cx, c.y - 1), 6.0, PI, TAU, 14, col, 2.6)
			draw_line(Vector2(cx - 6, c.y - 1), Vector2(cx - 6, c.y + 2), col, 2.6)
			if not open: draw_line(Vector2(cx + 6, c.y - 1), Vector2(cx + 6, c.y + 2), col, 2.6)
			draw_circle(Vector2(c.x, c.y + 5), 1.8, ThemeBuilder.c(Color(1, 1, 1, 0.95)) if active else ThemeBuilder.c(Color(0.08, 0.08, 0.1)))
	if badge: draw_circle(Vector2(size.x - 8, 8), 6, Color(0.92, 0.28, 0.28)); draw_arc(Vector2(size.x - 8, 8), 6, 0, TAU, 14, ThemeBuilder.c(Color(0.06, 0.06, 0.075)), 1.5)
