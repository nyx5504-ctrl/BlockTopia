class_name WorldBuilder
extends Node3D
## Builds the BASEPLATE world in code: sunny sky, grass island, plaza + monument, trees, rocks, parkour, stepped hill, ramp, clouds.
const HALF := 250.0
var sun: DirectionalLight3D
var clouds: Array = []
var _rng := RandomNumberGenerator.new()
var _mats := {}
var _keep_out: Array = []     # [Vector2 center, radius] areas where scenery must not spawn

func _m(c: Color, emissive := false, unshaded := false) -> StandardMaterial3D:
	var key := str(c) + str(emissive) + str(unshaded)
	if _mats.has(key): return _mats[key]
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 1.0; m.metallic_specular = 0.0
	if emissive: m.emission_enabled = true; m.emission = c; m.emission_energy_multiplier = 1.4
	if unshaded: m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mats[key] = m; return m

func _box(pos: Vector3, size: Vector3, c: Color, collide := true, rot := Vector3.ZERO, emissive := false) -> Node3D:
	var n: Node3D
	if collide:
		n = StaticBody3D.new()
		var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = size; cs.shape = sh; n.add_child(cs)
	else:
		n = Node3D.new()
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = _m(c, emissive); n.add_child(mi)
	n.position = pos; n.rotation_degrees = rot; add_child(n); return n

func build() -> void:
	_rng.seed = 20261112
	_environment(); _ground(); _plaza(); _monument(); _fence(); _parkour(); _hill(); _ramp(); _lamps()
	_trees(); _bushes(); _rocks(); _clouds()

func _environment() -> void:
	var env := Environment.new(); env.background_mode = Environment.BG_SKY
	var sky := Sky.new(); var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.22, 0.5, 0.92); psm.sky_horizon_color = Color(0.68, 0.84, 0.97)
	psm.ground_horizon_color = Color(0.68, 0.84, 0.97); psm.ground_bottom_color = Color(0.42, 0.6, 0.78)
	psm.sun_angle_max = 25.0; psm.sun_curve = 0.15
	sky.sky_material = psm; env.sky = sky
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED; env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.8, 0.84, 0.92); env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR; env.tonemap_exposure = 1.0
	env.fog_enabled = true; env.fog_light_color = Color(0.74, 0.87, 0.98); env.fog_density = 0.0009
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	sun = DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-48, -32, 0); sun.light_color = Color(1.0, 0.96, 0.88); sun.light_energy = 0.75
	sun.shadow_enabled = true; sun.directional_shadow_max_distance = 90.0; sun.shadow_blur = 1.5; add_child(sun)

func _grass_texture() -> ImageTexture:
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	for y in 128:
		for x in 128:
			var chk := ((x / 64) + (y / 64)) % 2 == 0
			var base := Color(0.3, 0.57, 0.2) if chk else Color(0.27, 0.52, 0.18)
			var n := _rng.randf_range(-0.018, 0.018)
			var edge := x % 64 < 2 or y % 64 < 2
			var c := Color(base.r + n, base.g + n, base.b + n)
			img.set_pixel(x, y, c.darkened(0.12) if edge else c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _ground() -> void:
	var gm := StandardMaterial3D.new(); gm.albedo_texture = _grass_texture(); gm.uv1_triplanar = true; gm.uv1_world_triplanar = true; gm.uv1_scale = Vector3(0.0625, 0.0625, 0.0625)
	gm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC; gm.roughness = 1.0; gm.metallic_specular = 0.0
	var top := StaticBody3D.new(); top.position = Vector3(0, -0.5, 0); add_child(top)
	var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = Vector3(HALF * 2, 1, HALF * 2); cs.shape = sh; top.add_child(cs)
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = sh.size; mi.mesh = bm; mi.material_override = gm; top.add_child(mi)
	_box(Vector3(0, -17, 0), Vector3(HALF * 2, 32, HALF * 2), Color(0.42, 0.3, 0.2), false)             # dirt underside of the floating island
	var sea := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(6000, 6000); sea.mesh = pm; sea.position = Vector3(0, -24, 0)
	var sm := StandardMaterial3D.new(); sm.albedo_color = Color(0.2, 0.5, 0.78); sm.roughness = 0.3; sm.metallic = 0.2; sea.material_override = sm; add_child(sea)
	for s in [[Vector3(HALF + 1, 20, 0), Vector3(2, 40, HALF * 2)], [Vector3(-HALF - 1, 20, 0), Vector3(2, 40, HALF * 2)], [Vector3(0, 20, HALF + 1), Vector3(HALF * 2, 40, 2)], [Vector3(0, 20, -HALF - 1), Vector3(HALF * 2, 40, 2)]]:
		var w := StaticBody3D.new(); w.position = s[0]; add_child(w); var c := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = s[1]; c.shape = b; w.add_child(c)
	# dirt paths from the plaza in four directions
	for p in [[Vector3(95, 0.03, 0), Vector3(120, 0.04, 9)], [Vector3(-95, 0.03, 0), Vector3(120, 0.04, 9)], [Vector3(0, 0.03, 95), Vector3(9, 0.04, 120)], [Vector3(0, 0.03, -95), Vector3(9, 0.04, 120)]]:
		_box(p[0], p[1], Color(0.66, 0.56, 0.4), false)

func _plaza() -> void:
	var disc := func(r: float, h: float, y: float, c: Color):
		var mi := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = r; cm.bottom_radius = r; cm.height = h; cm.radial_segments = 64; mi.mesh = cm; mi.position = Vector3(0, y, 0); mi.material_override = _m(c); add_child(mi)
	disc.call(36.0, 0.08, 0.04, Color(0.68, 0.65, 0.6)); disc.call(30.0, 0.1, 0.05, Color(0.5, 0.48, 0.45)); disc.call(26.0, 0.12, 0.06, Color(0.68, 0.65, 0.6))
	for i in 8:    # spawn pads: must match Backend/games/baseplate.js (8 points, radius 20)
		var a := float(i) / 8.0 * TAU
		var pad := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 2.2; cm.bottom_radius = 2.2; cm.height = 0.14; pad.mesh = cm
		pad.material_override = _m(Color(0.35, 0.65, 1.0) if i % 2 == 0 else Color(0.95, 0.95, 1.0), true); pad.position = Vector3(cos(a) * 20.0, 0.1, sin(a) * 20.0); add_child(pad)
	_keep_out.append([Vector2.ZERO, 52.0])

func _monument() -> void:
	_box(Vector3(0, 0.5, 0), Vector3(16, 1, 16), Color(0.55, 0.57, 0.62))
	var W := Color(0.9, 0.9, 0.93); var G := Color(0.42, 0.43, 0.48)
	_box(Vector3(-2.7, 3.5, 0), Vector3(5, 5, 5), G); _box(Vector3(2.7, 3.5, 0), Vector3(5, 5, 5), W)
	_box(Vector3(-2.7, 8.7, 0), Vector3(5, 5, 5), W); _box(Vector3(2.7, 8.7, 0), Vector3(5, 5, 5), G)
	var l := Label3D.new(); l.text = "BLOCKTOPIA"; l.font_size = 96; l.pixel_size = 0.02; l.outline_size = 24; l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y; l.position = Vector3(0, 13.8, 0); add_child(l)

func _fence() -> void:
	var e := HALF - 4.0
	for side in 4:
		for i in range(-17, 18):
			var t := i * 14.0
			var pos: Vector3 = [Vector3(t, 1.4, e), Vector3(t, 1.4, -e), Vector3(e, 1.4, t), Vector3(-e, 1.4, t)][side]
			_box(pos, Vector3(0.8, 2.8, 0.8), Color(0.55, 0.38, 0.22), false)
	for y in [1.0, 2.1]:
		_box(Vector3(0, y, e), Vector3(HALF * 2 - 8, 0.35, 0.35), Color(0.62, 0.44, 0.26), false); _box(Vector3(0, y, -e), Vector3(HALF * 2 - 8, 0.35, 0.35), Color(0.62, 0.44, 0.26), false)
		_box(Vector3(e, y, 0), Vector3(0.35, 0.35, HALF * 2 - 8), Color(0.62, 0.44, 0.26), false); _box(Vector3(-e, y, 0), Vector3(0.35, 0.35, HALF * 2 - 8), Color(0.62, 0.44, 0.26), false)

func _parkour() -> void:       # arc of platforms climbing to a flag
	var cols := [Color("e5604d"), Color("e8b33c"), Color("4cc38a"), Color("5b8def"), Color("a06be0")]
	var n := 12
	for i in n:
		var a := -0.35 + i * 0.062
		var pos := Vector3(cos(a) * 125.0, 0.8 + 1.35 * i, sin(a) * 125.0 - 40.0)
		_box(pos, Vector3(5, 0.8, 5), cols[i % cols.size()], true, Vector3(0, -rad_to_deg(a), 0))
	var last := Vector3(cos(-0.35 + n * 0.062) * 125.0, 0.8 + 1.35 * n, sin(-0.35 + n * 0.062) * 125.0 - 40.0)
	_box(last, Vector3(12, 1, 12), Color("f2c744"), true)
	_box(last + Vector3(0, 3.5, 0), Vector3(0.3, 6, 0.3), Color(0.9, 0.9, 0.9), false); _box(last + Vector3(1.2, 5.6, 0), Vector3(2.4, 1.4, 0.15), Color("e5604d"), false)
	_keep_out.append([Vector2(125, -40), 30.0])

func _hill() -> void:          # stepped pyramid
	var c := Vector3(-100, 0, -70)
	for k in 5:
		var s := 46.0 - k * 9.0
		_box(c + Vector3(0, 0.9 + 1.8 * k, 0), Vector3(s, 1.8, s), Color(0.4, 0.62, 0.3).lightened(0.04 * k))
	_box(c + Vector3(0, 10.2, 0), Vector3(3, 3, 3), Color("f2c744"), true, Vector3(0, 45, 0), true)
	_keep_out.append([Vector2(c.x, c.z), 36.0])

func _ramp() -> void:
	_box(Vector3(0, 3, 122), Vector3(24, 6, 24), Color(0.62, 0.62, 0.68))
	_box(Vector3(0, 2.5, 95), Vector3(12, 1, 30.6), Color(0.72, 0.72, 0.78), true, Vector3(-11.3, 0, 0))
	_box(Vector3(0, 7.2, 122), Vector3(8, 2.4, 8), Color("5b8def"))
	_keep_out.append([Vector2(0, 105), 28.0])

func _lamps() -> void:
	for i in 12:
		var a := float(i) / 12.0 * TAU + 0.26
		var p := Vector3(cos(a) * 41.0, 0, sin(a) * 41.0)
		_box(p + Vector3(0, 3, 0), Vector3(0.45, 6, 0.45), Color(0.18, 0.18, 0.2), false)
		_box(p + Vector3(0, 6.5, 0), Vector3(1.4, 1.4, 1.4), Color(1.0, 0.92, 0.65), false, Vector3.ZERO, true)

func _free_spot(margin: float) -> Vector3:
	for _i in 60:
		var p := Vector2(_rng.randf_range(-HALF + 14, HALF - 14), _rng.randf_range(-HALF + 14, HALF - 14))
		var ok := absf(p.x) > 8.0 and absf(p.y) > 8.0
		for k in _keep_out:
			if p.distance_to(k[0]) < k[1] + margin: ok = false
		if ok: return Vector3(p.x, 0, p.y)
	return Vector3(200, 0, 200)

func _trees() -> void:
	var greens := [Color("3f9a3a"), Color("4aa843"), Color("36883a")]
	for i in 60:
		var p := _free_spot(4.0); var h := _rng.randf_range(4.0, 6.5); var g: Color = greens[i % 3]; var sc := _rng.randf_range(0.85, 1.25)
		_box(p + Vector3(0, h / 2, 0), Vector3(1.3, h, 1.3), Color(0.5, 0.33, 0.2))
		_box(p + Vector3(0, h + 1.2, 0), Vector3(6, 3, 6) * sc, g, false); _box(p + Vector3(0, h + 3.7, 0), Vector3(4.4, 2.6, 4.4) * sc, g.lightened(0.06), false); _box(p + Vector3(0, h + 5.7, 0), Vector3(2.4, 2, 2.4) * sc, g.lightened(0.12), false)

func _bushes() -> void:
	for i in 70:
		var p := _free_spot(1.0); var s := _rng.randf_range(1.4, 2.4)
		_box(p + Vector3(0, s * 0.35, 0), Vector3(s, s * 0.7, s), Color(0.28, 0.55, 0.28), false, Vector3(0, _rng.randf_range(0, 90), 0))
		if i % 3 == 0: _box(p + Vector3(s * 0.2, s * 0.75, s * 0.2), Vector3(0.45, 0.45, 0.45), [Color("e5604d"), Color("f2c744"), Color("ffffff")][i % 3 + (i / 3) % 3 - i % 3], false, Vector3.ZERO, false)

func _rocks() -> void:
	for i in 28:
		var p := _free_spot(3.0); var s := _rng.randf_range(2.0, 5.5); var gv := _rng.randf_range(0.42, 0.62)
		_box(p + Vector3(0, s * 0.3, 0), Vector3(s * 1.3, s * 0.6, s), Color(gv, gv, gv + 0.03), true, Vector3(0, _rng.randf_range(0, 180), 0))

func _clouds() -> void:
	for i in 18:
		var c := Node3D.new(); c.position = Vector3(_rng.randf_range(-420, 420), _rng.randf_range(80, 130), _rng.randf_range(-420, 420)); add_child(c)
		var parts := _rng.randi_range(4, 7)
		for j in parts:
			var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(_rng.randf_range(16, 30), _rng.randf_range(6, 11), _rng.randf_range(12, 20)); mi.mesh = bm
			mi.position = Vector3(j * 13.0 - parts * 6.0, _rng.randf_range(-2, 3), _rng.randf_range(-6, 6)); mi.material_override = _m(Color(1, 1, 1), false, true); mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; c.add_child(mi)
		clouds.append(c)

func animate(delta: float) -> void:
	for c in clouds:
		c.position.x += delta * (2.5 + (c.position.y - 80.0) * 0.03)
		if c.position.x > 460.0: c.position.x = -460.0
