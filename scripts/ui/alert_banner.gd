class_name AlertBanner
extends Control
## Full-width hazard-striped warning band (incoming missiles / nukes). Fade it with `modulate.a`.

var text := ""
var tint := Color(1.0, 0.25, 0.15)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func show_msg(msg: String, col: Color) -> void:
	text = msg
	tint = col
	queue_redraw()


func _draw() -> void:
	var h := size.y
	draw_rect(Rect2(0, 0, size.x, h), Color(tint.r * 0.16, tint.g * 0.08, tint.b * 0.08, 0.86))
	MilTheme.draw_hazard(self, Rect2(0, 0, size.x, 7), tint, Color(0.02, 0.02, 0.02, 0.95), 10.0)
	MilTheme.draw_hazard(self, Rect2(0, h - 7, size.x, 7), tint, Color(0.02, 0.02, 0.02, 0.95), 10.0)
	var font := MilTheme.font_bold()
	var fs := 28
	var y := (h - font.get_height(fs)) * 0.5 + font.get_ascent(fs)
	draw_string_outline(font, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, 8, Color(0, 0, 0, 0.9))
	draw_string(font, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, tint.lightened(0.25))
