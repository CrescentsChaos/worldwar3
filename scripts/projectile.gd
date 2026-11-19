class_name Projectile
extends Node2D
## Bullets, shells, rockets, bombs and interceptor missiles.

var battle
var ptype: Dictionary = {}
var team := 0
var damage := 0.0
var splash := 0.0
var speed := 400.0
var target: Combatant = null
var target_pos := Vector2.ZERO
var homing := false
var is_interceptor := false
var layers: Array = ["ground"]    # layers a splash blast reaches
var vs: Dictionary = {}            # damage multipliers per target class
var pierce := 0.0
var quiet := false
var pend_amount := 0.0
var life := 7.0
var sprite: Sprite2D
var trail: Array[Vector2] = []
var trail_len := 0
var trail_color := Color.WHITE


func _ready() -> void:
	z_index = 35
	trail_len = int(ptype.get("trail", 0))
	trail_color = Color(str(ptype.get("color", "ffffff")))
	sprite = Sprite2D.new()
	var tex := SpriteLib.get_texture(str(ptype.get("sprite", "proj_bullet")), "proj")
	sprite.texture = tex
	var s := float(ptype.get("size", 10)) / maxf(float(tex.get_width()), 1.0)
	sprite.scale = Vector2(s, s)
	add_child(sprite)
	sprite.rotation = (target_pos - position).angle()


func _process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		_release()
		queue_free()
		return
	if homing:
		if is_instance_valid(target) and not target.dead:
			target_pos = target.position
		elif is_interceptor:
			_release()
			queue_free()
			return
	var to := target_pos - position
	var step := speed * delta
	if to.length() <= step + 1.0:
		position = target_pos
		_impact()
		return
	position += to.normalized() * step
	sprite.rotation = to.angle()
	if trail_len > 0:
		trail.append(position)
		if trail.size() > 8:
			trail.remove_at(0)
		queue_redraw()


func _release() -> void:
	if pend_amount > 0.0 and is_instance_valid(target):
		target.pending = maxf(0.0, target.pending - pend_amount)
	pend_amount = 0.0


func _impact() -> void:
	_release()
	if splash > 0.0:
		battle.explode(position, splash, damage, team, layers, 0.5, false, pierce, vs, quiet)
	elif is_instance_valid(target) and not target.dead:
		target.take_damage(damage * float(vs.get(target.cls, 1.0)), team, pierce)
		if is_interceptor:
			battle.spawn_explosion(position, 26.0, false)
			Sfx.play("intercept", -6.0, 0.08)
		elif target.layer != "missile":
			battle.spawn_explosion(position, 7.0, false, 0.18)
	queue_free()


func _draw() -> void:
	for i in range(1, trail.size()):
		var a := float(i) / float(trail.size())
		draw_line(trail[i - 1] - position, trail[i] - position, Color(trail_color, a * 0.30), 3.5)
		draw_line(trail[i - 1] - position, trail[i] - position, Color(trail_color.lightened(0.5), a * 0.9), 1.3)
