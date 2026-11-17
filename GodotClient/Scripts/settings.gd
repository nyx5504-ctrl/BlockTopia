extends Node
## Global settings, input map, launch info (from blocktopia:// links) and protocol registration.
const WEBSITE_URL := "https://nyx5504-ctrl.github.io/BlockTopia/"
const CFG_PATH := "user://settings.cfg"
signal changed

var sensitivity := 0.003
var volume := 0.8
var quality := 1            # 0 low, 1 medium, 2 high
var fov := 70.0
var cam_distance := 6.0
var touch_opacity := 0.6
var touch_size := 1.0
var show_fps := false
var show_names := true
var fullscreen := false
var registered_exe := ""
var launch := {}            # {game, code, ws}
var protocol_launched := false
# Native sign-in tokens live only for this app session and never go into a game link or settings.cfg.
var native_id_token := ""
var native_refresh_token := ""
var native_token_expiry := 0
var native_profile: Dictionary = {}

func _ready() -> void:
	load_cfg()
	_register_actions()
	apply_audio()
	if fullscreen: apply_window()

func reset_defaults() -> void:
	sensitivity = 0.003; volume = 0.8; quality = 1; fov = 70.0; cam_distance = 6.0; touch_opacity = 0.6; touch_size = 1.0
	show_fps = false; show_names = true; fullscreen = false
	apply_audio(); apply_window(); save_cfg(); changed.emit()

func apply_window() -> void:
	if is_mobile(): return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func is_mobile() -> bool:
	return OS.has_feature("mobile") or DisplayServer.is_touchscreen_available() or "--mobile" in OS.get_cmdline_user_args() or "--mobile" in OS.get_cmdline_args()

func load_cfg() -> void:
	var c := ConfigFile.new()
	if c.load(CFG_PATH) != OK: return
	for k in ["sensitivity", "volume", "quality", "fov", "cam_distance", "touch_opacity", "touch_size", "registered_exe", "show_fps", "show_names", "fullscreen"]:
		set(k, c.get_value("s", k, get(k)))

func save_cfg() -> void:
	var c := ConfigFile.new()
	for k in ["sensitivity", "volume", "quality", "fov", "cam_distance", "touch_opacity", "touch_size", "registered_exe", "show_fps", "show_names", "fullscreen"]:
		c.set_value("s", k, get(k))
	c.save(CFG_PATH)
	apply_audio()
	changed.emit()

func apply_audio() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))

## Parses blocktopia://play?game=baseplate&code=XXXX&ws=wss%3A%2F%2Fhost  (single-use code, never a password/token)
func parse_link(link: String) -> bool:
	if not link.begins_with("blocktopia://"): return false
	var q := link.get_slice("?", 1) if "?" in link else ""
	var d := {}
	for pair in q.split("&"):
		if "=" in pair: d[pair.get_slice("=", 0)] = pair.get_slice("=", 1).uri_decode()
	if d.get("code", "") == "" or d.get("ws", "") == "": return false
	if not (str(d.ws).begins_with("ws://") or str(d.ws).begins_with("wss://")): return false
	launch = {"game": d.get("game", "baseplate"), "code": d.code, "ws": d.ws}
	return true

## Android: when the website opens blocktopia:// (via the app's intent filter) the link arrives as the launch intent's data.
## Returns "" on other platforms, on builds without the intent filter, or when there is nothing new. Each link is returned once.
var _last_intent := ""
func android_launch_uri() -> String:
	if not OS.has_feature("android") or not Engine.has_singleton("AndroidRuntime"): return ""
	var rt = Engine.get_singleton("AndroidRuntime")
	var act = rt.getActivity() if rt else null
	if act == null: return ""
	var intent = act.getIntent()
	if intent == null: return ""
	var d = intent.getDataString()
	var u := str(d) if d != null else ""
	if not u.begins_with("blocktopia://") or u == _last_intent: return ""
	_last_intent = u
	return u

func _ev_key(k: Key) -> InputEventKey:
	var e := InputEventKey.new(); e.physical_keycode = k; return e
func _ev_axis(a: JoyAxis, v: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new(); e.axis = a; e.axis_value = v; return e
func _ev_btn(b: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new(); e.button_index = b; return e
func _add(action: String, events: Array) -> void:
	if InputMap.has_action(action): return
	InputMap.add_action(action, 0.2)
	for e in events: InputMap.action_add_event(action, e)

func _register_actions() -> void:
	_add("move_forward", [_ev_key(KEY_W), _ev_key(KEY_UP), _ev_axis(JOY_AXIS_LEFT_Y, -1.0)])
	_add("move_back", [_ev_key(KEY_S), _ev_key(KEY_DOWN), _ev_axis(JOY_AXIS_LEFT_Y, 1.0)])
	_add("move_left", [_ev_key(KEY_A), _ev_key(KEY_LEFT), _ev_axis(JOY_AXIS_LEFT_X, -1.0)])
	_add("move_right", [_ev_key(KEY_D), _ev_key(KEY_RIGHT), _ev_axis(JOY_AXIS_LEFT_X, 1.0)])
	_add("jump", [_ev_key(KEY_SPACE), _ev_btn(JOY_BUTTON_A)])
	_add("menu", [_ev_key(KEY_ESCAPE), _ev_btn(JOY_BUTTON_START)])
	_add("chat", [_ev_key(KEY_ENTER), _ev_key(KEY_KP_ENTER), _ev_key(KEY_SLASH)])
	_add("look_left", [_ev_axis(JOY_AXIS_RIGHT_X, -1.0)])
	_add("look_right", [_ev_axis(JOY_AXIS_RIGHT_X, 1.0)])
	_add("look_up", [_ev_axis(JOY_AXIS_RIGHT_Y, -1.0)])
	_add("look_down", [_ev_axis(JOY_AXIS_RIGHT_Y, 1.0)])

## Windows: asks the registry what blocktopia:// opens. "ok" = this exe, "points elsewhere" = another/old copy, "not registered", "" = not Windows.
func protocol_status() -> String:
	if not OS.has_feature("windows") or OS.has_feature("editor"): return ""
	var out := []
	var code := OS.execute("reg", ["query", "HKCU\\Software\\Classes\\blocktopia\\shell\\open\\command", "/ve"], out, true)
	if code != 0: return "not registered"
	var exe := OS.get_executable_path().replace("/", "\\").to_lower()
	return "ok" if "".join(out).to_lower().contains(exe) else "points elsewhere"

## Registers blocktopia:// with the OS for the installed (non-editor) desktop client.
func register_protocol(wait := false) -> void:
	if OS.has_feature("editor") or protocol_launched: return      # launched by the link => the OS already points at this exe
	var exe := OS.get_executable_path()
	if OS.has_feature("windows"):
		# Write a .reg file and import it silently. (reg.exe via OS.execute drops empty args and quotes, which broke the link.)
		var win_exe := exe.replace("/", "\\")
		var reg_path := OS.get_user_data_dir() + "/blocktopia-link.reg"
		var f := FileAccess.open(reg_path, FileAccess.WRITE)
		if f == null: return
		var q := "\""
		var cmd := q + win_exe.replace("\\", "\\\\") + q + " " + q + "%1" + q
		f.store_string("Windows Registry Editor Version 5.00\r\n\r\n[HKEY_CURRENT_USER\\Software\\Classes\\blocktopia]\r\n@=\"URL:BlockTopia Protocol\"\r\n\"URL Protocol\"=\"\"\r\n\r\n[HKEY_CURRENT_USER\\Software\\Classes\\blocktopia\\shell\\open\\command]\r\n@=\"" + cmd.replace("\"", "\\\"") + "\"\r\n")
		f.close()
		if wait: OS.execute("regedit", ["/s", reg_path.replace("/", "\\")])
		else: OS.create_process("regedit", ["/s", reg_path.replace("/", "\\")])
	elif OS.has_feature("linux"):
		var dir := OS.get_environment("HOME") + "/.local/share/applications"
		DirAccess.make_dir_recursive_absolute(dir)
		var f := FileAccess.open(dir + "/blocktopia.desktop", FileAccess.WRITE)
		if f:
			f.store_string("[Desktop Entry]\nType=Application\nName=BlockTopia\nExec=\"%s\" %%u\nMimeType=x-scheme-handler/blocktopia;\nTerminal=false\nCategories=Game;\n" % exe)
			f.close()
			OS.execute("xdg-mime", ["default", "blocktopia.desktop", "x-scheme-handler/blocktopia"])
	else:
		return   # macOS/iOS/Android register the scheme through their export settings (see Documentation/BUILDING.md)
	registered_exe = exe
	save_cfg()
