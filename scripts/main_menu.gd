extends Control
## Main menu - built entirely in code.

var _slot_box: VBoxContainer
var _status: Label
var _rng := RandomNumberGenerator.new()
var _decor: Array = []


func _ready() -> void:
	Sfx.play_music("music_menu")
	Sfx.stop_ambient()
	Engine.time_scale = 1.0
	get_tree().paused = false
	_rng.seed = 39
	for i in 26:
		_decor.append([Vector2(_rng.randf_range(0, 1280), _rng.randf_range(0, 720)), _rng.randf_range(0.2, 1.0)])
	_build()


func _build() -> void:
	var title := Label.new()
	title.text = "WORLD WAR 3"
	title.position = Vector2(0, 50)
	title.size = Vector2(1280, 90)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 78)
	title.add_theme_color_override("font_color", Color(0.93, 0.78, 0.28))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 12)
	add_child(title)
	var sub := Label.new()
	sub.text = "Run a whole country. Deploy armies. Launch missiles. Intercept the apocalypse."
	sub.position = Vector2(0, 140)
	sub.size = Vector2(1280, 30)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", Color(0.75, 0.82, 0.72))
	add_child(sub)

	var left := VBoxContainer.new()
	left.position = Vector2(300, 220)
	left.size = Vector2(300, 400)
	left.add_theme_constant_override("separation", 10)
	add_child(left)
	left.add_child(_heading("NEW GAME"))
	for diff in ["easy", "normal", "hard"]:
		var d: String = diff
		left.add_child(_btn("Start - " + d.capitalize(), func(): _new_game(d)))
	left.add_child(_heading("OTHER"))
	left.add_child(_btn("Open sprites folder", _open_sprites))
	left.add_child(_btn("Quit", func(): get_tree().quit()))

	var right := VBoxContainer.new()
	right.position = Vector2(680, 220)
	right.size = Vector2(320, 400)
	right.add_theme_constant_override("separation", 10)
	add_child(right)
	right.add_child(_heading("LOAD GAME"))
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

	_status = Label.new()
	_status.position = Vector2(0, 640)
	_status.size = Vector2(1280, 60)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 13)
	_status.add_theme_color_override("font_color", Color(0.7, 0.78, 0.68))
	_status.text = "Replace sprites by dropping PNGs into the sprites folder - see README.md.   Click to deploy, right-click to cancel.   WASD: move camera, wheel: zoom."
	add_child(_status)


func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", Color(0.93, 0.78, 0.28))
	return l


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


func _new_game(diff: String) -> void:
	SaveManager.pending_load = ""
	SaveManager.pending_difficulty = diff
	get_tree().change_scene_to_file("res://scenes/prematch.tscn")


func _load(slot: String) -> void:
	SaveManager.pending_load = slot
	get_tree().change_scene_to_file("res://scenes/battle.tscn")


func _open_sprites() -> void:
	DirAccess.make_dir_recursive_absolute(SpriteLib.USER_DIR)
	var path := ProjectSettings.globalize_path(SpriteLib.USER_DIR)
	OS.shell_open(path)
	_status.text = "Sprites folder: " + path


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.09, 0.12, 0.08))
	for d in _decor:
		draw_circle(d[0], 60.0 * d[1], Color(0.14, 0.19, 0.11, 0.6))
	draw_rect(Rect2(0, 0, 1280, 6), Color(0.93, 0.78, 0.28, 0.8))
	draw_rect(Rect2(0, 714, 1280, 6), Color(0.93, 0.78, 0.28, 0.8))
