class_name CommandPanel
extends Control
## Bottom-left readout: your production queues (one row per building) and the current unit selection.

var battle
var _t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = 0.15
		queue_redraw()


func _draw() -> void:
	if battle == null:
		return
	var font := MilTheme.font_ui()
	var mono := MilTheme.font_mono()
	# --- production rows, drawn from the bottom up
	var rows: Array = []
	var seen := {}
	for it in battle.queues[0]:
		var pr = it["prod"]
		if pr == null or not is_instance_valid(pr):
			continue
		var key: int = pr.get_instance_id()
		if not seen.has(key):
			seen[key] = rows.size()
			rows.append([pr, it, 1])
		else:
			rows[int(seen[key])][2] = int(rows[int(seen[key])][2]) + 1
	var y := size.y
	var w := size.x
	for i in range(rows.size() - 1, -1, -1):
		var row: Array = rows[i]
		var pr = row[0]
		var it: Dictionary = row[1]
		var ud: Dictionary = GameData.def_for(0, "unit", str(it["id"]))
		var frac := 1.0 - clampf(float(it["left"]) / maxf(float(it["total"]), 0.1), 0.0, 1.0)
		var powered: bool = pr.online()
		y -= 25.0
		draw_style_box(MilTheme.glass(MilTheme.BG, Color(MilTheme.LINE, 0.5), 8), Rect2(0, y, w, 22))
		if frac > 0.01:
			draw_style_box(MilTheme.box(Color(MilTheme.AMBER if powered else MilTheme.BAD, 0.85), Color(0, 0, 0, 0), 0, 0, 0, 2), Rect2(6, y + 18, (w - 12.0) * frac, 3))
		var tex := SpriteLib.get_texture(str(ud.get("sprite", it["id"])), str(ud.get("shape", "box")))
		draw_texture_rect(tex, Rect2(9, y + 3, 26, 15), false, SpriteLib.team_tint(0))
		var label := str(ud.get("name", it["id"]))
		if int(row[2]) > 1:
			label += "  +%d" % (int(row[2]) - 1)
		draw_string(font, Vector2(42, y + 14), label, HORIZONTAL_ALIGNMENT_LEFT, w * 0.5, 12, MilTheme.TEXT)
		var where := str(pr.def.get("name", "")).to_upper() if powered else "NO POWER"
		draw_string(font, Vector2(w * 0.5 - 20.0, y + 14), where, HORIZONTAL_ALIGNMENT_RIGHT, w * 0.5 - 50.0, 10, MilTheme.DIM if powered else MilTheme.BAD)
		draw_string(mono, Vector2(w - 42, y + 14), "%d%%" % int(frac * 100.0), HORIZONTAL_ALIGNMENT_RIGHT, 34, 11, MilTheme.AMBER)
	if not rows.is_empty():
		y -= 16.0
		draw_string(font, Vector2(4, y + 11), "PRODUCTION", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, MilTheme.DIM)
