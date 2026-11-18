class_name SwatchPicker
extends Button
## A color button that opens the shared BlockTopia palette (same colors as the website) instead of a free color wheel.
## Use like a ColorPickerButton: read/write `color`, listen to `color_changed`. Call attach_grid(container) once so the palette can open under the button.
signal color_changed(c: Color)
var color := Color("f2c744"):
	set(v): color = v; _restyle(); _mark()
var _grid: GridContainer

func _init() -> void:
	custom_minimum_size = Vector2(56, 40); focus_mode = Control.FOCUS_NONE; text = ""
	pressed.connect(func(): if _grid != null: _grid.visible = not _grid.visible)
	_restyle()

func _flat(c: Color, border: Color, r := 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = c; s.set_corner_radius_all(r); s.border_color = border; s.set_border_width_all(2); return s

func _restyle() -> void:
	add_theme_stylebox_override("normal", _flat(color, Color(0.35, 0.35, 0.4)))
	add_theme_stylebox_override("hover", _flat(color, Color(0.95, 0.95, 0.96)))
	add_theme_stylebox_override("pressed", _flat(color, Color(0.95, 0.95, 0.96)))
	add_theme_stylebox_override("focus", _flat(color, Color(0.95, 0.95, 0.96)))

func attach_grid(container: Control) -> void:
	_grid = GridContainer.new(); _grid.columns = 8; _grid.visible = false
	_grid.add_theme_constant_override("h_separation", 6); _grid.add_theme_constant_override("v_separation", 6)
	for hex in Palette.COLORS:
		var b := Button.new(); b.custom_minimum_size = Vector2(34, 34); b.focus_mode = Control.FOCUS_NONE; b.set_meta("hex", hex)
		var c := Color(hex)
		for st in ["normal", "hover", "pressed", "focus"]: b.add_theme_stylebox_override(st, _flat(c, Color(1, 1, 1, 0.9) if st != "normal" else Color(0.3, 0.3, 0.34), 7))
		b.pressed.connect(_pick.bind(hex)); _grid.add_child(b)
	container.add_child(_grid); _mark()

func _pick(hex: String) -> void:
	color = Color(hex); _grid.visible = false; color_changed.emit(color)

func _mark() -> void:   # ring around the swatch that is currently selected
	if _grid == null: return
	for b in _grid.get_children():
		var on := Color(str(b.get_meta("hex"))).is_equal_approx(color)
		var c := Color(str(b.get_meta("hex")))
		b.add_theme_stylebox_override("normal", _flat(c, Color(1, 1, 1) if on else Color(0.3, 0.3, 0.34), 7))
