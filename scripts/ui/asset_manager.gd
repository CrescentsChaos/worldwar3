class_name AssetManager
extends Control
## Asset Manager (v6): every sprite, sound, radio line, effect, tile, interface image and font can be replaced here
## without touching the project. A replacement is copied into the user:// folder (so it survives updates) and is
## used immediately. "Reset" deletes the replacement. Drop-in files work too: use "Open folder".

signal closed

const PAGE := 12
var cat := "sprites"
var page := 0
var filter := ""
var rows_box: VBoxContainer
var page_label: Label
var status_label: Label
var cat_buttons: Dictionary = {}
var _entries: Array = []
var _pending_id := ""
var dialog: FileDialog
var preview: AudioStreamPlayer


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.position = Vector2(110, 40)
	panel.size = Vector2(1060, 640)
	panel.add_theme_stylebox_override("panel", MilTheme.box(Color(0.05, 0.07, 0.06, 0.98), MilTheme.AMBER, 2, 12, 10))
	add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)
	var title := Label.new()
	title.text = "ASSET MANAGER   -   replace anything in the game"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", MilTheme.AMBER)
	vb.add_child(title)
	var hint := Label.new()
	hint.text = "Pick a category, press REPLACE and choose a file. Images become PNG (sprites face RIGHT; buildings with a front have 'art_front' in units.json). Sounds: .ogg .mp3 .wav. Radio lines: radio_<event>_<n>. Changes apply instantly."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(1030, 0)
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", MilTheme.DIM)
	vb.add_child(hint)
	var tabs := HBoxContainer.new()
	vb.add_child(tabs)
	for c in AssetCatalog.CATS:
		var cid: String = c[0]
		var b := _btn(str(c[1]), func(): _set_cat(cid))
		cat_buttons[cid] = b
		tabs.add_child(b)
	var fr := HBoxContainer.new()
	vb.add_child(fr)
	var le := LineEdit.new()
	le.placeholder_text = "filter (id or name) ..."
	le.custom_minimum_size = Vector2(320, 0)
	le.text_changed.connect(func(t: String): filter = t.to_lower(); page = 0; _fill())
	fr.add_child(le)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.add_theme_color_override("font_color", MilTheme.GOOD)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fr.add_child(status_label)
	rows_box = VBoxContainer.new()
	rows_box.add_theme_constant_override("separation", 3)
	rows_box.custom_minimum_size = Vector2(1030, 440)
	vb.add_child(rows_box)
	var foot := HBoxContainer.new()
	vb.add_child(foot)
	foot.add_child(_btn("< PREV", func(): page = maxi(0, page - 1); _fill()))
	page_label = Label.new()
	page_label.custom_minimum_size = Vector2(140, 0)
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_child(page_label)
	foot.add_child(_btn("NEXT >", func(): page += 1; _fill()))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(sp)
	foot.add_child(_btn("OPEN FOLDER", func(): OS.shell_open(ProjectSettings.globalize_path(AssetCatalog.user_dir(cat)))))
	foot.add_child(_btn("EXPORT CHECKLIST (.csv)", func():
		var path := AssetCatalog.export_checklist()
		_say("Checklist written to " + path if path != "" else "Could not write the checklist")))
	foot.add_child(_btn("CLOSE", func(): closed.emit(); queue_free()))
	dialog = FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.use_native_dialog = true
	dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	dialog.file_selected.connect(_on_file)
	add_child(dialog)
	preview = AudioStreamPlayer.new()
	preview.bus = Sfx.bus_sfx
	add_child(preview)
	_set_cat("sprites")


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 11)
	b.add_theme_stylebox_override("normal", MilTheme.box(MilTheme.PANEL, MilTheme.LINE, 1, 6, 3))
	b.add_theme_stylebox_override("hover", MilTheme.box(MilTheme.PANEL_HI, MilTheme.AMBER_DIM, 1, 6, 3))
	b.add_theme_stylebox_override("pressed", MilTheme.box(MilTheme.AMBER, MilTheme.AMBER, 1, 6, 3))
	b.pressed.connect(cb)
	return b


func _say(t: String) -> void:
	status_label.text = t


func _set_cat(c: String) -> void:
	cat = c
	page = 0
	_entries = AssetCatalog.entries(c)
	for k in cat_buttons:
		var on: bool = k == c
		cat_buttons[k].add_theme_stylebox_override("normal", MilTheme.box(MilTheme.AMBER_DIM if on else MilTheme.PANEL, MilTheme.AMBER if on else MilTheme.LINE, 1, 6, 3))
	_fill()


func _filtered() -> Array:
	if filter == "":
		return _entries
	var out: Array = []
	for e in _entries:
		if str(e["id"]).to_lower().contains(filter) or str(e["label"]).to_lower().contains(filter):
			out.append(e)
	return out


func _fill() -> void:
	for ch in rows_box.get_children():
		ch.queue_free()
	var list := _filtered()
	var pages := maxi(1, int(ceil(float(list.size()) / float(PAGE))))
	page = clampi(page, 0, pages - 1)
	page_label.text = "page %d / %d   (%d items)" % [page + 1, pages, list.size()]
	for i in range(page * PAGE, mini(list.size(), (page + 1) * PAGE)):
		rows_box.add_child(_row(list[i]))


func _row(e: Dictionary) -> Control:
	var id: String = e["id"]
	var h := HBoxContainer.new()
	h.custom_minimum_size = Vector2(0, 34)
	h.add_theme_constant_override("separation", 8)
	if cat == "sprites" or cat == "ui" or cat == "tiles":
		var tr := TextureRect.new()
		tr.custom_minimum_size = Vector2(34, 34)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var tex: Texture2D = null
		if cat == "tiles":
			tex = TileLib.get_tile(id)
		else:
			tex = SpriteLib.get_optional(id)
		tr.texture = tex
		h.add_child(tr)
	else:
		var sp := Control.new()
		sp.custom_minimum_size = Vector2(34, 34)
		h.add_child(sp)
	var l1 := Label.new()
	l1.text = id
	l1.custom_minimum_size = Vector2(250, 0)
	l1.clip_text = true
	l1.add_theme_font_size_override("font_size", 12)
	h.add_child(l1)
	var l2 := Label.new()
	l2.text = str(e["label"])
	l2.custom_minimum_size = Vector2(440, 0)
	l2.clip_text = true
	l2.add_theme_font_size_override("font_size", 11)
	l2.add_theme_color_override("font_color", MilTheme.DIM)
	h.add_child(l2)
	var st := AssetCatalog.status(cat, id)
	var l3 := Label.new()
	l3.text = st
	l3.custom_minimum_size = Vector2(90, 0)
	l3.add_theme_font_size_override("font_size", 11)
	l3.add_theme_color_override("font_color", MilTheme.GOOD if st == "CUSTOM" else (MilTheme.WARN if st == "PLACEHOLDER" or st == "SILENT" else MilTheme.DIM))
	h.add_child(l3)
	if cat == "audio" or cat == "radio":
		h.add_child(_btn("PLAY", func(): _play(id, str(e["label"]))))
	h.add_child(_btn("REPLACE", func(): _ask(id)))
	var rb := _btn("RESET", func(): AssetCatalog.reset_file(cat, id); _changed("Reset " + id))
	rb.disabled = st != "CUSTOM"
	h.add_child(rb)
	return h


func _ask(id: String) -> void:
	_pending_id = id
	var filters := PackedStringArray()
	match cat:
		"audio", "radio":
			filters.append("*.ogg, *.mp3, *.wav ; Audio")
		"fonts":
			filters.append("*.ttf, *.otf ; Fonts")
		_:
			filters.append("*.png, *.jpg, *.jpeg, *.webp ; Images")
	dialog.filters = filters
	dialog.title = "Replace  " + id
	dialog.popup_centered_ratio(0.7)


func _on_file(path: String) -> void:
	var err := AssetCatalog.import_file(cat, _pending_id, path)
	if err != "":
		_say(err)
		return
	_changed("Replaced " + _pending_id)


func _changed(msg: String) -> void:
	AssetCatalog.refresh_caches()
	var b = get_tree().current_scene
	if b is Battle:
		(b as Battle).reload_sprites()
	_say(msg)
	_fill()


func _play(id: String, label: String) -> void:
	var st: AudioStream = Sfx.file_stream(id)
	if st == null and Sfx.streams.has(id):
		st = Sfx.streams[id]
	if st == null and cat == "radio":
		st = Radio._synth(label, "unit")
	if st == null:
		_say("No sound for " + id + " (silent until you replace it)")
		return
	preview.stream = st
	preview.play()
