extends Control
## Native BlockTopia app: email sign-in, game discovery, details and in-app launch.
const FIREBASE_API_KEY := "AIzaSyCdEvulpM-5MGOTqQhcIrCaeylSMzXtoaA"
const AUTH_URL := "https://identitytoolkit.googleapis.com/v1/accounts:"
const TOKEN_URL := "https://securetoken.googleapis.com/v1/token"
const BACKEND_URL := "https://blocktopia-server-i1bq.onrender.com"

var _http: HTTPRequest
var _scroll: ScrollContainer
var _center: CenterContainer
var _col: VBoxContainer
var _status: Label
var _email: LineEdit
var _password: LineEdit
var _username: LineEdit
var _report_edit: TextEdit
var _report_reason: OptionButton
var _auth_mode := "login"
var _screen := "auth"
var _busy := false
var _id_token := ""
var _refresh_token := ""
var _token_expiry := 0
var _profile: Dictionary = {}
var _reaction := ""
var _report_open := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new(); bg.color = Color(0.043, 0.043, 0.047); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(bg)
	_scroll = ScrollContainer.new(); _scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); _scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; add_child(_scroll)
	_center = CenterContainer.new(); _center.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _scroll.add_child(_center)
	_col = VBoxContainer.new(); _col.add_theme_constant_override("separation", 14); _center.add_child(_col)
	_http = HTTPRequest.new(); _http.timeout = 20.0; add_child(_http)
	get_viewport().size_changed.connect(_fit); _fit()
	_id_token = Settings.native_id_token
	_refresh_token = Settings.native_refresh_token
	_token_expiry = Settings.native_token_expiry
	_profile = Settings.native_profile.duplicate(true)
	if _id_token != "":
		_set_status_screen("Loading your BlockTopia dashboard…")
		var result := await _api("profile", {})
		if result.ok and result.data.has("profile"):
			_profile = result.data.profile; Settings.native_profile = _profile.duplicate(true); _show_dashboard()
		elif result.ok and result.data.get("needsUsername", false):
			_show_profile_setup()
		else:
			_clear_native_session(); _show_auth()
	else:
		_show_auth()

func _fit() -> void:
	if _col == null: return
	var vs := get_viewport().get_visible_rect().size
	_col.custom_minimum_size = Vector2(clampf(vs.x - 32.0, 280.0, 720.0), 0)
	_center.custom_minimum_size = Vector2(0, maxf(vs.y - 16.0, 0.0))

func _clear() -> void:
	for node in _col.get_children():
		_col.remove_child(node); node.queue_free()
	_status = null; _email = null; _password = null; _username = null; _report_edit = null; _report_reason = null

func _set_status_screen(message: String) -> void:
	_screen = "loading"; _clear()
	_add_text("BlockTopia", 34, false)
	_add_text(message, 18, true)

func _add_text(value: String, font_size := 18, muted := false) -> Label:
	var l := Label.new(); l.text = value; l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.add_theme_font_size_override("font_size", font_size)
	if muted: l.modulate = Color(1, 1, 1, 0.68)
	_col.add_child(l); return l

func _add_field(placeholder: String, secret := false) -> LineEdit:
	var line := LineEdit.new(); line.placeholder_text = placeholder; line.secret = secret
	line.custom_minimum_size = Vector2(0, 52); line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.clear_button_enabled = not secret; _col.add_child(line); return line

func _add_button(label: String, callback: Callable, primary := false) -> Button:
	var b := Button.new(); b.text = label; b.custom_minimum_size = Vector2(0, 52); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 17)
	if primary:
		var style := ThemeBuilder.box(Color(0.2, 0.42, 0.82), Color(0.27, 0.5, 0.92), 10)
		b.add_theme_stylebox_override("normal", style); b.add_theme_stylebox_override("hover", style); b.add_theme_stylebox_override("pressed", style)
	b.pressed.connect(callback); _col.add_child(b); return b

func _add_tabs(detail := false) -> void:
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8); _col.add_child(row)
	var discover := Button.new(); discover.text = "Dashboard"; discover.custom_minimum_size = Vector2(0, 44); discover.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	discover.pressed.connect(_show_dashboard); row.add_child(discover)
	if detail:
		var game := Button.new(); game.text = "Baseplate"; game.disabled = true; game.custom_minimum_size = Vector2(0, 44); game.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(game)

func _show_auth(message := "") -> void:
	_screen = "auth"; _clear()
	var logo := TextureRect.new(); logo.texture = load("res://Assets/logo.png"); logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; logo.custom_minimum_size = Vector2(96, 96); logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; _col.add_child(logo)
	_add_text("BlockTopia", 34)
	_add_text("Sign in or create an account to discover and play games.", 16, true)
	var modes := HBoxContainer.new(); modes.add_theme_constant_override("separation", 8); _col.add_child(modes)
	var mode_group := ButtonGroup.new()
	for mode in ["login", "signup"]:
		var b := Button.new(); b.text = "Log in" if mode == "login" else "Sign up"; b.custom_minimum_size = Vector2(0, 46)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; b.toggle_mode = true; b.button_group = mode_group; b.button_pressed = _auth_mode == mode; b.pressed.connect(_set_auth_mode.bind(mode)); modes.add_child(b)
	if _auth_mode == "signup":
		_username = _add_field("Username (3–20 letters, numbers or _)")
	_email = _add_field("Email address"); _email.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	_password = _add_field("Password (at least 8 characters)", true); _password.secret = true
	_add_button("Create account" if _auth_mode == "signup" else "Log in", _submit_auth, true)
	if _auth_mode == "login":
		_add_button("Forgot password?", _send_password_reset)
	_status = _add_text(message, 15, true); _status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _set_auth_mode(mode: String) -> void:
	if _busy: return
	_auth_mode = mode; _show_auth()

func _submit_auth() -> void:
	if _busy: return
	var email := _email.text.strip_edges() if _email != null else ""
	var password := _password.text if _password != null else ""
	var username := _username.text.strip_edges() if _username != null else ""
	if email == "" or password == "":
		_status.text = "Enter your email and password."; return
	var is_signup := _auth_mode == "signup"
	if is_signup and not _valid_username(username):
		_status.text = "Choose a username with 3–20 letters, numbers or underscores."; return
	if is_signup and password.length() < 8:
		_status.text = "Use a password with at least 8 characters."; return
	_busy = true; _status.text = "Signing in…"
	var endpoint := "signUp" if is_signup else "signInWithPassword"
	var result := await _request_json(AUTH_URL + endpoint + "?key=" + FIREBASE_API_KEY, {"email": email, "password": password, "returnSecureToken": true})
	if not result.ok:
		_busy = false; _status.text = _auth_error(result.data); return
	_store_tokens(result.data)
	if is_signup:
		await _request_json(AUTH_URL + "sendOobCode?key=" + FIREBASE_API_KEY, {"requestType": "VERIFY_EMAIL", "idToken": _id_token})
	_status.text = "Loading your dashboard…"
	var profile_result := await _api("profile", {"username": username} if is_signup else {})
	_busy = false
	if not profile_result.ok:
		if is_signup:
			_show_profile_setup(profile_result.error); return
		_status.text = profile_result.error if profile_result.error != "" else "Couldn't load your profile. Try again."; return
	if profile_result.data.get("needsUsername", false):
		_show_profile_setup(); return
	_profile = profile_result.data.get("profile", {}); Settings.native_profile = _profile.duplicate(true)
	_show_dashboard()

func _valid_username(value: String) -> bool:
	var regex := RegEx.new(); regex.compile("^[A-Za-z0-9_]{3,20}$")
	return regex.search(value) != null

func _auth_error(data: Dictionary) -> String:
	var err: Variant = data.get("error", {})
	var code := str(err.get("message", "")) if err is Dictionary else str(err)
	match code:
		"INVALID_LOGIN_CREDENTIALS", "EMAIL_NOT_FOUND", "INVALID_PASSWORD": return "That email and password don't match."
		"EMAIL_EXISTS": return "An account already uses that email. Log in instead."
		"INVALID_EMAIL": return "Enter a valid email address."
		"MISSING_PASSWORD": return "Enter your password."
		"WEAK_PASSWORD", "WEAK_PASSWORD : Password should be at least 6 characters": return "Use a stronger password."
		"TOO_MANY_ATTEMPTS_TRY_LATER": return "Too many attempts. Wait a little and try again."
		"OPERATION_NOT_ALLOWED": return "Email and password sign-in is not enabled for this project."
		_: return "Couldn't sign in. Check your connection and try again."

func _send_password_reset() -> void:
	if _busy: return
	var email := _email.text.strip_edges() if _email != null else ""
	if email == "":
		_status.text = "Enter your email address first."; return
	_busy = true; _status.text = "Sending password reset email…"
	var result := await _request_json(AUTH_URL + "sendOobCode?key=" + FIREBASE_API_KEY, {"requestType": "PASSWORD_RESET", "email": email})
	_busy = false
	_status.text = "Check your inbox for a password reset link." if result.ok else _auth_error(result.data)

func _show_profile_setup(message := "") -> void:
	_screen = "profile"; _clear()
	_add_text("Choose your username", 30)
	_add_text("This name appears to other players in BlockTopia.", 16, true)
	_username = _add_field("Username (3–20 letters, numbers or _)")
	_add_button("Save username", _save_profile, true)
	_status = _add_text(message, 15, true)

func _save_profile() -> void:
	if _busy: return
	var name := _username.text.strip_edges()
	if not _valid_username(name):
		_status.text = "Choose a username with 3–20 letters, numbers or underscores."; return
	_busy = true; _status.text = "Saving your profile…"
	var result := await _api("profile", {"username": name})
	_busy = false
	if not result.ok:
		_status.text = result.error if result.error != "" else "Couldn't save that username. Try another."; return
	_profile = result.data.get("profile", {}); Settings.native_profile = _profile.duplicate(true); _show_dashboard()

func _show_dashboard() -> void:
	_screen = "dashboard"; _clear()
	var header := HBoxContainer.new(); header.add_theme_constant_override("separation", 10); _col.add_child(header)
	var heading := Label.new(); heading.text = "BlockTopia"; heading.add_theme_font_size_override("font_size", 30); heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(heading)
	var logout := Button.new(); logout.text = "Sign out"; logout.custom_minimum_size = Vector2(110, 44); logout.pressed.connect(_sign_out); header.add_child(logout)
	_add_tabs(false)
	_add_text("Welcome, %s" % str(_profile.get("username", "player")), 23)
	_add_text("Discover", 28)
	var card := PanelContainer.new(); card.size_flags_horizontal = Control.SIZE_EXPAND_FILL; card.add_theme_stylebox_override("panel", ThemeBuilder.box(Color(0.1, 0.1, 0.12), Color(0.24, 0.24, 0.28), 14)); _col.add_child(card)
	var body := VBoxContainer.new(); body.add_theme_constant_override("separation", 10); card.add_child(body)
	var art := TextureRect.new(); art.texture = load("res://Assets/baseplate.png"); art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; art.custom_minimum_size = Vector2(0, 190); art.size_flags_horizontal = Control.SIZE_EXPAND_FILL; body.add_child(art)
	var inset := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: inset.add_theme_constant_override("margin_" + side, 14)
	body.add_child(inset)
	var info := VBoxContainer.new(); info.add_theme_constant_override("separation", 7); inset.add_child(info)
	var name := Label.new(); name.text = "BASEPLATE"; name.add_theme_font_size_override("font_size", 25); info.add_child(name)
	var by := Label.new(); by.text = "By BlockTopia"; by.modulate = Color(1, 1, 1, 0.62); info.add_child(by)
	var desc := Label.new(); desc.text = "Explore a sunny world, meet other players, chat and play together."; desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; info.add_child(desc)
	var open := Button.new(); open.text = "View game"; open.custom_minimum_size = Vector2(0, 50); open.pressed.connect(_show_details); info.add_child(open)
	_add_text("More games are coming soon.", 15, true)

func _show_details() -> void:
	var should_load_reaction := _screen != "details"
	_screen = "details"; _clear()
	var header := HBoxContainer.new(); header.add_theme_constant_override("separation", 10); _col.add_child(header)
	var heading := Label.new(); heading.text = "BlockTopia"; heading.add_theme_font_size_override("font_size", 28); heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(heading)
	var logout := Button.new(); logout.text = "Sign out"; logout.custom_minimum_size = Vector2(110, 44); logout.pressed.connect(_sign_out); header.add_child(logout)
	_add_tabs(true)
	var art := TextureRect.new(); art.texture = load("res://Assets/baseplate.png"); art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; art.custom_minimum_size = Vector2(0, 240); art.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _col.add_child(art)
	_add_text("BASEPLATE", 31)
	_add_text("By BlockTopia", 17, true)
	_add_text("A sunny multiplayer world to explore, chat, meet friends and play together.", 17)
	var votes := HBoxContainer.new(); votes.add_theme_constant_override("separation", 10); _col.add_child(votes)
	var like := Button.new(); like.text = "♥  Like" if _reaction != "like" else "♥  Liked"; like.custom_minimum_size = Vector2(0, 50); like.size_flags_horizontal = Control.SIZE_EXPAND_FILL; like.pressed.connect(_send_reaction.bind("like")); votes.add_child(like)
	var dislike := Button.new(); dislike.text = "Dislike" if _reaction != "dislike" else "Disliked"; dislike.custom_minimum_size = Vector2(0, 50); dislike.size_flags_horizontal = Control.SIZE_EXPAND_FILL; dislike.pressed.connect(_send_reaction.bind("dislike")); votes.add_child(dislike)
	_add_button("Report this game", _toggle_report)
	if _report_open:
		_report_reason = OptionButton.new()
		for choice in ["Inappropriate content", "Abuse", "Spam", "Other"]: _report_reason.add_item(choice)
		_report_reason.custom_minimum_size = Vector2(0, 48); _report_reason.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _col.add_child(_report_reason)
		_report_edit = TextEdit.new(); _report_edit.placeholder_text = "Tell us what is wrong with this game."; _report_edit.custom_minimum_size = Vector2(0, 110); _report_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _col.add_child(_report_edit)
		_add_button("Send report", _submit_game_report, true)
	_add_button("Play", _launch_game, true)
	_status = _add_text("", 15, true)
	if should_load_reaction: _load_reaction()

func _toggle_report() -> void:
	if _busy: return
	_report_open = not _report_open; _show_details()

func _load_reaction() -> void:
	_busy = true
	var result := await _api("game-feedback", {"game": "baseplate", "action": "get-reaction"})
	_busy = false
	if _screen == "details" and result.ok:
		_reaction = str(result.data.get("reaction", "")); _show_details()

func _send_reaction(value: String) -> void:
	if _busy: return
	_busy = true; _status.text = "Saving your reaction…"
	var result := await _api("game-feedback", {"game": "baseplate", "action": "reaction", "reaction": value})
	_busy = false
	if result.ok:
		_reaction = str(result.data.get("reaction", "")); _show_details(); _status.text = "Your reaction was saved."
	else: _status.text = result.error if result.error != "" else "Couldn't save your reaction."

func _submit_game_report() -> void:
	if _busy: return
	var details := _report_edit.text.strip_edges() if _report_edit != null else ""
	if details == "":
		_status.text = "Add a short reason for the report."; return
	var reasons := ["inappropriate_content", "abuse", "spam", "other"]
	var reason: String = "other"
	if _report_reason != null:
		reason = str(reasons[_report_reason.selected])
	_busy = true; _status.text = "Sending your report…"
	var result := await _api("game-feedback", {"game": "baseplate", "action": "report", "reason": reason, "details": details})
	_busy = false
	if result.ok:
		_report_open = false; _show_details(); _status.text = "Thanks. Your report was sent to the BlockTopia team."
	else: _status.text = result.error if result.error != "" else "Couldn't send the report."

func _launch_game() -> void:
	if _busy: return
	_busy = true; _status.text = "Preparing your game…"
	var result := await _api("launch", {"game": "baseplate"})
	_busy = false
	if not result.ok or not result.data.has("code") or not result.data.has("ws"):
		_status.text = result.error if result.error != "" else "Couldn't start the game. Try again."; return
	Settings.launch = {"game": "baseplate", "code": str(result.data.code), "ws": str(result.data.ws)}
	Settings.protocol_launched = false
	get_tree().change_scene_to_file("res://Scenes/Baseplate.tscn")

func _sign_out() -> void:
	if _busy: return
	_clear_native_session(); _auth_mode = "login"; _show_auth()

func _clear_native_session() -> void:
	_id_token = ""; _refresh_token = ""; _token_expiry = 0; _profile = {}; _reaction = ""; _report_open = false
	Settings.native_id_token = ""; Settings.native_refresh_token = ""; Settings.native_token_expiry = 0; Settings.native_profile = {}

func _store_tokens(data: Dictionary) -> void:
	_id_token = str(data.get("idToken", "")); _refresh_token = str(data.get("refreshToken", ""))
	_token_expiry = int(Time.get_unix_time_from_system()) + int(str(data.get("expiresIn", "3600")))
	Settings.native_id_token = _id_token; Settings.native_refresh_token = _refresh_token; Settings.native_token_expiry = _token_expiry

func _ensure_fresh_token() -> bool:
	if _id_token == "": return false
	if int(Time.get_unix_time_from_system()) < _token_expiry - 60: return true
	if _refresh_token == "": return false
	var form := "grant_type=refresh_token&refresh_token=" + _refresh_token.uri_encode()
	var result := await _request_raw(TOKEN_URL + "?key=" + FIREBASE_API_KEY, PackedStringArray(["Content-Type: application/x-www-form-urlencoded"]), HTTPClient.METHOD_POST, form)
	if not result.ok: return false
	var data: Dictionary = result.data
	_id_token = str(data.get("id_token", "")); _refresh_token = str(data.get("refresh_token", _refresh_token))
	_token_expiry = int(Time.get_unix_time_from_system()) + int(str(data.get("expires_in", "3600")))
	Settings.native_id_token = _id_token; Settings.native_refresh_token = _refresh_token; Settings.native_token_expiry = _token_expiry
	return _id_token != ""

func _api(path: String, body: Dictionary) -> Dictionary:
	var fresh := await _ensure_fresh_token()
	if not fresh: return {"ok": false, "code": 401, "data": {}, "error": "Your session expired. Please sign in again."}
	return await _request_json(BACKEND_URL + "/" + path, body, _id_token)

func _request_json(url: String, body: Dictionary, bearer := "") -> Dictionary:
	var headers := PackedStringArray(["Content-Type: application/json"])
	if bearer != "": headers.append("Authorization: Bearer " + bearer)
	return await _request_raw(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))

func _request_raw(url: String, headers: PackedStringArray, method: int, body: String) -> Dictionary:
	var err := _http.request(url, headers, method, body)
	if err != OK: return {"ok": false, "code": 0, "data": {}, "error": "Could not connect. Check your internet and try again."}
	var reply: Array = await _http.request_completed
	var code := int(reply[1])
	var parsed: Variant = JSON.parse_string((reply[3] as PackedByteArray).get_string_from_utf8())
	var data: Dictionary = parsed if parsed is Dictionary else {}
	var error_value: Variant = data.get("error", "")
	var error_text := str(error_value.get("message", "")) if error_value is Dictionary else str(error_value)
	return {"ok": code >= 200 and code < 300, "code": code, "data": data, "error": error_text}
