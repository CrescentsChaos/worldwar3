extends Control
## Prematch build screen: choose your army (faction) and strategy; the enemy gets an army and strategy too.
## All content lives in data/units.json -> "factions".

const FACTION_ORDER := ["wehrmacht", "red_army", "ija", "british_army", "us_army", "french_army", "italian_army", "russian_gf"]
const GOLD := Color(1.0, 0.62, 0.10)

var _pf := "us_army"
var _ps := ""
var _enemy_choice := "random"       # "random" or a faction id
var _faction_group := ButtonGroup.new()
var _strategy_group := ButtonGroup.new()
var _faction_btns: Dictionary = {}
var _strat_box: VBoxContainer
var _faction_text: RichTextLabel
var _strategy_text: RichTextLabel
var _enemy_text: Label
var _enemy_opt: OptionButton
var _arsenal: Arsenal
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	theme = MilTheme.theme()
	Engine.time_scale = 1.0
	get_tree().paused = false
	_rng.randomize()
	Sfx.play_music("music_menu")
	if GameData.factions.is_empty():
		# A modded units.json without factions: skip the screen and play with the generic roster.
		SaveManager.pending_p_faction = ""
		SaveManager.pending_p_strategy = ""
		SaveManager.pending_e_faction = ""
		SaveManager.pending_e_strategy = ""
		call_deferred("_go_battle")
		return
	var ids := _faction_ids()
	if SaveManager.pending_p_faction != "" and ids.has(SaveManager.pending_p_faction):
		_pf = SaveManager.pending_p_faction
		_ps = SaveManager.pending_p_strategy
	elif not ids.has(_pf):
		_pf = str(ids[0])
	_build()
	_select_faction(_pf, _ps)


func _faction_ids() -> Array:
	var out: Array = []
	for id in FACTION_ORDER:
		if GameData.factions.has(id):
			out.append(id)
	for id in GameData.factions:
		if not out.has(id):
			out.append(id)
	return out


func _label(text: String, pos: Vector2, sz: Vector2, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = sz
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	add_child(l)
	return l


func _rich(pos: Vector2, sz: Vector2) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.position = pos
	r.size = sz
	r.scroll_active = true
	r.add_theme_font_size_override("normal_font_size", 14)
	r.add_theme_font_size_override("bold_font_size", 14)
	add_child(r)
	return r


func _toggle_btn(text: String, group: ButtonGroup, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_group = group
	b.custom_minimum_size = Vector2(0, 42)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


func _build() -> void:
	var title := _label("MISSION BRIEFING", Vector2(0, 18), Vector2(1280, 54), 42, Color(0.93, 0.94, 0.9))
	title.add_theme_font_override("font", MilTheme.font_bold())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := _label("SELECT YOUR ARMY AND STRATEGY   //   DIFFICULTY: %s" % SaveManager.pending_difficulty.to_upper(),
		Vector2(0, 74), Vector2(1280, 24), 13, GOLD)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_label("YOUR ARMY", Vector2(40, 108), Vector2(260, 24), 16, GOLD)
	var fbox := VBoxContainer.new()
	fbox.position = Vector2(40, 136)
	fbox.size = Vector2(260, 460)
	fbox.add_theme_constant_override("separation", 6)
	add_child(fbox)
	for fid in _faction_ids():
		var f: String = fid
		var b := _toggle_btn(str(GameData.factions[f].get("name", f)), _faction_group, func(): _select_faction(f, ""))
		fbox.add_child(b)
		_faction_btns[f] = b

	_faction_text = _rich(Vector2(326, 114), Vector2(396, 484))

	_label("STRATEGY", Vector2(750, 108), Vector2(260, 24), 16, GOLD)
	_strat_box = VBoxContainer.new()
	_strat_box.position = Vector2(750, 136)
	_strat_box.size = Vector2(250, 150)
	_strat_box.add_theme_constant_override("separation", 6)
	add_child(_strat_box)
	_strategy_text = _rich(Vector2(750, 300), Vector2(260, 298))

	_label("ENEMY ARMY", Vector2(1036, 108), Vector2(210, 24), 16, GOLD)
	_enemy_opt = OptionButton.new()
	_enemy_opt.position = Vector2(1036, 136)
	_enemy_opt.size = Vector2(210, 40)
	_enemy_opt.add_item("Random")
	for fid in _faction_ids():
		_enemy_opt.add_item(str(GameData.factions[fid].get("name", fid)))
	_enemy_opt.item_selected.connect(_on_enemy_selected)
	add_child(_enemy_opt)
	_enemy_text = _label("", Vector2(1036, 186), Vector2(210, 300), 13, Color(0.78, 0.82, 0.75))
	_enemy_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_refresh_enemy_text()

	var start := Button.new()
	start.text = "DEPLOY  >>"
	start.position = Vector2(520, 630)
	start.size = Vector2(240, 56)
	start.focus_mode = Control.FOCUS_NONE
	start.add_theme_font_size_override("font_size", 22)
	start.add_theme_font_override("font", MilTheme.font_bold())
	start.add_theme_stylebox_override("normal", MilTheme.box(MilTheme.AMBER, MilTheme.AMBER, 1, 10, 6))
	start.add_theme_stylebox_override("hover", MilTheme.box(MilTheme.AMBER.lightened(0.15), Color.WHITE, 1, 10, 6))
	start.add_theme_stylebox_override("pressed", MilTheme.box(MilTheme.AMBER.darkened(0.2), MilTheme.AMBER, 1, 10, 6))
	start.add_theme_color_override("font_color", MilTheme.BG_SOLID)
	start.add_theme_color_override("font_hover_color", MilTheme.BG_SOLID)
	start.add_theme_color_override("font_pressed_color", MilTheme.BG_SOLID)
	start.pressed.connect(_start)
	add_child(start)
	var back := Button.new()
	back.text = "BACK"
	back.position = Vector2(326, 636)
	back.size = Vector2(140, 44)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	add_child(back)
	var ars := Button.new()
	ars.text = "ARSENAL  -  VIEW ALL UNITS"
	ars.position = Vector2(800, 636)
	ars.size = Vector2(230, 44)
	ars.focus_mode = Control.FOCUS_NONE
	ars.pressed.connect(func(): _arsenal.open(_pf))
	add_child(ars)
	_arsenal = Arsenal.new()
	add_child(_arsenal)


func _select_faction(fid: String, want_strategy: String) -> void:
	_pf = fid
	var btn: Button = _faction_btns.get(fid)
	if btn != null:
		btn.button_pressed = true
	var f: Dictionary = GameData.factions[fid]
	for c in _strat_box.get_children():
		_strat_box.remove_child(c)
		c.queue_free()
	var strategies: Dictionary = f.get("strategies", {})
	for sid in strategies:
		var s: String = sid
		var b := _toggle_btn(str(strategies[s].get("name", s)), _strategy_group, func(): _select_strategy(s))
		_strat_box.add_child(b)
	var keys: Array = strategies.keys()
	_ps = want_strategy if strategies.has(want_strategy) else str(keys[0])
	_refresh_faction_text()
	_select_strategy(_ps)


func _select_strategy(sid: String) -> void:
	_ps = sid
	var f: Dictionary = GameData.factions[_pf]
	var strategies: Dictionary = f.get("strategies", {})
	var idx := strategies.keys().find(sid)
	if idx >= 0 and idx < _strat_box.get_child_count():
		var b := _strat_box.get_child(idx) as Button
		if b != null:
			b.button_pressed = true
	_refresh_strategy_text()


func _on_enemy_selected(i: int) -> void:
	_enemy_choice = "random" if i == 0 else str(_faction_ids()[i - 1])
	_refresh_enemy_text()


func _name_of(f: Dictionary, kind: String, id: String) -> String:
	var ro: Dictionary = f.get("roster", {})
	if ro.has(id):
		return str(ro[id].get("name", id))
	var names: Dictionary = f.get("names", {})
	if names.has(id):
		return str(names[id])
	return str(GameData.get_def(kind, id).get("name", id))


func _bullets(lines: Array) -> String:
	var out := ""
	for l in lines:
		out += "- %s\n" % str(l)
	return out


func _income_lines(src: Dictionary) -> Array:
	var out: Array = []
	var inc := float(src.get("income", 1.0))
	var mon := float(src.get("money", 1.0))
	if absf(inc - 1.0) > 0.001:
		out.append("Economy: income %+d%%" % int(round((inc - 1.0) * 100.0)))
	if absf(mon - 1.0) > 0.001:
		out.append("Economy: starting money %+d%%" % int(round((mon - 1.0) * 100.0)))
	return out


func _refresh_faction_text() -> void:
	var f: Dictionary = GameData.factions[_pf]
	var t := "[font_size=24][b]%s[/b][/font_size]\n" % str(f.get("name", _pf))
	t += "[color=#ff9e1a]%s[/color]  -  %s\n\n" % [str(f.get("tagline", "")), str(f.get("era", ""))]
	t += str(f.get("desc", "")) + "\n\n"
	t += "[b]Army perks[/b]\n"
	var perks: Array = GameData.describe_mods(f.get("mods", []))
	perks.append_array(_income_lines(f))
	t += _bullets(perks) if not perks.is_empty() else "- (none)\n"
	var ban: Array = f.get("ban", [])
	if not ban.is_empty():
		var bn: Array = []
		for b in ban:
			bn.append(_name_of(f, "unit", str(b)))
		t += "\n[b]Not available:[/b] %s\n" % ", ".join(PackedStringArray(bn))
	t += "\n[b]Signature roster[/b]\n"
	var sig: Array = []
	for pair in [["unit", "tank"], ["unit", "heavy_tank"], ["unit", "mammoth"], ["unit", "fighter"], ["unit", "stealth_bomber"],
			["unit", "battleship"], ["structure", "railgun"], ["strategic", "nuke"]]:
		var kind: String = pair[0]
		var id: String = pair[1]
		if not ban.has(id):
			sig.append(_name_of(f, kind, id))
	t += ", ".join(PackedStringArray(sig))
	_faction_text.text = t


func _refresh_strategy_text() -> void:
	var f: Dictionary = GameData.factions[_pf]
	var strategies: Dictionary = f.get("strategies", {})
	var s: Dictionary = strategies.get(_ps, {})
	if s.is_empty():
		_strategy_text.text = ""
		return
	var t := "[b]%s[/b]\n%s\n\n[b]Perks[/b]\n" % [str(s.get("name", _ps)), str(s.get("desc", ""))]
	var perks: Array = GameData.describe_mods(s.get("mods", []))
	perks.append_array(_income_lines(s))
	t += _bullets(perks) if not perks.is_empty() else "- (none)\n"
	var counts: Dictionary = {}
	var order: Array = []
	for e in s.get("setup", []):
		var nm := "%s" % _name_of(f, str(e[0]), str(e[1]))
		var n := int(e[4]) if e.size() > 4 else 1
		if not counts.has(nm):
			order.append(nm)
		counts[nm] = int(counts.get(nm, 0)) + n
	var parts := PackedStringArray()
	for nm in order:
		parts.append("%dx %s" % [int(counts[nm]), str(nm)])
	t += "\n[b]Starts with (free)[/b]\n" + ", ".join(parts)
	_strategy_text.text = t


func _refresh_enemy_text() -> void:
	if _enemy_choice == "random":
		_enemy_text.text = "A random army with a random strategy. You will see who it is when the battle starts."
	else:
		var f: Dictionary = GameData.factions[_enemy_choice]
		_enemy_text.text = "%s\n%s\n\nIts strategy is chosen at random." % [str(f.get("name", _enemy_choice)), str(f.get("tagline", ""))]


func _start() -> void:
	var ef := _enemy_choice
	var ids := _faction_ids()
	if ef == "random":
		ef = str(ids[_rng.randi() % ids.size()])
	var ss: Dictionary = GameData.factions[ef].get("strategies", {})
	var keys: Array = ss.keys()
	var es := str(keys[_rng.randi() % keys.size()]) if not keys.is_empty() else ""
	SaveManager.pending_p_faction = _pf
	SaveManager.pending_p_strategy = _ps
	SaveManager.pending_e_faction = ef
	SaveManager.pending_e_strategy = es
	_go_battle()


func _go_battle() -> void:
	SaveManager.pending_load = ""
	get_tree().change_scene_to_file("res://scenes/battle.tscn")


func _draw() -> void:
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(1280, 0), Vector2(1280, 720), Vector2(0, 720)]),
		PackedColorArray([Color(0.055, 0.065, 0.068), Color(0.055, 0.065, 0.068), Color(0.018, 0.022, 0.024), Color(0.018, 0.022, 0.024)]))
	for x in range(0, 1281, 80):
		draw_line(Vector2(x, 0), Vector2(x, 720), Color(0.7, 0.8, 0.7, 0.035), 1.0)
	for y in range(0, 721, 80):
		draw_line(Vector2(0, y), Vector2(1280, y), Color(0.7, 0.8, 0.7, 0.035), 1.0)
	for r in [Rect2(318, 106, 412, 500), Rect2(742, 292, 276, 314)]:
		draw_rect(r, Color(0.02, 0.024, 0.026, 0.88))
		draw_rect(r, MilTheme.LINE, false, 1.0)
		MilTheme.draw_brackets(self, r.grow(2.0), MilTheme.AMBER_DIM, 10.0, 1.5)
	draw_rect(Rect2(0, 0, 6, 720), MilTheme.AMBER)
	draw_rect(Rect2(0, 0, 1280, 2), Color(MilTheme.AMBER, 0.5))
	draw_rect(Rect2(0, 718, 1280, 2), Color(MilTheme.AMBER, 0.5))
