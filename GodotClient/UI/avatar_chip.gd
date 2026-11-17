class_name AvatarChip
extends PanelContainer
## Round player badge used by the leaderboard and the menu: a head-and-shoulders picture of the player's character with its face
## (yellow head, the player's shirt colour on the shoulders), like the Roblox player headshots.
const SKIN := Color("f2c744")
static var _face_tex: ImageTexture
var shirt := Color("2f6fd6")
var px := 32

## The classic smiley face, also used on the 3D character's head. Transparent background.
static func face_image(n := 128) -> Image:
	# Black ink only, with transparent pixels everywhere else. Shape follows the supplied face sketch.
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var black := Color(0, 0, 0, 1)
	var curve := PackedVector2Array([Vector2(0.24, 0.69), Vector2(0.40, 1.02), Vector2(0.60, 1.02), Vector2(0.76, 0.69)])
	var curve_points := PackedVector2Array()
	for i in 49:
		var t := float(i) / 48.0; var q := 1.0 - t
		curve_points.append(curve[0] * q * q * q + curve[1] * 3.0 * q * q * t + curve[2] * 3.0 * q * t * t + curve[3] * t * t * t)
	for y in n:
		for x in n:
			var p := Vector2((x + 0.5) / n, (y + 0.5) / n)
			var alpha := 0.0
			var left := p - Vector2(0.28, 0.28)
			var angle := -0.45
			var rotated := Vector2(left.x * cos(angle) + left.y * sin(angle), -left.x * sin(angle) + left.y * cos(angle))
			var left_d := Vector2(rotated.x / 0.145, rotated.y / 0.25).length()
			alpha = maxf(alpha, clampf((1.0 - left_d) * n * 0.55 + 0.5, 0.0, 1.0))
			var right := p - Vector2(0.76, 0.28)
			var right_d := Vector2(right.x / 0.12, right.y / 0.235).length()
			alpha = maxf(alpha, clampf((1.0 - right_d) * n * 0.55 + 0.5, 0.0, 1.0))
			var smile_d := INF
			for q in curve_points:
				smile_d = minf(smile_d, p.distance_to(q))
			alpha = maxf(alpha, clampf((0.022 - smile_d) * n * 0.8 + 0.5, 0.0, 1.0))
			img.set_pixel(x, y, Color(black.r, black.g, black.b, alpha))
	return img

static func face_texture() -> ImageTexture:
	if _face_tex == null: _face_tex = ImageTexture.create_from_image(face_image(128))
	return _face_tex

func setup(_pname: String, color: Color, size_px := 32) -> AvatarChip:
	px = size_px; shirt = color if color != Color.WHITE else Color("2f6fd6")
	custom_minimum_size = Vector2(px, px); size_flags_vertical = Control.SIZE_SHRINK_CENTER; mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.36, 0.40, 0.48); sb.set_corner_radius_all(px / 2); sb.set_content_margin_all(0)
	sb.border_color = Color(1, 1, 1, 0.25); sb.set_border_width_all(1); add_theme_stylebox_override("panel", sb)
	return self

func _draw() -> void:
	var s := float(px); var c := Vector2(s, s) * 0.5; var r := s * 0.5 - 1.0
	var y0 := s * 0.74                                               # shoulders: the part of the circle below y0, in the shirt colour
	var a0 := asin(clampf((y0 - c.y) / r, -1.0, 1.0)); var pts := PackedVector2Array()
	for i in 17:
		var a := a0 + (PI - 2.0 * a0) * i / 16.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	if pts.size() >= 3: draw_colored_polygon(pts, shirt)
	var hw := s * 0.52; var hh := s * 0.50; var hp := Vector2(c.x - hw * 0.5, s * 0.17)      # head
	var head := StyleBoxFlat.new(); head.bg_color = SKIN; head.set_corner_radius_all(int(s * 0.12)); head.draw(get_canvas_item(), Rect2(hp, Vector2(hw, hh)))
	draw_texture_rect(face_texture(), Rect2(hp + Vector2(hw * 0.1, hh * 0.1), Vector2(hw * 0.8, hh * 0.8)), false)
