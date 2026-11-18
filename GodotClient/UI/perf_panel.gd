class_name PerfPanel
extends VBoxContainer
## Roblox-style performance stats (PC only): Memory, Network (ping), CPU, GPU. Click a row to open a small card with the current value,
## the session average, the peak and a mini chart. Sampled once a second; the last 60 samples are charted.
const KEEP := 60
const BTN_W := 76.0
const CARD_W := 196.0
const METRICS := [
	{"id": "mem", "name": "Memory", "unit": "MB", "color": Color(0.45, 0.78, 1.0)},
	{"id": "net", "name": "Network", "unit": "ms", "color": Color(0.55, 0.9, 0.55)},
	{"id": "cpu", "name": "CPU", "unit": "ms", "color": Color(1.0, 0.78, 0.4)},
	{"id": "gpu", "name": "GPU", "unit": "ms", "color": Color(0.85, 0.6, 1.0)},
]
var hist := {}            # id -> Array[float] (last KEEP samples)
var total := {}           # id -> sum of all samples this session
var count := {}           # id -> number of samples
var peak := {}
var open_id := ""
var _rows := {}           # id -> Button
var _row: HBoxContainer
var _slot: MarginContainer
var _card: PanelContainer
var _card_title: Label
var _card_stats: Label
var _chart: Control
var _t := 0.0
var _vp_rid: RID

func _ready() -> void:
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_PASS
	for m in METRICS:
		hist[m.id] = []; total[m.id] = 0.0; count[m.id] = 0; peak[m.id] = 0.0
	_row = HBoxContainer.new(); _row.add_theme_constant_override("separation", 4); add_child(_row)
	for m in METRICS:
		var b := Button.new(); b.alignment = HORIZONTAL_ALIGNMENT_CENTER; b.custom_minimum_size = Vector2(BTN_W, 44); b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 13); b.clip_text = true
		var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.04, 0.04, 0.05, 0.66); sb.set_corner_radius_all(8); sb.set_content_margin_all(4)
		var hov := sb.duplicate(); hov.bg_color = Color(0.18, 0.18, 0.22, 0.85)
		b.add_theme_stylebox_override("normal", sb); b.add_theme_stylebox_override("hover", hov); b.add_theme_stylebox_override("pressed", hov); b.add_theme_stylebox_override("focus", sb)
		b.pressed.connect(_toggle.bind(m.id)); _row.add_child(b); _rows[m.id] = b
	_slot = MarginContainer.new(); add_child(_slot)       # holds the card; its left margin lines the card up under the clicked metric
	_card = PanelContainer.new(); _card.visible = false; _card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var cs := StyleBoxFlat.new(); cs.bg_color = Color(0.04, 0.04, 0.05, 0.78); cs.set_corner_radius_all(10); cs.set_content_margin_all(8); _card.add_theme_stylebox_override("panel", cs)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 4); _card.add_child(v)
	_card_title = Label.new(); _card_title.add_theme_font_size_override("font_size", 14); v.add_child(_card_title)
	_card_stats = Label.new(); _card_stats.add_theme_font_size_override("font_size", 12); _card_stats.modulate = Color(1, 1, 1, 0.8); v.add_child(_card_stats)
	_chart = Control.new(); _chart.custom_minimum_size = Vector2(CARD_W - 16, 58); _chart.draw.connect(_draw_chart); v.add_child(_chart)
	_slot.add_child(_card)
	_vp_rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp_rid, true)
	_sample(); _refresh()

func _exit_tree() -> void:
	if _vp_rid.is_valid(): RenderingServer.viewport_set_measure_render_time(_vp_rid, false)

func _toggle(id: String) -> void:
	open_id = "" if open_id == id else id
	_refresh()

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	_t += delta
	if _t >= 1.0: _t = 0.0; _sample(); _refresh()

func _value(id: String) -> float:
	match id:
		"mem": return float(OS.get_static_memory_usage()) / 1048576.0
		"net": return float(Net.ping_ms) if Net.ping_ms >= 0 else -1.0
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
	return ("%d MB" % roundi(v)) if id == "mem" else (("%d ms" % roundi(v)) if id == "net" else "%.1f ms" % v)

func _refresh() -> void:
	for m in METRICS:
		var h: Array = hist[m.id]
		_rows[m.id].text = "%s\n%s" % [tr(m.name), _fmt(m.id, h.back() if not h.is_empty() else -1.0)]
		_rows[m.id].add_theme_color_override("font_color", m.color if open_id == m.id else Color(1, 1, 1, 0.92))
	_card.visible = open_id != ""
	if open_id == "": return
	var idx := METRICS.map(func(x): return x.id).find(open_id)
	var row_w := BTN_W * METRICS.size() + 4.0 * (METRICS.size() - 1)
	_slot.add_theme_constant_override("margin_left", int(clampf(idx * (BTN_W + 4.0), 0.0, maxf(0.0, row_w - CARD_W))))
	var meta: Dictionary = METRICS.filter(func(x): return x.id == open_id)[0]
	var h: Array = hist[open_id]
	var avg: float = total[open_id] / float(maxi(count[open_id], 1))
	_card_title.text = tr(meta.name); _card_title.add_theme_color_override("font_color", meta.color)
	_card_stats.text = "%s %s   %s %s   Peak %s" % [tr("Current"), _fmt(open_id, h.back() if not h.is_empty() else -1.0), tr("Average"), _fmt(open_id, avg), _fmt(open_id, peak[open_id])]
	_chart.queue_redraw()

func _draw_chart() -> void:
	var r := Rect2(Vector2.ZERO, _chart.size)
	_chart.draw_rect(r, Color(0, 0, 0, 0.35)); 
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
