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
var domain := "land"            # land | water (ships) | sub (submarines) | amphib (divers)
var draft := 1                  # lowest water kind a ship can sail on (1 stream, 2 river, 3 deep sea)
var path: PackedVector2Array = PackedVector2Array()   # waypoints around rivers / along waterways
var path_i := 0
var path_t := 0.0
var path_goal := Vector2.ZERO
var _cd: Dictionary = {}        # draft -> [distance from here to the nearest water, time stamp]
var _submerged := false
var order := "auto"             # auto (AI marches on its own) | hold | move | attack_move
var order_pos := Vector2.ZERO
var selected := false
var overlay: Overlay = null      # health bar + labels, drawn above every sprite and effect
var _spd_mult := 1.0            # settings.move_speed_mult for units (the map is big)
var slow_t := 0.0               # slowed by wire / tank traps while > 0
var slow_m := 1.0
var buff_t := 0.0               # damage aura from an officer / observation post while > 0
var buff_m := 1.0
var lay_t := 0.0                # mine-laying timer (sappers, minelayers)
var trap_t := 0.0               # trap trigger scan timer
var aura_t := 0.0
var sweep_t := 0.0


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
	domain = str(def.get("domain", "land"))
	draft = int(def.get("draft", 1))
	radius = float(def.get("size", 32)) * float(def.get("radius_k", 0.42)) * GameData.sprite_scale()
	rotates = bool(def.get("rotate", kind != "base" and kind != "national"))
	desired_angle = 0.0 if team == 0 else PI
	lane_y = position.y
	cls = _derive_cls()
	goal_pos = battle.base_pos(1 - team)
	if kind == "unit":
		_spd_mult = float(GameData.settings.get("move_speed_mult", 1.0))
	lay_t = float(def.get("lay_every", 12.0)) * randf_range(0.3, 1.0)


func _derive_cls() -> String:
	match kind:
		"strategic": return "missile"
		"structure", "national", "base": return "structure"
	if domain == "water" or domain == "sub":
		return "ship"
	if layer == "air":
		return "air"
	if str(def.get("tab", "")) == "infantry":
		return "infantry"
	return "armor" if armor >= 8.0 else "vehicle"


## Ground / naval / helicopter units can be commanded. Strafing aircraft and suicide drones fly their own sorties.
func can_take_orders() -> bool:
	return kind == "unit" and _speed() > 0.0 and not bool(def.get("strafe", false)) and not bool(def.get("kamikaze", false))


func set_order(o: String, p: Vector2 = Vector2.ZERO) -> void:
	if not can_take_orders():
		return
	order = o
	order_pos = p if (o == "move" or o == "attack_move") else position
	path = PackedVector2Array()
	path_t = 0.0
	target = null if o == "move" else target


func _ready() -> void:
	add_to_group("combatants")
	add_to_group("team%d" % team)
	match layer:
		"air": z_index = 30
		"missile": z_index = 40
		"sub": z_index = 9
		_:
			match kind:
				"base": z_index = 5
				"national": z_index = 6
				"structure": z_index = 8
				_: z_index = 12
	retarget_t = randf() * 0.3
	if (kind == "national" or kind == "unit") and def.has("spawns"):
		spawn_t = float(def.get("spawn_every", 30.0)) * randf_range(0.4, 1.0)
	overlay = Overlay.new()
	overlay.owner_c = self
	add_child(overlay)
	build_sprite()


func build_sprite() -> void:
	if sprite != null:
		sprite.queue_free()
	sprite = Sprite2D.new()
	var tex := SpriteLib.get_texture(str(def.get("sprite", id)), str(def.get("shape", "box")))
	sprite.texture = tex
	var s := float(def.get("size", 32)) * GameData.sprite_scale() / maxf(float(tex.get_width()), 1.0)
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
	if domain == "amphib":
		_update_amphib()
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 4.0)
	if slow_t > 0.0:
		slow_t -= delta
	if buff_t > 0.0:
		buff_t -= delta
	retarget_t -= delta
	if retarget_t <= 0.0:
		retarget_t = 0.22 + randf() * 0.12
		_acquire()
		_compute_push()
	_act(delta)
	_tick_special(delta)
	if sprite != null:
		var mod := SpriteLib.team_tint(team).lerp(Color(2, 2, 2), flash * 0.6)
		if layer == "sub":
			mod.a = 0.6
		if is_trap():
			mod.a = 0.95 if team == 0 else 0.3      # enemy mines are barely visible
		sprite.modulate = mod
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
		if overlay != null:
			overlay.queue_redraw()


# ------------------------------------------------------------------ helpers

func _speed() -> float:
	return float(def.get("speed", 0)) * _spd_mult


func is_trap() -> bool:
	return kind == "structure" and def.has("trap")


## Weapon range (radar-guided systems reach further while a friendly radar station lives).
func _range() -> float:
	var r := float(def.get("range", 0.0))
	if bool(def.get("radar_boost", false)) and battle.has_capability(team, "radar"):
		r *= 1.3
	return r


## True for ships, submarines and divers that are currently swimming.
func in_water() -> bool:
	match domain:
		"water", "sub":
			return true
		"amphib":
			return _submerged
	return false


## Distance from here to the nearest water a ship of this draft can sail on (cached).
func coast_dist(dr: int) -> float:
	var now := Time.get_ticks_msec() / 1000.0
	var e: Array = _cd.get(dr, [])
	if e.is_empty() or now - float(e[1]) > (6.0 if _speed() <= 0.0 else 1.5):
		e = [Water.dist_to_water(position, dr), now]
		_cd[dr] = e
	return float(e[0])


## Divers dive when they swim into deep water: they can then only be hit by sonar weapons.
func _update_amphib() -> void:
	var sub_now := Water.kind_at(position) >= 2 and not Water.is_bridge(position)
	if sub_now != _submerged:
		_submerged = sub_now
		layer = "sub" if sub_now else "ground"


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
	var water_only: bool = bool(def.get("water_only", false))
	var swimmer: bool = domain == "water" or domain == "sub"
	var walker: bool = domain == "land" and layer == "ground" and _speed() > 0.0
	var best: Combatant = null
	var best_score := INF
	for n in battle.near_team(1 - team, position, sight + 160.0):
		var c := n as Combatant
		if c == null or c.dead or c.is_queued_for_deletion():
			continue
		if not targets.has(c.layer):
			continue
		if c.is_trap():
			continue                               # buried / hidden: only blasts and sweepers clear them
		var d := position.distance_to(c.position) - c.radius
		if d > sight or d < min_rng:
			continue
		if water_only and not c.in_water():
			continue                           # torpedoes and shore guns only fire at things in the water
		if d > rng:
			if walker and c.in_water():
				continue                       # land units don't chase targets out at sea
			if swimmer and not c.in_water() and c.coast_dist(draft) > rng - 8.0:
				continue                       # inland target that no ship can reach
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
	if order == "move" or order == "attack_move":
		goal_pos = order_pos
		return
	if order == "hold":
		goal_pos = position
		return
	if def.has("aura") and bool(def.get("follow", false)):
		goal_pos = _follow_goal()
	elif def.has("heal") and bool(def.get("follow", false)):
		goal_pos = _support_goal()
	elif domain == "water" or domain == "sub":
		goal_pos = battle.naval_goal(team, position, _range(), draft)
	else:
		goal_pos = battle.objective_for(team, position)


## Officers: walk with the front-most friendly ground fighters, staying a little behind them.
func _follow_goal() -> Vector2:
	var best: Combatant = null
	var best_v := -INF
	var dirx := 1.0 if team == 0 else -1.0
	for n in get_tree().get_nodes_in_group("team%d" % team):
		var c := n as Combatant
		if c == null or c == self or c.dead or c.is_queued_for_deletion():
			continue
		if c.kind != "unit" or c.layer != "ground" or c.domain != "land" or c._speed() <= 0.0 or c.def.has("aura"):
			continue
		var v := c.position.x * dirx
		if v > best_v:
			best_v = v
			best = c
	if best == null:
		return position
	return best.position - Vector2(dirx * 70.0, 0.0)


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
	for n in battle.near_team(team, position, 180.0):
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
	if order == "move" and speed > 0.0:
		if position.distance_to(order_pos) < 22.0:
			order = "hold"
		else:
			_move_toward(order_pos, speed, delta)
		if target != null and is_instance_valid(target) and not target.dead:
			_try_fire()
		return
	if target != null and is_instance_valid(target) and not target.dead:
		var d := position.distance_to(target.position) - target.radius
		if d > rng:
			if speed > 0.0 and order != "hold":
				_move_toward(target.position, speed, delta)
		else:
			desired_angle = (target.position - position).angle()
			_try_fire()
	elif speed > 0.0:
		target = null
		if order == "hold":
			return
		if order == "attack_move" and position.distance_to(order_pos) < 28.0:
			order = "hold"
			return
		if (def.has("heal") or def.has("aura")) and bool(def.get("follow", false)):
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
	if (kind == "national" or kind == "unit") and def.has("spawns"):
		spawn_t -= delta
		if spawn_t <= 0.0:
			spawn_t = float(def.get("spawn_every", 30.0)) * randf_range(0.9, 1.1)
			battle.garrison_spawn(self)
	if def.has("trap"):
		trap_t -= delta
		if trap_t <= 0.0:
			trap_t = 0.15
			_trap_scan(0.15)
	if def.has("aura"):
		aura_t -= delta
		if aura_t <= 0.0:
			aura_t = 0.5
			if online():
				_do_aura()
	if def.has("lays_trap"):
		_tick_lay(delta)
	if def.has("sweeper"):
		sweep_t -= delta
		if sweep_t <= 0.0:
			sweep_t = 0.4
			_do_sweep()


## Officers / observation posts: friends inside the radius fire harder for the next moment.
func _do_aura() -> void:
	var a: Dictionary = def.get("aura", {})
	var rad := float(a.get("radius", 250.0))
	var mult := float(a.get("dmg", 1.2))
	for n in get_tree().get_nodes_in_group("team%d" % team):
		var c := n as Combatant
		if c == null or c.dead or c.layer == "missile" or c.is_queued_for_deletion():
			continue
		if position.distance_to(c.position) <= rad:
			c.buff_m = mult if c.buff_t <= 0.0 else maxf(c.buff_m, mult)
			c.buff_t = 0.8


## Mines and tripwires blow up under enemies; wire and tank traps slow (and cut) them.
func _trap_scan(dt: float) -> void:
	var cfg: Dictionary = def.get("trap", {})
	var enemy := 1 - team
	var slow: Dictionary = cfg.get("slow", {})
	var trig: Array = cfg.get("triggers", [])
	var rad := float(slow.get("radius", cfg.get("radius", 20.0)))
	for n in battle.near_team(enemy, position, rad + 160.0):
		var c := n as Combatant
		if c == null or c.dead or c.kind != "unit" or c.layer == "air" or c.layer == "missile" or c.is_queued_for_deletion():
			continue
		if c.def.has("sweeper"):
			continue                                   # sappers and flail tanks walk over mines safely
		if position.distance_to(c.position) > rad + c.radius * 0.3:
			continue
		if not slow.is_empty():
			if (slow.get("classes", []) as Array).has(c.cls):
				c.slow_m = float(slow.get("mult", 0.4))
				c.slow_t = 0.4
				var dps := float(slow.get("dps", 0.0))
				if dps > 0.0:
					c.take_damage(dps * dt, team)
			continue
		if trig.has(c.cls):
			var vsd: Dictionary = cfg.get("vs", {})
			var lay: Array = cfg.get("layers", ["ground"])
			battle.explode(position, float(cfg.get("splash", 50.0)), float(cfg.get("damage", 100.0)), team,
				lay, 0.5, false, float(cfg.get("pierce", 0.0)), vsd)
			die(-1)
			return


## Sappers / minelayers drop a free mine now and then while they move through contested ground.
func _tick_lay(delta: float) -> void:
	lay_t -= delta
	if lay_t > 0.0 or vel.length_squared() < 4.0 or dead:
		return
	lay_t = float(def.get("lay_every", 12.0)) * randf_range(0.9, 1.2)
	var tid := str(def.get("lays_trap", ""))
	var td: Dictionary = GameData.def_for(team, "structure", tid)
	if td.is_empty() or battle.trap_count(team) >= int(GameData.settings.get("trap_cap", 90)):
		return
	if position.distance_to(battle.base_pos(team)) < 450.0:
		return                                         # keep our own roads clear
	var wet := str(td.get("domain", "land")) == "water"
	if wet != (Water.kind_at(position) >= 1) or Water.is_bridge(position):
		return
	battle.spawn_entity("structure", tid, team, position)


## Safely defuses enemy mines and traps around this unit.
func _do_sweep() -> void:
	var rad := float(def.get("sweeper", 100.0))
	for n in battle.near_team(1 - team, position, rad + 60.0):
		var c := n as Combatant
		if c == null or c.dead or not c.is_trap() or c.is_queued_for_deletion():
			continue
		if position.distance_to(c.position) <= rad:
			battle.spawn_explosion(c.position, 10.0, false, 0.2)
			c.die(-1)


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
	var goal := _steer(pos, delta)
	var dir := goal - position
	if dir.length() < 2.0:
		return
	dir = dir.normalized()
	desired_angle = dir.angle()
	vel = dir * speed * _terrain_speed() * (slow_m if slow_t > 0.0 else 1.0) + push
	_apply_move(vel * delta)


## 0 = head straight for the goal. Otherwise the path level for Water.find_path():
## 1-3 ships by draft, 4 vehicles (rivers need bridges), 5 infantry (can wade rivers, not the sea).
func _path_level() -> int:
	if domain == "water" or domain == "sub":
		return draft
	if domain == "amphib" or layer == "air" or _speed() <= 0.0:
		return 0
	return 5 if cls == "infantry" else 4


## The point to head for right now: the goal itself, or the next waypoint of a detour / sea route.
func _steer(goal: Vector2, delta: float) -> Vector2:
	var level := _path_level()
	if level == 0:
		return goal
	path_t -= delta
	if path_t <= 0.0 or path_goal.distance_to(goal) > 90.0:
		path_t = randf_range(3.5, 5.0)
		path_goal = goal
		path_i = 0
		path = PackedVector2Array()
		if level <= 3 or not Water.line_clear(position, goal, level):
			path = Water.find_path(position, goal, level)
	if path.size() == 0:
		return goal
	var last := path.size() - 1
	while path_i < last and position.distance_to(path[path_i]) < 20.0:
		path_i += 1
	if level >= 4 and path_i >= last and position.distance_to(path[last]) < 20.0:
		return goal
	return path[path_i]


func _terrain_speed() -> float:
	match domain:
		"land":
			if layer == "air":
				return 1.0
			return Water.speed_mult(position, cls == "infantry")
		"amphib":
			return float(def.get("swim_mult", 1.0)) if Water.kind_at(position) >= 1 else 1.0
	return 1.0


func _can_stand(p: Vector2) -> bool:
	match domain:
		"water", "sub":
			return Water.kind_at(p) >= draft
		"amphib":
			return true
	if layer == "air":
		return true
	return Water.land_ok(p, cls == "infantry")


## Moves by `step`, sliding along shores and river banks instead of entering forbidden terrain.
func _apply_move(step: Vector2) -> void:
	var np := position + step
	if not _can_stand(position) or _can_stand(np):
		position = np
	elif _can_stand(Vector2(np.x, position.y)):
		position = Vector2(np.x, position.y)
	elif _can_stand(Vector2(position.x, np.y)):
		position = Vector2(position.x, np.y)
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
	if layer == "air" or domain != "land":
		position.y = clampf(position.y, float(Water.Y_MIN) + 10.0, float(Water.Y_MAX) - 10.0)
	else:
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
		"hp": hp, "cd": cooldown_t, "rot": desired_angle, "sdir": strafe_dir, "lane": lane_y, "st": spawn_t,
		"ord": order, "ox": order_pos.x, "oy": order_pos.y}


func from_dict(d: Dictionary) -> void:
	hp = float(d.get("hp", hp))
	cooldown_t = float(d.get("cd", 0.0))
	desired_angle = float(d.get("rot", desired_angle))
	strafe_dir = float(d.get("sdir", 1.0))
	lane_y = float(d.get("lane", position.y))
	spawn_t = float(d.get("st", spawn_t))
	if d.has("ord"):
		order = str(d.get("ord", order))
		order_pos = Vector2(float(d.get("ox", 0.0)), float(d.get("oy", 0.0)))
	if sprite != null and rotates:
		sprite.rotation = desired_angle


# ------------------------------------------------------------------- drawing

func _draw() -> void:
	var tcol := SpriteLib.team_color(team)
	if is_trap():
		if team == 0:
			var cfg: Dictionary = def.get("trap", {})
			var tr := float(cfg.get("slow", {}).get("radius", cfg.get("radius", 20.0)))
			draw_arc(Vector2.ZERO, tr, 0.0, TAU, 24, Color(tcol, 0.35), 1.0)
		return
	if sprite != null and sprite.texture != null and domain != "water" and domain != "sub":
		var air := layer == "air"
		draw_set_transform(Vector2(9, 16) if air else Vector2(2.5, 4.0), sprite.rotation, sprite.scale)
		draw_texture(sprite.texture, -sprite.texture.get_size() * 0.5, Color(0, 0, 0, 0.26 if air else 0.38))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if domain == "water" or domain == "sub":
		_draw_wake()
	if selected:
		var sr := radius + 6.0
		MilTheme.draw_brackets(self, Rect2(Vector2(-sr, -sr), Vector2(sr, sr) * 2.0), MilTheme.GOOD, 6.0, 1.6)
		if order == "move" or order == "attack_move":
			var col := MilTheme.GOOD if order == "move" else MilTheme.WARN
			draw_dashed_line(Vector2.ZERO, order_pos - position, Color(col, 0.45), 1.2, 6.0)
		elif order == "hold":
			draw_arc(Vector2.ZERO, radius + 10.0, -PI * 0.2, PI * 0.2, 6, Color(MilTheme.WARN, 0.8), 2.0)
	if layer == "air":
		var py := -(radius + 4.0)
		draw_colored_polygon(PackedVector2Array([Vector2(0, py), Vector2(-4, py - 7), Vector2(4, py - 7)]), Color(tcol, 0.95))
	elif domain != "water" and domain != "sub":
		# four tactical corner ticks instead of a full circle
		var r := radius + 3.0
		for k in 4:
			var ang := float(k) * PI * 0.5 + PI * 0.25
			draw_arc(Vector2.ZERO, r, ang - 0.30, ang + 0.30, 6, Color(tcol, 0.85), 2.0)


## Health bar and labels. Drawn by the Overlay child (z_index 100) so text is never hidden by other sprites.
func draw_overlay(ci: CanvasItem) -> void:
	var tcol := SpriteLib.team_color(team)
	if (hp < max_hp and not is_trap()) or kind == "base" or selected:
		var w := maxf(radius * 2.0, 28.0)
		var y := -(radius + 12.0)
		var bx := -w * 0.5
		var frac := clampf(hp / max_hp, 0.0, 1.0)
		ci.draw_rect(Rect2(bx - 1.0, y - 1.0, w + 2.0, 6.0), Color(0, 0, 0, 0.78))
		var col := Color(0.50, 0.80, 0.34) if frac > 0.5 else (Color(0.95, 0.72, 0.18) if frac > 0.25 else Color(0.92, 0.25, 0.2))
		ci.draw_rect(Rect2(bx, y, w * frac, 4.0), col)
		var segs := int(clampf(w / 9.0, 3.0, 10.0))
		for i in range(1, segs):
			var tx := bx + w * float(i) / float(segs)
			ci.draw_line(Vector2(tx, y), Vector2(tx, y + 4.0), Color(0, 0, 0, 0.55), 1.0)
		ci.draw_rect(Rect2(bx - 5.0, y - 1.0, 3.0, 6.0), tcol)
	var font := MilTheme.font_bold()
	if kind == "national" or kind == "base":
		var lw := maxf(radius * 2.0 + 70.0, 110.0)
		var lp := Vector2(-lw * 0.5, radius + 17.0)
		var nm := str(def.get("name", id)).to_upper()
		ci.draw_string_outline(font, lp, nm, HORIZONTAL_ALIGNMENT_CENTER, lw, 12, 5, Color(0, 0, 0, 0.9))
		ci.draw_string(font, lp, nm, HORIZONTAL_ALIGNMENT_CENTER, lw, 12, tcol.lightened(0.5))
	if not online():
		var ow := 90.0
		var op := Vector2(-ow * 0.5, -(radius + 18.0))
		ci.draw_string_outline(font, op, "NO POWER", HORIZONTAL_ALIGNMENT_CENTER, ow, 11, 4, Color(0, 0, 0, 0.9))
		ci.draw_string(font, op, "NO POWER", HORIZONTAL_ALIGNMENT_CENTER, ow, 11, MilTheme.WARN)


## V-shaped wake behind a moving ship (fainter for submarines).
func _draw_wake() -> void:
	if vel.length_squared() < 4.0:
		return
	var a := sprite.rotation if sprite != null else desired_angle
	var fwd := Vector2.from_angle(a)
	var side := fwd.orthogonal()
	var half := float(def.get("size", 60)) * GameData.sprite_scale() * 0.5
	var stern := -fwd * half * 0.85
	var spread := float(def.get("size", 60)) * GameData.sprite_scale() * 0.2
	var al := 0.18 if domain == "sub" else 0.4
	draw_line(stern, stern - fwd * half * 0.9 + side * spread, Color(1, 1, 1, al), 2.0)
	draw_line(stern, stern - fwd * half * 0.9 - side * spread, Color(1, 1, 1, al), 2.0)
	draw_line(stern - fwd * half * 0.15, stern - fwd * half * 0.7, Color(1, 1, 1, al * 0.8), 3.0)


## Holds the health bar and labels so they always draw above every sprite and effect.
class Overlay extends Node2D:
	var owner_c = null

	func _init() -> void:
		z_as_relative = false
		z_index = 100

	func _draw() -> void:
		if owner_c != null and is_instance_valid(owner_c):
			owner_c.draw_overlay(self)
