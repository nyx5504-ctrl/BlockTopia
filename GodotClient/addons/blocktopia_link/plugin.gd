@tool
extends EditorPlugin
## Editor/export-time only. When the Android export uses the Gradle build, this adds an intent-filter for blocktopia:// links to the app,
## so pressing Play on the website opens the app. (Godot rebuilds the manifest itself and ignores hand edits, this is the supported hook.)
var _exporter: EditorExportPlugin

func _enter_tree() -> void:
	_exporter = LinkExporter.new(); add_export_plugin(_exporter)

func _exit_tree() -> void:
	if _exporter: remove_export_plugin(_exporter); _exporter = null

class LinkExporter extends EditorExportPlugin:
	func _get_name() -> String: return "BlockTopiaLink"
	func _supports_platform(platform: EditorExportPlatform) -> bool: return platform.get_os_name() == "Android"
	func _get_android_manifest_activity_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
		return """<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="blocktopia" />
</intent-filter>"""
