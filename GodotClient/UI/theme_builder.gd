class_name ThemeBuilder
## BlockTopia theme, built in code. Black (dark) by default; the dashboard can switch to white (Settings > Language/Background).
## `light` is only true while the dashboard (Home scene) is showing; the game always stays dark.
static var light := false
const NO_BORDER := Color(-1, -1, -1)
const ACCENT := Color("6d8bff")        # brand accent, the same blue/violet as the website (never inverted in the light theme)
const ACCENT_HOVER := Color("8aa2ff")
const ACCENT_2 := Color("a46bff")

## Maps a dark-theme color to the active theme (a plain invert, which suits the neutral greys used everywhere; alpha is kept).
static func c(col: Color) -> Color:
	return Color(1.0 - col.r, 1.0 - col.g, 1.0 - col.b, col.a) if light else col

## Filled accent button / selected state.
static func accent_box(hover := false, radius := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = ACCENT_HOVER if hover else ACCENT; s.border_color = Color(1, 1, 1, 0.0); s.set_corner_radius_all(radius)
	s.content_margin_left = 16; s.content_margin_right = 16; s.content_margin_top = 10; s.content_margin_bottom = 10
	s.shadow_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.35); s.shadow_size = 10; s.shadow_offset = Vector2(0, 3)
	return s

static func box(bg: Color, border := NO_BORDER, radius := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg; s.border_color = c(Color(0.16, 0.175, 0.24)) if border == NO_BORDER else border
	s.set_border_width_all(1); s.set_corner_radius_all(radius)
	s.content_margin_left = 14; s.content_margin_right = 14; s.content_margin_top = 9; s.content_margin_bottom = 9
	return s

static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 18
	var text := c(Color(0.95, 0.95, 0.96))
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var col := Color(0.105, 0.115, 0.16)
		if st == "hover": col = Color(0.16, 0.18, 0.27)
		if st == "disabled": col = Color(0.07, 0.075, 0.1)
		col = c(col)
		if st == "focus": col = Color(0, 0, 0, 0)
		var sb := box(col)
		if st == "hover": sb.border_color = ACCENT
		if st == "pressed": sb = accent_box()
		t.set_stylebox(st, "Button", sb)
		t.set_stylebox(st, "MenuButton", sb)
		t.set_stylebox(st, "OptionButton", sb)
	t.set_color("font_color", "Button", text)
	t.set_color("font_hover_color", "Button", text)
	t.set_color("font_pressed_color", "Button", Color(1, 1, 1))
	t.set_color("font_disabled_color", "Button", c(Color(0.4, 0.4, 0.43)))
	t.set_color("font_color", "Label", text)
	t.set_color("font_color", "CheckBox", text)
	t.set_color("font_color", "CheckButton", text)
	t.set_color("font_color", "MenuButton", text)
	t.set_color("font_color", "OptionButton", text)
	t.set_stylebox("panel", "PanelContainer", box(c(Color(0.07, 0.078, 0.11)), c(Color(0.16, 0.175, 0.24)), 18))
	t.set_stylebox("panel", "Panel", box(c(Color(0.07, 0.078, 0.11)), c(Color(0.16, 0.175, 0.24)), 18))
	t.set_stylebox("normal", "LineEdit", box(c(Color(0.045, 0.05, 0.075))))
	t.set_stylebox("focus", "LineEdit", box(c(Color(0.045, 0.05, 0.075)), ACCENT))
	t.set_color("font_color", "LineEdit", text)
	t.set_color("caret_color", "LineEdit", text)
	t.set_color("font_placeholder_color", "LineEdit", c(Color(1, 1, 1, 0.38)))
	t.set_color("default_color", "RichTextLabel", text)
	return t

## Sets the global theme for the dashboard (light allowed) or the game (always dark).
static func apply_to(tree: SceneTree, allow_light: bool) -> void:
	light = allow_light and Settings.theme == "light"
	tree.root.theme = build()
