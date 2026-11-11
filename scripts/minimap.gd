class_name Minimap
extends Control
## Overview of the whole map. Click or drag to move the camera.

var battle
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = 0.1
		queue_redraw()


func _to_mini(p: Vector2) -> Vector2:
	return Vector2(p.x / float(Battle.W) * size.x,
		(p.y - Battle.FIELD_TOP) / (Battle.FIELD_BOTTOM - Battle.FIELD_TOP) * size.y)


func _to_world(p: Vector2) -> Vector2:
	return Vector2(p.x / size.x * float(Battle.W),
		p.y / size.y * (Battle.FIELD_BOTTOM - Battle.FIELD_TOP) + Battle.FIELD_TOP)


func _gui_input(event: InputEvent) -> void:
	var pos := Vector2.ZERO
	var ok := false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			pos = mb.position
			ok = true
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			pos = mm.position
			ok = true
	if ok and battle != null:
		battle.focus_camera(_to_world(pos))
		accept_event()


func _draw() -> void:
	if battle == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.06, 0.04, 0.82))
	var pz := float(GameData.settings.get("player_zone_x", 1000)) / float(Battle.W) * size.x
	var ez := float(GameData.settings.get("enemy_zone_x", 2200)) / float(Battle.W) * size.x
	draw_rect(Rect2(0, 0, pz, size.y), Color(0.3, 0.55, 1.0, 0.10))
	draw_rect(Rect2(ez, 0, size.x - ez, size.y), Color(1.0, 0.3, 0.25, 0.10))
	for n in get_tree().get_nodes_in_group("combatants"):
		var c := n as Combatant
		if c == null or c.dead:
			continue
		var p := _to_mini(c.position)
		var col := SpriteLib.team_color(c.team)
		match c.kind:
			"base":
				draw_rect(Rect2(p - Vector2(4, 4), Vector2(8, 8)), col)
			"national":
				draw_rect(Rect2(p - Vector2(2.5, 2.5), Vector2(5, 5)), col.lightened(0.15))
			"strategic":
				draw_circle(p, 2.5, Color(1, 1, 1))
			"structure":
				draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)), col.darkened(0.25))
			_:
				draw_circle(p, 1.2, col)
	var cam: Camera2D = battle.cam
	if cam != null:
		var half := get_viewport_rect().size * 0.5 / cam.zoom.x
		var tl := _to_mini(cam.position - half)
		var br := _to_mini(cam.position + half)
		draw_rect(Rect2(tl, br - tl), Color(1, 1, 1, 0.9), false, 1.5)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.35, 0.42, 0.3), false, 1.0)
