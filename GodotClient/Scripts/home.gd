extends Control
## Native BlockTopia app: email sign-in, game discovery, details and in-app launch.
const FIREBASE_API_KEY := "AIzaSyCdEvulpM-5MGOTqQhcIrCaeylSMzXtoaA"
const AUTH_URL := "https://identitytoolkit.googleapis.com/v1/accounts:"
const TOKEN_URL := "https://securetoken.googleapis.com/v1/token"
const BACKEND_URL := "https://blocktopia-server-i1bq.onrender.com"
const FIRESTORE_URL := "https://firestore.googleapis.com/v1/projects/blocktopia-f3341/databases/(default)/documents/"

var _http: HTTPRequest
var _scroll: ScrollContainer
var _center: CenterContainer
var _col: VBoxContainer
var _side: PanelContainer
var _side_user: Label
var _side_chip: AvatarChip
var _side_buttons := {}
var _content_tabs: Control
var _top_logout: Button
var _auth_shell: PanelContainer
var _auth_shell_margin: MarginContainer
var _update_notice: PanelContainer
var _status: Label
var _email: LineEdit
var _password: LineEdit
var _username: LineEdit
var _remember_check: CheckBox
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
var _character_preview: Avatar
var _character_height: HSlider
var _character_height_text: Label
var _character_type: OptionButton
var _character_part_sizes := {}
var _character_part_colors := {}
var _character_status: Label
var _settings_section := "account"
var _settings_gen := 0
var _account_info: Dictionary = {}      # Firebase accounts:lookup (email, verified, created, last sign-in)
var _device_registered := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new(); bg.color = Color(0.043, 0.043, 0.047); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(bg)
	_scroll = ScrollContainer.new(); _scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); _scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; add_child(_scroll)
	_center = CenterContainer.new(); _center.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _scroll.add_child(_center)
	_col = VBoxContainer.new(); _col.add_theme_constant_override("separation", 14); _col.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _center.add_child(_col)
	_build_sidebar()
	_http = HTTPRequest.new(); _http.timeout = 20.0; add_child(_http)
	get_viewport().size_changed.connect(_fit); _fit()
	_id_token = Settings.native_id_token
	_refresh_token = Settings.native_refresh_token
	_token_expiry = Settings.native_token_expiry
	_profile = Settings.native_profile.duplicate(true)
	Settings.app_update_available.connect(_on_app_update_available)
	Settings.check_for_app_update()
	if _refresh_token != "" or _id_token != "":
		_set_status_screen("Loading your BlockTopia dashboard…")
		if await _ensure_fresh_token():
			var result := await _api("profile", {})
			if result.ok and result.data.has("profile"):
				_profile = result.data.profile; Settings.native_profile = _profile.duplicate(true); _show_dashboard()
			elif result.ok and result.data.get("needsUsername", false):
				_show_profile_setup()
			else:
				_clear_native_session(); _show_auth()
		else:
			_clear_native_session(); _show_auth()
	else:
		_show_auth()

func _fit() -> void:
	if _col == null: return
	var vs := get_viewport().get_visible_rect().size
	var auth_screen := _screen in ["auth", "profile"]
	var desktop_nav := vs.x >= 900.0 and not auth_screen and _screen != "loading"
	if _side != null: _side.visible = desktop_nav
	if _content_tabs != null: _content_tabs.visible = not desktop_nav
	if _top_logout != null: _top_logout.visible = not desktop_nav
	_scroll.offset_left = 244.0 if desktop_nav else 0.0
	_scroll.offset_right = 0.0
	var available := vs.x - (276.0 if desktop_nav else (76.0 if auth_screen else 32.0))
	var max_width := 420.0 if auth_screen else (520.0 if _screen == "loading" else 1120.0)
	_col.custom_minimum_size = Vector2(clampf(available, 180.0, max_width), 0)
	_center.custom_minimum_size = Vector2(0, maxf(vs.y - 16.0, 0.0))
	_sync_navigation()

func _build_sidebar() -> void:
	_side = PanelContainer.new(); _side.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE); _side.offset_right = 236.0
	_side.add_theme_stylebox_override("panel", ThemeBuilder.box(Color(0.075, 0.075, 0.085), Color(0.18, 0.18, 0.2), 0))
	add_child(_side)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 16)
	_side.add_child(margin)
	var stack := VBoxContainer.new(); stack.add_theme_constant_override("separation", 10); margin.add_child(stack)
	var brand := HBoxContainer.new(); brand.add_theme_constant_override("separation", 10); stack.add_child(brand)
	var mark := TextureRect.new(); mark.texture = load("res://Assets/logo.png"); mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; mark.custom_minimum_size = Vector2(36, 36); brand.add_child(mark)
	var name := Label.new(); name.text = "BlockTopia"; name.add_theme_font_size_override("font_size", 21); name.size_flags_vertical = Control.SIZE_SHRINK_CENTER; brand.add_child(name)
	var group := ButtonGroup.new()
	for item in ["Home", "Friends", "Notifications", "Settings", "Customization"]:
		var button := Button.new(); button.text = item; button.alignment = HORIZONTAL_ALIGNMENT_LEFT; button.custom_minimum_size = Vector2(0, 46); button.toggle_mode = true; button.button_group = group
		button.add_theme_stylebox_override("normal", ThemeBuilder.box(Color(0.075, 0.075, 0.085), Color(0.075, 0.075, 0.085), 10))
		button.add_theme_stylebox_override("hover", ThemeBuilder.box(Color(0.13, 0.13, 0.15), Color(0.13, 0.13, 0.15), 10))
		button.add_theme_stylebox_override("pressed", ThemeBuilder.box(Color(0.93, 0.93, 0.95), Color(0.93, 0.93, 0.95), 10))
		button.add_theme_color_override("font_pressed_color", Color(0.05, 0.05, 0.06))
		if item == "Home": button.pressed.connect(_show_dashboard)
		elif item == "Friends": button.pressed.connect(_show_friends)
		elif item == "Notifications": button.pressed.connect(_show_notifications)
		elif item == "Settings": button.pressed.connect(_show_settings)
		else: button.pressed.connect(_show_customization)
		stack.add_child(button); _side_buttons[item] = button
	var spacer := Control.new(); spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL; stack.add_child(spacer)
	_side_chip = AvatarChip.new().setup("Player", Color("#f4f4f2"), 36, Color("#f2c744")); stack.add_child(_side_chip)
	_side_user = Label.new(); _side_user.text = ""; _side_user.clip_text = true; stack.add_child(_side_user)
	var out := Button.new(); out.text = "Sign out"; out.custom_minimum_size = Vector2(0, 44); out.pressed.connect(_sign_out); stack.add_child(out)
	_sync_navigation()

func _sync_navigation() -> void:
	if _side == null: return
	var is_desktop := _side.visible
	for name in _side_buttons:
		_side_buttons[name].button_pressed = (name == "Customization" and _screen == "customization") or (name == "Friends" and _screen == "friends") or (name == "Notifications" and _screen == "notifications") or (name == "Settings" and _screen == "settings") or (name == "Home" and _screen in ["dashboard", "details"])
	if _side_chip != null:
		var character := _character_data() if _profile.has("character") else {"bodyColor": "#f2c744"}
		var display := str(_profile.get("username", "Player"))
		_side_chip.setup(display, Color(str(_profile.get("avatarColor", "#f4f4f2"))), 36, Color(str(character.get("bodyColor", "#f2c744"))))
		_side_chip.queue_redraw()
		_side_user.text = display
		_side_chip.visible = is_desktop and _profile.has("username")
		_side_user.visible = is_desktop and _profile.has("username")

func _clear() -> void:
	_content_tabs = null; _top_logout = null
	for node in _col.get_children():
		_col.remove_child(node); node.queue_free()
	_status = null; _email = null; _password = null; _username = null; _remember_check = null; _report_edit = null; _report_reason = null
	_character_preview = null; _character_height = null; _character_height_text = null; _character_type = null; _character_part_sizes.clear(); _character_part_colors.clear(); _character_status = null; _update_notice = null

func _set_status_screen(message: String) -> void:
	_hide_auth_shell()
	_screen = "loading"; _clear()
	_add_text("BlockTopia", 34, false)
	_add_text(message, 18, true)
	_fit()

func _add_text(value: String, font_size := 18, muted := false) -> Label:
	var l := Label.new(); l.text = value; l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT; l.add_theme_font_size_override("font_size", font_size)
	if muted: l.modulate = Color(1, 1, 1, 0.68)
	_col.add_child(l); return l

func _add_field(placeholder: String, secret := false) -> LineEdit:
	var line := LineEdit.new(); line.placeholder_text = placeholder; line.secret = secret
	line.custom_minimum_size = Vector2(0, 46); line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.clear_button_enabled = not secret; _col.add_child(line); return line

func _add_button(label: String, callback: Callable, primary := false) -> Button:
	var b := Button.new(); b.text = label; b.custom_minimum_size = Vector2(0, 46); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 16)
	if primary:
		var style := ThemeBuilder.box(Color(0.93, 0.93, 0.95), Color(0.98, 0.98, 0.99), 10)
		b.add_theme_stylebox_override("normal", style); b.add_theme_stylebox_override("hover", style); b.add_theme_stylebox_override("pressed", style)
		b.add_theme_color_override("font_color", Color(0.05, 0.05, 0.06)); b.add_theme_color_override("font_hover_color", Color(0.05, 0.05, 0.06))
	b.pressed.connect(callback); _col.add_child(b); return b

func _add_tabs(detail := false) -> void:
	var scroll := ScrollContainer.new(); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO; scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 50); scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.visible = get_viewport().get_visible_rect().size.x < 900.0; _col.add_child(scroll); _content_tabs = scroll
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8); scroll.add_child(row)
	var group := ButtonGroup.new()
	var tab_style := ThemeBuilder.box(Color(0.12, 0.12, 0.14), Color(0.22, 0.22, 0.25), 10)
	var tab_on := ThemeBuilder.box(Color(0.93, 0.93, 0.95), Color(0.93, 0.93, 0.95), 10)
	for item in ["Home", "Friends", "Notifications", "Settings", "Customization"]:
		var button := Button.new(); button.text = item; button.toggle_mode = true; button.button_group = group; button.custom_minimum_size = Vector2(112, 44)
		button.add_theme_stylebox_override("normal", tab_style); button.add_theme_stylebox_override("hover", tab_style); button.add_theme_stylebox_override("pressed", tab_on); button.add_theme_color_override("font_pressed_color", Color(0.05, 0.05, 0.06))
		button.button_pressed = (item == "Home" and _screen in ["dashboard", "details"]) or (item == "Friends" and _screen == "friends") or (item == "Notifications" and _screen == "notifications") or (item == "Settings" and _screen == "settings") or (item == "Customization" and _screen == "customization")
		if item == "Home": button.pressed.connect(_show_dashboard)
		elif item == "Friends": button.pressed.connect(_show_friends)
		elif item == "Notifications": button.pressed.connect(_show_notifications)
		elif item == "Settings": button.pressed.connect(_show_settings)
		else: button.pressed.connect(_show_customization)
		row.add_child(button)
	if detail:
		var game := Button.new(); game.text = "Baseplate"; game.disabled = true; game.custom_minimum_size = Vector2(112, 44)
		game.add_theme_stylebox_override("normal", tab_style); row.add_child(game)

func _show_auth(message := "") -> void:
	_screen = "auth"; _show_auth_shell(); _clear()
	var logo := TextureRect.new(); logo.texture = load("res://Assets/logo.png"); logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; logo.custom_minimum_size = Vector2(64, 64); logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; _col.add_child(logo)
	var brand_title := _add_text("BlockTopia", 28)
	brand_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tagline := _add_text("Build, play and hang out in a shared world.", 14, true)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var modes := HBoxContainer.new(); modes.add_theme_constant_override("separation", 8); _col.add_child(modes)
	var mode_group := ButtonGroup.new()
	for mode in ["login", "signup"]:
		var b := Button.new(); b.text = "Log in" if mode == "login" else "Sign up"; b.custom_minimum_size = Vector2(0, 46)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; b.toggle_mode = true; b.button_group = mode_group; b.button_pressed = _auth_mode == mode
		b.add_theme_stylebox_override("normal", ThemeBuilder.box(Color(0.12, 0.12, 0.14), Color(0.22, 0.22, 0.25), 10))
		b.add_theme_stylebox_override("hover", ThemeBuilder.box(Color(0.16, 0.16, 0.18), Color(0.24, 0.24, 0.27), 10))
		b.add_theme_stylebox_override("pressed", ThemeBuilder.box(Color(0.93, 0.93, 0.95), Color(0.93, 0.93, 0.95), 10))
		b.add_theme_color_override("font_pressed_color", Color(0.05, 0.05, 0.06))
		b.pressed.connect(_set_auth_mode.bind(mode)); modes.add_child(b)
	if _auth_mode == "signup":
		_add_text("Username", 15, true)
		_username = _add_field("3–20 letters, numbers or underscores")
	_add_text("Email or username" if _auth_mode == "login" else "Email", 15, true)
	_email = _add_field("Email address or username" if _auth_mode == "login" else "Email address")
	_email.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT if _auth_mode == "login" else LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	_add_text("Password", 15, true)
	_password = _add_field("At least 8 characters", true); _password.secret = true
	_remember_check = null
	if _auth_mode == "login":
		_remember_check = CheckBox.new(); _remember_check.text = "Keep me logged in"; _remember_check.button_pressed = Settings.native_remember; _col.add_child(_remember_check)
	_add_button("Create account" if _auth_mode == "signup" else "Log in", _submit_auth, true)
	if _auth_mode == "login":
		_add_button("Forgot password?", _send_password_reset)
	_status = _add_text(message, 15, true); _status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fit()

func _set_auth_mode(mode: String) -> void:
	if _busy: return
	_auth_mode = mode; _show_auth()

func _submit_auth() -> void:
	if _busy: return
	var identifier := _email.text.strip_edges() if _email != null else ""
	var password := _password.text if _password != null else ""
	var username := _username.text.strip_edges() if _username != null else ""
	if identifier == "" or password == "":
		_status.text = "Enter your email or username and password."; return
	var is_signup := _auth_mode == "signup"
	if is_signup and not _valid_username(username):
		_status.text = "Choose a username with 3–20 letters, numbers or underscores."; return
	if is_signup and password.length() < 8:
		_status.text = "Use a password with at least 8 characters."; return
	_busy = true
	_status.text = "Creating your account…" if is_signup else "Signing in…"
	var result: Dictionary
	if is_signup or identifier.contains("@"):
		var endpoint := "signUp" if is_signup else "signInWithPassword"
		result = await _request_json(AUTH_URL + endpoint + "?key=" + FIREBASE_API_KEY, {"email": identifier, "password": password, "returnSecureToken": true})
	else:
		var username_result := await _request_json(BACKEND_URL + "/auth/username", {"username": identifier, "password": password})
		if not username_result.ok:
			_busy = false; _status.text = _auth_error(username_result.data); return
		var exchange := await _request_json(AUTH_URL + "signInWithCustomToken?key=" + FIREBASE_API_KEY, {"token": str(username_result.data.get("customToken", "")), "returnSecureToken": true})
		result = exchange
	if not result.ok:
		_busy = false; _status.text = _auth_error(result.data); return
	_store_tokens(result.data, true if is_signup else (_remember_check != null and _remember_check.button_pressed))
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
		"INVALID_LOGIN_CREDENTIALS", "EMAIL_NOT_FOUND", "INVALID_PASSWORD": return "That email or username and password don't match."
		"EMAIL_EXISTS": return "An account already uses that email. Log in instead."
		"INVALID_EMAIL": return "Enter a valid email address."
		"MISSING_PASSWORD": return "Enter your password."
		"WEAK_PASSWORD", "WEAK_PASSWORD : Password should be at least 6 characters": return "Use a stronger password."
		"TOO_MANY_ATTEMPTS_TRY_LATER", "TOO_MANY_ATTEMPTS": return "Too many attempts. Wait a little and try again."
		"USERNAME_LOGIN_UNAVAILABLE": return "Username sign in is temporarily unavailable. Try again later."
		"OPERATION_NOT_ALLOWED": return "Email and password sign-in is not enabled for this project."
		_: return "Couldn't sign in. Check your connection and try again."

func _send_password_reset() -> void:
	if _busy: return
	var email := _email.text.strip_edges() if _email != null else ""
	if email == "" or not email.contains("@"):
		_status.text = "Enter your email address to reset your password."; return
	_busy = true; _status.text = "Sending password reset email…"
	var result := await _request_json(AUTH_URL + "sendOobCode?key=" + FIREBASE_API_KEY, {"requestType": "PASSWORD_RESET", "email": email})
	_busy = false
	_status.text = "Check your inbox for a password reset link." if result.ok else _auth_error(result.data)

func _show_profile_setup(message := "") -> void:
	_screen = "profile"; _show_auth_shell(); _clear()
	_add_text("Choose your username", 30)
	_add_text("This name appears to other players in BlockTopia.", 16, true)
	_username = _add_field("Username (3–20 letters, numbers or _)")
	_add_button("Save username", _save_profile, true)
	_status = _add_text(message, 15, true)
	_fit()

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

func _show_auth_shell() -> void:
	if _auth_shell != null and is_instance_valid(_auth_shell): return
	if _col.get_parent() == _center: _center.remove_child(_col)
	_auth_shell = PanelContainer.new()
	_auth_shell.add_theme_stylebox_override("panel", ThemeBuilder.box(Color(0.09, 0.09, 0.105), Color(0.22, 0.22, 0.25), 16))
	_center.add_child(_auth_shell)
	_auth_shell_margin = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: _auth_shell_margin.add_theme_constant_override("margin_" + side, 22)
	_auth_shell.add_child(_auth_shell_margin); _auth_shell_margin.add_child(_col)

func _hide_auth_shell() -> void:
	if _auth_shell == null or not is_instance_valid(_auth_shell): return
	if _col.get_parent() == _auth_shell_margin: _auth_shell_margin.remove_child(_col)
	_center.remove_child(_auth_shell); _auth_shell.queue_free(); _auth_shell = null; _auth_shell_margin = null
	_center.add_child(_col)

func _add_app_header() -> void:
	var header := HBoxContainer.new(); header.add_theme_constant_override("separation", 10); _col.add_child(header)
	var logo := TextureRect.new(); logo.texture = load("res://Assets/logo.png"); logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; logo.custom_minimum_size = Vector2(38, 38); logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER; header.add_child(logo)
	var heading := Label.new(); heading.text = "BlockTopia"; heading.add_theme_font_size_override("font_size", 22); heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(heading)
	if _profile.has("username"):
		var chip := AvatarChip.new().setup(str(_profile.username), Color(str(_profile.get("avatarColor", "#f4f4f2"))), 34, Color(str(_character_data().bodyColor)))
		header.add_child(chip)
		var user := Label.new(); user.text = str(_profile.username); user.clip_text = true; user.custom_minimum_size = Vector2(45, 0); user.add_theme_color_override("font_color", Color(1, 1, 1, 0.75)); header.add_child(user)
	_top_logout = Button.new(); _top_logout.text = "Sign out"; _top_logout.custom_minimum_size = Vector2(100, 44); _top_logout.pressed.connect(_sign_out); header.add_child(_top_logout)

func _add_update_banner() -> void:
	if not Settings.update_available or (_update_notice != null and is_instance_valid(_update_notice)): return
	_update_notice = PanelContainer.new(); _update_notice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_update_notice.add_theme_stylebox_override("panel", ThemeBuilder.box(Color(0.11, 0.16, 0.25), Color(0.24, 0.42, 0.7), 12)); _col.add_child(_update_notice)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 10); _update_notice.add_child(row)
	var note := Label.new(); note.text = "Update %s is available. Download and install it, then reopen BlockTopia." % Settings.update_version; note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; note.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(note)
	var get_update := Button.new(); get_update.text = "Download"; get_update.custom_minimum_size = Vector2(100, 44); get_update.pressed.connect(_open_update_download); row.add_child(get_update)

func _on_app_update_available(_version: String) -> void:
	if _screen in ["dashboard", "details", "customization", "friends", "notifications", "settings"]: _add_update_banner()

func _open_update_download() -> void:
	if Settings.update_url != "": OS.shell_open(Settings.update_url)

func _add_friends_invite() -> void:
	_add_text("Friends", 23)
	var card := PanelContainer.new(); card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", ThemeBuilder.box(Color(0.1, 0.1, 0.12), Color(0.24, 0.24, 0.28), 14)); _col.add_child(card)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 12); card.add_child(row)
	var plus := Label.new(); plus.text = "+"; plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; plus.custom_minimum_size = Vector2(52, 52); plus.add_theme_font_size_override("font_size", 34); plus.add_theme_color_override("font_color", Color("#f2c744")); row.add_child(plus)
	var details := VBoxContainer.new(); details.size_flags_horizontal = Control.SIZE_EXPAND_FILL; details.add_theme_constant_override("separation", 4); row.add_child(details)
	var title := Label.new(); title.text = "Add people to play"; title.add_theme_font_size_override("font_size", 19); details.add_child(title)
	var caption := Label.new(); caption.text = "Explore BlockTopia together."; caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; caption.modulate = Color(1, 1, 1, 0.68); details.add_child(caption)
	var add := Button.new(); add.text = "Add people"; add.custom_minimum_size = Vector2(118, 46); add.pressed.connect(_show_friends); row.add_child(add)

func _show_friends() -> void:
	_hide_auth_shell()
	_screen = "friends"; _clear()
	_add_app_header()
	_add_update_banner()
	_add_tabs(false)
	_add_text("Friends", 26)
	_add_text("Add people to play and explore BlockTopia together.", 15, true)
	var card := PanelContainer.new(); card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", ThemeBuilder.box(Color(0.1, 0.1, 0.12), Color(0.24, 0.24, 0.28), 14)); _col.add_child(card)
	var body := VBoxContainer.new(); body.add_theme_constant_override("separation", 10); card.add_child(body)
	var note := Label.new(); note.text = "Find friends, accept requests, see who's playing, and join them from the website Friends tab."; note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; note.modulate = Color(1, 1, 1, 0.68); body.add_child(note)
	var open := Button.new(); open.text = "Open Friends"; open.custom_minimum_size = Vector2(0, 46); open.size_flags_horizontal = Control.SIZE_EXPAND_FILL; open.pressed.connect(_open_website_friends); body.add_child(open)
	_fit()

func _open_website_friends() -> void:
	OS.shell_open(Settings.WEBSITE_URL + "#/friends")

func _show_notifications() -> void:
	_hide_auth_shell()
	_screen = "notifications"; _clear()
	_add_app_header()
	_add_update_banner()
	_add_tabs(false)
	_add_text("Notifications", 26)
	_add_text("Friend requests and account updates.", 15, true)
	var actions := HBoxContainer.new(); actions.add_theme_constant_override("separation", 8); _col.add_child(actions)
	var mark := Button.new(); mark.text = "Mark all as read"; mark.custom_minimum_size = Vector2(0, 42); mark.pressed.connect(_mark_notifications_read); actions.add_child(mark)
	var list := VBoxContainer.new(); list.add_theme_constant_override("separation", 10); _col.add_child(list)
	_add_notification_state(list, "Loading notifications…")
	_fit()
	var result := await _api("notifications", {})
	if _screen != "notifications" or not is_instance_valid(list): return
	for child in list.get_children(): child.queue_free()
	if not result.ok:
		_add_notification_state(list, result.error if result.error != "" else "Couldn't load notifications. Try again.")
		return
	var items: Array = result.data.get("items", [])
	if items.is_empty():
		_add_notification_state(list, "No notifications yet.")
		return
	for item_value in items:
		if not item_value is Dictionary: continue
		var item: Dictionary = item_value
		var card := PanelContainer.new(); card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", ThemeBuilder.box(Color(0.1, 0.1, 0.12), Color(0.24, 0.24, 0.28), 12)); list.add_child(card)
		var inner := MarginContainer.new()
		for side in ["left", "right", "top", "bottom"]: inner.add_theme_constant_override("margin_" + side, 12)
		card.add_child(inner)
		var text := Label.new(); text.text = str(item.get("text", item.get("type", "BlockTopia update"))); text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; inner.add_child(text)
	_fit()

func _add_notification_state(parent: Node, message: String) -> void:
	var label := Label.new(); label.text = message; label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; label.modulate = Color(1, 1, 1, 0.68); parent.add_child(label)

func _mark_notifications_read() -> void:
	var result := await _api("notifications", {"action": "mark-read"})
	if not result.ok:
		if _screen == "notifications": _add_notification_state(_col, result.error if result.error != "" else "Couldn't update notifications.")
		return
	if _screen == "notifications": _show_notifications()

# ---------------- Settings: Account / Security / Privacy / Language (same sections as the website) ----------------
func _show_settings(section := "") -> void:
	_hide_auth_shell()
	if section != "": _settings_section = section
	_settings_gen += 1
	var gen := _settings_gen
	_screen = "settings"; _clear()
	_add_app_header()
	_add_update_banner()
	_add_tabs(false)
	_add_text("Settings", 26)
	_add_settings_tabs()
	var body := VBoxContainer.new(); body.add_theme_constant_override("separation", 14); body.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _col.add_child(body)
	if _account_info.is_empty():
		var loading := _settings_note(body, "Loading your account…")
		_fit()
		var loaded := await _load_account_info()
		if gen != _settings_gen or _screen != "settings": return
		loading.queue_free()
		if not loaded:
			_settings_note(body, "Couldn't load your account. Check your connection and try again.")
			var retry := Button.new(); retry.text = "Try again"; retry.custom_minimum_size = Vector2(0, 46); retry.pressed.connect(_show_settings); body.add_child(retry)
			_fit(); return
	match _settings_section:
		"security": await _build_security(body, gen)
		"privacy": await _build_privacy(body, gen)
		"language": _build_language(body)
		_: _build_account(body)
	if gen == _settings_gen and _screen == "settings": _fit()

func _add_settings_tabs() -> void:
	var flow := HFlowContainer.new(); flow.add_theme_constant_override("h_separation", 8); flow.add_theme_constant_override("v_separation", 8); flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _col.add_child(flow)
	var group := ButtonGroup.new()
	var off := ThemeBuilder.box(Color(0.12, 0.12, 0.14), Color(0.22, 0.22, 0.25), 10)
	var on := ThemeBuilder.box(Color(0.93, 0.93, 0.95), Color(0.93, 0.93, 0.95), 10)
	for item in [["account", "Account"], ["security", "Security"], ["privacy", "Privacy"], ["language", "Language"]]:
		var b := Button.new(); b.text = str(item[1]); b.toggle_mode = true; b.button_group = group; b.custom_minimum_size = Vector2(110, 42)
		b.add_theme_stylebox_override("normal", off); b.add_theme_stylebox_override("hover", off); b.add_theme_stylebox_override("pressed", on); b.add_theme_stylebox_override("hover_pressed", on)
		b.add_theme_color_override("font_pressed_color", Color(0.05, 0.05, 0.06)); b.add_theme_color_override("font_hover_pressed_color", Color(0.05, 0.05, 0.06))
		b.button_pressed = str(item[0]) == _settings_section
		b.pressed.connect(_show_settings.bind(str(item[0])))
		flow.add_child(b)

func _settings_card(parent: Node, title := "") -> VBoxContainer:
	var card := PanelContainer.new(); card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", ThemeBuilder.box(Color(0.1, 0.1, 0.12), Color(0.24, 0.24, 0.28), 14)); parent.add_child(card)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 14)
	card.add_child(margin)
	var stack := VBoxContainer.new(); stack.add_theme_constant_override("separation", 10); margin.add_child(stack)
	if title != "":
		var heading := Label.new(); heading.text = title; heading.add_theme_font_size_override("font_size", 19); stack.add_child(heading)
	return stack

func _settings_note(parent: Node, text: String) -> Label:
	var l := Label.new(); l.text = text; l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; l.modulate = Color(1, 1, 1, 0.68); l.add_theme_font_size_override("font_size", 15)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; parent.add_child(l); return l

func _settings_row(parent: Node, label: String, value: String) -> Label:
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 12); parent.add_child(row)
	var l := Label.new(); l.text = label; l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; l.custom_minimum_size = Vector2(110, 0); l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(l)
	var v := Label.new(); v.text = value; v.modulate = Color(1, 1, 1, 0.72); v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; v.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	v.custom_minimum_size = Vector2(120, 0); v.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(v)
	return v

func _settings_button(parent: Node, text: String, callback: Callable) -> Button:
	var b := Button.new(); b.text = text; b.custom_minimum_size = Vector2(0, 46); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if callback.is_valid(): b.pressed.connect(callback)
	parent.add_child(b); return b

func _settings_field(parent: Node, placeholder: String) -> LineEdit:
	var line := LineEdit.new(); line.placeholder_text = placeholder; line.secret = true
	line.custom_minimum_size = Vector2(0, 46); line.size_flags_horizontal = Control.SIZE_EXPAND_FILL; parent.add_child(line); return line

func _settings_option(parent: Node, label: String, items: Array, current: String, field: String, status: Label) -> void:
	var l := Label.new(); l.text = label; l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; parent.add_child(l)
	var pick := OptionButton.new(); pick.custom_minimum_size = Vector2(0, 46); pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL; parent.add_child(pick)
	for i in items.size():
		pick.add_item(str(items[i][1]), i)
		if str(items[i][0]) == current: pick.select(i)
	pick.item_selected.connect(_save_setting_choice.bind(items, field, status))

func _fmt_ms(value: Variant) -> String:
	var seconds := int(str(value)) / 1000
	return "—" if seconds <= 0 else Time.get_date_string_from_unix_time(seconds)

# ---- Account ----
func _build_account(body: Node) -> void:
	var card := _settings_card(body, "Account")
	_settings_row(card, "Username", str(_profile.get("username", "Player")))
	_settings_note(card, "Usernames can't be changed.")
	_settings_row(card, "Email", str(_account_info.get("email", "")))
	var verified := bool(_account_info.get("emailVerified", false))
	var verify_state := _settings_row(card, "Email status", "Verified" if verified else "Not verified")
	if not verified:
		var resend := _settings_button(card, "Resend verification email", Callable())
		resend.pressed.connect(_resend_verification.bind(resend, verify_state))
	var password := _settings_card(body, "Password")
	var open := _settings_button(password, "Change password", Callable())
	var form := VBoxContainer.new(); form.visible = false; form.add_theme_constant_override("separation", 8); password.add_child(form)
	var current := _settings_field(form, "Current password")
	var fresh := _settings_field(form, "New password (8+ characters)")
	var confirm := _settings_field(form, "Confirm new password")
	var status := _settings_note(form, "")
	var save := _settings_button(form, "Save password", Callable())
	open.pressed.connect(func(): form.visible = not form.visible)
	save.pressed.connect(_change_password.bind(current, fresh, confirm, status, save, form))
	var out := _settings_button(body, "Log out", _sign_out)
	out.add_theme_color_override("font_color", Color(1.0, 0.55, 0.55))

func _resend_verification(button: Button, status: Label) -> void:
	button.disabled = true; status.text = "Sending…"
	var result := await _api_auth("sendOobCode", {"requestType": "VERIFY_EMAIL", "idToken": _id_token})
	if is_instance_valid(status): status.text = "Email sent" if result.ok else "Couldn't send"
	if is_instance_valid(button): button.disabled = false

func _change_password(current: LineEdit, fresh: LineEdit, confirm: LineEdit, status: Label, save: Button, form: Control) -> void:
	if _busy: return
	if current.text == "" or fresh.text == "" or confirm.text == "": status.text = "Fill in all three fields."; return
	if fresh.text.length() < 8: status.text = "Use at least 8 characters."; return
	if fresh.text != confirm.text: status.text = "The new passwords don't match."; return
	_busy = true; save.disabled = true; status.text = "Saving…"
	var email := str(_account_info.get("email", ""))
	var check := await _request_json(AUTH_URL + "signInWithPassword?key=" + FIREBASE_API_KEY, {"email": email, "password": current.text, "returnSecureToken": true})
	if not check.ok:
		_busy = false
		if is_instance_valid(save): save.disabled = false
		if is_instance_valid(status): status.text = "Your current password isn't right." if int(check.code) == 400 else "Couldn't check your password. Try again."
		return
	var changed := await _request_json(AUTH_URL + "update?key=" + FIREBASE_API_KEY, {"idToken": str(check.data.get("idToken", "")), "password": fresh.text, "returnSecureToken": true})
	_busy = false
	if changed.ok: _store_tokens(changed.data, Settings.native_remember)
	if not is_instance_valid(status): return
	save.disabled = false
	if changed.ok:
		current.text = ""; fresh.text = ""; confirm.text = ""; form.visible = false
	status.text = "Password updated." if changed.ok else _auth_error(changed.data)

# ---- Security ----
func _build_security(body: Node, gen: int) -> void:
	var summary := _settings_card(body, "Security")
	var count := _settings_row(summary, "Devices signed in", "…")
	_settings_row(summary, "Account created", _fmt_ms(_account_info.get("createdAt", "0")))
	_settings_row(summary, "Last sign-in", _fmt_ms(_account_info.get("lastLoginAt", "0")))
	var card := _settings_card(body, "Your devices")
	var list := VBoxContainer.new(); list.add_theme_constant_override("separation", 12); card.add_child(list)
	_settings_note(list, "Loading devices…")
	_settings_note(card, "Signing out a device logs it out the next time it opens BlockTopia.")
	var result := await _fs(HTTPClient.METHOD_GET, "users/%s/devices?pageSize=100" % _uid())
	if gen != _settings_gen or _screen != "settings": return
	for child in list.get_children(): child.queue_free()
	if not result.ok:
		_settings_note(list, "Couldn't load your devices. Try again."); count.text = "—"; return
	var devices: Array = []
	for doc in result.data.get("documents", []):
		var fields: Dictionary = doc.get("fields", {})
		devices.append({"id": str(doc.get("name", "")).get_file(), "name": str(_fs_read(fields.get("name"))), "type": str(_fs_read(fields.get("type"))), "revoked": _fs_read(fields.get("revoked")) == true, "last": _fs_time(fields.get("lastActive"))})
	devices.sort_custom(func(a, b): return int(a.last) > int(b.last))
	var active := 0
	for d in devices:
		if not d.revoked: active += 1
	count.text = str(active)
	if devices.is_empty(): _settings_note(list, "No devices yet.")
	for d in devices:
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 10); list.add_child(row)
		var info := VBoxContainer.new(); info.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(info)
		var title := Label.new(); title.text = str(d.name) if str(d.name) != "" and str(d.name) != "<null>" else "Unknown device"; title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; info.add_child(title)
		var sub := "Signed out" if d.revoked else ("Active now" if int(Time.get_unix_time_from_system()) - int(d.last) < 180 else "Last active " + Time.get_date_string_from_unix_time(int(d.last)))
		_settings_note(info, sub)
		if str(d.id) == Settings.device_id:
			var tag := Label.new(); tag.text = "This device"; tag.modulate = Color(1, 1, 1, 0.68); row.add_child(tag)
		else:
			var action := Button.new(); action.text = "Remove" if d.revoked else "Sign out"; action.custom_minimum_size = Vector2(100, 44)
			action.pressed.connect(_device_action.bind("remove" if d.revoked else "out", str(d.id))); row.add_child(action)

func _device_action(action: String, id: String) -> void:
	var path := "users/%s/devices/%s" % [_uid(), id]
	if action == "out": await _fs_patch(path, {"revoked": true, "revokedAt": int(Time.get_unix_time_from_system() * 1000.0)})
	else: await _fs(HTTPClient.METHOD_DELETE, path)
	if _screen == "settings" and _settings_section == "security": _show_settings()

# ---- Privacy ----
func _build_privacy(body: Node, gen: int) -> void:
	var card := _settings_card(body, "Privacy")
	var loading := _settings_note(card, "Loading…")
	var result := await _fs(HTTPClient.METHOD_GET, "users/" + _uid())
	if gen != _settings_gen or _screen != "settings": return
	loading.queue_free()
	if not result.ok:
		_settings_note(card, "Couldn't load your privacy settings. Try again."); return
	var fields: Dictionary = result.data.get("fields", {})
	var requests_value: Variant = _fs_read(fields.get("allowRequests"))
	var join_value: Variant = _fs_read(fields.get("allowJoin"))
	var status := _settings_note(card, "")
	_settings_option(card, "Who can send you friend requests", [["everyone", "Everyone"], ["none", "No one"]], "none" if requests_value == "none" else "everyone", "allowRequests", status)
	_settings_option(card, "Who can join you in a game", [["friends", "Friends only"], ["nobody", "No one"]], "nobody" if join_value == "nobody" else "friends", "allowJoin", status)

func _save_setting_choice(index: int, items: Array, field: String, status: Label) -> void:
	status.text = "Saving…"
	var result := await _fs_patch("users/" + _uid(), {field: str(items[index][0])})
	if is_instance_valid(status): status.text = "Saved." if result.ok else "Couldn't save. Try again."

# ---- Language ----
func _build_language(body: Node) -> void:
	var card := _settings_card(body, "Language")
	_settings_row(card, "App language", "English")
	_settings_note(card, "The app is in English for now. Your website language is changed on the website.")
	_settings_button(card, "Open website language settings", func(): OS.shell_open(Settings.WEBSITE_URL + "#/settings/language"))

# ---- Firebase helpers (Firestore REST with the signed-in user's token; the same rules as the website apply) ----
func _uid() -> String:
	return str(_account_info.get("localId", ""))

func _api_auth(action: String, body: Dictionary) -> Dictionary:
	return await _request_json(AUTH_URL + action + "?key=" + FIREBASE_API_KEY, body)

func _load_account_info() -> bool:
	if not await _ensure_fresh_token(): return false
	var result := await _api_auth("lookup", {"idToken": _id_token})
	if not result.ok: return false
	var users: Array = result.data.get("users", [])
	if users.is_empty(): return false
	_account_info = users[0]
	return true

func _fs(method: int, path: String, body := {}) -> Dictionary:
	if not await _ensure_fresh_token(): return {"ok": false, "code": 401, "data": {}, "error": "Your session expired. Please sign in again."}
	var headers := PackedStringArray(["Content-Type: application/json", "Authorization: Bearer " + _id_token])
	return await _request_raw(FIRESTORE_URL + path, headers, method, "" if body.is_empty() else JSON.stringify(body))

func _fs_value(value: Variant) -> Dictionary:
	if value is bool: return {"booleanValue": value}
	if value is int: return {"integerValue": str(value)}
	return {"stringValue": str(value)}

func _fs_patch(path: String, fields: Dictionary) -> Dictionary:
	var query := PackedStringArray()
	var typed := {}
	for key in fields:
		query.append("updateMask.fieldPaths=" + str(key).uri_encode())
		typed[str(key)] = _fs_value(fields[key])
	return await _fs(HTTPClient.METHOD_PATCH, path + "?" + "&".join(query), {"fields": typed})

func _fs_read(value: Variant) -> Variant:
	if not (value is Dictionary): return null
	if value.has("stringValue"): return value.stringValue
	if value.has("booleanValue"): return value.booleanValue
	if value.has("integerValue"): return int(str(value.integerValue))
	if value.has("timestampValue"): return value.timestampValue
	return null

func _fs_time(value: Variant) -> int:
	var raw: Variant = _fs_read(value)
	if raw == null: return 0
	return int(Time.get_unix_time_from_datetime_string(str(raw).substr(0, 19)))

func _now_iso() -> String:
	return Time.get_datetime_string_from_system(true) + "Z"

# Lists this app under Settings > Security (like each browser does on the website) and honors "Sign out" from the website.
func _register_device() -> void:
	if _account_info.is_empty() and not await _load_account_info(): return
	if Settings.device_id == "":
		Settings.device_id = "app-%d-%d" % [int(Time.get_unix_time_from_system()), randi() % 1000000]
		Settings.save_cfg()
	var path := "users/%s/devices/%s" % [_uid(), Settings.device_id]
	var existing := await _fs(HTTPClient.METHOD_GET, path)
	var fields: Dictionary = existing.data.get("fields", {}) if existing.ok else {}
	if _fs_read(fields.get("revoked")) == true:
		var revoked_at := 0
		var raw_revoked: Variant = _fs_read(fields.get("revokedAt"))
		if raw_revoked != null: revoked_at = int(raw_revoked)
		if revoked_at > int(str(_account_info.get("lastLoginAt", "0"))):
			_clear_native_session(); _auth_mode = "login"; _show_auth("This device was signed out from your account settings.")
			return
	var info := {"name": "BlockTopia App · " + OS.get_name(), "browser": "BlockTopia App", "os": OS.get_name(), "type": "phone" if Settings.is_mobile() else "desktop", "revoked": false}
	var typed := {"lastActive": {"timestampValue": _now_iso()}}
	if not existing.ok: typed["firstSeen"] = {"timestampValue": _now_iso()}
	for key in info: typed[key] = _fs_value(info[key])
	var query := PackedStringArray()
	for key in typed: query.append("updateMask.fieldPaths=" + str(key).uri_encode())
	await _fs(HTTPClient.METHOD_PATCH, path + "?" + "&".join(query), {"fields": typed})

func _show_dashboard() -> void:
	_hide_auth_shell()
	_screen = "dashboard"; _clear()
	if not _device_registered: _device_registered = true; _register_device()
	_add_app_header()
	_add_update_banner()
	_add_tabs(false)
	_add_text("Welcome, %s" % str(_profile.get("username", "player")), 20)
	_add_friends_invite()
	_add_text("Featured", 23)
	var card := PanelContainer.new(); card.size_flags_horizontal = Control.SIZE_EXPAND_FILL; card.add_theme_stylebox_override("panel", ThemeBuilder.box(Color(0.1, 0.1, 0.12), Color(0.24, 0.24, 0.28), 14)); _col.add_child(card)
	var wide := get_viewport().get_visible_rect().size.x >= 720.0
	var body: BoxContainer = HBoxContainer.new() if wide else VBoxContainer.new(); body.add_theme_constant_override("separation", 0); card.add_child(body)
	var art := TextureRect.new(); art.texture = load("res://Assets/baseplate.png"); art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.custom_minimum_size = Vector2(380, 270) if wide else Vector2(0, 190); art.size_flags_horizontal = Control.SIZE_EXPAND_FILL; body.add_child(art)
	var inset := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: inset.add_theme_constant_override("margin_" + side, 18)
	inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL; body.add_child(inset)
	var info := VBoxContainer.new(); info.add_theme_constant_override("separation", 8); inset.add_child(info)
	var name := Label.new(); name.text = "BASEPLATE"; name.add_theme_font_size_override("font_size", 25); info.add_child(name)
	var by := Label.new(); by.text = "By BlockTopia"; by.modulate = Color(1, 1, 1, 0.62); info.add_child(by)
	var desc := Label.new(); desc.text = "Explore a sunny world, meet other players, chat and play together."; desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; info.add_child(desc)
	var open := Button.new(); open.text = "View game"; open.custom_minimum_size = Vector2(0, 48); open.pressed.connect(_show_details); info.add_child(open)
	var custom_card := PanelContainer.new(); custom_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_card.add_theme_stylebox_override("panel", ThemeBuilder.box(Color(0.1, 0.1, 0.12), Color(0.24, 0.24, 0.28), 14)); _col.add_child(custom_card)
	var custom_row := HBoxContainer.new(); custom_row.add_theme_constant_override("separation", 12); custom_card.add_child(custom_row)
	var custom_intro := VBoxContainer.new(); custom_intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL; custom_row.add_child(custom_intro)
	var custom_title := Label.new(); custom_title.text = "Make your character yours"; custom_title.add_theme_font_size_override("font_size", 20); custom_intro.add_child(custom_title)
	var custom_note := Label.new(); custom_note.text = "Set your height, body type, and each part's size and color."; custom_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; custom_note.modulate = Color(1, 1, 1, 0.65); custom_intro.add_child(custom_note)
	var custom_open := Button.new(); custom_open.text = "Customize"; custom_open.custom_minimum_size = Vector2(130, 48); custom_open.pressed.connect(_show_customization); custom_row.add_child(custom_open)
	_add_text("More games are coming soon.", 15, true)
	_fit()

func _character_data() -> Dictionary:
	var value: Variant = _profile.get("character", {})
	var c: Dictionary = value if value is Dictionary else {}
	var body_type := str(c.get("bodyType", "classic"))
	if not body_type in ["classic", "slim", "broad"]: body_type = "classic"
	var legacy_skin := str(c.get("bodyColor", "#f2c744"))
	var stored: Variant = c.get("parts", {})
	var parts: Dictionary = stored.duplicate(true) if stored is Dictionary else {}
	var defaults := {
		"head": {"size": 1.0, "color": legacy_skin}, "torso": {"size": 1.0, "color": "#2f6fd6"},
		"leftArm": {"size": 1.0, "color": legacy_skin}, "rightArm": {"size": 1.0, "color": legacy_skin},
		"leftLeg": {"size": 1.0, "color": "#3f9a52"}, "rightLeg": {"size": 1.0, "color": "#3f9a52"}
	}
	for part in defaults:
		var v: Variant = parts.get(part, {})
		var obj: Dictionary = v if v is Dictionary else {}
		defaults[part].size = clampf(float(obj.get("size", 1.0)), 0.7, 1.3)
		var color := str(obj.get("color", defaults[part].color))
		defaults[part].color = color if color.begins_with("#") and color.length() == 7 else defaults[part].color
	return {"height": clampf(float(c.get("height", 1.0)), 0.75, 1.25), "bodyType": body_type, "bodyColor": defaults["head"]["color"], "parts": defaults}

func _make_avatar_preview(parent: Node, character: Dictionary, size := Vector2(0, 210)) -> Avatar:
	var holder := SubViewportContainer.new(); holder.stretch = true; holder.custom_minimum_size = size
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL; parent.add_child(holder)
	var view := SubViewport.new(); view.size = Vector2i(360, 220); view.transparent_bg = true; view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.world_3d = World3D.new(); holder.add_child(view)
	var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-35, -25, 0); view.add_child(light)
	var camera := Camera3D.new(); camera.position = Vector3(0, 1.45, 3.8); camera.look_at(Vector3(0, 1.3, 0), Vector3.UP); camera.current = true; view.add_child(camera)
	var preview := Avatar.new(); preview.setup(str(_profile.get("username", "Player")), Color(str(_profile.get("avatarColor", "#2f6fd6"))), character, false); view.add_child(preview)
	return preview

func _add_character_customizer(parent: Node) -> void:
	var title := Label.new(); title.text = "Character"; title.add_theme_font_size_override("font_size", 24); parent.add_child(title)
	var panel := PanelContainer.new(); panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", ThemeBuilder.box(Color(0.1, 0.1, 0.12), Color(0.24, 0.24, 0.28), 14)); parent.add_child(panel)
	var body := VBoxContainer.new(); body.add_theme_constant_override("separation", 12); panel.add_child(body)
	var character := _character_data()
	_character_preview = _make_avatar_preview(body, character, Vector2(0, 220))
	var fields := VBoxContainer.new(); fields.add_theme_constant_override("separation", 7); body.add_child(fields)
	var height_row := HBoxContainer.new(); fields.add_child(height_row)
	_character_height_text = Label.new(); _character_height_text.text = "Height: %d%%" % roundi(float(character.height) * 100.0); _character_height_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL; height_row.add_child(_character_height_text)
	var height_value := Label.new(); height_value.text = "Body proportions"; height_value.modulate = Color(1, 1, 1, 0.62); fields.add_child(height_value)
	_character_height = HSlider.new(); _character_height.min_value = 0.75; _character_height.max_value = 1.25; _character_height.step = 0.05; _character_height.value = float(character.height); _character_height.custom_minimum_size = Vector2(0, 36); fields.add_child(_character_height)
	_character_height.value_changed.connect(func(_v): _preview_character())
	_character_type = OptionButton.new()
	for label in ["Classic", "Slim", "Broad"]: _character_type.add_item(label)
	_character_type.select(["classic", "slim", "broad"].find(str(character.bodyType)))
	_character_type.custom_minimum_size = Vector2(0, 44); fields.add_child(_character_type)
	_character_type.item_selected.connect(func(_i): _preview_character())
	var names := {"head": "Head", "torso": "Torso", "leftArm": "Left arm", "rightArm": "Right arm", "leftLeg": "Left leg", "rightLeg": "Right leg"}
	for part in names:
		var spec: Dictionary = character.parts[part]
		var row := VBoxContainer.new(); row.add_theme_constant_override("separation", 4); fields.add_child(row)
		var heading := HBoxContainer.new(); row.add_child(heading)
		var part_name := Label.new(); part_name.text = names[part]; part_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL; heading.add_child(part_name)
		var part_size_text := Label.new(); part_size_text.text = "%d%%" % roundi(float(spec.size) * 100.0); part_size_text.modulate = Color(1, 1, 1, 0.65); heading.add_child(part_size_text)
		var part_controls := HBoxContainer.new(); part_controls.add_theme_constant_override("separation", 8); row.add_child(part_controls)
		var slider := HSlider.new(); slider.min_value = 0.7; slider.max_value = 1.3; slider.step = 0.05; slider.value = float(spec.size); slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL; slider.custom_minimum_size = Vector2(0, 34); part_controls.add_child(slider)
		var picker := SwatchPicker.new(); part_controls.add_child(picker); picker.attach_grid(row); picker.color = Color(str(spec.color))
		_character_part_sizes[part] = slider; _character_part_colors[part] = picker
		slider.value_changed.connect(func(v): part_size_text.text = "%d%%" % roundi(v * 100.0); _preview_character())
		picker.color_changed.connect(func(_c): _preview_character())
	var reset := Button.new(); reset.text = "Reset to defaults"; reset.custom_minimum_size = Vector2(0, 46); reset.pressed.connect(_reset_character_controls); body.add_child(reset)
	var save := Button.new(); save.text = "Save customization"; save.custom_minimum_size = Vector2(0, 50); save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save.add_theme_stylebox_override("normal", ThemeBuilder.box(Color(0.2, 0.42, 0.82), Color(0.27, 0.5, 0.92), 10))
	save.pressed.connect(_save_character); body.add_child(save)
	_character_status = Label.new(); _character_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _character_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; body.add_child(_character_status)

func _read_character_controls() -> Dictionary:
	var types := ["classic", "slim", "broad"]
	var parts := {}
	for part in _character_part_sizes:
		parts[part] = {"size": _character_part_sizes[part].value, "color": _character_part_colors[part].color.to_html(false)}
	return {"height": _character_height.value, "bodyType": types[_character_type.selected], "bodyColor": parts["head"]["color"], "parts": parts}

func _preview_character() -> void:
	if _character_preview == null or not is_instance_valid(_character_preview): return
	var c := _read_character_controls()
	_character_height_text.text = "Height: %d%%" % roundi(float(c.height) * 100.0)
	_character_preview.apply_character(c)

func _reset_character_controls() -> void:
	_character_height.value = 1.0
	_character_type.select(0)
	var default_colors := {"head": "#f2c744", "torso": "#2f6fd6", "leftArm": "#f2c744", "rightArm": "#f2c744", "leftLeg": "#3f9a52", "rightLeg": "#3f9a52"}
	for part in default_colors:
		_character_part_sizes[part].value = 1.0
		_character_part_colors[part].color = Color(str(default_colors[part]))
	_preview_character()
	if _character_status != null: _character_status.text = "Default character restored. Save to apply."

func _save_character() -> void:
	if _busy: return
	_busy = true; _character_status.text = "Saving your character…"
	var result := await _api("profile", {"character": _read_character_controls()})
	_busy = false
	if result.ok and result.data.has("profile"):
		_profile = result.data.profile; Settings.native_profile = _profile.duplicate(true)
		_character_status.text = "Character saved to your account."
	else:
		_character_status.text = result.error if result.error != "" else "Couldn't save your character. Try again."

func _show_customization() -> void:
	_hide_auth_shell()
	_screen = "customization"; _clear()
	_add_app_header()
	_add_update_banner()
	_add_tabs(false)
	_add_text("Customization", 28)
	_add_text("Adjust your character like Roblox. Your changes sync to your website profile and games.", 16, true)
	_add_character_customizer(_col)
	_fit()

func _show_details() -> void:
	_hide_auth_shell()
	var should_load_reaction := _screen != "details"
	_screen = "details"; _clear()
	_add_app_header()
	_add_update_banner()
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
	_fit()

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
	_id_token = ""; _refresh_token = ""; _token_expiry = 0; _profile = {}; _reaction = ""; _report_open = false; _account_info = {}; _device_registered = false
	Settings.clear_native_session()

func _store_tokens(data: Dictionary, remember := true) -> void:
	_id_token = str(data.get("idToken", "")); _refresh_token = str(data.get("refreshToken", ""))
	_token_expiry = int(Time.get_unix_time_from_system()) + int(str(data.get("expiresIn", "3600")))
	Settings.native_id_token = _id_token; Settings.native_refresh_token = _refresh_token; Settings.native_token_expiry = _token_expiry
	Settings.persist_native_session(remember)

func _ensure_fresh_token() -> bool:
	if _id_token != "" and int(Time.get_unix_time_from_system()) < _token_expiry - 60: return true
	if _refresh_token == "": return false
	var form := "grant_type=refresh_token&refresh_token=" + _refresh_token.uri_encode()
	var result := await _request_raw(TOKEN_URL + "?key=" + FIREBASE_API_KEY, PackedStringArray(["Content-Type: application/x-www-form-urlencoded"]), HTTPClient.METHOD_POST, form)
	if not result.ok: return false
	var data: Dictionary = result.data
	_id_token = str(data.get("id_token", "")); _refresh_token = str(data.get("refresh_token", _refresh_token))
	_token_expiry = int(Time.get_unix_time_from_system()) + int(str(data.get("expires_in", "3600")))
	Settings.native_id_token = _id_token; Settings.native_refresh_token = _refresh_token; Settings.native_token_expiry = _token_expiry
	if Settings.native_remember: Settings.persist_native_session(true)
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
	# One HTTPRequest per call, so background requests (device registration) can't collide with screen requests.
	var http := HTTPRequest.new(); http.timeout = 20.0; add_child(http)
	var err := http.request(url, headers, method, body)
	if err != OK:
		http.queue_free()
		return {"ok": false, "code": 0, "data": {}, "error": "Could not connect. Check your internet and try again."}
	var reply: Array = await http.request_completed
	http.queue_free()
	var code := int(reply[1])
	var parsed: Variant = JSON.parse_string((reply[3] as PackedByteArray).get_string_from_utf8())
	var data: Dictionary = parsed if parsed is Dictionary else {}
	var error_value: Variant = data.get("error", "")
	var error_text := str(error_value.get("message", "")) if error_value is Dictionary else str(error_value)
	return {"ok": code >= 200 and code < 300, "code": code, "data": data, "error": error_text}
