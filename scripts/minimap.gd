class_name Minimap
extends Control
## Overview of the whole map. Click or drag to move the camera.

var battle
var _t := 0.0
var _bg: ImageTexture


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
		(p.y - float(Water.Y_MIN)) / float(Water.Y_MAX - Water.Y_MIN) * size.y)


func _to_world(p: Vector2) -> Vector2:
	return Vector2(p.x / size.x * float(Battle.W),
		p.y / size.y * float(Water.Y_MAX - Water.Y_MIN) + float(Water.Y_MIN))


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
	if _bg == null:
		_bg = ImageTexture.create_from_image(Water.minimap_image(int(size.x), int(size.y)))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.025, 0.027))
	draw_texture_rect(_bg, Rect2(Vector2.ZERO, size), false, Color(0.62, 0.68, 0.64))
	# tactical grid
	var gx := 0.0
	while gx < size.x:
		draw_line(Vector2(gx, 0), Vector2(gx, size.y), Color(0.7, 0.8, 0.7, 0.07), 1.0)
		gx += size.x / 12.0
	var gy := 0.0
	while gy < size.y:
		draw_line(Vector2(0, gy), Vector2(size.x, gy), Color(0.7, 0.8, 0.7, 0.07), 1.0)
		gy += size.y / 5.0
	var pz := float(GameData.settings.get("player_zone_x", 1000)) / float(Battle.W) * size.x
	var ez := float(GameData.settings.get("enemy_zone_x", 2200)) / float(Battle.W) * size.x
	draw_rect(Rect2(0, 0, pz, size.y), Color(MilTheme.FRIEND, 0.09))
	draw_rect(Rect2(ez, 0, size.x - ez, size.y), Color(MilTheme.ENEMY, 0.09))
	draw_line(Vector2(pz, 0), Vector2(pz, size.y), Color(MilTheme.FRIEND, 0.4), 1.0)
	draw_line(Vector2(ez, 0), Vector2(ez, size.y), Color(MilTheme.ENEMY, 0.4), 1.0)
	for n in get_tree().get_nodes_in_group("combatants"):
		var c := n as Combatant
		if c == null or c.dead or not c.visible:
			continue                                     # fog of war: hidden enemies are not on the map
		var p := _to_mini(c.position)
		var col := SpriteLib.team_color(c.team)
		match c.kind:
			"base":
				draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), Color(0, 0, 0, 0.8))
				draw_rect(Rect2(p - Vector2(4, 4), Vector2(8, 8)), col)
				draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)), Color(0, 0, 0, 0.8))
			"national":
				draw_rect(Rect2(p - Vector2(2.5, 2.5), Vector2(5, 5)), col.lightened(0.1))
			"strategic":
				draw_circle(p, 3.0, Color(1.0, 0.85, 0.4))
				draw_arc(p, 5.0, 0.0, TAU, 14, Color(1.0, 0.4, 0.2, 0.8), 1.0)
			"structure":
				draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)), col.darkened(0.2))
			_:
				draw_circle(p, 1.3, col)
	var cam: Camera2D = battle.cam
	if cam != null:
		var half := get_viewport_rect().size * 0.5 / cam.zoom.x
		var tl := _to_mini(cam.position - half)
		var br := _to_mini(cam.position + half)
		draw_rect(Rect2(tl, br - tl), Color(1, 1, 1, 0.85), false, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), MilTheme.LINE_HI, false, 1.0)
	MilTheme.draw_brackets(self, Rect2(Vector2.ZERO, size).grow(-1.0), MilTheme.AMBER, 9.0, 2.0)
	var font := MilTheme.font_ui()
	draw_string(font, Vector2(8, 15), "TACTICAL OVERVIEW", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(MilTheme.AMBER, 0.85))
