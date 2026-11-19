class_name PerfPanel
extends Control
## Roblox-style performance bar (PC only), a strip along the bottom of the screen: FPS, Mem, CPU, GPU, Sent, Recv, NetworkPing.
## Every segment shows its current value and a small live graph. Click a segment for a card with current / average / peak and a 60 s chart.
## Sampled once a second.
const KEEP := 60
const BAR_H := 44.0
const CARD_W := 214.0
const CARD_H := 112.0
const METRICS := [
	{"id": "fps", "name": "FPS", "color": Color(1, 1, 1, 0.9), "w": 112.0},
	{"id": "mem", "name": "Mem", "color": Color(0.85, 0.88, 0.22), "w": 178.0},
	{"id": "cpu", "name": "CPU", "color": Color(0.50, 0.76, 0.22), "w": 150.0},
	{"id": "gpu", "name": "GPU", "color": Color(0.50, 0.76, 0.22), "w": 150.0},
	{"id": "sent", "name": "Sent", "color": Color(0.70, 0.74, 0.82), "w": 150.0},
	{"id": "recv", "name": "Recv", "color": Color(0.85, 0.88, 0.22), "w": 150.0},
	{"id": "net", "name": "NetworkPing", "color": Color(0.91, 0.40, 0.16), "w": 150.0},
]
var hist := {}            # id -> Array[float] (last KEEP samples)
var total := {}           # id -> sum of all samples this session
var count := {}           # id -> number of samples
var peak := {}
var open_id := ""
var _segs := {}           # id -> Seg
var _card: PanelContainer
var _card_title: Label
var _card_stats: Label
var _chart: Control
var _t := 0.0
var _vp_rid: RID
var _last_sent := 0
var _last_recv := 0

## One segment of the bar: name + value on the left, a small graph on the right.
class Seg extends Button:
	const BH := 44.0
	const KEEP_N := 60
	var meta: Dictionary
	var text_value := "--"
	var samples: Array = []
	var hi := 1.0
	func _init(m: Dictionary) -> void:
		meta = m; flat = true; focus_mode = Control.FOCUS_NONE; custom_minimum_size = Vector2(m.w, BH)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	func _draw() -> void:
		var f := ThemeDB.fallback_font
		if get_draw_mode() == DRAW_HOVER or get_draw_mode() == DRAW_PRESSED: draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.07))
		draw_line(Vector2(size.x - 0.5, 4), Vector2(size.x - 0.5, size.y - 4), Color(1, 1, 1, 0.16), 1.0)
		if meta.id == "fps":
			draw_string(f, Vector2(12, 30), text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.92))
			return
		draw_string(f, Vector2(10, 17), meta.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.62))
		draw_string(f, Vector2(10, 35), text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.95))
		var gx := size.x * 0.56; var gw := size.x - gx - 10.0; var gy := 8.0; var gh := size.y - 16.0
		if samples.size() < 2 or gw < 8.0: return
		var step := gw / float(KEEP_N)
		var top := maxf(hi, 0.001)
		for i in samples.size():
			var v := clampf(float(samples[i]) / top, 0.0, 1.0)
			var h := maxf(2.0, gh * v)
			var x := gx + gw - step * float(samples.size() - i)
			draw_rect(Rect2(x, gy + gh - h, maxf(step - 0.5, 1.0), h), Color(meta.color.r, meta.color.g, meta.color.b, 0.9))

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.0; anchor_right = 1.0; anchor_top = 1.0; anchor_bottom = 1.0
	offset_left = 0.0; offset_right = 0.0; offset_top = -BAR_H; offset_bottom = 0.0
	for m in METRICS:
		hist[m.id] = []; total[m.id] = 0.0; count[m.id] = 0; peak[m.id] = 0.0
	var bar := PanelContainer.new(); bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bs := StyleBoxFlat.new(); bs.bg_color = Color(0.05, 0.05, 0.06, 0.82); bs.border_color = Color(1, 1, 1, 0.1); bs.border_width_top = 1; bs.set_content_margin_all(0)
	bar.add_theme_stylebox_override("panel", bs); add_child(bar)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 0); bar.add_child(row)
	for m in METRICS:
		var s := Seg.new(m); s.pressed.connect(_toggle.bind(m.id)); s.mouse_entered.connect(s.queue_redraw); s.mouse_exited.connect(s.queue_redraw)
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL if m.id == "net" else Control.SIZE_FILL
		row.add_child(s); _segs[m.id] = s
	_card = PanelContainer.new(); _card.visible = false; _card.custom_minimum_size = Vector2(CARD_W, CARD_H)
	var cs := StyleBoxFlat.new(); cs.bg_color = Color(0.04, 0.04, 0.05, 0.88); cs.set_corner_radius_all(10); cs.set_content_margin_all(8); _card.add_theme_stylebox_override("panel", cs)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 4); _card.add_child(v)
	_card_title = Label.new(); _card_title.add_theme_font_size_override("font_size", 14); v.add_child(_card_title)
	_card_stats = Label.new(); _card_stats.add_theme_font_size_override("font_size", 12); _card_stats.modulate = Color(1, 1, 1, 0.8); v.add_child(_card_stats)
	_chart = Control.new(); _chart.custom_minimum_size = Vector2(CARD_W - 16, 58); _chart.draw.connect(_draw_chart); v.add_child(_chart)
	add_child(_card)
	_vp_rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp_rid, true)
	_last_sent = Net.bytes_sent; _last_recv = Net.bytes_recv
	_sample(); _refresh()

func _exit_tree() -> void:
	if _vp_rid.is_valid(): RenderingServer.viewport_set_measure_render_time(_vp_rid, false)

func _toggle(id: String) -> void:
	if id == "fps": return
	open_id = "" if open_id == id else id
	_refresh()

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	_t += delta
	if _t >= 1.0: _t = 0.0; _sample(); _refresh()

func _value(id: String) -> float:
	match id:
		"fps": return float(Engine.get_frames_per_second())
		"mem": return float(OS.get_static_memory_usage()) / 1048576.0
		"net": return float(Net.ping_ms) if Net.ping_ms >= 0 else -1.0
		"sent":
			var d := maxi(0, Net.bytes_sent - _last_sent); _last_sent = Net.bytes_sent; return float(d) / 1024.0
		"recv":
			var d2 := maxi(0, Net.bytes_recv - _last_recv); _last_recv = Net.bytes_recv; return float(d2) / 1024.0
		"cpu": return (Performance.get_monitor(Performance.TIME_PROCESS) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0
		"gpu":
			var g := float(RenderingServer.viewport_get_measured_render_time_gpu(_vp_rid))      # 0 on renderers that can't time the GPU
			if g > 0.0: return g
			var fps := Engine.get_frames_per_second()      # fallback: the part of the frame that isn't CPU work (GPU + vsync wait)
			return maxf(0.0, 1000.0 / float(maxi(fps, 1)) - _value("cpu"))
	return 0.0

func _sample() -> void:
	for m in METRICS:
		var v := _value(m.id)
		if v < 0.0: continue
		var h: Array = hist[m.id]; h.append(v)
		if h.size() > KEEP: h.pop_front()
		total[m.id] += v; count[m.id] += 1; peak[m.id] = maxf(peak[m.id], v)

func _fmt(id: String, v: float) -> String:
	if v < 0.0: return "--"
	match id:
		"fps": return "%d FPS" % roundi(v)
		"mem": return "%.2f MB" % v
		"net": return "%d ms" % roundi(v)
		"sent", "recv": return "%.2f KB/s" % v
	return "%.2f ms" % v

func _refresh() -> void:
	for m in METRICS:
		var h: Array = hist[m.id]; var s: Seg = _segs[m.id]
		s.text_value = _fmt(m.id, h.back() if not h.is_empty() else -1.0)
		s.samples = h
		var hi := 0.001
		for x in h: hi = maxf(hi, x)
		s.hi = hi * 1.2 if m.id != "mem" else maxf(hi * 1.05, 1.0)
		s.queue_redraw()
	_card.visible = open_id != ""
	if open_id == "": return
	var meta: Dictionary = METRICS.filter(func(x): return x.id == open_id)[0]
	var seg: Seg = _segs[open_id]
	var h2: Array = hist[open_id]
	var avg: float = total[open_id] / float(maxi(count[open_id], 1))
	_card_title.text = tr(meta.name); _card_title.add_theme_color_override("font_color", meta.color)
	_card_stats.text = "%s %s   %s %s   %s %s" % [tr("Current"), _fmt(open_id, h2.back() if not h2.is_empty() else -1.0), tr("Average"), _fmt(open_id, avg), tr("Peak"), _fmt(open_id, peak[open_id])]
	var gx := seg.global_position.x - global_position.x
	_card.position = Vector2(clampf(gx, 6.0, maxf(6.0, size.x - CARD_W - 6.0)), -CARD_H - 8.0)
	_chart.queue_redraw()

func _draw_chart() -> void:
	var r := Rect2(Vector2.ZERO, _chart.size)
	_chart.draw_rect(r, Color(0, 0, 0, 0.35))
	var h: Array = hist.get(open_id, [])
	if h.size() < 2: return
	var meta: Dictionary = METRICS.filter(func(x): return x.id == open_id)[0]
	var hi := 0.001
	for v in h: hi = maxf(hi, v)
	hi *= 1.15
	var lo := 0.0
	if open_id == "mem":      # memory barely moves: zoom the chart in around the values so changes are visible
		lo = h.min(); hi = maxf(h.max(), lo + 1.0) * 1.0 + 0.5
		lo = maxf(0.0, lo - 0.5)
	var pts := PackedVector2Array()
	for i in h.size():
		pts.append(Vector2(r.size.x * float(i) / float(KEEP - 1) + (r.size.x * float(KEEP - h.size()) / float(KEEP - 1)), r.size.y - 3.0 - (r.size.y - 6.0) * clampf((h[i] - lo) / (hi - lo), 0.0, 1.0)))
	var avg: float = total[open_id] / float(maxi(count[open_id], 1))
	var ay := r.size.y - 3.0 - (r.size.y - 6.0) * clampf((avg - lo) / (hi - lo), 0.0, 1.0)
	_chart.draw_dashed_line(Vector2(0, ay), Vector2(r.size.x, ay), Color(1, 1, 1, 0.3), 1.0, 4.0)
	_chart.draw_polyline(pts, meta.color, 2.0, true)
