class_name FriendFace
extends Control
## Friend badge: a small LIVE 3D render of the friend's character (head and shoulders), so it changes whenever they customize
## (the friends list is reloaded every 30 seconds). A green dot sits under it while they're online.
## Only the first MAX_3D badges are 3D (each one is a tiny viewport); any extra friends get a flat face in their head colour.
const MAX_3D := 24
static var live_3d := 0
var px := 56
var online := false
var _flat := false
var _head := Color("f2c744")
var _bg: StyleBoxFlat
var _view: SubViewport
var _camera: Camera3D

func setup(character: Dictionary, is_online: bool, size_px := 56, display_name := "", shirt_hex := "") -> FriendFace:
	px = size_px; online = is_online
	custom_minimum_size = Vector2(px, px); size_flags_vertical = Control.SIZE_SHRINK_CENTER; mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_color := Color(0.93, 0.93, 0.95)
	_bg = StyleBoxFlat.new(); _bg.bg_color = bg_color; _bg.set_corner_radius_all(maxi(8, px / 5))
	if live_3d >= MAX_3D:
		_flat = true
		var parts: Variant = character.get("parts", {})
		var h: Variant = parts.get("head", {}) if parts is Dictionary else {}
		if h is Dictionary and str(h.get("color", "")).begins_with("#"): _head = Color(str(h.get("color")))
		queue_redraw()
	else:
		live_3d += 1; _build_3d(character, display_name, shirt_hex, bg_color)
	if online: _add_dot()
	return self

func _build_3d(character: Dictionary, display_name: String, shirt_hex: String, bg_color: Color) -> void:
	var clip := Panel.new(); clip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_theme_stylebox_override("panel", _bg); clip.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW; add_child(clip)
	var holder := SubViewportContainer.new(); holder.stretch = true; holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); holder.mouse_filter = Control.MOUSE_FILTER_IGNORE; clip.add_child(holder)
	_view = SubViewport.new(); _view.size = Vector2i(px, px); _view.transparent_bg = true; _view.msaa_3d = Viewport.MSAA_4X
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS; _view.world_3d = World3D.new(); holder.add_child(_view)
	var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-30, -20, 0); _view.add_child(light)
	var env_light := OmniLight3D.new(); env_light.position = Vector3(0.6, 2.6, 2.4); env_light.light_energy = 0.8; env_light.omni_range = 12.0; _view.add_child(env_light)
	var height := clampf(float(character.get("height", 1.0)), 0.75, 1.25)
	var center := Vector3(0, 2.34 * height, 0)           # head height of the rig (it scales with the character's height)
	_camera = Camera3D.new(); _camera.fov = 30.0; _camera.position = center + Vector3(0, 0.05, 1.7 * height); _view.add_child(_camera); _camera.current = true
	_camera.look_at(center, Vector3.UP)
	var avatar := Avatar.new()
	avatar.setup(display_name, Color(shirt_hex) if shirt_hex.begins_with("#") else Color("2f6fd6"), character, false)
	_view.add_child(avatar)
	_settle()

func _settle() -> void:      # render a few frames, then only when the badge is rebuilt (saves GPU time)
	for i in 4: await get_tree().process_frame
	if _view != null and is_instance_valid(_view): _view.render_target_update_mode = SubViewport.UPDATE_ONCE

func _add_dot() -> void:
	var dot := Panel.new(); dot.mouse_filter = Control.MOUSE_FILTER_IGNORE; dot.size = Vector2(16, 16); dot.position = Vector2(float(px) * 0.5 - 8.0, float(px) - 9.0)
	var st := StyleBoxFlat.new(); st.bg_color = Color(0.25, 0.85, 0.4); st.set_corner_radius_all(8); st.set_border_width_all(3); st.border_color = Color(0.075, 0.075, 0.082)
	dot.add_theme_stylebox_override("panel", st); add_child(dot)

func _draw() -> void:
	if not _flat or _bg == null: return
	var s := float(px)
	draw_style_box(_bg, Rect2(0, 0, s, s))
	var c := Vector2(s * 0.5, s * 0.48); var r := s * 0.3
	draw_circle(c, r, _head); draw_arc(c, r, 0.0, TAU, 40, Color(0, 0, 0, 0.18), 1.0, true)
	var f := r * 0.86
	draw_texture_rect(AvatarChip.face_texture(), Rect2(c - Vector2(f, f), Vector2(f, f) * 2.0), false)
