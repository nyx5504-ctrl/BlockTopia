class_name ChatUI
extends CanvasLayer
## Roblox-style top-left HUD: [menu button] [chat button]. The chat button toggles a chat window; the menu button opens the in-game menu.
signal menu_pressed
var menu_btn: IconButton
var chat_btn: IconButton
var window: PanelContainer
var log_box: RichTextLabel
var input: LineEdit
var typing := false
const NAME_COLORS := ["#fd7b7b", "#ffb86b", "#f7e26b", "#8be28b", "#6bd6e8", "#7aa7ff", "#c58bff", "#ff8bd0"]

func _ready() -> void:
	layer = 5
	var root := Control.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(root)
	var bar := HBoxContainer.new(); bar.position = Vector2(12, 10); bar.add_theme_constant_override("separation", 8); root.add_child(bar)
	menu_btn = IconButton.new("menu"); menu_btn.pressed.connect(func(): menu_pressed.emit()); bar.add_child(menu_btn)
	chat_btn = IconButton.new("chat"); chat_btn.pressed.connect(toggle_window); bar.add_child(chat_btn)
	window = PanelContainer.new(); window.position = Vector2(12, 66); window.custom_minimum_size = Vector2(380, 230); root.add_child(window)
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.04, 0.04, 0.05, 0.62); sb.set_corner_radius_all(14); sb.set_content_margin_all(10); window.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 8); window.add_child(v)
	log_box = RichTextLabel.new(); log_box.bbcode_enabled = true; log_box.scroll_following = true; log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_box.add_theme_font_size_override("normal_font_size", 16); log_box.add_theme_font_size_override("bold_font_size", 16); v.add_child(log_box)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 6); v.add_child(row)
	input = LineEdit.new(); input.placeholder_text = "Click here or press Enter to chat"; input.max_length = 150; input.size_flags_horizontal = Control.SIZE_EXPAND_FILL; input.custom_minimum_size = Vector2(0, 38)
	input.focus_entered.connect(func(): typing = true); input.focus_exited.connect(func(): typing = false)
	input.text_submitted.connect(_submit); input.gui_input.connect(_on_input); row.add_child(input)
	var send := Button.new(); send.text = "Send"; send.pressed.connect(func(): _submit(input.text)); row.add_child(send)
	window.visible = not Settings.is_mobile(); chat_btn.active = window.visible
	Net.chat_received.connect(_on_chat); Net.chat_blocked.connect(func(t): system(t, "#e8b33c")); Net.system_message.connect(func(t): system(t))

func toggle_window() -> void:
	window.visible = not window.visible; chat_btn.active = window.visible
	if window.visible: chat_btn.badge = false
	else: input.release_focus()

func _on_input(e: InputEvent) -> void:
	if e.is_action_pressed("menu"): input.release_focus(); input.accept_event()

func _submit(text: String) -> void:
	input.clear(); input.release_focus()
	if text.strip_edges() != "": Net.send_chat(text)

func open() -> void:
	if not window.visible: toggle_window()
	input.grab_focus()
func _esc(s: String) -> String: return s.replace("[", "[lb]")
func system(text: String, color := "#9a9aa2") -> void:
	log_box.append_text("[color=%s]%s[/color]\n" % [color, _esc(text)])
	if not window.visible: chat_btn.badge = true
func _on_chat(_id: int, pname: String, text: String) -> void:
	var col: String = NAME_COLORS[abs(pname.hash()) % NAME_COLORS.size()]
	log_box.append_text("[color=%s][b]%s[/b][/color]: %s\n" % [col, _esc(pname), _esc(text)])
	if not window.visible: chat_btn.badge = true
