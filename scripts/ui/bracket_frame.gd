class_name BracketFrame
extends Control
## Four L-shaped corner brackets around its rect (selection / panel decoration). Never takes mouse input.

var color := Color(1.0, 0.62, 0.10)
var arm := 10.0
var width := 1.5


func _init(col: Color = Color(1.0, 0.62, 0.10), p_arm: float = 10.0, p_width: float = 1.5) -> void:
	color = col
	arm = p_arm
	width = p_width
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	MilTheme.draw_brackets(self, Rect2(Vector2.ZERO, size).grow(-1.0), color, arm, width)
