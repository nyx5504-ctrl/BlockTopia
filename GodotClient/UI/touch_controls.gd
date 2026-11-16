class_name TouchControls
extends Control
## Mobile controls: floating joystick on the left, big JUMP button bottom-right, drag anywhere else on the right to look around.
## `is_ui` (set by baseplate.gd) tells us when a touch landed on a menu / chat / player-list so it isn't also used for moving.
var move := Vector2.ZERO
var jump_held := false
var is_ui := Callable()
var _look := Vector2.ZERO
var _joy_id := -1; var _joy_origin := Vector2.ZERO; var _joy_pos := Vector2.ZERO
var _look_id := -1; var _jump_id := -1
var _look_last := Vector2.ZERO

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(queue_redraw)

func consume_look() -> Vector2:
	var l := _look; _look = Vector2.ZERO; return l

func _u() -> float: return clampf(size.y / 720.0, 0.75, 1.5) * Settings.touch_size      # one "unit" scales with the screen and the size setting
func _joy_radius() -> float: return 92.0 * _u()
func _jump_center() -> Vector2: return Vector2(size.x - 125.0 * _u(), size.y - 135.0 * _u())
func _jump_radius() -> float: return 64.0 * _u()
func _home_center() -> Vector2: return Vector2(165.0 * _u(), size.y - 150.0 * _u())

func _reset() -> void:
	_joy_id = -1; _look_id = -1; _jump_id = -1; move = Vector2.ZERO; jump_held = false; queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_VISIBILITY_CHANGED: _reset()

func _input(e: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if e is InputEventScreenTouch:
		var p: Vector2 = e.position
		if e.pressed:
			if is_ui.is_valid() and is_ui.call(p): return
			if p.distance_to(_jump_center()) <= _jump_radius() * 1.4 and _jump_id == -1:
				_jump_id = e.index; jump_held = true
			elif p.x < size.x * 0.46 and p.y > size.y * 0.22 and _joy_id == -1:
				_joy_id = e.index; _joy_origin = p; _joy_pos = p; move = Vector2.ZERO
			elif p.x >= size.x * 0.46 and _look_id == -1:
				_look_id = e.index; _look_last = p
		else:
			if e.index == _joy_id: _joy_id = -1; move = Vector2.ZERO
			if e.index == _look_id: _look_id = -1
			if e.index == _jump_id: _jump_id = -1; jump_held = false
		queue_redraw()
	elif e is InputEventScreenDrag:
		if e.index == _joy_id:
			_joy_pos = e.position
			var off: Vector2 = _joy_pos - _joy_origin
			if off.length() > _joy_radius() * 1.25: _joy_origin = _joy_pos - off.normalized() * _joy_radius() * 1.25      # the stick follows your thumb, like Roblox
			move = ((_joy_pos - _joy_origin) / _joy_radius()).limit_length(1.0)
			if move.length() < 0.12: move = Vector2.ZERO
		elif e.index == _look_id:
			_look += e.relative
		queue_redraw()

func _draw() -> void:
	if not is_visible_in_tree(): return
	var a := clampf(Settings.touch_opacity + 0.15, 0.3, 1.0); var u := _u()
	var dark := Color(0, 0, 0, a * 0.30); var ring := Color(1, 1, 1, a * 0.95); var shade := Color(0, 0, 0, a * 0.45)
	# joystick: dark disc + white ring so it shows on the light baseplate and the sky
	var c := _joy_origin if _joy_id != -1 else _home_center()
	var r := _joy_radius()
	draw_circle(c, r, dark); draw_arc(c, r, 0.0, TAU, 56, ring, 4.0 * u, true)
	var knob := (c + move * r) if _joy_id != -1 else c
	draw_circle(knob + Vector2(0, 3.0 * u), 40.0 * u, shade)
	draw_circle(knob, 40.0 * u, Color(1, 1, 1, a * (0.95 if _joy_id != -1 else 0.55)))
	# jump button: dark disc, white ring, bold up arrow
	var jc := _jump_center(); var jr := _jump_radius()
	draw_circle(jc, jr, Color(0, 0, 0, a * (0.55 if jump_held else 0.32))); draw_arc(jc, jr, 0.0, TAU, 56, ring, 4.0 * u, true)
	var w := 9.0 * u
	for pass_i in 2:
		var off := Vector2(0, 2.5 * u) if pass_i == 0 else Vector2.ZERO
		var col := shade if pass_i == 0 else Color(1, 1, 1, a)
		draw_line(jc + off + Vector2(-26, 10) * u, jc + off + Vector2(0, -16) * u, col, w, true); draw_line(jc + off + Vector2(0, -16) * u, jc + off + Vector2(26, 10) * u, col, w, true)
