class_name FeedLog
extends Control
## Short fading event log (buildings destroyed, launches...) shown under the top bar on the left.

const MAX_LINES := 5
const LIFE := 8.0

var _lines: Array = []   # [text, color, age]


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS


func push(msg: String, col: Color = Color(0.88, 0.9, 0.87)) -> void:
	_lines.append([msg, col, 0.0])
	while _lines.size() > MAX_LINES:
		_lines.remove_at(0)
	queue_redraw()


func _process(delta: float) -> void:
	if _lines.is_empty():
		return
	for l in _lines:
		l[2] = float(l[2]) + delta
	while not _lines.is_empty() and float(_lines[0][2]) > LIFE:
		_lines.remove_at(0)
	queue_redraw()


func _draw() -> void:
	var font := MilTheme.font_ui()
	var fs := 13
	var y := 0.0
	for l in _lines:
		var age: float = l[2]
		var a := clampf((LIFE - age) / 1.5, 0.0, 1.0)
		var txt: String = l[0]
		var col: Color = l[1]
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 20.0
		draw_rect(Rect2(0, y, w, 20), Color(0.03, 0.035, 0.037, 0.72 * a))
		draw_rect(Rect2(0, y, 3, 20), Color(col, a))
		draw_string(font, Vector2(11, y + 14.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, a))
		y += 23.0
