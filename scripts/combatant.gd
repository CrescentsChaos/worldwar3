class_name Combatant
extends Node2D
## Anything that can be shot at and (usually) shoots back: infantry, vehicles,
## aircraft, defensive structures, country buildings and the capital.
## Strategic missiles extend this.
## All positions use `position` (battle-local space) - never global_position.

var battle                      # Battle (untyped to avoid circular type refs)
var id := ""
var kind := "unit"              # unit | structure | national | base | strategic
var def: Dictionary = {}
var team := 0
var hp := 100.0
var max_hp := 100.0
var layer := "ground"           # ground | air | missile
var cls := "vehicle"            # infantry | vehicle | armor | air | structure | missile (used by damage bonuses)
var radius := 14.0
var armor := 0.0
var cooldown_t := 0.0
var target: Combatant = null
var retarget_t := 0.0
var desired_angle := 0.0
var strafe_dir := 1.0           # +1 toward the enemy, -1 back home (bombers)
var lane_y := 300.0
var push := Vector2.ZERO
var vel := Vector2.ZERO          # last movement velocity (for shot leading)
var flash := 0.0
var dead := false
var pending := 0.0              # interceptor damage already in flight at us
var sprite: Sprite2D
var rotates := true
var goal_pos := Vector2.ZERO    # where this unit marches when it has nothing to shoot at
var spawn_t := 0.0              # country buildings that train free units
var heal_t := 0.0
var _drawn_hp := -1.0
var _drawn_off := false


func setup(p_battle, p_kind: String, p_id: String, p_def: Dictionary, p_team: int) -> void:
	battle = p_battle
	kind = p_kind
	id = p_id
	def = p_def
	team = p_team
	max_hp = float(def.get("hp", 100))
	hp = max_hp
	layer = str(def.get("layer", "ground"))
	armor = float(def.get("armor", 0))
	radius = float(def.get("size", 32)) * 0.42
	rotates = bool(def.get("rotate", kind != "base" and kind != "national"))
	desired_angle = 0.0 if team == 0 else PI
	lane_y = position.y
	cls = _derive_cls()
	goal_pos = battle.base_pos(1 - team)


func _derive_cls() -> String:
	match kind:
		"strategic": return "missile"
		"structure", "national", "base": return "structure"
	if layer == "air":
		return "air"
	if str(def.get("tab", "")) == "infantry":
		return "infantry"
	return "armor" if armor >= 8.0 else "vehicle"


func _ready() -> void:
	add_to_group("combatants")
	add_to_group("team%d" % team)
	match layer:
		"air": z_index = 30
		"missile": z_index = 40
		_:
			match kind:
				"base": z_index = 5
				"national": z_index = 6
				"structure": z_index = 8
				_: z_index = 12
	retarget_t = randf() * 0.3
	if kind == "national" and def.has("spawns"):
		spawn_t = float(def.get("spawn_every", 30.0)) * randf_range(0.4, 1.0)
	build_sprite()


func build_sprite() -> void:
	if sprite != null:
		sprite.queue_free()
	sprite = Sprite2D.new()
	var tex := SpriteLib.get_texture(str(def.get("sprite", id)), str(def.get("shape", "box")))
	sprite.texture = tex
	var s := float(def.get("size", 32)) / maxf(float(tex.get_width()), 1.0)
	sprite.scale = Vector2(s, s)
	sprite.modulate = SpriteLib.team_tint(team)
	sprite.rotation = desired_angle if rotates else 0.0
	add_child(sprite)


func refresh_sprite() -> void:
	build_sprite()
	_drawn_hp = -1.0


func _process(delta: float) -> void:
	if dead:
		return
	cooldown_t = maxf(0.0, cooldown_t - delta)
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 4.0)
	retarget_t -= delta
	if retarget_t <= 0.0:
		retarget_t = 0.22 + randf() * 0.12
		_acquire()
		_compute_push()
	_act(delta)
	_tick_special(delta)
	if sprite != null:
		sprite.modulate = SpriteLib.team_tint(team).lerp(Color(2, 2, 2), flash * 0.6)
		if rotates:
			sprite.rotation = lerp_angle(sprite.rotation, desired_angle, minf(1.0, delta * 9.0))
	_maybe_redraw()


## Static buildings only redraw when something visible changed (cheap with 100+ entities).
func _maybe_redraw() -> void:
	var off := not online()
	if _speed() > 0.0 or layer == "air" or flash > 0.0 or hp != _drawn_hp or off != _drawn_off or _drawn_hp < 0.0:
		_drawn_hp = hp
		_drawn_off = off
		queue_redraw()


# ------------------------------------------------------------------ helpers

func _speed() -> float:
	return float(def.get("speed", 0))


## Weapon range (radar-guided systems reach further while a friendly radar station lives).
func _range() -> float:
	var r := float(def.get("range", 0.0))
	if bool(def.get("radar_boost", false)) and battle.has_capability(team, "radar"):
		r *= 1.3
	return r


## False for powered systems (SAM, interceptors, railguns...) while the power grid is down.
func online() -> bool:
	if bool(def.get("needs_power", false)):
		return battle.has_capability(team, "power")
	return true


# ------------------------------------------------------------------ targeting

func _acquire() -> void:
	if _speed() > 0.0 and not bool(def.get("strafe", false)):
		_update_goal()
	var rng := _range()
	if rng <= 0.0 or float(def.get("damage", 0.0)) <= 0.0 or not online():
		target = null
		return
	var strafe: bool = def.get("strafe", false)
	var bonus := 0.0
	if not strafe and _speed() > 0.0:
		bonus = float(def.get("sight_bonus", 140.0))
	var sight := rng + bonus
	var min_rng := float(def.get("min_range", 0.0))
	var targets: Array = def.get("targets", [])
	var prefer: Array = def.get("prefer", [])
	var best: Combatant = null
	var best_score := INF
	for n in get_tree().get_nodes_in_group("team%d" % (1 - team)):
		var c := n as Combatant
		if c == null or c.dead or c.is_queued_for_deletion():
			continue
		if not targets.has(c.layer):
			continue
		var d := position.distance_to(c.position) - c.radius
		if d > sight or d < min_rng:
			continue
		var stealth := float(c.def.get("stealth", 0.0))
		if stealth > 0.0 and d > rng * stealth:
			continue                           # stealth aircraft are only seen up close
		var score := d
		if c.layer == "missile":
			if c.pending >= c.hp:
				continue                       # already doomed by other interceptors
			if c.def.get("nuke", false):
				score *= 0.4                   # nukes first
		else:
			if c.kind == "base":
				score += 60.0                  # prefer units over the capital
			elif c.kind == "national":
				score += 35.0
			if prefer.has(c.cls):
				score *= 0.55
		if score < best_score:
			best_score = score
			best = c
	target = best


func _update_goal() -> void:
	if def.has("heal") and bool(def.get("follow", false)):
		goal_pos = _support_goal()
	else:
		goal_pos = battle.objective_for(team, position)


## Medics / engineers / repair vehicles: walk to the nearest wounded friend, else the nearest friend.
func _support_goal() -> Vector2:
	var h: Dictionary = def.get("heal", {})
	var cls_list: Array = h.get("cls", [])
	var hurt: Combatant = null
	var hurt_d := INF
	var near: Combatant = null
	var near_d := INF
	for n in get_tree().get_nodes_in_group("team%d" % team):
		var c := n as Combatant
		if c == null or c == self or c.dead or c.is_queued_for_deletion():
			continue
		if c.kind != "unit" or c.def.has("heal") or not cls_list.has(c.cls):
			continue
		var d := position.distance_to(c.position)
		if c.hp < c.max_hp * 0.95 and d < hurt_d:
			hurt_d = d
			hurt = c
		if d < near_d:
			near_d = d
			near = c
	if hurt != null:
		return hurt.position
	if near != null:
		return near.position
	return position


func _compute_push() -> void:
	push = Vector2.ZERO
	if _speed() <= 0.0:
		return
	for n in get_tree().get_nodes_in_group("team%d" % team):
		var c := n as Combatant
		if c == null or c == self or c.dead or c.layer != layer or c._speed() <= 0.0:
			continue
		var off := position - c.position
		var d := off.length()
		var min_d := (radius + c.radius) * 0.9
		if d < min_d:
			if d < 0.1:
				off = Vector2.from_angle(randf() * TAU)
				d = 1.0
			push += off / d * (min_d - d) * 3.0
	push = push.limit_length(40.0)


# ------------------------------------------------------------------- actions

func _act(delta: float) -> void:
	vel = Vector2.ZERO
	if not online():
		return
	var speed := _speed()
	var rng := _range()
	if def.get("strafe", false):
		_strafe(delta, speed)
		if target != null and is_instance_valid(target) and not target.dead:
			_try_fire()
		return
	if target != null and is_instance_valid(target) and not target.dead:
		var d := position.distance_to(target.position) - target.radius
		if d > rng:
			if speed > 0.0:
				_move_toward(target.position, speed, delta)
		else:
			desired_angle = (target.position - position).angle()
			_try_fire()
	elif speed > 0.0:
		target = null
		if def.has("heal") and bool(def.get("follow", false)):
			if position.distance_to(goal_pos) > 80.0:
				_move_toward(goal_pos, speed, delta)
		else:
			_move_toward(goal_pos, speed, delta)


## Healing / repairing and free-unit production run on their own timers.
func _tick_special(delta: float) -> void:
	if def.has("heal"):
		heal_t -= delta
		if heal_t <= 0.0:
			heal_t = 0.5
			if online():
				_do_heal(0.5)
	if kind == "national" and def.has("spawns"):
		spawn_t -= delta
		if spawn_t <= 0.0:
			spawn_t = float(def.get("spawn_every", 30.0)) * randf_range(0.9, 1.1)
			battle.garrison_spawn(self)


func _do_heal(dt: float) -> void:
	var h: Dictionary = def.get("heal", {})
	var amount := float(h.get("rate", 10.0)) * dt
	var rad := float(h.get("radius", 100.0))
	var cls_list: Array = h.get("cls", [])
	for n in get_tree().get_nodes_in_group("team%d" % team):
		var c := n as Combatant
		if c == null or c == self or c.dead or c.is_queued_for_deletion():
			continue
		if c.layer == "missile" or c.hp >= c.max_hp or not cls_list.has(c.cls):
			continue
		if position.distance_to(c.position) > rad + c.radius:
			continue
		c.hp = minf(c.max_hp, c.hp + amount)


func _move_toward(pos: Vector2, speed: float, delta: float) -> void:
	var dir := pos - position
	if dir.length() < 2.0:
		return
	dir = dir.normalized()
	desired_angle = dir.angle()
	vel = dir * speed + push
	position += vel * delta
	_clamp_to_field()


func _strafe(delta: float, speed: float) -> void:
	var toward := 1.0 if team == 0 else -1.0
	var dirx := strafe_dir * toward
	vel = Vector2(dirx * speed, 0.0)
	position.x += dirx * speed * delta
	position.y = move_toward(position.y, lane_y, 55.0 * delta)
	desired_angle = 0.0 if dirx > 0.0 else PI
	var x := position.x
	var enemy_edge := float(battle.W) + 90.0 if team == 0 else -90.0
	var home_edge := 90.0 if team == 0 else float(battle.W) - 90.0
	if strafe_dir > 0.0 and ((team == 0 and x > enemy_edge) or (team == 1 and x < enemy_edge)):
		strafe_dir = -1.0
		lane_y = battle.pick_bombing_lane(team)
	elif strafe_dir < 0.0 and ((team == 0 and x < home_edge) or (team == 1 and x > home_edge)):
		strafe_dir = 1.0
		lane_y = battle.pick_bombing_lane(team)


func _clamp_to_field() -> void:
	position.x = clampf(position.x, 12.0, float(battle.W) - 12.0)
	position.y = clampf(position.y, battle.FIELD_TOP + 10.0, battle.FIELD_BOTTOM - 10.0)


func _try_fire() -> void:
	if cooldown_t > 0.0 or target == null:
		return
	var d := position.distance_to(target.position) - target.radius
	if d > _range() + 4.0:
		return
	cooldown_t = float(def.get("cooldown", 1.0)) * randf_range(0.95, 1.08)
	if bool(def.get("kamikaze", false)):
		_kamikaze()
		return
	if not def.get("strafe", false):
		desired_angle = (target.position - position).angle()
	battle.fire_projectile(self, target)


func _kamikaze() -> void:
	var vsd: Dictionary = def.get("vs", {})
	battle.explode(position, float(def.get("splash", 50.0)), float(def.get("damage", 100.0)), team,
		["ground"], 0.5, false, float(def.get("pierce", 0.0)), vsd)
	die(-1)


# ------------------------------------------------------------------- damage

## `pierce` is subtracted from armor for this hit (armor-piercing weapons).
func take_damage(amount: float, source_team: int, pierce: float = 0.0) -> void:
	if dead:
		return
	var eff_armor := maxf(armor - pierce, 0.0)
	var dmg := maxf(amount * 0.2, amount - eff_armor)
	hp -= dmg
	flash = 1.0
	if hp <= 0.0:
		die(source_team)


func die(source_team: int) -> void:
	if dead:
		return
	dead = true
	battle.on_combatant_died(self, source_team)
	queue_free()


# ------------------------------------------------------------------- saving

func to_dict() -> Dictionary:
	return {"t": kind, "id": id, "team": team, "x": position.x, "y": position.y,
		"hp": hp, "cd": cooldown_t, "rot": desired_angle, "sdir": strafe_dir, "lane": lane_y, "st": spawn_t}


func from_dict(d: Dictionary) -> void:
	hp = float(d.get("hp", hp))
	cooldown_t = float(d.get("cd", 0.0))
	desired_angle = float(d.get("rot", desired_angle))
	strafe_dir = float(d.get("sdir", 1.0))
	lane_y = float(d.get("lane", position.y))
	spawn_t = float(d.get("st", spawn_t))
	if sprite != null and rotates:
		sprite.rotation = desired_angle


# ------------------------------------------------------------------- drawing

func _draw() -> void:
	if layer == "air" and sprite != null and sprite.texture != null:
		draw_set_transform(Vector2(9, 16), sprite.rotation, sprite.scale)
		draw_texture(sprite.texture, -sprite.texture.get_size() * 0.5, Color(0, 0, 0, 0.28))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if layer != "air":
		draw_arc(Vector2.ZERO, radius + 2.0, 0.0, TAU, 22, Color(SpriteLib.team_color(team), 0.8), 2.0)
	if hp < max_hp or kind == "base":
		var w := maxf(radius * 2.0, 26.0)
		var y := -(radius + 11.0)
		var frac := clampf(hp / max_hp, 0.0, 1.0)
		draw_rect(Rect2(-w * 0.5, y, w, 4.0), Color(0, 0, 0, 0.65))
		var col := Color(0.3, 0.9, 0.35) if frac > 0.5 else (Color(0.95, 0.8, 0.2) if frac > 0.25 else Color(0.95, 0.25, 0.2))
		draw_rect(Rect2(-w * 0.5, y, w * frac, 4.0), col)
	var font := ThemeDB.fallback_font
	if kind == "national" or kind == "base":
		var lw := maxf(radius * 2.0 + 70.0, 110.0)
		var lp := Vector2(-lw * 0.5, radius + 17.0)
		draw_string_outline(font, lp, str(def.get("name", id)), HORIZONTAL_ALIGNMENT_CENTER, lw, 13, 5, Color(0, 0, 0, 0.85))
		draw_string(font, lp, str(def.get("name", id)), HORIZONTAL_ALIGNMENT_CENTER, lw, 13,
			SpriteLib.team_color(team).lightened(0.45))
	if not online():
		var ow := 90.0
		var op := Vector2(-ow * 0.5, -(radius + 16.0))
		draw_string_outline(font, op, "NO POWER", HORIZONTAL_ALIGNMENT_CENTER, ow, 11, 4, Color(0, 0, 0, 0.9))
		draw_string(font, op, "NO POWER", HORIZONTAL_ALIGNMENT_CENTER, ow, 11, Color(1.0, 0.85, 0.2))
