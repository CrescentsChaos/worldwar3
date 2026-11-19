class_name PrepPanel
extends Control
## Preparation phase UI (the war is frozen): banner with the countdown and START BATTLE, plus a side panel for the
## battle plan (army stance, objective, fog, autopilot) and build designs (move / rotate / sell, save & load layouts).
var battle
var banner: Panel
var timer_label: Label
var side: PanelContainer
var focus_buttons: Dictionary = {}
var stance_buttons: Dictionary = {}
var fog_button: Button
var auto_button: Button
var slot_labels: Dictionary = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


func build(b) -> void:
	battle = b
	# --- banner
	banner = Panel.new()
	banner.position = Vector2(400, 58)
	banner.size = Vector2(480, 44)
	banner.add_theme_stylebox_override("panel", MilTheme.box(Color(0.06, 0.08, 0.07, 0.92), MilTheme.AMBER, 2, 6, 4))
	add_child(banner)
	var t := Label.new()
	t.text = "PREPARATION PHASE"
	t.position = Vector2(14, 4)
	t.size = Vector2(250, 18)
	t.add_theme_font_size_override("font_size", 14)
	t.add_theme_font_override("font", MilTheme.font_bold())
	t.add_theme_color_override("font_color", MilTheme.AMBER)
	banner.add_child(t)
	timer_label = Label.new()
	timer_label.position = Vector2(14, 22)
	timer_label.size = Vector2(250, 18)
	timer_label.add_theme_font_size_override("font_size", 11)
	timer_label.add_theme_color_override("font_color", MilTheme.DIM)
	banner.add_child(timer_label)
	banner.add_child(_btn("START BATTLE [Enter]", Vector2(270, 6), Vector2(200, 32), func(): battle.end_prep(), 13))
	# --- side panel
	side = PanelContainer.new()
	side.position = Vector2(972, 122)
	side.size = Vector2(300, 326)
	side.add_theme_stylebox_override("panel", MilTheme.box(Color(0.05, 0.07, 0.06, 0.9), MilTheme.LINE, 1, 8, 6))
	add_child(side)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	side.add_child(vb)
	vb.add_child(_cap("BATTLE PLAN"))
	var r1 := HBoxContainer.new()
	vb.add_child(r1)
	for st in [["assault", "ASSAULT"], ["defend", "DEFEND"], ["manual", "MANUAL"]]:
		var sid: String = st[0]
		var bt := _flat(st[1], func(): battle.stance = sid; refresh())
		stance_buttons[sid] = bt
		r1.add_child(bt)
	vb.add_child(_cap("ARMY OBJECTIVE"))
	var r2 := HBoxContainer.new()
	vb.add_child(r2)
	for f in [["auto", "NEAREST"], ["capital", "CAPITAL"], ["economy", "ECONOMY"], ["industry", "INDUSTRY"]]:
		var fid: String = f[0]
		var fb := _flat(f[1], func(): battle.plan_focus = fid; refresh())
		focus_buttons[fid] = fb
		r2.add_child(fb)
	var r3 := HBoxContainer.new()
	vb.add_child(r3)
	fog_button = _flat("", func(): battle.set_fog(not battle.fog_enabled); refresh())
	r3.add_child(fog_button)
	auto_button = _flat("", func(): battle.set_autopilot(not battle.autopilot); refresh())
	r3.add_child(auto_button)
	vb.add_child(_flat("SET RALLY FLAG [F]", func(): battle._cmd_mode = "rally"; battle.hud.toast("Rally point: click where new units should gather")))
	vb.add_child(_cap("BUILD DESIGN"))
	var hint := Label.new()
	hint.text = "Click a building to select, drag to move.\nR rotate  |  Del sell (bought only)\nPick a card below to place new ones."
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", MilTheme.DIM)
	vb.add_child(hint)
	var r4 := HBoxContainer.new()
	vb.add_child(r4)
	r4.add_child(_flat("ROTATE [R]", func(): battle.prep_rotate(1)))
	r4.add_child(_flat("SELL [Del]", func(): battle.prep_sell()))
	var r5 := HBoxContainer.new()
	vb.add_child(r5)
	r5.add_child(_flat("MIRROR N-S", func(): battle.mirror_layout()))
	r5.add_child(_flat("RESET LAYOUT", func(): battle.reset_layout()))
	for row in [["save", "SAVE"], ["load", "LOAD"]]:
		var rr := HBoxContainer.new()
		vb.add_child(rr)
		var lab := Label.new()
		lab.text = row[1] + " DESIGN"
		lab.custom_minimum_size = Vector2(92, 0)
		lab.add_theme_font_size_override("font_size", 10)
		lab.add_theme_color_override("font_color", MilTheme.DIM)
		rr.add_child(lab)
		for slot in ["a", "b", "c"]:
			var sl: String = slot
			var mode: String = row[0]
			rr.add_child(_flat(sl.to_upper(), func():
				if mode == "save":
					battle.save_layout(sl)
				else:
					battle.load_layout(sl)
				refresh()))
	refresh()


func _cap(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", MilTheme.AMBER_DIM)
	return l


func _flat(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 10)
	b.add_theme_stylebox_override("normal", MilTheme.box(MilTheme.PANEL, MilTheme.LINE, 1, 4, 3))
	b.add_theme_stylebox_override("hover", MilTheme.box(MilTheme.PANEL_HI, MilTheme.AMBER_DIM, 1, 4, 3))
	b.add_theme_stylebox_override("pressed", MilTheme.box(MilTheme.AMBER, MilTheme.AMBER, 1, 4, 3))
	b.pressed.connect(cb)
	return b


func _btn(text: String, pos: Vector2, sz: Vector2, cb: Callable, fs: int) -> Button:
	var b := _flat(text, cb)
	b.position = pos
	b.size = sz
	b.add_theme_font_size_override("font_size", fs)
	b.add_theme_stylebox_override("normal", MilTheme.box(Color(0.18, 0.4, 0.16), MilTheme.GOOD, 1, 4, 3))
	return b


func _hl(b: Button, on: bool) -> void:
	b.add_theme_stylebox_override("normal", MilTheme.box(MilTheme.AMBER_DIM if on else MilTheme.PANEL, MilTheme.AMBER if on else MilTheme.LINE, 1, 4, 3))


func refresh() -> void:
	if battle == null:
		return
	for k in stance_buttons:
		_hl(stance_buttons[k], battle.stance == k)
	for k in focus_buttons:
		_hl(focus_buttons[k], battle.plan_focus == k)
	if fog_button != null:
		fog_button.text = "FOG OF WAR: %s" % ("ON" if battle.fog_enabled else "OFF")
	if auto_button != null:
		auto_button.text = "AUTOPILOT: %s" % ("ON" if battle.autopilot else "OFF")
	if battle.hud != null:
		battle.hud.refresh_modes()


func _process(_d: float) -> void:
	if not visible or battle == null:
		return
	if battle.prep_t > 0.0:
		var t := int(ceil(battle.prep_t))
		timer_label.text = "Battle starts automatically in %d:%02d" % [t / 60, t % 60]
	else:
		timer_label.text = "No time limit - press START when ready"
