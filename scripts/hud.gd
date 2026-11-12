class_name HUD
extends CanvasLayer
## All UI is built in code: top bar, deploy cards, pause / save menu, alerts.

var battle

var root: Control
var money_label: Label
var income_label: Label
var time_label: Label
var cap_label: Label
var p_bar: ProgressBar
var e_bar: ProgressBar
var p_hp_label: Label
var e_hp_label: Label
var card_box: HBoxContainer
var card_scroll: ScrollContainer
var country_label: Label
var minimap: Minimap
var _styled_sel := "~"
var info_label: Label
var toast_label: Label
var alert_label: Label
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
	add_child(root)
	_build_top_bar()
	_build_bottom_panel()
	_build_overlays()
	if not GameData.tabs.is_empty():
		current_tab = str(GameData.tabs[0].get("id", "infantry"))


# ------------------------------------------------------------------ building

func _panel_style(col: Color, border: Color = Color(0, 0, 0, 0), bw: int = 0, radius: int = 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	return sb


func _label(text: String, pos: Vector2, size: Vector2, font_size: int = 14, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = size
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _outline(l: Label) -> void:
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)


func _make_button(text: String, pos: Vector2, size: Vector2, cb: Callable, font_size: int = 14) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	b.pressed.connect(cb)
	return b


func _build_top_bar() -> void:
	var bar := Panel.new()
	bar.position = Vector2.ZERO
	bar.size = Vector2(1280, 56)
	bar.add_theme_stylebox_override("panel", _panel_style(Color(0.07, 0.09, 0.07, 0.94), Color(0.25, 0.3, 0.22), 1, 0))
	root.add_child(bar)
	bar.add_child(_label("WORLD WAR 3", Vector2(14, 14), Vector2(190, 30), 22, Color(0.93, 0.78, 0.28)))
	money_label = _label("$ 0", Vector2(226, 4), Vector2(170, 30), 26, Color(0.5, 1.0, 0.55))
	bar.add_child(money_label)
	income_label = _label("+0 / s", Vector2(228, 34), Vector2(160, 18), 12, Color(0.7, 0.8, 0.7))
	bar.add_child(income_label)

	p_bar = ProgressBar.new()
	p_bar.position = Vector2(400, 12)
	p_bar.size = Vector2(240, 30)
	p_bar.custom_minimum_size = Vector2(240, 30)
	p_bar.show_percentage = false
	p_bar.add_theme_stylebox_override("background", _panel_style(Color(0, 0, 0, 0.6), Color(0.2, 0.3, 0.4), 1, 3))
	p_bar.add_theme_stylebox_override("fill", _panel_style(SpriteLib.team_color(0), Color(0, 0, 0, 0), 0, 3))
	bar.add_child(p_bar)
	p_hp_label = _label("YOUR CAPITAL", Vector2(400, 17), Vector2(240, 22), 12, Color.WHITE)
	p_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_outline(p_hp_label)
	bar.add_child(p_hp_label)
	e_bar = ProgressBar.new()
	e_bar.position = Vector2(650, 12)
	e_bar.size = Vector2(240, 30)
	e_bar.custom_minimum_size = Vector2(240, 30)
	e_bar.show_percentage = false
	e_bar.fill_mode = ProgressBar.FILL_END_TO_BEGIN
	e_bar.add_theme_stylebox_override("background", _panel_style(Color(0, 0, 0, 0.6), Color(0.4, 0.2, 0.2), 1, 3))
	e_bar.add_theme_stylebox_override("fill", _panel_style(SpriteLib.team_color(1), Color(0, 0, 0, 0), 0, 3))
	bar.add_child(e_bar)
	e_hp_label = _label("ENEMY CAPITAL", Vector2(650, 17), Vector2(240, 22), 12, Color.WHITE)
	e_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_outline(e_hp_label)
	bar.add_child(e_hp_label)

	country_label = _label("", Vector2(898, 6), Vector2(90, 44), 12, Color(0.8, 0.88, 0.8))
	bar.add_child(country_label)
	time_label = _label("00:00", Vector2(992, 4), Vector2(80, 26), 20)
	bar.add_child(time_label)
	cap_label = _label("Units 0/90", Vector2(992, 32), Vector2(90, 18), 12, Color(0.75, 0.8, 0.75))
	bar.add_child(cap_label)

	bar.add_child(_make_button("Menu", Vector2(1084, 10), Vector2(56, 36), _open_menu, 13))
	var speeds := [1.0, 2.0, 3.0]
	for i in speeds.size():
		var s: float = speeds[i]
		var b := _make_button("%dx" % int(s), Vector2(1146 + i * 42, 10), Vector2(38, 36), func(): _set_speed(s), 13)
		b.toggle_mode = true
		bar.add_child(b)
		speed_buttons.append(b)
	speed_buttons[0].button_pressed = true


func _build_bottom_panel() -> void:
	var panel := Panel.new()
	panel.position = Vector2(0, 568)
	panel.size = Vector2(1280, 152)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.07, 0.09, 0.07, 0.96), Color(0.25, 0.3, 0.22), 1, 0))
	root.add_child(panel)
	var x := 12.0
	for t in GameData.tabs:
		var tid := str(t.get("id", ""))
		var b := _make_button(str(t.get("name", tid)), Vector2(x, 6), Vector2(104, 28), func(): _show_tab(tid), 12)
		b.toggle_mode = true
		panel.add_child(b)
		tab_buttons[tid] = b
		x += 108.0
	panel.add_child(_make_button("<", Vector2(x + 6.0, 6), Vector2(30, 28), func(): _scroll_cards(-320), 14))
	panel.add_child(_make_button(">", Vector2(x + 40.0, 6), Vector2(30, 28), func(): _scroll_cards(320), 14))
	panel.add_child(_label("WASD: camera  Wheel: zoom  Home/End: capitals  Q/E: tabs  1-9: select",
		Vector2(x + 80.0, 10), Vector2(maxf(1270.0 - x - 80.0, 200.0), 20), 11, Color(0.6, 0.68, 0.6)))
	card_scroll = ScrollContainer.new()
	card_scroll.position = Vector2(12, 40)
	card_scroll.size = Vector2(944, 106)
	card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(card_scroll)
	card_box = HBoxContainer.new()
	card_box.add_theme_constant_override("separation", 6)
	card_scroll.add_child(card_box)
	var info_bg := Panel.new()
	info_bg.position = Vector2(966, 40)
	info_bg.size = Vector2(304, 106)
	info_bg.add_theme_stylebox_override("panel", _panel_style(Color(0.03, 0.04, 0.03, 0.8), Color(0.25, 0.3, 0.22), 1, 4))
	panel.add_child(info_bg)
	info_label = _label("", Vector2(8, 4), Vector2(290, 98), 12, Color(0.85, 0.9, 0.85))
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_bg.add_child(info_label)
	# Overview map (click / drag to move the camera).
	minimap = Minimap.new()
	minimap.battle = battle
	minimap.position = Vector2(970, 568 - 128)
	minimap.size = Vector2(300, 120)
	root.add_child(minimap)


func _scroll_cards(amount: int) -> void:
	card_scroll.scroll_horizontal = maxi(0, card_scroll.scroll_horizontal + amount)


func _build_overlays() -> void:
	toast_label = _label("", Vector2(240, 520), Vector2(800, 30), 18, Color(1, 1, 0.8))
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_color_override("font_outline_color", Color.BLACK)
	toast_label.add_theme_constant_override("outline_size", 6)
	toast_label.modulate.a = 0.0
	root.add_child(toast_label)

	alert_label = _label("", Vector2(140, 74), Vector2(1000, 44), 32, Color(1, 0.25, 0.2))
	alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alert_label.add_theme_color_override("font_outline_color", Color.BLACK)
	alert_label.add_theme_constant_override("outline_size", 8)
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
	var psb := _panel_style(Color(0.06, 0.08, 0.06, 0.97), Color(0.9, 0.75, 0.3), 2, 10)
	psb.set_content_margin_all(14)
	pause_panel.add_theme_stylebox_override("panel", psb)
	pause_panel.position = Vector2(400, 70)
	pause_panel.size = Vector2(480, 440)
	pause_panel.visible = false
	root.add_child(pause_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	pause_panel.add_child(vb)
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.93, 0.78, 0.28))
	vb.add_child(title)
	vb.add_child(_vbtn("Resume", _close_menu))
	var sep := Label.new()
	sep.text = "SAVE GAME"
	sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sep)
	for i in range(1, 4):
		var slot := "slot%d" % i
		var b := _vbtn("", func(): _do_save(slot))
		vb.add_child(b)
		slot_buttons["save:" + slot] = b
	var sep2 := Label.new()
	sep2.text = "LOAD GAME"
	sep2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sep2)
	for slot in SaveManager.SLOTS:
		var s: String = slot
		var b2 := _vbtn("", func(): _do_load(s))
		vb.add_child(b2)
		slot_buttons["load:" + s] = b2
	vb.add_child(_vbtn("Reload sprites (F10)", func(): battle.reload_sprites()))
	vb.add_child(_vbtn("Quit to main menu", _to_menu))

	# Game over
	over_panel = PanelContainer.new()
	var osb := _panel_style(Color(0.05, 0.06, 0.05, 0.96), Color(0.9, 0.75, 0.3), 2, 10)
	osb.set_content_margin_all(18)
	over_panel.add_theme_stylebox_override("panel", osb)
	over_panel.position = Vector2(430, 180)
	over_panel.size = Vector2(420, 300)
	over_panel.visible = false
	root.add_child(over_panel)
	var ovb := VBoxContainer.new()
	ovb.add_theme_constant_override("separation", 12)
	over_panel.add_child(ovb)
	over_title = Label.new()
	over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	over_title.add_theme_font_size_override("font_size", 44)
	ovb.add_child(over_title)
	over_stats = Label.new()
	over_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ovb.add_child(over_stats)
	ovb.add_child(_vbtn("Play again", _restart))
	ovb.add_child(_vbtn("Main menu", _to_menu))


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
	var icon := TextureRect.new()
	icon.texture = SpriteLib.get_texture(str(d.get("sprite", id)), str(d.get("shape", "box")))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(35, 5)
	icon.size = Vector2(80, 54)
	icon.modulate = SpriteLib.team_tint(0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)
	var lab := Label.new()
	var base_text := "%s\n$%d" % [str(d.get("name", id)), int(d.get("cost", 0))]
	if hotkey <= 9:
		base_text = "%d. %s" % [hotkey, base_text]
	lab.text = base_text
	lab.position = Vector2(0, 62)
	lab.size = Vector2(150, 40)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 13)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(lab)
	var ov := ColorRect.new()
	ov.color = Color(0, 0, 0, 0.62)
	ov.position = Vector2.ZERO
	ov.size = Vector2(150, 104)
	ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.visible = false
	b.add_child(ov)
	cards[kind + ":" + id] = {"button": b, "overlay": ov, "label": lab, "def": d, "kind": kind, "id": id, "text": base_text}
	return b


func _select(kind: String, id: String) -> void:
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
		var border := Color(0.95, 0.8, 0.3) if selected else Color(0.28, 0.34, 0.26)
		var bg := Color(0.2, 0.26, 0.16) if selected else Color(0.11, 0.14, 0.1)
		b.add_theme_stylebox_override("normal", _panel_style(bg, border, 3 if selected else 1, 5))
		b.add_theme_stylebox_override("hover", _panel_style(bg.lightened(0.12), border, 2, 5))
		b.add_theme_stylebox_override("pressed", _panel_style(bg.lightened(0.2), border, 3, 5))


func _info_text(kind: String, id: String) -> String:
	var d := GameData.def_for(0, kind, id)
	if d.is_empty():
		return ""
	var lines: Array[String] = [str(d.get("name", id)) + "   $" + str(int(d.get("cost", 0)))]
	lines.append(str(d.get("desc", "")))
	if kind == "strategic":
		lines.append("Damage %d  |  Blast radius %d  |  Cooldown %ds  |  Interceptor hits to kill: %d" % [
			int(d.get("damage", 0)), int(d.get("splash", 0)), int(d.get("cooldown", 0)),
			int(ceil(float(d.get("hp", 1)) / 130.0))])
	else:
		var dps := float(d.get("damage", 0)) / maxf(float(d.get("cooldown", 1.0)), 0.05)
		lines.append("HP %d  Armor %d  DPS %d  Range %d  Speed %d" % [
			int(d.get("hp", 0)), int(d.get("armor", 0)), int(dps), int(d.get("range", 0)), int(d.get("speed", 0))])
		var tg: Array = d.get("targets", [])
		if not tg.is_empty():
			lines.append("Hits: " + ", ".join(PackedStringArray(tg)))
		if d.has("income"):
			lines.append("Income +%s / s" % str(d.get("income")))
		var prov: Array = d.get("provides", [])
		if not prov.is_empty():
			var names: Array[String] = []
			for p in prov:
				names.append(GameData.cap_name(str(p)))
			lines.append("Provides: " + ", ".join(PackedStringArray(names)))
		if d.has("limit"):
			lines.append("Max %d per country" % int(d.get("limit")))
	var vs: Dictionary = d.get("vs", {})
	if not vs.is_empty():
		var parts: Array[String] = []
		for k in vs:
			parts.append("%s x%s" % [str(k), str(vs[k])])
		lines.append("Damage: " + ", ".join(PackedStringArray(parts)))
	if d.get("stealth", 0.0) != 0.0:
		lines.append("Stealth: seen only at close range")
	var req := GameData.requirements(d)
	if not req.is_empty():
		var rn: Array[String] = []
		for r in req:
			rn.append(GameData.cap_name(str(r)))
		lines.append("Requires: " + ", ".join(PackedStringArray(rn)))
	return "\n".join(lines)


# ------------------------------------------------------------------- updates

func _process(delta: float) -> void:
	if battle == null:
		return
	var b: Battle = battle
	money_label.text = "$ %d" % int(b.money[0])
	income_label.text = "+%.1f / s" % b.income_rate(0)
	country_label.text = "Your land %d/%d\nEnemy land %d/%d" % [b.nat_alive(0), int(b.nat_start[0]), b.nat_alive(1), int(b.nat_start[1])]
	var t := int(b.elapsed)
	time_label.text = "%02d:%02d" % [t / 60, t % 60]
	cap_label.text = "Units %d/%d" % [b.unit_count(0, false), int(GameData.settings.get("unit_cap", 90))]
	_update_hq(0, p_bar, p_hp_label, "YOUR CAPITAL")
	_update_hq(1, e_bar, e_hp_label, "ENEMY CAPITAL")
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
		var lab: Label = c["label"]
		var missing: String = b.missing_requirement(0, c["def"])
		if missing != "":
			lab.text = "%s\nNeeds %s" % [str(c["def"].get("name", "")), GameData.cap_name(missing)]
			lab.modulate = Color(1.0, 0.7, 0.3)
			ov.visible = true
			ov.size.y = 104.0
		else:
			lab.text = c["text"]
			lab.modulate = Color.WHITE if b.money[0] >= float(c["def"].get("cost", 0)) else Color(1.0, 0.45, 0.4)
	info_label.text = _info_text(b.sel_kind, b.sel_id) if b.sel_kind != "" else "Select something below, then click the battlefield. Destroy the enemy capital - and cripple their cities, factories and airbases to weaken them."
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


func _update_hq(team: int, bar: ProgressBar, label: Label, prefix: String) -> void:
	var hq = battle.bases[team]  # untyped: the HQ may already be freed
	if hq != null and is_instance_valid(hq):
		bar.max_value = hq.max_hp
		bar.value = maxf(hq.hp, 0.0)
		label.text = "%s  %d / %d" % [prefix, int(maxf(hq.hp, 0.0)), int(hq.max_hp)]
	else:
		bar.value = 0.0
		label.text = prefix + "  DESTROYED"


# ----------------------------------------------------------------- feedback

func toast(msg: String) -> void:
	if toast_label == null:
		return
	toast_label.text = msg
	toast_t = 2.6
	toast_label.modulate.a = 1.0


func alert(msg: String, nuke: bool) -> void:
	alert_label.text = msg
	alert_label.add_theme_color_override("font_color", Color(1, 0.15, 0.1) if nuke else Color(1, 0.65, 0.2))
	alert_t = 4.5 if nuke else 2.5
	Sfx.play("alarm", -2.0, 0.5)


func flash(a: float) -> void:
	flash_rect.modulate.a = a


func show_game_over(won: bool) -> void:
	victory = won
	over_timer = 1.6


func _show_over_panel() -> void:
	var b: Battle = battle
	over_title.text = "VICTORY" if victory else "DEFEAT"
	over_title.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5) if victory else Color(1.0, 0.35, 0.3))
	var t := int(b.elapsed)
	over_stats.text = "Time %02d:%02d\nEnemy units destroyed: %d\nMissiles intercepted: %d\nMissiles launched: %d" % [
		t / 60, t % 60, b.kills[0], b.intercepted[0], b.launched[0]]
	over_panel.visible = true
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
	get_tree().paused = true
	_refresh_slots()


func _close_menu() -> void:
	menu_open = false
	pause_panel.visible = false
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
