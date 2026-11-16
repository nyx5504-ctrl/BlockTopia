class_name TouchControls
extends Control
## On-screen controls: left joystick, drag right side to look, jump / chat / menu buttons.
var move := Vector2.ZERO
var jump_held := false
var _look := Vector2.ZERO
var _joy_id := -1; var _joy_origin := Vector2.ZERO; var _joy_pos := Vector2.ZERO
var _look_id := -1; var _jump_id := -1
const JOY_R := 90.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT); mouse_filter = Control.MOUSE_FILTER_IGNORE

func consume_look() -> Vector2:
	var l := _look; _look = Vector2.ZERO; return l

func _s() -> float: return Settings.touch_size
func _jump_rect() -> Rect2: return Rect2(size.x - 190 * _s(), size.y - 190 * _s(), 130 * _s(), 130 * _s())

func _input(e: InputEvent) -> void:
	if not visible: return
	if e is InputEventScreenTouch:
		var p: Vector2 = e.position
		if e.pressed:
			if p.y < 80 and p.x < 220: return                               # top-left HUD buttons
			if p.x > size.x - 260 and p.y < 340: return                      # player list
			if _jump_rect().has_point(p): _jump_id = e.index; jump_held = true
			elif p.x < size.x * 0.45 and p.y > size.y * 0.3 and _joy_id == -1: _joy_id = e.index; _joy_origin = p; _joy_pos = p
			elif _look_id == -1 and p.x >= size.x * 0.45: _look_id = e.index
		else:
			if e.index == _joy_id: _joy_id = -1; move = Vector2.ZERO
			if e.index == _look_id: _look_id = -1
			if e.index == _jump_id: _jump_id = -1; jump_held = false
		queue_redraw()
	elif e is InputEventScreenDrag:
		if e.index == _joy_id:
			_joy_pos = e.position; move = ((_joy_pos - _joy_origin) / JOY_R).limit_length(1.0)
			if move.length() < 0.15: move = Vector2.ZERO
		elif e.index == _look_id: _look += e.relative
		queue_redraw()

func _draw() -> void:
	var a := Settings.touch_opacity; var s := _s()
	var col := Color(1, 1, 1, a * 0.35); var fill := Color(1, 1, 1, a * 0.7)
	if _joy_id != -1:
		draw_circle(_joy_origin, JOY_R * s, col); draw_circle(_joy_origin + move * JOY_R * s, 34 * s, fill)
	else:
		draw_circle(Vector2(150 * s, size.y - 150 * s), JOY_R * s, Color(1, 1, 1, a * 0.12))
	var jr := _jump_rect(); draw_circle(jr.get_center(), jr.size.x / 2.0, col if not jump_held else fill)
	draw_string(ThemeDB.fallback_font, jr.get_center() + Vector2(-22 * s, 8 * s), "JUMP", HORIZONTAL_ALIGNMENT_LEFT, -1, int(20 * s), Color(1, 1, 1, a + 0.2))
