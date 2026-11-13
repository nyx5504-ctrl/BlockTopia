extends Node
## Entry point: reads a blocktopia:// link (or --code/--ws test args) and routes to Baseplate or Home.
func _ready() -> void:
	get_tree().root.theme = ThemeBuilder.build()
	var args := Array(OS.get_cmdline_args()) + Array(OS.get_cmdline_user_args())
	var code := ""; var ws := ""
	for a in args:
		var s := str(a)
		if s.begins_with("blocktopia://") and Settings.parse_link(s): Settings.protocol_launched = true
		elif s.begins_with("--code="): code = s.substr(7)
		elif s.begins_with("--ws="): ws = s.substr(5)
	if code != "" and ws != "":
		Settings.launch = {"game": "baseplate", "code": code, "ws": ws}
		Settings.protocol_launched = true
	Settings.register_protocol()
	await get_tree().process_frame
	get_tree().change_scene_to_file("res://Scenes/Baseplate.tscn" if Settings.launch.has("code") else "res://Scenes/Home.tscn")
