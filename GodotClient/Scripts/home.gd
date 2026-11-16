extends Control
## BlockTopia client home: shows the game and lets you join via a link. Sessions are normally started from the website.
var status: Label
var play: Button
var link_in: LineEdit

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new(); bg.color = Color(0.043, 0.043, 0.047); bg.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(bg)
	var c := CenterContainer.new(); c.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(c)
	var col := VBoxContainer.new(); col.add_theme_constant_override("separation", 14); col.custom_minimum_size = Vector2(460, 0); c.add_child(col)
	var logo := TextureRect.new(); logo.texture = load("res://Assets/icon.svg"); logo.custom_minimum_size = Vector2(88, 88); logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; col.add_child(logo)
	var t := Label.new(); t.text = "BlockTopia"; t.add_theme_font_size_override("font_size", 44); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; col.add_child(t)
	var card := PanelContainer.new(); col.add_child(card)
	var cm := MarginContainer.new(); for s in ["left", "right", "top", "bottom"]: cm.add_theme_constant_override("margin_" + s, 18)
	card.add_child(cm)
	var cv := VBoxContainer.new(); cv.add_theme_constant_override("separation", 10); cm.add_child(cv)
	var n := Label.new(); n.text = "BASEPLATE"; n.add_theme_font_size_override("font_size", 26); cv.add_child(n)
	var d := Label.new(); d.text = "A big open 3D baseplate. Run, jump and chat with other players."; d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; d.modulate = Color(1, 1, 1, 0.7); cv.add_child(d)
	play = Button.new(); play.text = "Play"; play.custom_minimum_size = Vector2(0, 52); play.pressed.connect(_play); cv.add_child(play)
	status = Label.new(); status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; status.modulate = Color(1, 1, 1, 0.6); col.add_child(status)
	var web := Button.new(); web.text = "Open BlockTopia website"; web.pressed.connect(func(): OS.shell_open(Settings.WEBSITE_URL)); col.add_child(web)
	link_in = LineEdit.new(); link_in.placeholder_text = "Paste a blocktopia:// link (Android / manual)"; col.add_child(link_in)
	var join := Button.new(); join.text = "Join from link"; join.pressed.connect(_from_link); col.add_child(join)
	_refresh()

func _refresh() -> void:
	var ready_to_play: bool = Settings.launch.has("code")
	play.disabled = not ready_to_play
	status.text = "Ready to join Baseplate." if ready_to_play else "Press PLAY on the BlockTopia website to start a session. Launch links work once and expire after a minute."

func _from_link() -> void:
	if Settings.parse_link(link_in.text.strip_edges()): _refresh(); _play()
	else: status.text = "That doesn't look like a valid, current BlockTopia link."

func _play() -> void:
	if Settings.launch.has("code"): get_tree().change_scene_to_file("res://Scenes/Baseplate.tscn")
