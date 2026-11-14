extends Control
## Shown when the client is opened by hand. Games start from the website (PLAY), so this is just a landing page.
## On phones there is also a "Join from link" box, because Android can't open blocktopia:// links on its own.
var status: Label
var link_in: LineEdit
var _last_clip := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new(); bg.color = Color(0.043, 0.043, 0.047); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(bg)
	var c := CenterContainer.new(); c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(c)
	var col := VBoxContainer.new(); col.add_theme_constant_override("separation", 16); col.custom_minimum_size = Vector2(560, 0); c.add_child(col)
	var logo := TextureRect.new(); logo.texture = load("res://Assets/logo.png"); logo.custom_minimum_size = Vector2(190, 190)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS; col.add_child(logo)
	var t := Label.new(); t.text = "BlockTopia"; t.add_theme_font_size_override("font_size", 46); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; col.add_child(t)
	var d := Label.new(); d.text = "The BlockTopia client is still being worked on.\nFor now, use the website to join games."
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; d.modulate = Color(1, 1, 1, 0.68); d.add_theme_font_size_override("font_size", 20); col.add_child(d)
	var web := Button.new(); web.text = "Open the BlockTopia website"; web.custom_minimum_size = Vector2(0, 54)
	web.pressed.connect(func(): OS.shell_open(Settings.WEBSITE_URL)); col.add_child(web)
	if Settings.is_mobile():
		var sep := HSeparator.new(); sep.modulate = Color(1, 1, 1, 0.25); col.add_child(sep)
		var h := Label.new(); h.text = "Already pressed Play on the website? Paste the launch link here."; h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; h.modulate = Color(1, 1, 1, 0.55); h.add_theme_font_size_override("font_size", 16); col.add_child(h)
		link_in = LineEdit.new(); link_in.placeholder_text = "blocktopia://play?..."; link_in.custom_minimum_size = Vector2(0, 50); col.add_child(link_in)
		var join := Button.new(); join.text = "Join game"; join.custom_minimum_size = Vector2(0, 50); join.pressed.connect(_from_link); col.add_child(join)
	status = Label.new(); status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; status.modulate = Color(1, 1, 1, 0.6); col.add_child(status)
	_try_clipboard.call_deferred()

# Phones can't open blocktopia:// links, so the website copies the link and we pick it up from the clipboard when the app opens / comes to the front.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN: _try_clipboard()

func _try_clipboard() -> void:
	if not Settings.is_mobile() or not is_inside_tree(): return
	var c := DisplayServer.clipboard_get().strip_edges()
	if c == "" or c == _last_clip or not c.begins_with("blocktopia://"): return
	_last_clip = c
	if Settings.parse_link(c):
		DisplayServer.clipboard_set("")          # a launch link works once, don't reuse it
		status.text = "Joining..."
		get_tree().change_scene_to_file("res://Scenes/Baseplate.tscn")
	else:
		status.text = "That launch link has a problem. Press Play on the website again."

func _from_link() -> void:
	if Settings.parse_link(link_in.text.strip_edges()): get_tree().change_scene_to_file("res://Scenes/Baseplate.tscn")
	else: status.text = "That doesn't look like a valid, current BlockTopia link. Press Play on the website again and copy the new one."
