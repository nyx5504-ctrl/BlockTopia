extends Control
## Shown when the client is opened by hand. Games start from the website (PLAY), so this is a landing page.
## Phones can't open blocktopia:// links on their own: the website copies the launch link, and this screen picks it up from the
## clipboard the moment the app opens (or you can paste it / press "Join from clipboard").
var status: Label
var link_in: LineEdit
var _last_clip := ""
var _scroll: ScrollContainer
var _center: CenterContainer
var _col: VBoxContainer
var _logo: TextureRect
var _title: Label
var _desc: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new(); bg.color = Color(0.043, 0.043, 0.047); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(bg)
	_scroll = ScrollContainer.new(); _scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); _scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; add_child(_scroll)
	_center = CenterContainer.new(); _center.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _scroll.add_child(_center)
	_col = VBoxContainer.new(); _col.add_theme_constant_override("separation", 14); _center.add_child(_col)
	_logo = TextureRect.new(); _logo.texture = load("res://Assets/logo.png"); _logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; _logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS; _col.add_child(_logo)
	_title = Label.new(); _title.text = "BlockTopia"; _title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _col.add_child(_title)
	_desc = Label.new(); _desc.text = "The BlockTopia client is still being worked on.\nFor now, use the website to join games."
	_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _desc.modulate = Color(1, 1, 1, 0.68); _col.add_child(_desc)
	var web := Button.new(); web.text = "Open the BlockTopia website"; web.custom_minimum_size = Vector2(0, 54)
	web.pressed.connect(func(): OS.shell_open(Settings.WEBSITE_URL)); _col.add_child(web)
	if Settings.is_mobile():
		var sep := HSeparator.new(); sep.modulate = Color(1, 1, 1, 0.25); _col.add_child(sep)
		var h := Label.new(); h.text = "Pressed Play on the website? Come back here and your game starts by itself. If it doesn't, tap the button below."
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; h.modulate = Color(1, 1, 1, 0.6); h.add_theme_font_size_override("font_size", 16); _col.add_child(h)
		var clip := Button.new(); clip.text = "Join from clipboard"; clip.custom_minimum_size = Vector2(0, 54); clip.pressed.connect(func(): _try_clipboard(true)); _col.add_child(clip)
		link_in = LineEdit.new(); link_in.placeholder_text = "or paste the blocktopia:// link here"; link_in.custom_minimum_size = Vector2(0, 50); _col.add_child(link_in)
		var join := Button.new(); join.text = "Join with pasted link"; join.custom_minimum_size = Vector2(0, 50); join.pressed.connect(_from_link); _col.add_child(join)
	status = Label.new(); status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; status.modulate = Color(1, 1, 1, 0.6); _col.add_child(status)
	get_viewport().size_changed.connect(_fit); _fit()
	_try_clipboard.call_deferred()

## Everything scales with the window so it fits a small landscape phone, a tall portrait phone and a big desktop window.
func _fit() -> void:
	var vs := get_viewport().get_visible_rect().size
	var w := clampf(vs.x - 40.0, 240.0, 560.0)
	_col.custom_minimum_size = Vector2(w, 0)
	_center.custom_minimum_size = Vector2(0, maxf(vs.y - 8.0, 0.0))
	var sz := clampf(minf(vs.y * 0.26, w * 0.5), 72.0, 190.0)
	_logo.custom_minimum_size = Vector2(sz, sz)
	_title.add_theme_font_size_override("font_size", int(clampf(vs.y * 0.075, 30.0, 46.0)))
	_desc.add_theme_font_size_override("font_size", int(clampf(vs.y * 0.036, 16.0, 20.0)))

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN: _try_clipboard()

func _try_clipboard(manual := false) -> void:
	if not is_inside_tree(): return
	var au := Settings.android_launch_uri()                  # app already open when the website's Play button was pressed
	if au != "" and Settings.parse_link(au):
		status.text = "Joining..."; get_tree().change_scene_to_file("res://Scenes/Baseplate.tscn"); return
	if not manual and not Settings.is_mobile(): return
	var c := DisplayServer.clipboard_get().strip_edges()
	if not c.begins_with("blocktopia://"):
		if manual: status.text = "No launch link on the clipboard. Press Play on the website first."
		return
	if c == _last_clip and not manual: return
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
