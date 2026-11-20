class_name SelectionPanel
extends Control
## Bottom-right card that only exists while something is selected: one unit shows its full state (health, ammo,
## supplies, passengers, road / off-road speed, orders); several units show a grouped summary and the shortcuts
## that matter for them. Replaces the permanent text block of the old HUD.

var battle
var _t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _process(delta: float) -> void:
	if battle == null:
		return
	var n := 0
	for c in battle.selected:
		if is_instance_valid(c) and not c.dead:
			n += 1
	visible = n > 0 and battle.sel_kind == ""
	if not visible:
		return
	_t -= delta
	if _t <= 0.0:
		_t = 0.1
		queue_redraw()


func _bar(rect: Rect2, frac: float, col: Color) -> void:
	var back := MilTheme.box(Color(0, 0, 0, 0.45), Color(0, 0, 0, 0), 0, 0, 0, 3)
	draw_style_box(back, rect)
	if frac > 0.01:
		var fill := MilTheme.box(col, Color(0, 0, 0, 0), 0, 0, 0, 3)
		draw_style_box(fill, Rect2(rect.position, Vector2(maxf(rect.size.x * clampf(frac, 0.0, 1.0), 6.0), rect.size.y)))


func _draw() -> void:
	if battle == null:
		return
	var sel: Array = []
	for c in battle.selected:
		if is_instance_valid(c) and not c.dead:
			sel.append(c)
	if sel.is_empty():
		return
	var font := MilTheme.font_ui()
	var bold := MilTheme.font_bold()
	var mono := MilTheme.font_mono()
	draw_style_box(MilTheme.glass(MilTheme.BG, MilTheme.LINE, 12), Rect2(Vector2.ZERO, size))
	var w := size.x
	if sel.size() == 1:
		_draw_single(sel[0], font, bold, mono, w)
	else:
		_draw_group(sel, font, bold, mono, w)


func _draw_single(c, font: Font, bold: Font, mono: Font, w: float) -> void:
	var d: Dictionary = c.def
	var tex := SpriteLib.get_texture(str(d.get("sprite", c.id)), str(d.get("shape", "box")))
	var box_r := Rect2(12, 12, 72, 44)
	draw_style_box(MilTheme.box(Color(0, 0, 0, 0.30), Color(0, 0, 0, 0), 0, 0, 0, 8), box_r)
	var ts := tex.get_size()
	var sc := minf(box_r.size.x / ts.x, box_r.size.y / ts.y) * 0.9
	draw_texture_rect(tex, Rect2(box_r.position + (box_r.size - ts * sc) * 0.5, ts * sc), false, SpriteLib.team_tint(0))
	draw_string(bold, Vector2(94, 28), str(d.get("name", c.id)), HORIZONTAL_ALIGNMENT_LEFT, w - 106.0, 15, MilTheme.TEXT)
	var sub: String = c.drive.to_upper() if c.kind == "unit" else str(c.kind).to_upper()
	if c.kind == "unit" and c.speed_known():
		sub += "   ROAD %d   OFF-ROAD %d" % [int(c.road_speed()), int(c.off_speed())]
	draw_string(font, Vector2(94, 46), sub, HORIZONTAL_ALIGNMENT_LEFT, w - 106.0, 10, MilTheme.DIM)
	var y := 70.0
	var hp_f: float = c.hp / maxf(c.max_hp, 1.0)
	_bar(Rect2(12, y, w - 24.0, 8), hp_f, MilTheme.GOOD if hp_f > 0.5 else (MilTheme.WARN if hp_f > 0.25 else MilTheme.BAD))
	draw_string(mono, Vector2(12, y + 22), "HEALTH  %d / %d" % [int(c.hp), int(c.max_hp)], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, MilTheme.DIM)
	y += 30.0
	if c.ammo_max >= 0.0:
		var af: float = c.ammo_frac()
		_bar(Rect2(12, y, w - 24.0, 8), af, MilTheme.GOLD if af > 0.25 else MilTheme.BAD)
		draw_string(mono, Vector2(12, y + 22), "AMMO  %d / %d%s" % [int(c.ammo), int(c.ammo_max), "   EMPTY" if c.ammo < 1.0 else ""],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, MilTheme.DIM if c.ammo >= 1.0 else MilTheme.BAD)
		y += 30.0
	if c.supply_max > 0.0:
		_bar(Rect2(12, y, w - 24.0, 8), c.supply / c.supply_max, Color(0.45, 0.75, 0.98))
		draw_string(mono, Vector2(12, y + 22), "SUPPLIES  %d / %d crates" % [int(c.supply), int(c.supply_max)], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, MilTheme.DIM)
		y += 30.0
	if c.seats > 0:
		draw_string(bold, Vector2(12, y + 12), "SEATS  %d / %d" % [c.passengers.size(), c.seats], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MilTheme.TEXT)
		var px := 98.0
		for i in c.seats:
			if i >= 16:
				break
			var filled: bool = i < c.passengers.size()
			var r := Rect2(px + float(i) * 11.0, y + 3.0, 8, 10)
			draw_style_box(MilTheme.box(MilTheme.AMBER if filled else Color(1, 1, 1, 0.12), Color(0, 0, 0, 0), 0, 0, 0, 2), r)
		y += 24.0
	if c.parked:
		draw_string(font, Vector2(12, y + 12), "REARMING  %.0fs" % c.rearm_left, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MilTheme.GOLD)
	elif c.resupplying:
		draw_string(font, Vector2(12, y + 12), "FALLING BACK TO RESUPPLY", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MilTheme.GOLD)
	var hint := _hints(c)
	draw_string(font, Vector2(12, size.y - 10.0), hint, HORIZONTAL_ALIGNMENT_LEFT, w - 24.0, 10, MilTheme.DIM)


func _hints(c) -> String:
	var parts: PackedStringArray = ["RMB move"]
	if c.cls == "infantry":
		parts.append("RMB on transport = board")
	if c.seats > 0 and c.kind == "unit":
		parts.append("U dismount")
		parts.append("G drop-off")
	var pa: String = c.primary_active()
	if pa != "" and c.can_use(pa):
		parts.append("Z %s" % Abilities.ability_name(pa))
	return "   ".join(parts)


func _draw_group(sel: Array, font: Font, bold: Font, mono: Font, w: float) -> void:
	draw_string(bold, Vector2(14, 26), "%d SELECTED" % sel.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, MilTheme.TEXT)
	var counts := {}
	var ammo_sum := 0.0
	var ammo_n := 0
	var seats := 0
	var riders := 0
	var low := 0
	for c in sel:
		var nm := str(c.def.get("name", c.id))
		counts[nm] = int(counts.get(nm, 0)) + 1
		if c.ammo_max >= 0.0:
			ammo_sum += c.ammo_frac()
			ammo_n += 1
			if c.ammo_frac() < 0.25:
				low += 1
		seats += c.seats
		riders += c.passengers.size()
	var y := 46.0
	var shown := 0
	for nm in counts:
		if shown >= 5:
			draw_string(font, Vector2(14, y + 11), "+ %d more types" % (counts.size() - shown), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MilTheme.DIM)
			y += 16.0
			break
		draw_string(font, Vector2(14, y + 11), "%d x" % int(counts[nm]), HORIZONTAL_ALIGNMENT_LEFT, 34.0, 12, MilTheme.AMBER)
		draw_string(font, Vector2(50, y + 11), str(nm), HORIZONTAL_ALIGNMENT_LEFT, w - 64.0, 12, MilTheme.TEXT)
		y += 17.0
		shown += 1
	y += 8.0
	if ammo_n > 0:
		var avg := ammo_sum / float(ammo_n)
		_bar(Rect2(14, y, w - 28.0, 7), avg, MilTheme.GOLD if avg > 0.25 else MilTheme.BAD)
		draw_string(mono, Vector2(14, y + 20), "AVG AMMO %d%%%s" % [int(avg * 100.0), ("   %d LOW" % low) if low > 0 else ""],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, MilTheme.DIM if low == 0 else MilTheme.WARN)
		y += 28.0
	if seats > 0:
		draw_string(font, Vector2(14, y + 11), "TRANSPORT SEATS  %d / %d" % [riders, seats], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MilTheme.TEXT)
	var ab := {}
	for c in sel:
		var pa: String = c.primary_active()
		if pa != "" and c.can_use(pa):
			ab[pa] = int(ab.get(pa, 0)) + 1
	var hint := "RMB move   T attack-move   X hold"
	for pa in ab:
		hint += "   Z %s x%d" % [Abilities.ability_name(str(pa)), int(ab[pa])]
	draw_string(font, Vector2(14, size.y - 10.0), hint, HORIZONTAL_ALIGNMENT_LEFT, w - 28.0, 10, MilTheme.DIM)
