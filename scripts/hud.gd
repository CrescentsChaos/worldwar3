class_name HUD
extends CanvasLayer
## All UI is built in code: top bar, deploy cards, pause / save menu, alerts.

var battle

var root: Control
var money_label: Label
var income_label: Label
var time_label: Label
var cap_label: Label
var p_bar: SegBar
var e_bar: SegBar
var p_hp_label: Label
var e_hp_label: Label
var feed: FeedLog
var pause_frame: BracketFrame
var over_frame: BracketFrame
var info_frame: BracketFrame
var cmd_panel: CommandPanel
var card_box: HBoxContainer
var card_scroll: ScrollContainer
var country_label: Label
var minimap: Minimap
var _styled_sel := "~"
var info_label: RichTextLabel
var sheet: UnitSheet
var _hover_key := ""
var _sheet_key := ""
var _last_info := "~"
var toast_label: Label
var alert_label: AlertBanner
var flash_rect: ColorRect
var pause_panel: PanelContainer
var slot_buttons: Dictionary = {}
var over_panel: PanelContainer
var over_title: Label
var over_stats: Label
var tab_buttons: Dictionary = {}
var speed_buttons: Array = []

var cards: Dictionary = {}          # "kind:id" -> {button, overlay, label, def, kind, id}
var current_tab := "infantry"
var toast_t := 0.0
var alert_t := 0.0
var menu_open := false
var over_timer := -1.0
var victory := false


func _init() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = MilTheme.theme()
	add_child(root)
	_build_top_bar()
	_build_bottom_panel()
	_build_overlays()
	_build_mode_buttons()
	if not GameData.tabs.is_empty():
		current_tab = str(GameData.tabs[0].get("id", "infantry"))


# ------------------------------------------------------------------ building

func _panel_style(col: Color, border: Color = Color(0, 0, 0, 0), bw: int = 0, _radius: int = 0) -> StyleBoxFlat:
	return MilTheme.box(col, border, bw)


func _label(text: String, pos: Vector2, size: Vector2, font_size: int = 14, color: Color = MilTheme.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = size
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _make_button(text: String, pos: Vector2, size: Vector2, cb: Callable, font_size: int = 14) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_stylebox_override("normal", MilTheme.box(MilTheme.PANEL, MilTheme.LINE, 1, 4, 2))
	b.add_theme_stylebox_override("hover", MilTheme.box(MilTheme.PANEL_HI, MilTheme.AMBER_DIM, 1, 4, 2))
	b.add_theme_stylebox_override("pressed", MilTheme.box(MilTheme.AMBER, MilTheme.AMBER, 1, 4, 2))
	b.add_theme_stylebox_override("hover_pressed", MilTheme.box(MilTheme.AMBER, MilTheme.AMBER, 1, 4, 2))
	b.pressed.connect(cb)
	return b


func _build_top_bar() -> void:
	var bar := Panel.new()
	bar.position = Vector2.ZERO
	bar.size = Vector2(1280, 54)
	bar.add_theme_stylebox_override("panel", MilTheme.edge_box(Color(0.035, 0.04, 0.043, 0.95), MilTheme.LINE_HI, SIDE_BOTTOM, 1))
	root.add_child(bar)
	var accent := ColorRect.new()
	accent.color = MilTheme.AMBER
	accent.position = Vector2(0, 0)
	accent.size = Vector2(5, 54)
	bar.add_child(accent)

	var brand := _label("WW3", Vector2(18, 4), Vector2(120, 32), 28, MilTheme.AMBER)
	brand.add_theme_font_override("font", MilTheme.font_bold())
	bar.add_child(brand)
	bar.add_child(MilTheme.caption("Theatre command", Vector2(19, 35), Vector2(140, 14), MilTheme.DIM, 10))

	bar.add_child(MilTheme.caption("Funds", Vector2(166, 5), Vector2(110, 14), MilTheme.DIM, 10))
	money_label = MilTheme.readout("$ 0", Vector2(165, 15), Vector2(150, 34), MilTheme.AMBER, 26)
	bar.add_child(money_label)
	bar.add_child(MilTheme.caption("Income", Vector2(310, 5), Vector2(80, 14), MilTheme.DIM, 10))
	income_label = MilTheme.readout("+0.0/s", Vector2(309, 19), Vector2(100, 26), MilTheme.GOOD, 17)
	bar.add_child(income_label)
	bar.add_child(MilTheme.caption("Force", Vector2(410, 5), Vector2(70, 14), MilTheme.DIM, 10))
	cap_label = MilTheme.readout("0/90", Vector2(409, 19), Vector2(80, 26), MilTheme.TEXT, 17)
	bar.add_child(cap_label)

	# capitals
	p_bar = SegBar.new()
	p_bar.position = Vector2(496, 8)
	p_bar.size = Vector2(226, 20)
	p_bar.color = SpriteLib.team_color(0)
	bar.add_child(p_bar)
	p_hp_label = MilTheme.caption("Your capital", Vector2(496, 31), Vector2(226, 16), MilTheme.FRIEND, 10)
	bar.add_child(p_hp_label)
	e_bar = SegBar.new()
	e_bar.position = Vector2(806, 8)
	e_bar.size = Vector2(226, 20)
	e_bar.color = SpriteLib.team_color(1)
	e_bar.from_right = true
	bar.add_child(e_bar)
	e_hp_label = MilTheme.caption("Enemy capital", Vector2(806, 31), Vector2(226, 16), MilTheme.ENEMY, 10)
	e_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar.add_child(e_hp_label)

	# clock block between the capitals
	var clock_bg := ColorRect.new()
	clock_bg.color = Color(0, 0, 0, 0.55)
	clock_bg.position = Vector2(728, 8)
	clock_bg.size = Vector2(72, 38)
	bar.add_child(clock_bg)
	time_label = MilTheme.readout("00:00", Vector2(728, 8), Vector2(72, 24), MilTheme.TEXT, 19)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(time_label)
	var tcap := MilTheme.caption("Elapsed", Vector2(728, 31), Vector2(72, 14), MilTheme.DIM, 9)
	tcap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(tcap)

	country_label = MilTheme.readout("", Vector2(1042, 6), Vector2(90, 44), MilTheme.DIM, 11)
	bar.add_child(country_label)

	bar.add_child(_make_button("MENU", Vector2(1136, 12), Vector2(46, 30), _open_menu, 11))
	var speeds := [1.0, 2.0, 3.0]
	for i in speeds.size():
		var s: float = speeds[i]
		var b := _make_button("%dx" % int(s), Vector2(1186 + i * 31, 12), Vector2(28, 30), func(): _set_speed(s), 12)
		b.toggle_mode = true
		bar.add_child(b)
		speed_buttons.append(b)
	speed_buttons[0].button_pressed = true

	feed = FeedLog.new()
	feed.position = Vector2(14, 64)
	feed.size = Vector2(420, 130)
	root.add_child(feed)


func _build_bottom_panel() -> void:
	var panel := Panel.new()
	panel.position = Vector2(0, 568)
	panel.size = Vector2(1280, 152)
	panel.add_theme_stylebox_override("panel", MilTheme.edge_box(Color(0.035, 0.04, 0.043, 0.96), MilTheme.LINE_HI, SIDE_TOP, 1))
	root.add_child(panel)
	var x := 12.0
	for t in GameData.tabs:
		var tid := str(t.get("id", ""))
		var b := _make_button(str(t.get("name", tid)).to_upper(), Vector2(x, 6), Vector2(100, 30), func(): _show_tab(tid), 12)
		MilTheme.style_tab(b)
		b.toggle_mode = true
		panel.add_child(b)
		tab_buttons[tid] = b
		x += 102.0
	panel.add_child(_make_button("<", Vector2(x + 6.0, 8), Vector2(28, 26), func(): _scroll_cards(-320), 13))
	panel.add_child(_make_button(">", Vector2(x + 38.0, 8), Vector2(28, 26), func(): _scroll_cards(320), 13))
	panel.add_child(MilTheme.caption("WASD cam / wheel zoom / Q E tabs / 1-9 queue / V stance / P autopilot / X hold / T atk-move / F rally",
		Vector2(x + 78.0, 14), Vector2(maxf(1270.0 - x - 78.0, 200.0), 18), Color(0.4, 0.44, 0.42), 10))
	card_scroll = ScrollContainer.new()
	card_scroll.position = Vector2(12, 42)
	card_scroll.size = Vector2(944, 106)
	card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(card_scroll)
	card_box = HBoxContainer.new()
	card_box.add_theme_constant_override("separation", 6)
	card_scroll.add_child(card_box)
	var info_bg := Panel.new()
	info_bg.position = Vector2(966, 42)
	info_bg.size = Vector2(304, 104)
	info_bg.add_theme_stylebox_override("panel", MilTheme.box(Color(0.02, 0.024, 0.026, 0.9), MilTheme.LINE, 1))
	panel.add_child(info_bg)
	info_frame = BracketFrame.new(MilTheme.AMBER_DIM, 8.0, 1.5)
	info_frame.position = info_bg.position
	info_frame.size = info_bg.size
	panel.add_child(info_frame)
	info_label = RichTextLabel.new()
	info_label.bbcode_enabled = true
	info_label.scroll_active = false
	info_label.position = Vector2(10, 6)
	info_label.size = Vector2(286, 94)
	info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_label.add_theme_font_size_override("normal_font_size", 11)
	info_label.add_theme_font_size_override("bold_font_size", 14)
	info_label.add_theme_font_override("bold_font", MilTheme.font_bold())
	info_label.add_theme_color_override("default_color", Color(0.78, 0.82, 0.78))
	info_bg.add_child(info_label)
	# Overview map (click / drag to move the camera).
	minimap = Minimap.new()
	minimap.battle = battle
	minimap.position = Vector2(970, 568 - 112)
	minimap.size = Vector2(300, 104)
	root.add_child(minimap)
	cmd_panel = CommandPanel.new()
	cmd_panel.battle = battle
	cmd_panel.position = Vector2(12, 392)
	cmd_panel.size = Vector2(350, 168)
	root.add_child(cmd_panel)
	# Full datasheet, shown while hovering a card (bottom-left, above the card strip; never blocks clicks).
	sheet = UnitSheet.new()
	sheet.position = Vector2(12, 200)
	sheet.visible = false
	root.add_child(sheet)


## Army stance + autopilot toggles (top right of the battlefield).
var stance_button: Button
var autopilot_button: Button


func _build_mode_buttons() -> void:
	stance_button = _make_button("", Vector2(1030, 62), Vector2(242, 26), func(): battle.cycle_stance(), 11)
	root.add_child(stance_button)
	autopilot_button = _make_button("", Vector2(1030, 92), Vector2(242, 26), func(): battle.set_autopilot(not battle.autopilot), 11)
	root.add_child(autopilot_button)
	refresh_modes()


func refresh_modes() -> void:
	if stance_button == null or battle == null:
		return
	var names := {"assault": "AUTO-ASSAULT", "defend": "DEFEND RALLY", "manual": "MANUAL"}
	stance_button.text = "ARMY: %s   [V]" % names.get(battle.stance, "?")
	autopilot_button.text = "AUTOPILOT: %s   [P]" % ("ON" if battle.autopilot else "OFF")


func _scroll_cards(amount: int) -> void:
	card_scroll.scroll_horizontal = maxi(0, card_scroll.scroll_horizontal + amount)


func _build_overlays() -> void:
	toast_label = _label("", Vector2(240, 528), Vector2(100, 30), 15, MilTheme.TEXT)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.add_theme_stylebox_override("normal", MilTheme.edge_box(Color(0.03, 0.035, 0.037, 0.88), MilTheme.AMBER, SIDE_LEFT, 3, 14, 6))
	toast_label.modulate.a = 0.0
	root.add_child(toast_label)

	alert_label = AlertBanner.new()
	alert_label.position = Vector2(0, 66)
	alert_label.size = Vector2(1280, 52)
	alert_label.modulate.a = 0.0
	root.add_child(alert_label)

	flash_rect = ColorRect.new()
	flash_rect.color = Color(1, 0.97, 0.85, 1)
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.modulate.a = 0.0
	root.add_child(flash_rect)

	# Pause / save menu
	pause_panel = PanelContainer.new()
	var psb := MilTheme.box(Color(0.035, 0.04, 0.043, 0.97), MilTheme.LINE_HI, 1, 18, 14)
	pause_panel.add_theme_stylebox_override("panel", psb)
	pause_panel.position = Vector2(400, 70)
	pause_panel.size = Vector2(480, 440)
	pause_panel.visible = false
	root.add_child(pause_panel)
	pause_frame = BracketFrame.new(MilTheme.AMBER, 16.0, 2.0)
	pause_frame.position = pause_panel.position - Vector2(6, 6)
	pause_frame.size = pause_panel.size + Vector2(12, 12)
	pause_frame.visible = false
	root.add_child(pause_frame)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	pause_panel.add_child(vb)
	var title := Label.new()
	title.text = "COMMAND PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", MilTheme.font_bold())
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", MilTheme.AMBER)
	vb.add_child(title)
	vb.add_child(_vbtn("Resume", _close_menu))
	vb.add_child(_section("Save game"))
	for i in range(1, 4):
		var slot := "slot%d" % i
		var b := _vbtn("", func(): _do_save(slot))
		vb.add_child(b)
		slot_buttons["save:" + slot] = b
	vb.add_child(_section("Load game"))
	for slot in SaveManager.SLOTS:
		var s: String = slot
		var b2 := _vbtn("", func(): _do_load(s))
		vb.add_child(b2)
		slot_buttons["load:" + s] = b2
	vb.add_child(_vbtn("Reload sprites (F10)", func(): battle.reload_sprites()))
	vb.add_child(_vbtn("Abort mission - main menu", _to_menu))

	# Game over
	over_panel = PanelContainer.new()
	var osb := MilTheme.box(Color(0.03, 0.035, 0.038, 0.97), MilTheme.LINE_HI, 1, 22, 18)
	over_panel.add_theme_stylebox_override("panel", osb)
	over_panel.position = Vector2(420, 170)
	over_panel.size = Vector2(440, 320)
	over_panel.visible = false
	root.add_child(over_panel)
	over_frame = BracketFrame.new(MilTheme.AMBER, 18.0, 2.0)
	over_frame.position = over_panel.position - Vector2(6, 6)
	over_frame.size = over_panel.size + Vector2(12, 12)
	over_frame.visible = false
	root.add_child(over_frame)
	var ovb := VBoxContainer.new()
	ovb.add_theme_constant_override("separation", 10)
	over_panel.add_child(ovb)
	over_title = Label.new()
	over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	over_title.add_theme_font_override("font", MilTheme.font_bold())
	over_title.add_theme_font_size_override("font_size", 52)
	ovb.add_child(over_title)
	over_stats = Label.new()
	over_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	over_stats.add_theme_font_override("font", MilTheme.font_mono())
	over_stats.add_theme_font_size_override("font_size", 13)
	over_stats.add_theme_color_override("font_color", MilTheme.DIM)
	ovb.add_child(over_stats)
	ovb.add_child(_vbtn("Redeploy - play again", _restart))
	ovb.add_child(_vbtn("Main menu", _to_menu))


func _section(text: String) -> Label:
	var l := MilTheme.caption(text, Vector2.ZERO, Vector2.ZERO, MilTheme.AMBER_DIM, 11)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _vbtn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 34)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


# --------------------------------------------------------------------- cards

func rebuild_cards() -> void:
	_show_tab(current_tab)


func _show_tab(tab: String) -> void:
	current_tab = tab
	for k in tab_buttons:
		tab_buttons[k].button_pressed = (k == tab)
	for c in card_box.get_children():
		c.queue_free()
	cards.clear()
	card_scroll.scroll_horizontal = 0
	var hotkey := 1
	for item in GameData.items_for_tab(tab, 0):
		var kind: String = item[0]
		var id: String = item[1]
		var d := GameData.def_for(0, kind, id)
		var card := _make_card(kind, id, d, hotkey)
		card_box.add_child(card)
		hotkey += 1
	_refresh_card_styles(true)


func _make_card(kind: String, id: String, d: Dictionary, hotkey: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(150, 104)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): _select(kind, id))
	b.mouse_entered.connect(_on_card_hover.bind(kind + ":" + id, true))
	b.mouse_exited.connect(_on_card_hover.bind(kind + ":" + id, false))
	var back := ColorRect.new()
	back.color = Color(0.016, 0.02, 0.022, 0.75)
	back.position = Vector2(3, 3)
	back.size = Vector2(144, 58)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(back)
	var icon := TextureRect.new()
	icon.texture = SpriteLib.get_texture(str(d.get("sprite", id)), str(d.get("shape", "box")))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(30, 5)
	icon.size = Vector2(90, 54)
	icon.modulate = SpriteLib.team_tint(0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)
	var ov := ColorRect.new()
	ov.color = Color(0, 0, 0, 0.66)
	ov.position = Vector2.ZERO
	ov.size = Vector2(150, 104)
	ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.visible = false
	b.add_child(ov)
	if hotkey <= 9:
		var hk := MilTheme.caption(str(hotkey), Vector2(7, 4), Vector2(16, 14), MilTheme.DIM, 11)
		b.add_child(hk)
	var nm := Label.new()
	nm.text = str(d.get("name", id))
	nm.position = Vector2(7, 62)
	nm.size = Vector2(138, 18)
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.add_theme_font_size_override("font_size", 12)
	nm.add_theme_color_override("font_color", MilTheme.TEXT)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(nm)
	var cost := MilTheme.readout("$%d" % int(d.get("cost", 0)), Vector2(7, 80), Vector2(70, 20), MilTheme.AMBER, 14)
	b.add_child(cost)
	var status := MilTheme.caption("", Vector2(62, 83), Vector2(84, 16), MilTheme.WARN, 9)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.clip_text = true
	b.add_child(status)
	var sel := BracketFrame.new(MilTheme.AMBER, 12.0, 2.0)
	sel.size = Vector2(150, 104)
	sel.visible = false
	b.add_child(sel)
	cards[kind + ":" + id] = {"button": b, "overlay": ov, "cost": cost, "status": status, "sel": sel,
		"def": d, "kind": kind, "id": id}
	return b


func _select(kind: String, id: String) -> void:
	if kind == "unit":
		# Units are produced, not dropped: queue at the right building (Shift = 5 at once).
		battle.select("", "")
		var n := 5 if Input.is_key_pressed(KEY_SHIFT) else 1
		for i in n:
			var err: String = battle.queue_unit(0, id)
			if err != "":
				toast(err)
				break
		_refresh_card_styles(true)
		return
	if battle.sel_kind == kind and battle.sel_id == id:
		battle.select("", "")
	else:
		battle.select(kind, id)
	_refresh_card_styles()


func _refresh_card_styles(force: bool = false) -> void:
	var sel_key: String = battle.sel_kind + ":" + battle.sel_id
	if not force and sel_key == _styled_sel:
		return
	_styled_sel = sel_key
	for key in cards:
		var c: Dictionary = cards[key]
		var selected: bool = battle.sel_kind == c["kind"] and battle.sel_id == c["id"]
		var b: Button = c["button"]
		var border := MilTheme.AMBER if selected else MilTheme.LINE
		var bg := Color(0.14, 0.11, 0.05, 0.96) if selected else MilTheme.PANEL
		b.add_theme_stylebox_override("normal", MilTheme.box(bg, border, 2 if selected else 1))
		b.add_theme_stylebox_override("hover", MilTheme.box(bg.lightened(0.08), MilTheme.AMBER if selected else MilTheme.AMBER_DIM, 1))
		b.add_theme_stylebox_override("pressed", MilTheme.box(bg.lightened(0.16), MilTheme.AMBER, 2))
		var fr: BracketFrame = c["sel"]
		fr.visible = selected


const IDLE_INFO := "[color=#ff9e1a][b]COMMAND[/b][/color]\n[color=#8a948f]Unit cards queue production at your Barracks / Factory / Airbase / Port (Shift = x5).\nDrag to select. RMB move, Ctrl+RMB or T attack-move, X hold, F rally point, C select all.\nDefenses and buildings: pick a card, then click the map.[/color]"


func _on_card_hover(key: String, inside: bool) -> void:
	if inside:
		_hover_key = key
	elif _hover_key == key:
		_hover_key = ""


## Compact summary for the always-visible info panel (the hover datasheet has the full detail).
func _info_bbcode(kind: String, id: String) -> String:
	var d := GameData.def_for(0, kind, id)
	if d.is_empty():
		return ""
	var t := "[b][color=#ffb02e]%s[/color][/b]   [color=#ff9e1a]$%d[/color]\n" % [str(d.get("name", id)), int(float(d.get("cost", 0)))]
	var cls := str(d.get("class", ""))
	if cls != "":
		t += "[color=#7f8a86]%s[/color]\n" % cls
	if kind == "strategic":
		t += "Damage %d | Blast %d | Cooldown %ds | Interceptor hits %d\n" % [
			int(d.get("damage", 0)), int(d.get("splash", 0)), int(d.get("cooldown", 0)),
			int(ceil(float(d.get("hp", 1)) / 130.0))]
	else:
		t += "HP %d  Armor %d  DPS %d  Range %d  Speed %d\n" % [
			int(d.get("hp", 0)), int(d.get("armor", 0)), int(GameData.dps_of(d)), int(d.get("range", 0)), int(d.get("speed", 0))]
		if d.has("income"):
			t += "Income +%s / s\n" % str(d.get("income"))
		var prov: Array = d.get("provides", [])
		if not prov.is_empty():
			var names: Array[String] = []
			for p in prov:
				names.append(GameData.cap_name(str(p)))
			t += "Provides: " + ", ".join(PackedStringArray(names)) + "\n"
	t += "[color=#c3cbc4]%s[/color]" % str(d.get("desc", ""))
	var req := GameData.requirements(d)
	if not req.is_empty():
		var rn: Array[String] = []
		for r in req:
			rn.append(GameData.cap_name(str(r)))
		t += "\n[color=#ffbd33]Requires: %s[/color]" % ", ".join(PackedStringArray(rn))
	return t


func _update_sheet() -> void:
	if _hover_key == "" or not cards.has(_hover_key) or menu_open:
		sheet.visible = false
		_sheet_key = ""
		return
	var c: Dictionary = cards[_hover_key]
	var missing: String = battle.missing_requirement(0, c["def"])
	var key := _hover_key + "|" + missing
	if key != _sheet_key:
		_sheet_key = key
		sheet.set_def(c["def"], str(c["kind"]), missing)
	sheet.visible = true
	sheet.position = Vector2(12.0, 560.0 - sheet.size.y)


# ------------------------------------------------------------------- updates

func _process(delta: float) -> void:
	if battle == null:
		return
	var b: Battle = battle
	money_label.text = "$ %d" % int(b.money[0])
	income_label.text = "+%.1f/s" % b.income_rate(0)
	country_label.text = "SECTORS\nYOU   %d/%d\nENEMY %d/%d" % [b.nat_alive(0), int(b.nat_start[0]), b.nat_alive(1), int(b.nat_start[1])]
	var t := int(b.elapsed)
	time_label.text = "%02d:%02d" % [t / 60, t % 60]
	cap_label.text = "%d/%d" % [b.unit_count(0, false), int(GameData.settings.get("unit_cap", 90))]
	_update_hq(0, p_bar, p_hp_label, "Your capital")
	_update_hq(1, e_bar, e_hp_label, "Enemy capital")
	for key in cards:
		var c: Dictionary = cards[key]
		var cd := b.get_cooldown(0, c["kind"], c["id"])
		var ov: ColorRect = c["overlay"]
		if cd > 0.0:
			var total := maxf(b.cooldown_total(c["kind"], c["id"]), 0.1)
			ov.visible = true
			ov.size.y = 104.0 * clampf(cd / total, 0.0, 1.0)
		else:
			ov.visible = false
		var cost_l: Label = c["cost"]
		var status_l: Label = c["status"]
		var missing: String = b.missing_requirement(0, c["def"])
		if missing != "":
			status_l.text = "NEEDS " + GameData.cap_name(missing).to_upper()
			ov.visible = true
			ov.size.y = 104.0
		else:
			status_l.text = ""
		cost_l.add_theme_color_override("font_color", MilTheme.AMBER if b.money[0] >= float(c["def"].get("cost", 0)) else MilTheme.BAD)
	var info := _info_bbcode(b.sel_kind, b.sel_id) if b.sel_kind != "" else IDLE_INFO
	if info != _last_info:
		_last_info = info
		info_label.text = info
	_update_sheet()
	if toast_t > 0.0:
		toast_t -= delta
		toast_label.modulate.a = clampf(toast_t / 0.6, 0.0, 1.0)
	if alert_t > 0.0:
		alert_t -= delta
		var blink := 0.55 + 0.45 * sin(alert_t * 10.0)
		alert_label.modulate.a = clampf(alert_t, 0.0, 1.0) * blink
	if flash_rect.modulate.a > 0.0:
		flash_rect.modulate.a = maxf(0.0, flash_rect.modulate.a - delta * 0.7)
	if over_timer > 0.0:
		over_timer -= delta
		if over_timer <= 0.0:
			_show_over_panel()
	_refresh_card_styles()


func _update_hq(team: int, bar: SegBar, label: Label, prefix: String) -> void:
	var hq = battle.bases[team]  # untyped: the HQ may already be freed
	if hq != null and is_instance_valid(hq):
		bar.set_state(maxf(hq.hp, 0.0), hq.max_hp, "%d / %d" % [int(maxf(hq.hp, 0.0)), int(hq.max_hp)])
		label.text = prefix.to_upper()
	else:
		bar.set_state(0.0, 1.0, "DESTROYED")
		label.text = (prefix + "  -  down").to_upper()


# ----------------------------------------------------------------- feedback

func toast(msg: String) -> void:
	if toast_label == null:
		return
	toast_label.text = msg
	toast_label.reset_size()
	toast_label.position = Vector2((1280.0 - toast_label.size.x) * 0.5, 526.0)
	toast_t = 2.6
	toast_label.modulate.a = 1.0
	if msg.ends_with("destroyed!") and feed != null:
		feed.push(msg, MilTheme.ENEMY if msg.begins_with("Enemy") else MilTheme.WARN)


func alert(msg: String, nuke: bool) -> void:
	var col := Color(1.0, 0.18, 0.12) if nuke else Color(1.0, 0.62, 0.15)
	alert_label.show_msg(msg.replace("!!", "").strip_edges().to_upper(), col)
	alert_t = 4.5 if nuke else 2.5
	if feed != null:
		feed.push(msg.replace("!!", "").strip_edges(), col)
	Sfx.play("alarm", -2.0, 0.5)


func flash(a: float) -> void:
	flash_rect.modulate.a = a


func show_game_over(won: bool) -> void:
	victory = won
	over_timer = 1.6


func _show_over_panel() -> void:
	var b: Battle = battle
	over_title.text = "VICTORY" if victory else "DEFEAT"
	over_title.add_theme_color_override("font_color", MilTheme.GOOD if victory else MilTheme.BAD)
	var t := int(b.elapsed)
	over_stats.text = ("ENEMY CAPITAL DESTROYED" if victory else "YOUR CAPITAL HAS FALLEN") + "\n\n" + \
		"TIME ............ %02d:%02d\nKILLS ........... %d\nINTERCEPTED ..... %d\nLAUNCHED ........ %d" % [
		t / 60, t % 60, b.kills[0], b.intercepted[0], b.launched[0]]
	over_panel.visible = true
	over_frame.visible = true
	get_tree().paused = true


# ---------------------------------------------------------------- menu logic

func _set_speed(s: float) -> void:
	Engine.time_scale = s
	var speeds := [1.0, 2.0, 3.0]
	for i in speed_buttons.size():
		speed_buttons[i].button_pressed = is_equal_approx(speeds[i], s)


func _open_menu() -> void:
	if battle.over:
		return
	menu_open = true
	pause_panel.visible = true
	pause_frame.visible = true
	get_tree().paused = true
	_refresh_slots()


func _close_menu() -> void:
	menu_open = false
	pause_panel.visible = false
	pause_frame.visible = false
	if not battle.over:
		get_tree().paused = false


func _refresh_slots() -> void:
	for i in range(1, 4):
		var slot := "slot%d" % i
		slot_buttons["save:" + slot].text = "Save  >  " + SaveManager.slot_summary(slot)
	for slot in SaveManager.SLOTS:
		var btn: Button = slot_buttons["load:" + slot]
		btn.text = "Load  >  " + SaveManager.slot_summary(slot)
		btn.disabled = not SaveManager.has_save(slot)


func _do_save(slot: String) -> void:
	battle.save_slot(slot)
	_refresh_slots()


func _do_load(slot: String) -> void:
	if battle.load_slot(slot):
		_close_menu()
	_refresh_slots()


func _restart() -> void:
	SaveManager.pending_load = ""
	SaveManager.pending_difficulty = battle.difficulty
	get_tree().paused = false
	get_tree().reload_current_scene()


func _to_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _tab_step(step: int) -> void:
	var ids: Array = []
	for t in GameData.tabs:
		ids.append(str(t.get("id", "")))
	var i := ids.find(current_tab)
	_show_tab(ids[(i + step + ids.size()) % ids.size()])


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not menu_open:
		var mb := event as InputEventMouseButton
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			if card_scroll.get_global_rect().has_point(mb.position):
				_scroll_cards(-160 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 160)
				get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_ESCAPE:
			if battle.over:
				return
			if menu_open:
				_close_menu()
			elif battle.sel_kind != "":
				battle.select("", "")
			elif not battle.selected.is_empty():
				battle.clear_selection()
			else:
				_open_menu()
		KEY_F5:
			if not battle.over:
				battle.save_slot("slot1")
		KEY_F9:
			if not battle.over and battle.load_slot("slot1"):
				_close_menu()
		KEY_F10:
			battle.reload_sprites()
		KEY_V:
			if not menu_open and not battle.over:
				battle.cycle_stance()
		KEY_P:
			if not menu_open and not battle.over:
				battle.set_autopilot(not battle.autopilot)
		KEY_HOME:
			battle.focus_camera(battle.base_pos(0) + Vector2(520, 0))
		KEY_END:
			battle.focus_camera(battle.base_pos(1) - Vector2(520, 0))
		KEY_Q:
			if not menu_open:
				_tab_step(-1)
		KEY_E:
			if not menu_open:
				_tab_step(1)
		_:
			if menu_open or battle.over:
				return
			var n: int = event.keycode - KEY_1
			if n >= 0 and n <= 8:
				var items := GameData.items_for_tab(current_tab, 0)
				if n < items.size():
					_select(items[n][0], items[n][1])
