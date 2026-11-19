class_name Missile
extends Combatant
## A strategic missile / nuke in flight. Can be shot down by interceptors.

var start_pos := Vector2.ZERO
var target_pos := Vector2.ZERO
var speed := 300.0
var damage := 0.0
var splash := 0.0
var total_dist := 1.0
var arc := 0.3
var trail: Array[Vector2] = []
var is_nuke := false


func setup_missile(p_battle, p_id: String, p_def: Dictionary, p_team: int, p_start: Vector2, p_target: Vector2) -> void:
	position = p_start
	setup(p_battle, "strategic", p_id, p_def, p_team)
	start_pos = p_start
	target_pos = p_target
	speed = float(def.get("speed", 300)) * float(GameData.settings.get("missile_speed_mult", 1.8))
	damage = float(def.get("damage", 100))
	splash = float(def.get("splash", 100))
	arc = float(def.get("arc", 0.3))
	is_nuke = bool(def.get("nuke", false))
	total_dist = maxf(p_start.distance_to(p_target), 1.0)
	desired_angle = (p_target - p_start).angle()


func _process(delta: float) -> void:
	if dead:
		return
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 4.0)
	var to := target_pos - position
	var step := speed * delta
	desired_angle = to.angle()
	if to.length() <= step:
		position = target_pos
		_detonate()
		return
	position += to.normalized() * step
	trail.append(position)
	if trail.size() > 26:
		trail.remove_at(0)
	if sprite != null:
		sprite.rotation = desired_angle
		var prog := 1.0 - to.length() / total_dist
		var lift := 1.0 + arc * sin(PI * clampf(prog, 0.0, 1.0))
		var base_s := float(def.get("size", 40)) / maxf(float(sprite.texture.get_width()), 1.0)
		sprite.scale = Vector2(base_s, base_s) * lift
		sprite.modulate = SpriteLib.team_tint(team).lerp(Color(2, 2, 2), flash * 0.6)
	queue_redraw()


func _detonate() -> void:
	if dead:
		return
	dead = true
	var vsd: Dictionary = def.get("vs", {})
	battle.explode(position, splash, damage, team, ["ground", "air"], 0.7 if is_nuke else 0.5, is_nuke,
		float(def.get("pierce", 0.0)), vsd)
	queue_free()


func take_damage(amount: float, source_team: int, _pierce: float = 0.0) -> void:
	if dead:
		return
	hp -= amount
	flash = 1.0
	if hp <= 0.0:
		die(source_team)


func to_dict() -> Dictionary:
	return {"t": "missile", "id": id, "team": team, "x": position.x, "y": position.y,
		"hp": hp, "sx": start_pos.x, "sy": start_pos.y, "tx": target_pos.x, "ty": target_pos.y}


func _draw() -> void:
	var n := trail.size()
	for i in range(1, n):
		var a := float(i) / float(n)
		var p0 := trail[i - 1] - position
		var p1 := trail[i] - position
		draw_line(p0, p1, Color(0.72, 0.72, 0.68, a * 0.24), (8.0 if is_nuke else 5.0) * (1.7 - a))
		if i > n - 9:
			draw_line(p0, p1, Color(1.0, 0.72, 0.28, a * 0.85), (4.0 if is_nuke else 2.4) * a + 0.6)
	if sprite != null:
		var tail := -Vector2.from_angle(sprite.rotation) * float(def.get("size", 40)) * 0.45
		var gr := 10.0 if is_nuke else 6.0
		draw_circle(tail, gr, Color(1.0, 0.55, 0.15, 0.25))
		draw_circle(tail, gr * 0.5, Color(1.0, 0.9, 0.6, 0.7))
	if sprite != null and sprite.texture != null:
		draw_set_transform(Vector2(10, 18), sprite.rotation, sprite.scale)
		draw_texture(sprite.texture, -sprite.texture.get_size() * 0.5, Color(0, 0, 0, 0.25))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
