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
func _jump_center() -> Vector2: return Vector2(size.x - 118.0 * _u(), size.y - 128.0 * _u())
func _jump_radius() -> float: return 58.0 * _u()
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
			if off.length() > _joy_radius() * 1.6: _joy_origin = _joy_pos - off.normalized() * _joy_radius() * 1.6      # only drifts if the thumb goes far away
			move = ((_joy_pos - _joy_origin) / _joy_radius()).limit_length(1.0)
			if move.length() < 0.12: move = Vector2.ZERO
		elif e.index == _look_id:
			_look += e.relative
		queue_redraw()

func _draw() -> void:
	if not is_visible_in_tree(): return
	var a := clampf(Settings.touch_opacity + 0.15, 0.3, 1.0); var u := _u()
	# Thumbstick (Roblox style): a soft grey disc with a thin ring, and a round thumb that stays inside it and grows slightly when held.
	var c := _joy_origin if _joy_id != -1 else _home_center()
	var r := _joy_radius()
	draw_circle(c, r, Color(0.1, 0.1, 0.12, a * 0.34)); draw_arc(c, r, 0.0, TAU, 64, Color(1, 1, 1, a * 0.55), 3.0 * u, true)
	var held := _joy_id != -1
	var kr := 38.0 * u * (1.08 if held else 1.0)
	var knob := c + (move * (r - kr * 0.55) if held else Vector2.ZERO)
	draw_circle(knob + Vector2(0, 3.0 * u), kr, Color(0, 0, 0, a * 0.35))
	draw_circle(knob, kr, Color(0.93, 0.93, 0.95, a * (0.92 if held else 0.62))); draw_arc(knob, kr, 0.0, TAU, 48, Color(1, 1, 1, a), 2.0 * u, true)
	# Jump button: big round button with a bold rounded up arrow. It shrinks and brightens while pressed.
	var jc := _jump_center(); var jr := _jump_radius() * (0.93 if jump_held else 1.0)
	draw_circle(jc + Vector2(0, 4.0 * u), jr, Color(0, 0, 0, a * 0.28))
	draw_circle(jc, jr, Color(0.1, 0.1, 0.12, a * (0.5 if jump_held else 0.34)))
	draw_arc(jc, jr, 0.0, TAU, 64, Color(1, 1, 1, a * (0.95 if jump_held else 0.6)), 3.5 * u, true)
	var w := 8.0 * u; var col := Color(1, 1, 1, a * (1.0 if jump_held else 0.9)); var s := jr / 64.0
	var tip := jc + Vector2(0, -22.0) * u * s; var l := jc + Vector2(-23, 3.0) * u * s; var rr := jc + Vector2(23, 3.0) * u * s
	draw_line(l, tip, col, w, true); draw_line(tip, rr, col, w, true); draw_line(tip, jc + Vector2(0, 24.0) * u * s, col, w, true)
	for p in [l, tip, rr, jc + Vector2(0, 24.0) * u * s]: draw_circle(p, w * 0.5, col)
