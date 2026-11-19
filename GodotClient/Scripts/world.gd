class_name WorldBuilder
extends Node3D
## BASEPLATE world: one flat grey baseplate (500 x 500, matches the server bounds) under a clear blue sky image. No scenery, no clouds.
const HALF := 250.0                       # must match Backend/games/baseplate.js (CFG.HALF)
const SKY_PATH := "res://Assets/sky.png"  # equirectangular sky picture, swap it for any other 2:1 panorama
const PLATE_PATH := "res://Assets/baseplate.png"
var sun: DirectionalLight3D
var env: Environment

func build() -> void:
	_environment(); _baseplate(); _walls()

func _environment() -> void:
	env = Environment.new(); env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var pano := PanoramaSkyMaterial.new(); pano.panorama = load(SKY_PATH)
	sky.sky_material = pano; env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.80, 0.87, 0.98); env.ambient_light_energy = 0.62
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY          # materials pick up a little of the sky
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC; env.tonemap_exposure = 1.1; env.tonemap_white = 5.0       # soft highlights instead of hard clipping
	env.adjustment_enabled = true; env.adjustment_contrast = 1.07; env.adjustment_saturation = 1.12            # a little more depth and colour
	env.glow_enabled = true; env.glow_intensity = 0.4; env.glow_strength = 0.9; env.glow_bloom = 0.04; env.glow_hdr_threshold = 1.0
	env.fog_enabled = false      # no fog: the sky picture stays clean
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	sun = DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-48, -32, 0); sun.light_color = Color(1.0, 0.96, 0.88); sun.light_energy = 1.0
	sun.shadow_enabled = true; sun.shadow_bias = 0.03; sun.shadow_normal_bias = 1.2; add_child(sun)

## Graphics quality: 0 Low, 1 Medium, 2 High, 3 Ultra. Each step gets sharper, softer shadows, smoother edges and sharper textures at an angle.
func apply_quality(q: int, vp: Viewport) -> void:
	q = clampi(q, 0, 2 if Settings.is_mobile() else 3)
	sun.shadow_enabled = q >= 1
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if q >= 2 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = [70.0, 110.0, 150.0, 220.0][q]
	sun.shadow_blur = [1.0, 1.2, 1.6, 2.2][q]
	RenderingServer.directional_shadow_atlas_set_size([2048, 2048, 4096, 8192][q], true)
	RenderingServer.directional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, RenderingServer.SHADOW_QUALITY_SOFT_HIGH][q])
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_8X][q]
	vp.anisotropic_filtering_level = [Viewport.ANISOTROPY_2X, Viewport.ANISOTROPY_4X, Viewport.ANISOTROPY_8X, Viewport.ANISOTROPY_16X][q]
	env.glow_enabled = q >= 2; env.glow_intensity = 0.35 if q == 2 else 0.5

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
