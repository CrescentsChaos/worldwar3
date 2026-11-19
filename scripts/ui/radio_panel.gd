class_name RadioPanel
extends Control
## RADIO NET: the last few radio lines as subtitles. The line being transmitted shows animated signal bars.
## Click the panel (or press Space) to jump the camera to where the latest report came from. M mutes the voices.

const SHOW := 5
const LIFE := 16.0
var battle


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(400, 150)


func _process(_d: float) -> void:
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# which line was clicked?
		var lines := _visible_lines()
		var row := int((event.position.y - 24.0) / 26.0)
		var idx := lines.size() - 1 - (SHOW - 1 - row)
		if row >= 0 and idx >= 0 and idx < lines.size():
			var e: Dictionary = lines[idx]
			if bool(e.get("has_pos", false)) and battle != null:
				battle.focus_camera(e["pos"])
				accept_event()
				return
		var rp: Variant = Radio.last_position()
		if rp != null and battle != null:
			battle.focus_camera(rp)
		accept_event()


func _visible_lines() -> Array:
	var now := Time.get_ticks_msec() / 1000.0
	var out: Array = []
	for e in Radio.log_lines:
		if now - float(e.get("start", now)) < LIFE:
			out.append(e)
	if out.size() > SHOW:
		out = out.slice(out.size() - SHOW)
	return out


func _draw() -> void:
	var lines := _visible_lines()
	var talking: bool = not Radio.current.is_empty()
	if lines.is_empty() and not talking:
		# a thin idle header so the player knows the net exists
		var f0 := MilTheme.font_mono()
		draw_string(f0, Vector2(2, 12), "RADIO NET  [M] voice %s" % ("ON" if Radio.enabled else "MUTED"), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(MilTheme.DIM, 0.7))
		return
	var font := MilTheme.font_ui()
	var mono := MilTheme.font_mono()
	var h := 22.0 + float(SHOW) * 26.0
	draw_rect(Rect2(0, 0, size.x, h), Color(0.03, 0.05, 0.05, 0.62))
	draw_rect(Rect2(0, 0, 3, h), Color(MilTheme.AMBER, 0.8))
	draw_string(mono, Vector2(10, 14), "RADIO NET   [SPACE] jump   [M] voice %s" % ("ON" if Radio.enabled else "MUTED"), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, MilTheme.DIM)
	if talking:
		var t := Time.get_ticks_msec() / 90.0
		for i in 5:
			var bh := 3.0 + 7.0 * absf(sin(t * 0.7 + float(i) * 1.7))
			draw_rect(Rect2(size.x - 40.0 + float(i) * 7.0, 13.0 - bh, 4.0, bh), MilTheme.AMBER)
	var now := Time.get_ticks_msec() / 1000.0
	for i in lines.size():
		var e: Dictionary = lines[i]
		var row := SHOW - lines.size() + i
		var y := 24.0 + float(row) * 26.0
		var age := now - float(e.get("start", now))
		var a := clampf((LIFE - age) / 4.0, 0.0, 1.0)
		var is_now: bool = int(e.get("id", -1)) == int(Radio.current.get("id", -2))
		var col := MilTheme.TEXT
		if str(e.get("kind", "")) == "enemy":
			col = MilTheme.BAD
		elif int(e.get("prio", 0)) >= 3:
			col = MilTheme.WARN
		elif is_now:
			col = MilTheme.AMBER
		col.a = a
		var who := "%s: " % str(e.get("speaker", "?")) if not str(e.get("text", "")).begins_with(str(e.get("speaker", "?"))) else ""
		draw_string(font, Vector2(10, y + 11.0), who + str(e.get("text", "")), HORIZONTAL_ALIGNMENT_LEFT, size.x - 18.0, 12, col)
		if bool(e.get("has_pos", false)):
			draw_string(mono, Vector2(size.x - 44.0, y + 24.0), Radio.grid_ref(e["pos"]), HORIZONTAL_ALIGNMENT_RIGHT, 38.0, 9, Color(MilTheme.AMBER_DIM, a))
