class_name Recorder
extends Node
## PC hotkeys. F11 toggles fullscreen. F12 starts / stops a gameplay recording:
##  - while recording the whole screen has a red outline; the video contains only the game (the window itself is captured, never the desktop,
##    so switching to another app can't leak into it) and the game's sound;
##  - recording forces fullscreen; leaving fullscreen, closing the app or pressing F12 again ends it;
##  - the video is saved as Downloads/BlockTopia Videos/BlockTopia_<date>_<time>.avi (Motion-JPEG + PCM sound, plays in VLC, Windows Media Player etc.).
const FPS := 30
const MAX_W := 1280
const JPG_Q := 0.75
const MAX_SECONDS := 600.0
const BORDER := 6
const START_DELAY := 0.9      # lets the "recording started" note disappear and fullscreen settle before the first frame
var recording := false
var out_dir_override := ""
var last_path := ""
var _outline_layer: CanvasLayer
var _outline: Panel
var _note: Label
var _note_id := 0
var _t0 := 0.0
var _issued := 0
var _size := Vector2i.ZERO
var _cap: AudioEffectCapture
var _audio_acc := PackedVector2Array()
var _thread: Thread
var _sem := Semaphore.new()
var _mutex := Mutex.new()
var _queue := []
var _w: AviWriter
var _path := ""
var _test := false
var _test_t := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_outline_layer = CanvasLayer.new(); _outline_layer.layer = 100; add_child(_outline_layer)
	_outline = Panel.new(); _outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); _outline.mouse_filter = Control.MOUSE_FILTER_IGNORE; _outline.visible = false
	var sb := StyleBoxFlat.new(); sb.draw_center = false; sb.bg_color = Color(0, 0, 0, 0); sb.border_color = Color(0.93, 0.1, 0.1); sb.set_border_width_all(BORDER)
	_outline.add_theme_stylebox_override("panel", sb); _outline_layer.add_child(_outline)
	_note = Label.new(); _note.visible = false; _note.set_anchors_preset(Control.PRESET_CENTER_BOTTOM); _note.position = Vector2(-220, -70); _note.custom_minimum_size = Vector2(440, 0)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _note.add_theme_font_size_override("font_size", 20); _note.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95)); _note.add_theme_constant_override("outline_size", 8)
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE; _outline_layer.add_child(_note)
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--rectest="): out_dir_override = str(a).substr(10); _test = true

func _available() -> bool: return not Settings.is_mobile()

func _input(e: InputEvent) -> void:
	if not _available() or not (e is InputEventKey) or not e.pressed or e.echo: return
	if e.keycode == KEY_F11: _toggle_fullscreen(); get_viewport().set_input_as_handled()
	elif e.keycode == KEY_F12: (stop() if recording else start()); get_viewport().set_input_as_handled()

func _toggle_fullscreen() -> void:
	Settings.fullscreen = DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN
	Settings.apply_window()

func _say(t: String, secs := 3.0) -> void:
	_note.text = t; _note.visible = true; _note_id += 1; var me := _note_id
	await get_tree().create_timer(secs).timeout
	if me == _note_id: _note.visible = false

func _is_fullscreen() -> bool:
	var m := DisplayServer.window_get_mode()
	return m == DisplayServer.WINDOW_MODE_FULLSCREEN or m == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN

func start() -> void:
	if recording or not _available(): return
	var dir := out_dir_override
	if dir == "":
		dir = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
		if dir == "": dir = OS.get_user_data_dir()
		dir = dir.path_join("BlockTopia Videos")
	if DirAccess.make_dir_recursive_absolute(dir) != OK and not DirAccess.dir_exists_absolute(dir):
		_say("Couldn't create the BlockTopia Videos folder.", 4.0); return
	var d := Time.get_datetime_dict_from_system()
	_path = dir.path_join("BlockTopia_%04d-%02d-%02d_%02d-%02d-%02d.avi" % [d.year, d.month, d.day, d.hour, d.minute, d.second])
	if not _is_fullscreen():
		Settings.fullscreen = true; Settings.apply_window()
	recording = true; _outline.visible = true; _issued = 0; _size = Vector2i.ZERO; _audio_acc = PackedVector2Array(); _w = null; _queue.clear()
	_cap = AudioEffectCapture.new(); _cap.buffer_length = 1.0; AudioServer.add_bus_effect(0, _cap)
	_t0 = Time.get_ticks_msec() / 1000.0 + START_DELAY
	_say("Recording started. Press F12 to stop.", START_DELAY)
	_thread = Thread.new(); _thread.start(_worker)

func stop(silent := false) -> void:
	if not recording: return
	recording = false; _outline.visible = false
	_mutex.lock(); _queue.append(null); _mutex.unlock(); _sem.post()
	if _thread: _thread.wait_to_finish(); _thread = null
	var idx := AudioServer.get_bus_effect_count(0) - 1
	for i in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, i) == _cap: idx = i
	if _cap: AudioServer.remove_bus_effect(0, idx); _cap = null
	last_path = _path if (_w != null and _w.frames > 0) else ""
	_w = null
	if not silent:
		if last_path != "": _say("Saved to Downloads / BlockTopia Videos", 4.0)
		else: _say("Recording was too short to save.", 3.0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if recording: stop(true)

func _process(delta: float) -> void:
	if _test:
		_test_t += delta
		if _test_t > 2.0 and not recording and last_path == "": start()
		if recording and _test_t > 5.0: stop(true); print("RECTEST file=", last_path); get_tree().quit()
	if not recording: return
	_outline.modulate.a = 0.78 + 0.22 * sin(Time.get_ticks_msec() / 220.0)
	if not _is_fullscreen() and Time.get_ticks_msec() / 1000.0 > _t0 + 0.3 and not _test:     # left fullscreen: recording ends
		stop(); return
	var now := Time.get_ticks_msec() / 1000.0
	if _cap and now >= _t0:
		var n := _cap.get_frames_available()
		if n > 0: _audio_acc.append_array(_cap.get_buffer(n))
	elif _cap:
		var n0 := _cap.get_frames_available()
		if n0 > 0: _cap.clear_buffer()
	if now < _t0: return
	var el := now - _t0
	if el > MAX_SECONDS: stop(); _say("Recording stopped after 10 minutes. Saved.", 4.0); return
	var due := int(floor(el * FPS)) - _issued
	if due <= 0: return
	_mutex.lock(); var backlog := _queue.size(); _mutex.unlock()
	if backlog > 6: return          # encoder is behind: skip, the next frame repeats for the missing time
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty(): return
	if img.get_format() != Image.FORMAT_RGB8: img.convert(Image.FORMAT_RGB8)
	var b := BORDER + 2; var w := img.get_width(); var h := img.get_height()
	if w > b * 4 and h > b * 4:                       # paint over the red outline with the pixels just inside it, so the video has no outline
		img.blit_rect(img, Rect2i(0, b, w, b), Vector2i(0, 0)); img.blit_rect(img, Rect2i(0, h - 2 * b, w, b), Vector2i(0, h - b))
		img.blit_rect(img, Rect2i(b, 0, b, h), Vector2i(0, 0)); img.blit_rect(img, Rect2i(w - 2 * b, 0, b, h), Vector2i(w - b, 0))
	if _size == Vector2i.ZERO:
		var tw := mini(w, MAX_W); var th := int(round(h * float(tw) / w)); _size = Vector2i(tw - tw % 2, th - th % 2)
	if img.get_size() != _size: img.resize(_size.x, _size.y, Image.INTERPOLATE_BILINEAR)
	_issued += due
	_mutex.lock(); _queue.append({"img": img, "n": due, "audio": _audio_acc}); _mutex.unlock(); _sem.post()
	_audio_acc = PackedVector2Array()

func _worker() -> void:
	var rate := int(AudioServer.get_mix_rate())
	while true:
		_sem.wait()
		_mutex.lock(); var job = _queue.pop_front() if _queue.size() > 0 else null; _mutex.unlock()
		if job == null:
			if _w: _w.finish()
			return
		if _w == null:
			_w = AviWriter.new()
			if not _w.open(_path, job.img.get_width(), job.img.get_height(), FPS, rate): _w = null; continue
		var jpg: PackedByteArray = job.img.save_jpg_to_buffer(JPG_Q)
		var pcm := PackedByteArray(); var a: PackedVector2Array = job.audio; pcm.resize(a.size() * 4)
		for i in a.size():
			var l := clampi(int(a[i].x * 32767.0), -32768, 32767); var r := clampi(int(a[i].y * 32767.0), -32768, 32767)
			pcm.encode_s16(i * 4, l); pcm.encode_s16(i * 4 + 2, r)
		_w.add(jpg, int(job.n), pcm)

## Minimal AVI (RIFF) writer: one MJPG video stream + one 16-bit stereo PCM audio stream, with an idx1 index.
class AviWriter:
	var f: FileAccess
	var frames := 0
	var samples := 0
	var rate := 44100
	var fps := 30
	var w := 0
	var h := 0
	var movi_pos := 0
	var movi_start := 0
	var index := PackedByteArray()
	var max_chunk := 0
	var pos_avih_frames := 0
	var pos_vid_len := 0
	var pos_aud_len := 0
	func _u32(v: int) -> void: f.store_32(v & 0xFFFFFFFF)
	func _cc(s: String) -> void: f.store_buffer(s.to_ascii_buffer())
	func open(path: String, width: int, height: int, fps_: int, rate_: int) -> bool:
		f = FileAccess.open(path, FileAccess.WRITE)
		if f == null: return false
		w = width; h = height; fps = fps_; rate = rate_
		_cc("RIFF"); _u32(0); _cc("AVI ")
		_cc("LIST"); var hdrl_size_pos := f.get_position(); _u32(0); _cc("hdrl")
		_cc("avih"); _u32(56); _u32(1000000 / fps); _u32(0); _u32(0); _u32(0x10); pos_avih_frames = f.get_position(); _u32(0); _u32(0); _u32(2); _u32(1 << 20); _u32(w); _u32(h); for i in 4: _u32(0)
		_cc("LIST"); _u32(4 + 8 + 56 + 8 + 40); _cc("strl")
		_cc("strh"); _u32(56); _cc("vids"); _cc("MJPG"); _u32(0); f.store_16(0); f.store_16(0); _u32(0); _u32(1); _u32(fps); _u32(0); pos_vid_len = f.get_position(); _u32(0); _u32(1 << 20); _u32(0xFFFFFFFF); _u32(0); f.store_16(0); f.store_16(0); f.store_16(w); f.store_16(h)
		_cc("strf"); _u32(40); _u32(40); _u32(w); _u32(h); f.store_16(1); f.store_16(24); _cc("MJPG"); _u32(w * h * 3); _u32(0); _u32(0); _u32(0); _u32(0)
		_cc("LIST"); _u32(4 + 8 + 56 + 8 + 16); _cc("strl")
		_cc("strh"); _u32(56); _cc("auds"); _u32(0); _u32(0); f.store_16(0); f.store_16(0); _u32(0); _u32(4); _u32(rate * 4); _u32(0); pos_aud_len = f.get_position(); _u32(0); _u32(1 << 16); _u32(0xFFFFFFFF); _u32(4); f.store_16(0); f.store_16(0); f.store_16(0); f.store_16(0)
		_cc("strf"); _u32(16); f.store_16(1); f.store_16(2); _u32(rate); _u32(rate * 4); f.store_16(4); f.store_16(16)
		var end := f.get_position(); f.seek(hdrl_size_pos); _u32(end - hdrl_size_pos - 4); f.seek(end)
		_cc("LIST"); movi_pos = f.get_position(); _u32(0); _cc("movi"); movi_start = f.get_position() - 4
		return true
	func _chunk(id: String, data: PackedByteArray, flags: int) -> void:
		var off := f.get_position() - movi_start
		_cc(id); _u32(data.size()); f.store_buffer(data)
		if data.size() % 2 == 1: f.store_8(0)
		max_chunk = maxi(max_chunk, data.size())
		var e := PackedByteArray(); e.resize(16); e.encode_u32(4, flags); e.encode_u32(8, off); e.encode_u32(12, data.size())
		for i in 4: e[i] = id.unicode_at(i)
		index.append_array(e)
	func add(jpg: PackedByteArray, repeat: int, pcm: PackedByteArray) -> void:
		for i in repeat:
			_chunk("00dc", jpg, 0x10); frames += 1
			if i == 0 and pcm.size() > 0: _chunk("01wb", pcm, 0x10); samples += pcm.size() / 4
	func finish() -> void:
		var movi_end := f.get_position()
		_cc("idx1"); _u32(index.size()); f.store_buffer(index)
		var end := f.get_position()
		f.seek(movi_pos); _u32(movi_end - movi_pos - 4)
		f.seek(4); _u32(end - 8)
		f.seek(pos_avih_frames); _u32(frames)
		f.seek(pos_vid_len); _u32(frames)
		f.seek(pos_aud_len); _u32(samples)
		f.close()
