class_name LocalPlayer
extends CharacterBody3D
## The player you control. Client moves immediately; the server validates every position (see Backend/games/baseplate.js).
const SPEED := 16.0
const JUMP := 12.0
const GRAVITY := 30.0
var avatar: Avatar
var pivot: Node3D
var arm: SpringArm3D
var cam: Camera3D
var yaw := 0.0
var pitch := -0.25
var blocked := false      # true while a menu / chat / overlay has focus
var touch: Node = null    # TouchControls (optional)
var test_move := Vector2.ZERO
var anim := "idle"
var rmb := false           # Roblox-style: hold right mouse to look around

func setup(display_name: String, color: Color) -> void:
	var cs := CollisionShape3D.new(); var cap := CapsuleShape3D.new(); cap.radius = 0.5; cap.height = 2.3
	cs.shape = cap; cs.position = Vector3(0, 1.15, 0); add_child(cs)
	avatar = Avatar.new(); add_child(avatar); avatar.setup(display_name, color)
	pivot = Node3D.new(); pivot.position = Vector3(0, 1.8, 0); add_child(pivot)
	arm = SpringArm3D.new(); arm.spring_length = Settings.cam_distance; arm.margin = 0.3; arm.add_excluded_object(get_rid()); pivot.add_child(arm)
	cam = Camera3D.new(); cam.fov = Settings.fov; cam.current = true; arm.add_child(cam)
	floor_snap_length = 0.3

func _unhandled_input(e: InputEvent) -> void:
	if blocked:
		if rmb: rmb = false; Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_RIGHT and not Settings.is_mobile():
		rmb = e.pressed; Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if e.pressed else Input.MOUSE_MODE_VISIBLE
	elif e is InputEventMouseMotion and rmb and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= e.relative.x * Settings.sensitivity
		pitch = clampf(pitch - e.relative.y * Settings.sensitivity, -1.3, 0.6)
	elif e is InputEventMouseButton and e.pressed and (e.button_index == MOUSE_BUTTON_WHEEL_UP or e.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		Settings.cam_distance = clampf(Settings.cam_distance + (-0.6 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 0.6), 2.0, 14.0)

func _physics_process(delta: float) -> void:
	arm.spring_length = lerpf(arm.spring_length, Settings.cam_distance, 0.2); cam.fov = Settings.fov
	var v := Vector2.ZERO; var want_jump := false
	if not blocked:
		v = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		want_jump = Input.is_action_just_pressed("jump") or Input.is_action_pressed("jump")
		var ls := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		yaw -= ls.x * 2.6 * delta; pitch = clampf(pitch - ls.y * 1.8 * delta, -1.3, 0.6)
		if touch:
			v += touch.move; v = v.limit_length(1.0)
			var ld: Vector2 = touch.consume_look()
			yaw -= ld.x * Settings.sensitivity * 1.4; pitch = clampf(pitch - ld.y * Settings.sensitivity * 1.4, -1.3, 0.6)
			want_jump = want_jump or touch.jump_held
	if test_move != Vector2.ZERO: v = test_move
	pivot.rotation.y = yaw; arm.rotation.x = pitch
	var dir := Basis(Vector3.UP, yaw) * Vector3(v.x, 0, v.y)
	velocity.x = dir.x * SPEED; velocity.z = dir.z * SPEED
	if is_on_floor():
		if want_jump: velocity.y = JUMP
	else:
		velocity.y = maxf(velocity.y - GRAVITY * delta, -50.0)
	move_and_slide()
	if dir.length() > 0.1:
		avatar.rotation.y = lerp_angle(avatar.rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-14.0 * delta))
	var hs := Vector2(velocity.x, velocity.z).length()
	anim = ("jump" if velocity.y > 0.5 else "fall") if not is_on_floor() else ("run" if hs > 0.5 else "idle")
	avatar.anim = anim; avatar.speed = hs

func teleport(p: Vector3) -> void:
	global_position = p; velocity = Vector3.ZERO
