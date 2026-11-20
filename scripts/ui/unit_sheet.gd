class_name UnitSheet
extends PanelContainer
## Datasheet for one unit, structure or strategic weapon: icon, name, class, cost, a realistic description,
## stat bars (normalised against every army's roster so they are comparable), strengths / weaknesses,
## special rules, requirements and the real-world spec line. Used by the in-battle hover card and the
## prematch Arsenal browser. Call set_def() with a definition from GameData.def_for() / def_for_faction().

const GOLD := Color(1.0, 0.62, 0.10)
const DIM := Color(0.54, 0.58, 0.56)
const TEXT := Color(0.88, 0.90, 0.87)
const C_HP := Color(0.52, 0.76, 0.40)
const C_ARMOR := Color(0.50, 0.64, 0.80)
const C_DPS := Color(0.92, 0.50, 0.20)
const C_RANGE := Color(0.40, 0.74, 0.78)
const C_SPEED := Color(0.88, 0.76, 0.36)
const C_HEAL := Color(0.76, 0.50, 0.76)
const TAB_CLASS := {"infantry": "Infantry", "vehicles": "Vehicle", "air": "Aircraft", "navy": "Warship", "defenses": "Defense"}

var _icon: TextureRect
var _name: Label
var _sub: Label
var _cost: Label
var _desc: RichTextLabel
var _bars: StatBars
var _tags: RichTextLabel
var _specs: RichTextLabel


## Horizontal stat bars drawn directly (no node per row).
class StatBars extends Control:
	const ROW_H := 17.0
	var rows: Array = []   # {"label": String, "text": String, "frac": float, "color": Color}

	func set_rows(r: Array) -> void:
		rows = r
		custom_minimum_size = Vector2(0.0, maxf(float(rows.size()) * ROW_H, 1.0))
		queue_redraw()

	func _draw() -> void:
		var font: Font = MilTheme.font_ui()
		var mono: Font = MilTheme.font_mono()
		var bar_x := 74.0
		var val_w := 80.0
		var bar_w := maxf(size.x - bar_x - val_w - 6.0, 10.0)
		for i in rows.size():
			var r: Dictionary = rows[i]
			var y := float(i) * ROW_H
			draw_string(font, Vector2(0.0, y + 12.0), str(r["label"]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.54, 0.58, 0.56))
			draw_rect(Rect2(bar_x, y + 4.0, bar_w, 8.0), Color(0.02, 0.025, 0.027, 0.9))
			var fr := clampf(float(r["frac"]), 0.0, 1.0)
			if fr > 0.0:
				var col: Color = r["color"]
				draw_rect(Rect2(bar_x, y + 4.0, maxf(bar_w * fr, 2.0), 8.0), col)
				draw_rect(Rect2(bar_x, y + 4.0, maxf(bar_w * fr, 2.0), 2.0), Color(1, 1, 1, 0.18))
			for k in range(1, 10):
				var tx := bar_x + bar_w * float(k) / 10.0
				draw_line(Vector2(tx, y + 4.0), Vector2(tx, y + 12.0), Color(0, 0, 0, 0.5), 1.0)
			draw_rect(Rect2(bar_x, y + 4.0, bar_w, 8.0), Color(0.3, 0.33, 0.32), false, 1.0)
			draw_string(mono, Vector2(bar_x + bar_w + 8.0, y + 12.0), str(r["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.9, 0.92, 0.88))


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(440, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.028, 0.033, 0.036, 0.97)
	sb.border_color = Color(0.62, 0.40, 0.09)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 7)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(76, 50)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_icon)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_theme_constant_override("separation", 1)
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(tv)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 19)
	_name.add_theme_font_override("font", MilTheme.font_bold())
	_name.add_theme_color_override("font_color", TEXT)
	tv.add_child(_name)
	_sub = Label.new()
	_sub.add_theme_font_size_override("font_size", 11)
	_sub.add_theme_color_override("font_color", DIM)
	tv.add_child(_sub)
	_cost = Label.new()
	_cost.add_theme_font_size_override("font_size", 20)
	_cost.add_theme_font_override("font", MilTheme.font_mono())
	_cost.add_theme_color_override("font_color", GOLD)
	_cost.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(_cost)
	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sep)
	_desc = _rich(12)
	v.add_child(_desc)
	_bars = StatBars.new()
	_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_bars)
	_tags = _rich(11)
	v.add_child(_tags)
	_specs = _rich(11)
	v.add_child(_specs)


func _rich(fs: int) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_theme_font_size_override("normal_font_size", fs)
	r.add_theme_font_size_override("bold_font_size", fs)
	r.add_theme_color_override("default_color", TEXT)
	return r


## missing: capability id the player currently lacks for this item ("" = none).
func set_def(d: Dictionary, kind: String, missing: String = "") -> void:
	if d.is_empty():
		visible = false
		return
	_icon.texture = SpriteLib.get_texture(str(d.get("sprite", d.get("id", ""))), str(d.get("shape", "box")))
	_icon.modulate = SpriteLib.team_tint(0)
	_name.text = str(d.get("name", ""))
	_cost.text = "$%d" % int(float(d.get("cost", 0)))
	var cls := str(d.get("class", ""))
	if cls == "":
		cls = _fallback_class(d, kind)
	var fac: Dictionary = GameData.factions.get(str(d.get("faction", "")), {})
	var fname := str(fac.get("name", ""))
	_sub.text = cls if fname == "" else "%s   |   %s" % [cls, fname]
	_desc.text = str(d.get("desc", ""))
	_bars.set_rows(_rows_for(d, kind))
	_tags.text = _tags_for(d, kind, missing)
	var spec_parts: PackedStringArray = []
	for s in str(d.get("specs", "")).split("|"):
		var t := s.strip_edges()
		if t != "":
			spec_parts.append(t)
	_specs.visible = not spec_parts.is_empty()
	_specs.text = "[color=#45c7e0]REAL-WORLD DATA[/color]   " + "   [color=#4b524f]|[/color]   ".join(spec_parts) if _specs.visible else ""
	reset_size()


func _fallback_class(d: Dictionary, kind: String) -> String:
	if kind == "strategic":
		return "Strategic weapon"
	if kind == "national":
		return "Country building"
	return str(TAB_CLASS.get(str(d.get("tab", "")), "Unit"))


func _row(label: String, text: String, frac: float, col: Color) -> Dictionary:
	return {"label": label, "text": text, "frac": frac, "color": col}


func _rows_for(d: Dictionary, kind: String) -> Array:
	var rows: Array = []
	var m: Dictionary = GameData.stat_max(str(d.get("tab", "")))
	if kind == "strategic":
		var dmg := float(d.get("damage", 0.0))
		var sp := float(d.get("splash", 0.0))
		rows.append(_row("Damage", str(int(dmg)), dmg / float(m["damage"]), C_DPS))
		rows.append(_row("Blast radius", str(int(sp)), sp / float(m["splash"]), C_RANGE))
		rows.append(_row("Cooldown", "%d s" % int(float(d.get("cooldown", 0.0))), 0.0, C_SPEED))
		rows.append(_row("Interceptors", "%d hits" % int(ceil(float(d.get("hp", 1.0)) / 130.0)), 0.0, C_ARMOR))
		return rows
	var hp := float(d.get("hp", 0.0))
	rows.append(_row("Health", str(int(hp)), hp / float(m["hp"]), C_HP))
	if kind != "national":
		var ar := float(d.get("armor", 0.0))
		rows.append(_row("Armor", str(int(ar)), ar / float(m["armor"]), C_ARMOR))
	var dps := GameData.dps_of(d)
	if dps > 0.0:
		var txt := "%d dps" % int(round(dps))
		if bool(d.get("kamikaze", false)):
			txt = "%d one-shot" % int(float(d.get("damage", 0.0)))
		rows.append(_row("Firepower", txt, dps / float(m["dps"]), C_DPS))
	var rg := float(d.get("range", 0.0))
	if rg > 0.0:
		rows.append(_row("Range", str(int(rg)), rg / float(m["range"]), C_RANGE))
	var spd := float(d.get("speed", 0.0))
	if spd > 0.0:
		rows.append(_row("Speed", str(int(spd)), spd / float(m["speed"]), C_SPEED))
	if d.has("heal"):
		var h: Dictionary = d["heal"]
		var rate := float(h.get("rate", 0.0))
		rows.append(_row("Repair rate", "%d /s" % int(rate), rate / 40.0, C_HEAL))
	return rows


func _title_case(s: String) -> String:
	return s.capitalize()


func _tags_for(d: Dictionary, kind: String, missing: String) -> String:
	var lines: PackedStringArray = []
	if kind != "strategic" and float(d.get("damage", 0.0)) > 0.0:
		var tg: Array = d.get("targets", ["ground"])
		var names: PackedStringArray = []
		for x in tg:
			names.append(_title_case(str(x)))
		lines.append("[color=#8f9a95]Engages[/color]  " + ", ".join(names))
	var vs: Dictionary = d.get("vs", {})
	var strong: PackedStringArray = []
	var weak: PackedStringArray = []
	for k in vs:
		var mult := float(vs[k])
		if mult > 1.05:
			strong.append("%s x%s" % [_title_case(str(k)), str(snappedf(mult, 0.01))])
		elif mult < 0.95:
			weak.append("%s x%s" % [_title_case(str(k)), str(snappedf(mult, 0.01))])
	if not strong.is_empty():
		lines.append("[color=#8fd16f]Strong vs[/color]  " + ", ".join(strong))
	if not weak.is_empty():
		lines.append("[color=#e08560]Weak vs[/color]  " + ", ".join(weak))
	var notes: PackedStringArray = []
	if float(d.get("stealth", 0.0)) != 0.0:
		notes.append("Stealth: seen only at close range")
	if bool(d.get("kamikaze", false)):
		notes.append("Suicide weapon")
	if float(d.get("splash", 0.0)) > 0.0 and kind != "strategic":
		notes.append("Blast radius %d" % int(float(d.get("splash", 0.0))))
	if float(d.get("min_range", 0.0)) > 0.0:
		notes.append("Min range %d" % int(float(d.get("min_range", 0.0))))
	if float(d.get("pierce", 0.0)) > 0.0:
		notes.append("Armor piercing %d" % int(float(d.get("pierce", 0.0))))
	var cargo: Array = d.get("cargo", [])
	if not cargo.is_empty():
		notes.append("Carries %d troops" % cargo.size())
	if d.has("spawn_every"):
		notes.append("Launches an aircraft every %ds" % int(float(d.get("spawn_every", 0.0))))
	if d.has("income"):
		notes.append("Income +%s / s" % str(d.get("income")))
	if d.has("limit"):
		notes.append("Max %d per country" % int(float(d.get("limit", 0.0))))
	if bool(d.get("scout", false)):
		notes.append("Scout: roams ahead on its own, sees %d" % int(Abilities.vision_for(kind, d, "air")))
	if not notes.is_empty():
		lines.append("[color=#8f9a95]Notes[/color]  " + "  -  ".join(notes))
	var util: PackedStringArray = []
	for a in Abilities.for_def(kind, d):
		util.append("%s (%s)" % [Abilities.ability_name(str(a)), "Z" if Abilities.is_active(str(a)) else "auto"])
	if not util.is_empty():
		lines.append("[color=#e0a93a]Utility[/color]  " + ",  ".join(util))
	var req := GameData.requirements(d)
	if not req.is_empty():
		var rn: PackedStringArray = []
		for r in req:
			var nm := GameData.cap_name(str(r))
			rn.append("[color=#ff9a4a]%s (offline)[/color]" % nm if str(r) == missing else nm)
		lines.append("[color=#ffbd33]Requires[/color]  " + ", ".join(rn))
	return "\n".join(lines)
