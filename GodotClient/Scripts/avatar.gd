class_name Avatar
extends Node3D
## Roblox R6 rig (Assets/roblox-r6.glb) driven by procedural bone animation, with Roblox-style chat bubbles.
## Front of the character faces +Z, feet at y = 0. The rig is 5.1 studs tall; MODEL_SCALE brings it to ~2.6 m.
const MODEL := preload("res://Assets/roblox-r6.glb")
const MODEL_SCALE := 0.5
const SKIN := Color("f2c744")
const PANTS := Color("3f9a52")
const DEFAULT_SHIRT := Color("2f6fd6")

var anim := "idle"          # idle | run | jump | fall
var speed := 0.0            # horizontal speed, set by the owner (local: velocity, remote: position delta)
var skel: Skeleton3D
var bone := {}              # role -> bone index
var rest_g := {}            # bone index -> global rest basis (skeleton space)
var rest_p := {}            # bone index -> rest position
var _t := 0.0
var _phase := 0.0
var _prev_anim := "idle"
var _land_t := 0.0          # >0 for a moment after landing: a small knee-bend dip
var _cur := {"arm_l": 0.0, "arm_r": 0.0, "leg_l": 0.0, "leg_r": 0.0, "lean": 0.0, "out_l": 0.0, "out_r": 0.0, "bob": 0.0, "head": 0.0, "twist": 0.0, "legout": 0.0}
var _bubble: Node3D
var _name_label: Label3D
var _holder: Node3D
var _display_name := ""
var _show_name := true
var _shirt_color := DEFAULT_SHIRT

func setup(display_name: String, color: Color, character: Dictionary = {}, show_name := true) -> void:
	_display_name = display_name
	_show_name = show_name
	_shirt_color = color if color != Color.WHITE else DEFAULT_SHIRT
	_name_label = Label3D.new(); _name_label.text = display_name; _name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.pixel_size = 0.006; _name_label.font_size = 48; _name_label.outline_size = 14
	_name_label.no_depth_test = true; _name_label.render_priority = 3; add_child(_name_label)
	Settings.changed.connect(_apply_names)
	apply_character(character)

func apply_character(character: Dictionary) -> void:
	if _holder != null and is_instance_valid(_holder): _holder.queue_free()
	skel = null; bone.clear(); rest_g.clear(); rest_p.clear()
	var height := clampf(float(character.get("height", 1.0)), 0.75, 1.25)
	var body_type := str(character.get("bodyType", "classic"))
	var width := 0.84 if body_type == "slim" else (1.16 if body_type == "broad" else 1.0)
	var body_color := Color(str(character.get("bodyColor", "#f2c744")))
	var part_values: Variant = character.get("parts", {})
	var parts: Dictionary = part_values if part_values is Dictionary else {}
	_holder = Node3D.new()
	_holder.scale = Vector3(MODEL_SCALE * width, MODEL_SCALE * height, MODEL_SCALE * width)
	_holder.position = Vector3(0, 2.0 * MODEL_SCALE * height, 0)
	add_child(_holder)
	var inst: Node = MODEL.instantiate(); _holder.add_child(inst)
	skel = inst.find_child("Skeleton3D", true, false) as Skeleton3D
	var roles := {"torso": "Torso_00", "head": "Head_01", "arm_l": "Left Arm_02", "arm_r": "Right Arm_03", "leg_l": "Left Leg_04", "leg_r": "Right Leg_05"}
	for r in roles: bone[r] = skel.find_bone(roles[r])
	for i in skel.get_bone_count():
		rest_g[i] = skel.get_bone_global_rest(i).basis.orthonormalized(); rest_p[i] = skel.get_bone_rest(i).origin
	for mi in inst.find_children("*", "MeshInstance3D", true, false): _paint(mi as MeshInstance3D, parts, body_color)
	if _name_label:
		_name_label.position = Vector3(0, 2.85 * height, 0)
		_name_label.visible = _show_name and Settings.show_names

func _apply_names() -> void:
	if _name_label: _name_label.visible = _show_name and Settings.show_names

## Apply per-part colours and size directly to the skinned mesh vertices.
func _part_for_bone(name: String) -> String:
	if name.begins_with("Head"): return "head"
	if name.begins_with("Torso"): return "torso"
	if name.contains("Left Arm"): return "leftArm"
	if name.contains("Right Arm"): return "rightArm"
	if name.contains("Left Leg"): return "leftLeg"
	if name.contains("Right Leg"): return "rightLeg"
	return "torso"

func _paint(mi: MeshInstance3D, parts: Dictionary, legacy_skin: Color) -> void:
	var am := mi.mesh as ArrayMesh
	if am == null or mi.skin == null: return
	var arr := am.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]; var wts: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	if verts.is_empty() or bones.is_empty() or wts.is_empty(): return
	var per := bones.size() / verts.size()
	var roles := PackedStringArray(); roles.resize(verts.size())
	var bounds := {}
	for v in verts.size():
		var best := 0; var bw := -1.0
		for k in per:
			if wts[v * per + k] > bw: bw = wts[v * per + k]; best = bones[v * per + k]
		var nm := mi.skin.get_bind_name(best)
		if nm == "": nm = skel.get_bone_name(mi.skin.get_bind_bone(best))
		var role := _part_for_bone(nm); roles[v] = role
		var bb: AABB = bounds.get(role, AABB(verts[v], Vector3.ZERO))
		bounds[role] = bb.expand(verts[v])
	var sized := verts.duplicate()
	var cols := PackedColorArray(); cols.resize(verts.size())
	for v in verts.size():
		var role := roles[v]
		var spec: Dictionary = parts.get(role, {})
		var fallback := legacy_skin if role in ["head", "leftArm", "rightArm"] else (DEFAULT_SHIRT if role == "torso" else PANTS)
		var color := Color(str(spec.get("color", fallback.to_html(false))))
		var scale := clampf(float(spec.get("size", 1.0)), 0.7, 1.3)
		var bb: AABB = bounds[role]; var centre := bb.position + bb.size * 0.5
		sized[v] = centre + (verts[v] - centre) * scale
		cols[v] = Color(minf(color.r * 1.15, 1.0), minf(color.g * 1.15, 1.0), minf(color.b * 1.15, 1.0))
	arr[Mesh.ARRAY_VERTEX] = sized
	arr[Mesh.ARRAY_COLOR] = cols
	var nm2 := ArrayMesh.new(); nm2.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := am.surface_get_material(0).duplicate() as StandardMaterial3D
	mat.vertex_color_use_as_albedo = true; mat.roughness = 1.0; mat.metallic_specular = 0.0
	if str(mi.name).to_lower().contains("head"):
		_replace_face_texture(mat)
	nm2.surface_set_material(0, mat); mi.mesh = nm2

## Replace the model's baked face in its head atlas; no floating Sprite3D is added.
func _replace_face_texture(mat: StandardMaterial3D) -> void:
	if mat.albedo_texture == null: return
	var image := mat.albedo_texture.get_image()
	if image == null or image.is_empty(): return
	var w := image.get_width(); var h := image.get_height()
	var x0 := int(w * 0.25); var x1 := int(w * 0.52)
	var y0 := int(h * 0.20); var y1 := int(h * 0.82)
	var min_x := x1; var min_y := y1; var max_x := x0; var max_y := y0
	for y in range(y0, y1):
		for x in range(x0, x1):
			var px := image.get_pixel(x, y)
			if px.a > 0.5 and px.r < 0.12 and px.g < 0.12 and px.b < 0.12:
				min_x = mini(min_x, x); max_x = maxi(max_x, x); min_y = mini(min_y, y); max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y: return
	var pad := maxi(3, int(w * 0.004))
	var rx := maxi(0, min_x - pad); var ry := maxi(0, min_y - pad)
	var region := Rect2i(rx, ry, mini(w, max_x + pad + 1) - rx, mini(h, max_y + pad + 1) - ry)
	var sample_x := maxi(0, region.position.x - 2); var sample_y := clampi(region.position.y + region.size.y / 2, 0, h - 1)
	var background := image.get_pixel(sample_x, sample_y)
	image.fill_rect(region, background)
	var face := AvatarChip.face_image(128)
	face.flip_y()
	face.resize(region.size.x, region.size.y, Image.INTERPOLATE_LANCZOS)
	image.blend_rect(face, Rect2i(Vector2i.ZERO, face.get_size()), region.position)
	mat.albedo_texture = ImageTexture.create_from_image(image)

# ---- bone helpers (skeleton space is Z-up; character forward (+Z) is skeleton -Y) ----
func _pose(b: int, r_skel: Basis) -> void:
	var parent := skel.get_bone_parent(b)
	var pg: Basis = rest_g[parent] if parent >= 0 else Basis.IDENTITY
	skel.set_bone_pose_rotation(b, (pg.inverse() * r_skel * rest_g[b]).orthonormalized().get_rotation_quaternion())

func _swing_basis(fwd: float, out: float, left_side: bool) -> Basis:
	# fwd > 0 swings the limb forward; out > 0 spreads it sideways away from the body
	return Basis(Vector3.UP, (-out if left_side else out)) * Basis(Vector3.RIGHT, -fwd)

func _process(delta: float) -> void:
	if skel == null: return
	_t += delta
	if _prev_anim in ["jump", "fall"] and anim in ["idle", "run"]: _land_t = 0.22          # touched the ground
	_prev_anim = anim; _land_t = maxf(_land_t - delta, 0.0)
	var T := {"arm_l": 0.0, "arm_r": 0.0, "leg_l": 0.0, "leg_r": 0.0, "lean": 0.0, "out_l": 0.08, "out_r": 0.08, "bob": 0.0, "head": 0.0, "twist": 0.0, "legout": 0.0}
	var k := 1.0 - exp(-16.0 * delta)
	match anim:
		"run":
			# Walk and run blend with speed: slow = short, relaxed steps; fast = long strides, forward lean, arms pumping.
			var amp := clampf(speed / 13.0, 0.4, 1.0)
			_phase += delta * clampf(speed, 3.0, 22.0) * 0.62
			var s := sin(_phase)
			T.leg_l = s * 0.95 * amp; T.leg_r = -s * 0.95 * amp
			T.arm_l = -s * 0.85 * amp; T.arm_r = s * 0.85 * amp; T.out_l = 0.08 + 0.05 * amp; T.out_r = 0.08 + 0.05 * amp
			T.lean = 0.04 + 0.11 * amp; T.bob = -absf(cos(_phase)) * 0.16 * amp; T.twist = s * 0.14 * amp; T.head = -0.03 - 0.05 * amp
		"jump":
			T.arm_l = 2.6; T.arm_r = 2.6; T.out_l = 0.4; T.out_r = 0.4
			T.leg_l = 0.55; T.leg_r = -0.4; T.lean = -0.05; T.head = 0.12; T.bob = 0.04
		"fall":
			T.arm_l = 1.7; T.arm_r = 1.7; T.out_l = 0.85 + sin(_t * 9.0) * 0.06; T.out_r = 0.85 - sin(_t * 9.0) * 0.06
			T.leg_l = 0.3; T.leg_r = -0.25; T.legout = 0.18; T.head = 0.1; T.lean = 0.03
		_:
			var br := sin(_t * 1.7)
			T.arm_l = br * 0.035; T.arm_r = -br * 0.035; T.out_l = 0.09 + br * 0.02; T.out_r = 0.09 + br * 0.02
			T.bob = br * 0.025; T.head = sin(_t * 0.8) * 0.03; T.twist = sin(_t * 0.6) * 0.035 + sin(_t * 0.23) * 0.03
	if _land_t > 0.0:                                                  # landing dip: body drops, arms swing out for balance, then recovers
		var lp := _land_t / 0.22
		T.bob -= 0.2 * sin(lp * PI); T.lean += 0.08 * sin(lp * PI); T.out_l += 0.25 * lp; T.out_r += 0.25 * lp
	for key in T: _cur[key] = lerpf(_cur[key], T[key], k)
	# torso: lean about the hips, twist about the spine, bob up/down
	var torso: int = bone.torso
	_pose(torso, Basis(Vector3.BACK, _cur.twist) * Basis(Vector3.RIGHT, -_cur.lean))
	skel.set_bone_pose_position(torso, rest_p[torso] + Vector3(0, 0, _cur.bob))
	_pose(bone.head, Basis(Vector3.RIGHT, -_cur.head) * Basis(Vector3.BACK, -_cur.twist * 1.4))
	_pose(bone.arm_l, _swing_basis(_cur.arm_l, _cur.out_l, true))
	_pose(bone.arm_r, _swing_basis(_cur.arm_r, _cur.out_r, false))
	_pose(bone.leg_l, Basis(Vector3.UP, -_cur.legout) * Basis(Vector3.RIGHT, -_cur.leg_l))
	_pose(bone.leg_r, Basis(Vector3.UP, _cur.legout) * Basis(Vector3.RIGHT, -_cur.leg_r))

# ---------------- Roblox-style chat bubble ----------------
func _bubble_image(w: int, h: int, r: int, tail: int) -> Image:
	var H := h + tail; var img := Image.create(w, H, false, Image.FORMAT_RGBA8)
	for y in H:
		for x in w:
			var a := 0.0
			if y < h:
				var dx := maxf(maxf(r - x, x - (w - 1 - r)), 0.0); var dy := maxf(maxf(r - y, y - (h - 1 - r)), 0.0)
				a = clampf(0.5 - (sqrt(dx * dx + dy * dy) - r), 0.0, 1.0)
			else:
				a = clampf((tail - (y - h)) * 0.9 - absf(x - w / 2.0) + 0.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return img

func say(text: String) -> void:
	if _bubble: _bubble.queue_free()
	var font := ThemeDB.fallback_font; var fs := 30; var maxw := 300.0; var ps := 0.0055
	var ts := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, maxw, fs)
	var pad := 20; var tail := 14
	var w := int(ts.x) + pad * 2; var h := int(ts.y) + pad * 2
	_bubble = Node3D.new(); add_child(_bubble)
	var sp := Sprite3D.new(); sp.texture = ImageTexture.create_from_image(_bubble_image(w, h, 20, tail)); sp.pixel_size = ps
	sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED; sp.no_depth_test = true; sp.render_priority = 1; sp.shaded = false; sp.modulate = Color(1, 1, 1, 0.96)
	_bubble.add_child(sp)
	var lb := Label3D.new(); lb.text = text; lb.font_size = fs; lb.pixel_size = ps; lb.width = maxf(ts.x, 10.0) + 4.0
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; lb.modulate = Color(0.08, 0.08, 0.1); lb.outline_size = 0
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED; lb.no_depth_test = true; lb.render_priority = 2
	lb.position = Vector3(0, tail * ps * 0.5, 0.0); _bubble.add_child(lb)
	_bubble.position = Vector3(0, 3.2 + (h + tail) * ps * 0.5, 0)
	var me := _bubble
	await get_tree().create_timer(7.0).timeout
	if is_instance_valid(me) and me == _bubble: me.queue_free(); _bubble = null
