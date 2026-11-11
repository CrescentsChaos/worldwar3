class_name Explosion
extends Node2D
## Purely visual blast. Damage is applied by Battle.explode().

var radius := 40.0
var duration := 0.5
var age := 0.0
var nuke := false


func _ready() -> void:
	z_index = 50


func _process(delta: float) -> void:
	age += delta
	if age >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := clampf(age / duration, 0.0, 1.0)
	var r := radius * (1.0 - pow(1.0 - t, 3.0))
	var a := 1.0 - t
	if nuke:
		draw_circle(Vector2.ZERO, r, Color(1.0, 0.45, 0.1, 0.45 * a))
		draw_circle(Vector2.ZERO, r * 0.72, Color(1.0, 0.7, 0.25, 0.6 * a))
		draw_circle(Vector2.ZERO, r * 0.4, Color(1.0, 0.97, 0.8, 0.9 * a))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 72, Color(1, 1, 1, 0.8 * a), 5.0)
		draw_arc(Vector2.ZERO, r * 0.82, 0.0, TAU, 64, Color(1, 0.8, 0.4, 0.5 * a), 3.0)
		draw_circle(Vector2(0, -radius * 0.25 * t), radius * 0.22 * (0.6 + t), Color(0.3, 0.18, 0.1, 0.55 * a))
	else:
		draw_circle(Vector2.ZERO, r, Color(1.0, 0.55 + 0.25 * t, 0.12, 0.55 * a))
		draw_circle(Vector2.ZERO, r * 0.6, Color(1.0, 0.92, 0.55, 0.75 * a))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(1, 1, 1, 0.5 * a), 2.0)
