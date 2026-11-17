class_name WorldBuilder
extends Node3D
## BASEPLATE world: one flat grey baseplate (500 x 500, matches the server bounds) under a clear blue sky image. No scenery, no clouds.
const HALF := 250.0                       # must match Backend/games/baseplate.js (CFG.HALF)
const SKY_PATH := "res://Assets/sky.png"  # equirectangular sky picture, swap it for any other 2:1 panorama
const PLATE_PATH := "res://Assets/baseplate.png"
var sun: DirectionalLight3D

func build() -> void:
	_environment(); _baseplate(); _walls()

func _environment() -> void:
	var env := Environment.new(); env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var pano := PanoramaSkyMaterial.new(); pano.panorama = load(SKY_PATH)
	sky.sky_material = pano; env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.82, 0.88, 0.97); env.ambient_light_energy = 0.52
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = false      # no fog: the sky picture stays clean
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	sun = DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-48, -32, 0); sun.light_color = Color(1.0, 0.97, 0.9); sun.light_energy = 0.72
	sun.shadow_enabled = true; sun.directional_shadow_max_distance = 90.0; sun.shadow_blur = 1.2; add_child(sun)

func _baseplate() -> void:
	var mat := StandardMaterial3D.new(); mat.albedo_texture = load(PLATE_PATH)
	mat.uv1_scale = Vector3(HALF * 2.0 / 8.0, HALF * 2.0 / 8.0, 1.0)     # the texture is 8 x 8 studs
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC; mat.roughness = 0.9; mat.metallic_specular = 0.2
	var body := StaticBody3D.new(); body.position = Vector3(0, -0.5, 0); add_child(body)
	var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = Vector3(HALF * 2.0, 1.0, HALF * 2.0); cs.shape = sh; body.add_child(cs)
	var mi := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(HALF * 2.0, HALF * 2.0); mi.mesh = pm; mi.position = Vector3(0, 0.5, 0); mi.material_override = mat; body.add_child(mi)
	# thin dark edge so the plate reads as a slab when you walk to the rim
	var edge := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(HALF * 2.0 - 0.1, 4.0, HALF * 2.0 - 0.1); edge.mesh = bm; edge.position = Vector3(0, -2.4, 0)
	var em := StandardMaterial3D.new(); em.albedo_color = Color(0.42, 0.41, 0.43); em.roughness = 1.0; edge.material_override = em; add_child(edge)

func _walls() -> void:       # invisible walls just past the server's movement limit so nobody walks off
	for s in [[Vector3(HALF + 1, 20, 0), Vector3(2, 40, HALF * 2)], [Vector3(-HALF - 1, 20, 0), Vector3(2, 40, HALF * 2)], [Vector3(0, 20, HALF + 1), Vector3(HALF * 2, 40, 2)], [Vector3(0, 20, -HALF - 1), Vector3(HALF * 2, 40, 2)]]:
		var w := StaticBody3D.new(); w.position = s[0]; add_child(w)
		var c := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = s[1]; c.shape = b; w.add_child(c)

func animate(_delta: float) -> void:
	pass                      # nothing moves in the world (no clouds)
