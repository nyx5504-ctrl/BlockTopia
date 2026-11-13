class_name ThemeBuilder
## Dark black/grey/white BlockTopia theme, built in code.
static func box(bg: Color, border := Color(0.18, 0.18, 0.2), radius := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg; s.border_color = border
	s.set_border_width_all(1); s.set_corner_radius_all(radius)
	s.content_margin_left = 14; s.content_margin_right = 14; s.content_margin_top = 9; s.content_margin_bottom = 9
	return s

static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 18
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var c := Color(0.1, 0.1, 0.11)
		if st == "hover": c = Color(0.17, 0.17, 0.19)
		if st == "pressed": c = Color(0.25, 0.25, 0.28)
		if st == "disabled": c = Color(0.07, 0.07, 0.08)
		if st == "focus": c = Color(0, 0, 0, 0)
		t.set_stylebox(st, "Button", box(c))
		t.set_stylebox(st, "MenuButton", box(c))
		t.set_stylebox(st, "OptionButton", box(c))
	t.set_color("font_color", "Button", Color(0.95, 0.95, 0.96))
	t.set_color("font_disabled_color", "Button", Color(0.4, 0.4, 0.43))
	t.set_color("font_color", "Label", Color(0.95, 0.95, 0.96))
	t.set_color("font_color", "MenuButton", Color(0.95, 0.95, 0.96))
	t.set_color("font_color", "OptionButton", Color(0.95, 0.95, 0.96))
	t.set_stylebox("panel", "PanelContainer", box(Color(0.075, 0.075, 0.082), Color(0.2, 0.2, 0.22), 14))
	t.set_stylebox("panel", "Panel", box(Color(0.075, 0.075, 0.082), Color(0.2, 0.2, 0.22), 14))
	t.set_stylebox("normal", "LineEdit", box(Color(0.04, 0.04, 0.045)))
	t.set_stylebox("focus", "LineEdit", box(Color(0.04, 0.04, 0.045), Color(0.5, 0.5, 0.55)))
	t.set_color("font_color", "LineEdit", Color(0.95, 0.95, 0.96))
	t.set_color("default_color", "RichTextLabel", Color(0.95, 0.95, 0.96))
	return t
