class_name ThemeBuilder
## BlockTopia theme, built in code. Black (dark) by default; the dashboard can switch to white (Settings > Language/Background).
## `light` is only true while the dashboard (Home scene) is showing; the game always stays dark.
static var light := false
const NO_BORDER := Color(-1, -1, -1)
const ACCENT := Color(0.93, 0.93, 0.95)   # "accent" is plain white on the black theme (and black on the white theme): no colour, like the website
const ACCENT_HOVER := Color(1, 1, 1)

## Maps a dark-theme color to the active theme (a plain invert, which suits the neutral greys used everywhere; alpha is kept).
static func c(col: Color) -> Color:
	return Color(1.0 - col.r, 1.0 - col.g, 1.0 - col.b, col.a) if light else col

## Filled primary button / selected state (white on black, black on white).
static func accent_box(hover := false, radius := 10) -> StyleBoxFlat:
	var s := box(c(ACCENT_HOVER if hover else ACCENT), c(Color(0.98, 0.98, 0.99)), radius)
	return s

## Text colour for use on top of accent_box.
static func on_accent() -> Color:
	return c(Color(0.05, 0.05, 0.06))

static func box(bg: Color, border := NO_BORDER, radius := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg; s.border_color = c(Color(0.18, 0.18, 0.2)) if border == NO_BORDER else border
	s.set_border_width_all(1); s.set_corner_radius_all(radius)
	s.content_margin_left = 14; s.content_margin_right = 14; s.content_margin_top = 9; s.content_margin_bottom = 9
	return s

static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 18
	var text := c(Color(0.95, 0.95, 0.96))
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var col := Color(0.1, 0.1, 0.11)
		if st == "hover": col = Color(0.17, 0.17, 0.19)
		if st == "pressed": col = Color(0.25, 0.25, 0.28)
		if st == "disabled": col = Color(0.07, 0.07, 0.08)
		col = c(col)
		if st == "focus": col = Color(0, 0, 0, 0)
		t.set_stylebox(st, "Button", box(col))
		t.set_stylebox(st, "MenuButton", box(col))
		t.set_stylebox(st, "OptionButton", box(col))
	t.set_color("font_color", "Button", text)
	t.set_color("font_hover_color", "Button", text)
	t.set_color("font_pressed_color", "Button", text)
	t.set_color("font_disabled_color", "Button", c(Color(0.4, 0.4, 0.43)))
	t.set_color("font_color", "Label", text)
	t.set_color("font_color", "CheckBox", text)
	t.set_color("font_color", "CheckButton", text)
	t.set_color("font_color", "MenuButton", text)
	t.set_color("font_color", "OptionButton", text)
	t.set_stylebox("panel", "PanelContainer", box(c(Color(0.075, 0.075, 0.082)), c(Color(0.2, 0.2, 0.22)), 14))
	t.set_stylebox("panel", "Panel", box(c(Color(0.075, 0.075, 0.082)), c(Color(0.2, 0.2, 0.22)), 14))
	t.set_stylebox("normal", "LineEdit", box(c(Color(0.04, 0.04, 0.045))))
	t.set_stylebox("focus", "LineEdit", box(c(Color(0.04, 0.04, 0.045)), c(Color(0.5, 0.5, 0.55))))
	t.set_color("font_color", "LineEdit", text)
	t.set_color("caret_color", "LineEdit", text)
	t.set_color("font_placeholder_color", "LineEdit", c(Color(1, 1, 1, 0.38)))
	t.set_color("default_color", "RichTextLabel", text)
	return t

## Sets the global theme for the dashboard (light allowed) or the game (always dark).
static func apply_to(tree: SceneTree, allow_light: bool) -> void:
	light = allow_light and Settings.theme == "light"
	tree.root.theme = build()
