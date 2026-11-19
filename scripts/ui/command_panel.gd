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
		_t = 0.08
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
	var w := 340.0
	for i in range(rows.size() - 1, -1, -1):
		var row: Array = rows[i]
		var pr = row[0]
		var it: Dictionary = row[1]
		var ud: Dictionary = GameData.def_for(0, "unit", str(it["id"]))
		var frac := 1.0 - clampf(float(it["left"]) / maxf(float(it["total"]), 0.1), 0.0, 1.0)
		var powered: bool = pr.online()
		y -= 25.0
		draw_rect(Rect2(0, y, w, 22), Color(0.03, 0.035, 0.037, 0.8))
		draw_rect(Rect2(0, y, 3, 22), MilTheme.AMBER if powered else MilTheme.BAD)
		draw_rect(Rect2(3, y + 18, (w - 3.0) * frac, 4), Color(MilTheme.AMBER, 0.9))
		var tex := SpriteLib.get_texture(str(ud.get("sprite", it["id"])), str(ud.get("shape", "box")))
		draw_texture_rect(tex, Rect2(8, y + 2, 26, 15), false, SpriteLib.team_tint(0))
		var label := str(ud.get("name", it["id"]))
		if int(row[2]) > 1:
			label += "  +%d" % (int(row[2]) - 1)
		draw_string(font, Vector2(40, y + 14), label, HORIZONTAL_ALIGNMENT_LEFT, 190, 12, MilTheme.TEXT)
		var where := str(pr.def.get("name", "")).to_upper() if powered else "NO POWER"
		draw_string(font, Vector2(150, y + 14), where, HORIZONTAL_ALIGNMENT_RIGHT, 150, 10, MilTheme.DIM if powered else MilTheme.BAD)
		draw_string(mono, Vector2(w - 36, y + 14), "%d%%" % int(frac * 100.0), HORIZONTAL_ALIGNMENT_RIGHT, 32, 11, MilTheme.AMBER)
	if not rows.is_empty():
		y -= 16.0
		draw_string(font, Vector2(2, y + 11), "PRODUCTION", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, MilTheme.AMBER_DIM)
	# --- selection summary above the production rows
	var sel: Array = battle.selected
	if not sel.is_empty():
		var counts := {}
		for c in sel:
			if is_instance_valid(c):
				var nm := str(c.def.get("name", c.id))
				counts[nm] = int(counts.get(nm, 0)) + 1
		var parts: PackedStringArray = []
		for nm in counts:
			parts.append("%dx %s" % [int(counts[nm]), str(nm)])
		var txt := ", ".join(parts)
		y -= 46.0
		draw_rect(Rect2(0, y, w, 42), Color(0.03, 0.035, 0.037, 0.82))
		draw_rect(Rect2(0, y, 3, 42), MilTheme.GOOD)
		draw_string(font, Vector2(10, y + 14), "SELECTED  %d" % sel.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MilTheme.GOOD)
		draw_string(font, Vector2(10, y + 27), txt, HORIZONTAL_ALIGNMENT_LEFT, w - 16.0, 11, MilTheme.TEXT)
		draw_string(font, Vector2(10, y + 39), "RMB move   CTRL+RMB / T attack-move   X hold", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, MilTheme.DIM)
