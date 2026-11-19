class_name FriendFace
extends Control
## Friend badge for the app: a rounded square showing the friend's face in THEIR head colour and size (it changes when they customize),
## with a green dot under the face while they are online.
var head := Color("f2c744")
var head_scale := 1.0
var online := false
var px := 52
var _bg: StyleBoxFlat

func setup(character: Dictionary, is_online: bool, size_px := 52) -> FriendFace:
	px = size_px; online = is_online
	custom_minimum_size = Vector2(px, px); size_flags_vertical = Control.SIZE_SHRINK_CENTER; mouse_filter = Control.MOUSE_FILTER_IGNORE
	var parts: Variant = character.get("parts", {})
	var h: Variant = parts.get("head", {}) if parts is Dictionary else {}
	if h is Dictionary:
		var col := str(h.get("color", "#f2c744"))
		if col.begins_with("#") and col.length() == 7: head = Color(col)
		head_scale = clampf(float(h.get("size", 1.0)), 0.7, 1.3)
	_bg = StyleBoxFlat.new(); _bg.bg_color = Color(0.95, 0.95, 0.97); _bg.set_corner_radius_all(maxi(8, px / 5))
	queue_redraw()
	return self

func _draw() -> void:
	var s := float(px)
	if _bg == null: return
	draw_style_box(_bg, Rect2(0, 0, s, s))
	var c := Vector2(s * 0.5, s * 0.48)
	var r := minf(s * 0.3 * head_scale, s * 0.4)
	draw_circle(c, r, head)
	draw_arc(c, r, 0.0, TAU, 40, Color(0, 0, 0, 0.18), 1.0, true)
	var f := r * 0.86
	draw_texture_rect(AvatarChip.face_texture(), Rect2(c - Vector2(f, f), Vector2(f, f) * 2.0), false)
	if online:
		var d := Vector2(s * 0.5, s - 1.0)
		draw_circle(d, 8.0, Color(0.085, 0.085, 0.1))
		draw_circle(d, 6.0, Color(0.25, 0.85, 0.4))
