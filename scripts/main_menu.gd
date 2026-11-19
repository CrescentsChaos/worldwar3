extends Control
## Main menu - built entirely in code. Dark "command room": contour map, tactical grid, radar sweep.

var _slot_box: VBoxContainer
var _status: Label
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _contours: Array = []     # [center, phases, ring count, ring step]
var _blips: Array = []        # [pos, angle, friendly]


func _ready() -> void:
	theme = MilTheme.theme()
	Sfx.play_music("music_menu")
	Sfx.stop_ambient()
	Engine.time_scale = 1.0
	get_tree().paused = false
	_rng.seed = 1939
	for i in 6:
		_contours.append([Vector2(_rng.randf_range(80, 1200), _rng.randf_range(60, 660)),
			Vector2(_rng.randf_range(0.0, TAU), _rng.randf_range(0.0, TAU)), _rng.randi_range(5, 9), _rng.randf_range(24.0, 38.0)])
	var radar_c := Vector2(930, 410)
	for i in 14:
		var ang := _rng.randf() * TAU
		var d := _rng.randf_range(40.0, 280.0)
		_blips.append([radar_c + Vector2.from_angle(ang) * d, ang, i % 3 != 0])
	_build()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _build() -> void:
	add_child(MilTheme.caption("Global conflict simulation  //  theatre command", Vector2(72, 168), Vector2(700, 20), MilTheme.AMBER, 14))

	var left := VBoxContainer.new()
	left.position = Vector2(72, 232)
	left.size = Vector2(380, 400)
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
	b.custom_minimum_size = Vector2(0, 46)
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


func _open_sprites() -> void:
	DirAccess.make_dir_recursive_absolute(SpriteLib.USER_DIR)
	var path := ProjectSettings.globalize_path(SpriteLib.USER_DIR)
	OS.shell_open(path)
	_status.text = ("SPRITES FOLDER: " + path).to_upper()


# ------------------------------------------------------------------ backdrop

func _draw() -> void:
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(1280, 0), Vector2(1280, 720), Vector2(0, 720)]),
		PackedColorArray([Color(0.055, 0.065, 0.068), Color(0.055, 0.065, 0.068), Color(0.018, 0.022, 0.024), Color(0.018, 0.022, 0.024)]))
	var menu_bg: Texture2D = SpriteLib.get_optional("ui_menu_bg")
	if menu_bg != null:
		draw_texture_rect(menu_bg, Rect2(0, 0, 1280, 720), false, Color(1, 1, 1, 0.55))
	# contour map
	for c in _contours:
		var ctr: Vector2 = c[0]
		var ph: Vector2 = c[1]
		var rings: int = c[2]
		var step: float = c[3]
		for k in range(1, rings + 1):
			var pts := PackedVector2Array()
			var base := step * float(k)
			for i in 97:
				var th := float(i) / 96.0 * TAU
				var wob := 1.0 + 0.16 * sin(3.0 * th + ph.x + float(k) * 0.21) + 0.09 * sin(5.0 * th + ph.y - float(k) * 0.13) + 0.04 * sin(9.0 * th + ph.x * 2.0)
				pts.append(ctr + Vector2.from_angle(th) * base * wob)
			draw_polyline(pts, Color(0.55, 0.62, 0.5, 0.05 + 0.012 * float(k % 3)), 1.0)
	# tactical grid
	for x in range(0, 1281, 80):
		draw_line(Vector2(x, 0), Vector2(x, 720), Color(0.7, 0.8, 0.7, 0.035), 1.0)
	for y in range(0, 721, 80):
		draw_line(Vector2(0, y), Vector2(1280, y), Color(0.7, 0.8, 0.7, 0.035), 1.0)
	for x in range(0, 1281, 160):
		for y in range(0, 721, 160):
			draw_line(Vector2(x - 5, y), Vector2(x + 5, y), Color(0.9, 0.95, 0.9, 0.16), 1.0)
			draw_line(Vector2(x, y - 5), Vector2(x, y + 5), Color(0.9, 0.95, 0.9, 0.16), 1.0)

	# radar
	var rc := Vector2(930, 410)
	for r in [80.0, 160.0, 240.0, 320.0]:
		draw_arc(rc, r, 0.0, TAU, 96, Color(0.55, 0.8, 0.55, 0.10), 1.0)
	draw_line(rc + Vector2(-330, 0), rc + Vector2(330, 0), Color(0.55, 0.8, 0.55, 0.08), 1.0)
	draw_line(rc + Vector2(0, -330), rc + Vector2(0, 330), Color(0.55, 0.8, 0.55, 0.08), 1.0)
	var sweep := fmod(_t * 0.9, TAU)
	for k in 36:
		var a0 := sweep - float(k) * 0.025
		var a1 := a0 - 0.025
		var al := 0.16 * (1.0 - float(k) / 36.0)
		draw_colored_polygon(PackedVector2Array([rc, rc + Vector2.from_angle(a0) * 330.0, rc + Vector2.from_angle(a1) * 330.0]),
			Color(0.45, 0.9, 0.5, al))
	draw_line(rc, rc + Vector2.from_angle(sweep) * 330.0, Color(0.6, 1.0, 0.6, 0.55), 1.5)
	for b in _blips:
		var bp: Vector2 = b[0]
		var ang: float = b[1]
		var since := fposmod(sweep - ang, TAU)
		var a := clampf(1.0 - since / 4.2, 0.0, 1.0)
		if a <= 0.02:
			continue
		var col := MilTheme.FRIEND if bool(b[2]) else MilTheme.ENEMY
		draw_rect(Rect2(bp - Vector2(3, 3), Vector2(6, 6)), Color(col, a), false, 1.5)
		draw_circle(bp, 1.5, Color(col, a))

	# left-edge shading so the menu text stays readable
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(560, 0), Vector2(560, 720), Vector2(0, 720)]),
		PackedColorArray([Color(0, 0, 0, 0.62), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.62)]))

	# amber side bar + title block
	draw_rect(Rect2(0, 0, 6, 720), MilTheme.AMBER)
	draw_rect(Rect2(72, 70, 4, 92), MilTheme.AMBER)
	var tf := MilTheme.font_bold()
	_spaced(tf, "WORLD WAR 3", Vector2(92, 142), 92, 12.0, Color(0, 0, 0, 0.7), Vector2(3, 3))
	_spaced(tf, "WORLD WAR 3", Vector2(92, 142), 92, 12.0, Color(0.93, 0.94, 0.9), Vector2.ZERO)
	_hazard_rule(Rect2(72, 196, 380, 6))
	draw_rect(Rect2(0, 0, 1280, 2), Color(MilTheme.AMBER, 0.5))
	draw_rect(Rect2(0, 718, 1280, 2), Color(MilTheme.AMBER, 0.5))
	MilTheme.draw_brackets(self, Rect2(14, 14, 1252, 692), Color(MilTheme.LINE_HI, 0.7), 22.0, 1.5)


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
