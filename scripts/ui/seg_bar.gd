class_name SegBar
extends Control
## Segmented integrity bar used for the two capitals in the top bar.

var value := 0.0
var max_value := 1.0
var color := Color(0.36, 0.62, 0.88)
var from_right := false
var text := ""
var segments := 20


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_state(v: float, m: float, txt: String) -> void:
	if is_equal_approx(v, value) and is_equal_approx(m, max_value) and txt == text:
		return
	value = v
	max_value = m
	text = txt
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0, 0, 0, 0.66))
	var frac := clampf(value / maxf(max_value, 1.0), 0.0, 1.0)
	var inner := r.grow(-2.0)
	var fw := inner.size.x * frac
	var fx := inner.position.x + (inner.size.x - fw if from_right else 0.0)
	var fr := Rect2(fx, inner.position.y, fw, inner.size.y)
	var col := color if frac > 0.3 else MilTheme.BAD
	draw_rect(fr, Color(col, 0.88))
	draw_rect(Rect2(fr.position, Vector2(fr.size.x, 2.0)), Color(1, 1, 1, 0.2))
	for i in range(1, segments):
		var x := inner.position.x + inner.size.x * float(i) / float(segments)
		draw_line(Vector2(x, inner.position.y), Vector2(x, inner.end.y), Color(0, 0, 0, 0.55), 1.0)
	draw_rect(r, MilTheme.LINE_HI, false, 1.0)
	var font := MilTheme.font_mono()
	var fs := 12
	var y := (size.y - font.get_height(fs)) * 0.5 + font.get_ascent(fs)
	draw_string(font, Vector2(1.0, y + 1.0), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(0.0, y), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, Color(1, 1, 1, 0.95))
