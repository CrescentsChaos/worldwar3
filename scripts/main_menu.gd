extends Control
## Main menu - built entirely in code. Dark "command room": contour map, tactical grid, radar sweep.

var _slot_box: VBoxContainer
var _status: Label
var _rng := RandomNumberGenerator.new()
var _t := 0.0


func _ready() -> void:
	theme = MilTheme.theme()
	Sfx.play_music("music_menu")
	Sfx.stop_ambient()
	Engine.time_scale = 1.0
	get_tree().paused = false
	_rng.seed = 1939
	_build()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _build() -> void:
	add_child(MilTheme.caption("Global conflict simulation  //  theatre command", Vector2(72, 168), Vector2(700, 20), MilTheme.AMBER, 14))

	var left := VBoxContainer.new()
	left.position = Vector2(72, 232)
	left.size = Vector2(380, 440)
	left.add_theme_constant_override("separation", 8)
	add_child(left)
	left.add_child(_heading("New campaign"))
	var names := {"easy": "RECRUIT", "normal": "VETERAN", "hard": "ELITE"}
	for diff in ["easy", "normal", "hard"]:
		var d: String = diff
		left.add_child(_btn("%s   -   %s" % [d.to_upper(), str(names[d])], func(): _new_game(d)))
	left.add_child(_heading("Command"))
	left.add_child(_btn("OPEN SPRITES FOLDER", _open_sprites))
	left.add_child(_btn("ASSET MANAGER  (replace anything)", _open_assets))
	left.add_child(_btn("ASSET GUIDE  (how to replace things)", _open_guide))
	left.add_child(_btn("QUIT TO DESKTOP", func(): get_tree().quit()))

	var right := VBoxContainer.new()
	right.position = Vector2(500, 232)
	right.size = Vector2(300, 300)
	right.add_theme_constant_override("separation", 8)
	add_child(right)
	right.add_child(_heading("Resume operation"))
	_slot_box = VBoxContainer.new()
	_slot_box.add_theme_constant_override("separation", 8)
	right.add_child(_slot_box)
	for slot in SaveManager.SLOTS:
		var s: String = slot
		var b := _btn(SaveManager.slot_summary(s), func(): _load(s))
		b.disabled = not SaveManager.has_save(s)
		b.custom_minimum_size = Vector2(0, 40)
		b.add_theme_font_size_override("font_size", 12)
		_slot_box.add_child(b)

	_status = MilTheme.caption("Click to deploy  /  right-click cancel  /  WASD camera  /  wheel zoom  /  drop PNGs in the sprites folder to re-skin units",
		Vector2(72, 676), Vector2(1136, 18), Color(0.4, 0.44, 0.42), 11)
	add_child(_status)


func _heading(text: String) -> Label:
	var l := MilTheme.caption(text, Vector2.ZERO, Vector2.ZERO, MilTheme.AMBER_DIM, 12)
	l.custom_minimum_size = Vector2(0, 26)
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return l


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	b.focus_mode = Control.FOCUS_NONE
	MilTheme.style_menu(b)
	b.pressed.connect(cb)
	return b


func _new_game(diff: String) -> void:
	SaveManager.pending_load = ""
	SaveManager.pending_difficulty = diff
	get_tree().change_scene_to_file("res://scenes/prematch.tscn")


func _load(slot: String) -> void:
	SaveManager.pending_load = slot
	get_tree().change_scene_to_file("res://scenes/battle.tscn")


func _open_assets() -> void:
	add_child(AssetManager.new())


func _open_guide() -> void:
	add_child(AssetGuide.new())


func _open_sprites() -> void:
	DirAccess.make_dir_recursive_absolute(SpriteLib.USER_DIR)
	var path := ProjectSettings.globalize_path(SpriteLib.USER_DIR)
	OS.shell_open(path)
	_status.text = ("SPRITES FOLDER: " + path).to_upper()


# ------------------------------------------------------------------ backdrop

func _hex(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 7:
		pts.append(c + Vector2.from_angle(float(i) * TAU / 6.0 + PI / 6.0) * r)
	draw_polyline(pts, col, 1.0)


func _draw() -> void:
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(1280, 0), Vector2(1280, 720), Vector2(0, 720)]),
		PackedColorArray([Color(0.085, 0.095, 0.088), Color(0.060, 0.068, 0.062), Color(0.020, 0.024, 0.022), Color(0.034, 0.040, 0.036)]))
	var menu_bg: Texture2D = SpriteLib.get_optional("ui_menu_bg")
	if menu_bg != null:
		draw_texture_rect(menu_bg, Rect2(0, 0, 1280, 720), false, Color(1, 1, 1, 0.9))
	else:
		# procedural backdrop: hex grid + slow light sweep + big accent slash
		var hr := 46.0
		var dx := hr * 1.7320508
		for row in 11:
			for col in 18:
				var c := Vector2(float(col) * dx + (dx * 0.5 if row % 2 == 1 else 0.0), float(row) * hr * 1.5)
				var fall := clampf(1.0 - c.x / 1500.0, 0.0, 1.0)
				_hex(c, hr - 2.0, Color(0.72, 0.78, 0.62, 0.025 + 0.05 * fall))
		var sweep := fmod(_t * 90.0, 2600.0) - 600.0
		draw_polygon(PackedVector2Array([Vector2(sweep, 0), Vector2(sweep + 120.0, 0), Vector2(sweep - 160.0, 720), Vector2(sweep - 280.0, 720)]),
			PackedColorArray([Color(1, 0.85, 0.6, 0.0), Color(1, 0.85, 0.6, 0.05), Color(1, 0.85, 0.6, 0.0), Color(1, 0.85, 0.6, 0.0)]))
		draw_polygon(PackedVector2Array([Vector2(760, 720), Vector2(1020, 0), Vector2(1280, 0), Vector2(1280, 720)]),
			PackedColorArray([Color(0, 0, 0, 0), Color(MilTheme.AMBER, 0.10), Color(MilTheme.AMBER, 0.02), Color(0, 0, 0, 0.0)]))
		draw_line(Vector2(760, 720), Vector2(1020, 0), Color(MilTheme.AMBER, 0.55), 2.0)
	# left shading so the menu text stays readable
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(620, 0), Vector2(620, 720), Vector2(0, 720)]),
		PackedColorArray([Color(0, 0, 0, 0.70), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.70)]))
	# top / bottom rails
	draw_rect(Rect2(0, 0, 1280, 3), Color(MilTheme.AMBER, 0.85))
	draw_rect(Rect2(0, 717, 1280, 3), Color(MilTheme.AMBER, 0.35))
	var logo: Texture2D = SpriteLib.get_optional("ui_logo")
	if logo != null:
		var ls := logo.get_size()
		var k := minf(560.0 / ls.x, 120.0 / ls.y)
		draw_texture_rect(logo, Rect2(Vector2(72, 66), ls * k), false)
	else:
		var tf := MilTheme.font_bold()
		draw_rect(Rect2(72, 70, 6, 96), MilTheme.AMBER)
		_spaced(tf, "WORLD WAR 3", Vector2(94, 144), 88, 8.0, Color(0, 0, 0, 0.7), Vector2(3, 3))
		_spaced(tf, "WORLD WAR 3", Vector2(94, 144), 88, 8.0, Color(0.93, 0.94, 0.9), Vector2.ZERO)
	_hazard_rule(Rect2(72, 196, 380, 5))
	MilTheme.draw_brackets(self, Rect2(16, 16, 1248, 688), Color(MilTheme.LINE_HI, 0.55), 26.0, 2.0)


## Hazard stripe rule drawn without clip_contents: every stripe is clipped to the rect by hand.
func _hazard_rule(r: Rect2) -> void:
	draw_rect(r, Color(0.02, 0.02, 0.02, 0.9))
	var stripe := 8.0
	var x := r.position.x
	while x < r.end.x:
		var x2 := minf(x + stripe, r.end.x)
		draw_rect(Rect2(x, r.position.y, x2 - x, r.size.y), MilTheme.AMBER)
		x += stripe * 2.0


## Draws text with extra letter spacing (Label cannot do this).
func _spaced(font: Font, text: String, pos: Vector2, fs: int, spacing: float, col: Color, shadow: Vector2) -> void:
	var x := pos.x + shadow.x
	for i in text.length():
		var ch := text.substr(i, 1)
		draw_string(font, Vector2(x, pos.y + shadow.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		x += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + spacing
