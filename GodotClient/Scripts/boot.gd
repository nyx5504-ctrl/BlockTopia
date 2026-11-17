extends Node
## Entry point: reads a blocktopia:// link (or --code/--ws test args) and routes to Baseplate or Home.
func _ready() -> void:
	get_tree().root.theme = ThemeBuilder.build()
	if get_tree().root.get_node_or_null("Recorder") == null:        # F11 fullscreen / F12 recording on PC, lives for the whole session
		var rec := Recorder.new(); rec.name = "Recorder"; get_tree().root.add_child.call_deferred(rec)
	var args := Array(OS.get_cmdline_args()) + Array(OS.get_cmdline_user_args())
	var code := ""; var ws := ""
	for a in args:
		var s := str(a)
		if s.begins_with("blocktopia://") and Settings.parse_link(s): Settings.protocol_launched = true
		elif s.begins_with("--code="): code = s.substr(7)
		elif s.begins_with("--ws="): ws = s.substr(5)
	var au := Settings.android_launch_uri()                  # phone: opened straight from the website
	if au != "" and Settings.parse_link(au): Settings.protocol_launched = true
	if code != "" and ws != "":
		Settings.launch = {"game": "baseplate", "code": code, "ws": ws}
		Settings.protocol_launched = true
	await get_tree().process_frame
	Settings.register_protocol.call_deferred()      # after the first frame, never blocks startup
	get_tree().change_scene_to_file("res://Scenes/Baseplate.tscn" if Settings.launch.has("code") else "res://Scenes/Home.tscn")
