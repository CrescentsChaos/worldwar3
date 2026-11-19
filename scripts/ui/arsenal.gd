class_name Arsenal
extends Control
## Full-screen browser of one army's roster (prematch screen). Pick a category on the left,
## an item in the list, and its datasheet appears on the right. Esc or Close returns.

signal closed

const GOLD := Color(1.0, 0.62, 0.10)
const TAB_IDS := ["infantry", "vehicles", "air", "navy", "defenses", "strategic"]

var _fid := ""
var _tab := "infantry"
var _title: Label
var _blurb: Label
var _list: ItemList
var _sheet: UnitSheet
var _note: Label
var _tab_btns: Dictionary = {}
var _entries: Array = []
var _group := ButtonGroup.new()


func _init() -> void:
	position = Vector2.ZERO
	size = Vector2(1280, 720)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.022, 0.026, 0.028, 0.99)
	dim.size = Vector2(1280, 720)
	add_child(dim)
	_title = _label("", Vector2(40, 16), Vector2(900, 40), 28, Color(0.93, 0.94, 0.9))
	_title.add_theme_font_override("font", MilTheme.font_bold())
	_blurb = _label("", Vector2(40, 56), Vector2(1000, 22), 13, MilTheme.DIM)
	var close := Button.new()
	close.text = "CLOSE  (ESC)"
	close.position = Vector2(1110, 22)
	close.size = Vector2(130, 40)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(close_arsenal)
	add_child(close)
	var x := 40.0
	for t in GameData.tabs:
		var tid := str(t.get("id", ""))
		if not TAB_IDS.has(tid):
			continue
		var b := Button.new()
		b.text = str(t.get("name", tid)).to_upper()
		b.toggle_mode = true
		b.button_group = _group
		b.position = Vector2(x, 88)
		b.size = Vector2(150, 34)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_show_tab.bind(tid))
		add_child(b)
		_tab_btns[tid] = b
		x += 154.0
	_list = ItemList.new()
	_list.position = Vector2(40, 134)
	_list.size = Vector2(400, 520)
	_list.fixed_icon_size = Vector2i(52, 34)
	_list.add_theme_font_size_override("font_size", 14)
	_list.item_selected.connect(_on_item)
	add_child(_list)
	_sheet = UnitSheet.new()
	_sheet.position = Vector2(470, 134)
	_sheet.custom_minimum_size = Vector2(560, 0)
	add_child(_sheet)
	_note = _label("", Vector2(40, 660), Vector2(1200, 44), 12, Color(0.75, 0.6, 0.45))
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _label(text: String, pos: Vector2, sz: Vector2, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = sz
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	add_child(l)
	return l


func open(fid: String) -> void:
	if not GameData.factions.has(fid):
		return
	_fid = fid
	var f: Dictionary = GameData.factions[fid]
	_title.text = "%s - ARSENAL" % str(f.get("name", fid)).to_upper()
	_blurb.text = "%s   |   Each entry is a distinct unit with its own stats, not a renamed generic." % str(f.get("era", ""))
	var ban: Array = f.get("ban", [])
	var bn: PackedStringArray = []
	for b in ban:
		var bd := _def_any(str(b))
		bn.append(str(bd.get("name", b)))
	_note.text = ("Not fielded by this army: " + ", ".join(bn)) if not bn.is_empty() else ""
	visible = true
	_show_tab(_tab)


func close_arsenal() -> void:
	visible = false
	closed.emit()


func _def_any(id: String) -> Dictionary:
	for kind in ["unit", "structure", "strategic"]:
		var d: Dictionary = GameData.get_def(kind, id)
		if not d.is_empty():
			return d
	return {}


func _show_tab(tid: String) -> void:
	_tab = tid
	var btn: Button = _tab_btns.get(tid)
	if btn != null:
		btn.set_pressed_no_signal(true)
	_list.clear()
	_entries.clear()
	var f: Dictionary = GameData.factions[_fid]
	var ban: Array = f.get("ban", [])
	for pair in GameData.items_for_tab(tid):
		var kind: String = pair[0]
		var id: String = pair[1]
		if kind == "national" or ban.has(id):
			continue
		var d := GameData.def_for_faction(_fid, kind, id)
		var icon := SpriteLib.get_texture(str(d.get("sprite", id)), str(d.get("shape", "box")))
		_list.add_item("%s     $%d" % [str(d.get("name", id)), int(float(d.get("cost", 0)))], icon)
		_entries.append([kind, id])
	if not _entries.is_empty():
		_list.select(0)
		_on_item(0)


func _on_item(i: int) -> void:
	if i < 0 or i >= _entries.size():
		return
	var e: Array = _entries[i]
	_sheet.visible = true
	_sheet.set_def(GameData.def_for_faction(_fid, str(e[0]), str(e[1])), str(e[0]))


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close_arsenal()
		get_viewport().set_input_as_handled()
