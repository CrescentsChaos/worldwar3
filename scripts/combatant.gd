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
# --- v6: utility abilities, vision, rotation, radio
var callsign := ""              # radio callsign (made up lazily by Radio)
var facing := 0.0               # sprite rotation of buildings that do not turn by themselves (rotate / place with R)
var abilities: Array = []       # see abilities.gd
var ab_cd: Dictionary = {}      # active ability id -> seconds left
var vision := 0.0               # how far this thing sees (fog of war / spotting)
var spotted := true             # is it visible to the player? (own team: always true)
var explored := false           # enemy buildings stay on the map once seen
var reveal_t := 0.0             # shown for a moment after it fires
var mark_t := 0.0               # painted by a designator: takes +25% damage and stays visible
var still_t := 0.0              # seconds spent standing still
var dug_in := false
var sieged := false
var retreating := false         # badly damaged and heading for a repair point
var repair_spot := Vector2.ZERO
var cargo_loaded := true        # APCs: still carrying their troops
var scout_wp := Vector2.ZERO    # scouts: current patrol point
var scout_wp_t := 0.0
var ab_t := 0.0
var prep_bought := false        # bought during the preparation phase (can be sold for a full refund)
# --- v7: drive, ammunition, supply, transport, flight
var drive := "foot"             # foot | wheeled | truck | tracked | heavy | air | ship (data/logistics.json -> mobility)
var road_mult := 1.0            # speed on roads, relative to the unit's base speed
var off_mult := 1.0             # speed off the roads
var ammo := -1.0                # shots left (-1 = unlimited)
var ammo_max := -1.0
var supply := 0.0               # crates carried (supply trucks / transport helicopters)
var supply_max := 0.0
var seats := 0
var passengers: Array = []      # [{id, hp, ammo}] infantry riding inside this vehicle
var board_target: Combatant = null
var board_cd := 0.0             # just dismounted: do not climb straight back in
var drop_set := false           # transport: unload on arrival at the move destination
var tr_state := "load"          # auto transports: load | go | return
var load_wait := 0.0
var resupplying := false
var supply_spot := Vector2.ZERO
var low_ammo_said := false
var logi_t := 0.0
var flight := ""                # fighter | strike | bomber | orbit | drone | uav | heli | "" (not an aircraft)
var heading := 0.0
var fspeed := 0.0
var fl_mode := "ingress"        # takeoff | ingress | extend | rtb | rearm
var fl_goal := Vector2.ZERO
var fl_t := 0.0
var parked := false             # landed at an airbase / carrier, rearming (hidden, cannot be targeted)
var rearm_left := 0.0
var bank := 0.0
var shadow: Sprite2D
var _base_scale := Vector2.ONE
var _tint := Color.WHITE
var _last_mod := Color(-1, -1, -1, -1)
var _drawn_mark := false
var _drawn_ammo := -1


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
	abilities = Abilities.for_def(kind, def)
	vision = Abilities.vision_for(kind, def, cls)
	cargo_loaded = false
	goal_pos = battle.base_pos(1 - team)
	drive = _derive_drive()
	var mob: Dictionary = GameData.mobility(drive)
	road_mult = float(mob.get("road", 1.0))
	off_mult = float(mob.get("off", 1.0))
	if kind == "unit":
		ammo_max = float(def.get("ammo", -1.0))
		ammo = ammo_max
		supply_max = float(def.get("supply_cap", 0.0))
		supply = supply_max
		var pre: Array = def.get("cargo", [])
		seats = maxi(int(def.get("seats", 0)), pre.size())
		for cid in pre:
			passengers.append({"id": str(cid), "hp": -1.0, "ammo": -1.0})
		cargo_loaded = not passengers.is_empty()
		flight = str(def.get("flight", ""))
		if layer == "air" and flight == "":
			flight = "bomber" if bool(def.get("strafe", false)) else ("drone" if bool(def.get("kamikaze", false)) else "heli")
		if is_transport():
			load_wait = float(GameData.logi("transport", "wait_for_load", 18.0))
		if is_fixed_wing():
			_begin_takeoff()
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
	board_target = null
	drop_set = false
	resupplying = false
	retreating = false                    # a direct order from the player ends a fall-back
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
	if shadow != null:
		shadow.queue_free()
		shadow = null
	var tex := SpriteLib.get_texture(str(def.get("sprite", id)), str(def.get("shape", "box")))
	var s := float(def.get("size", 32)) * GameData.sprite_scale() / maxf(float(tex.get_width()), 1.0)
	_base_scale = Vector2(s, s)
	# the drop shadow is a plain sprite (no per-frame redraw of the whole unit)
	if domain != "water" and domain != "sub" and not is_trap():
		var air := layer == "air"
		shadow = Sprite2D.new()
		shadow.texture = tex
		shadow.scale = _base_scale
		shadow.position = Vector2(9.0, 16.0) if air else Vector2(2.5, 4.0)
		shadow.modulate = Color(0, 0, 0, 0.26 if air else 0.38)
		shadow.rotation = desired_angle if rotates else facing
		add_child(shadow)
	sprite = Sprite2D.new()
	sprite.texture = tex
	sprite.scale = _base_scale
	_tint = SpriteLib.team_tint(team)
	sprite.modulate = _tint
	_last_mod = Color(-1, -1, -1, -1)
	sprite.rotation = desired_angle if rotates else facing
	add_child(sprite)


func refresh_sprite() -> void:
	build_sprite()
	_drawn_hp = -1.0


func _process(delta: float) -> void:
	if dead:
		return
	if battle != null and battle.prep:
		_prep_tick()
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
	_tick_abilities(delta)
	_tick_logistics(delta)
	if sprite != null:
		var mod := _tint.lerp(Color(2, 2, 2), flash * 0.6) if flash > 0.0 else _tint
		if layer == "sub":
			mod.a = 0.6
		if is_trap():
			mod.a = 0.95 if team == 0 else 0.3      # enemy mines are barely visible
		if mod != _last_mod:
			_last_mod = mod
			sprite.modulate = mod
		if rotates:
			if is_fixed_wing():
				sprite.rotation = heading            # the flight model already turns smoothly
				sprite.scale = Vector2(_base_scale.x, _base_scale.y * (1.0 - 0.24 * absf(bank)))
			else:
				sprite.rotation = lerp_angle(sprite.rotation, desired_angle, minf(1.0, delta * 9.0))
		if shadow != null:
			shadow.rotation = sprite.rotation
			shadow.scale = sprite.scale
	_maybe_redraw()


## Units only redraw when something visible changed (hp, selection line, wake, ammo pip...), not every frame.
func _maybe_redraw() -> void:
	var off := not online()
	var mv := vel.length_squared() > 1.0
	var mark := mark_t > 0.0
	var am := int(ammo) if ammo_max >= 0.0 else -1
	var redraw_self: bool = flash > 0.0 or off != _drawn_off or mark != _drawn_mark or _drawn_hp < 0.0 \
		or (mv and (selected or domain == "water" or domain == "sub"))
	if redraw_self or hp != _drawn_hp or am != _drawn_ammo:
		_drawn_hp = hp
		_drawn_off = off
		_drawn_mark = mark
		_drawn_ammo = am
		if redraw_self:
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
	if sieged:
		r *= 1.25
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
	if parked:
		target = null
		return
	if _speed() > 0.0 and (not bool(def.get("strafe", false)) or flight == "bomber"):
		_update_goal()
	var rng := _range()
	if rng <= 0.0 or float(def.get("damage", 0.0)) <= 0.0 or not online() or not has_ammo():
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
	var indirect: bool = str(def.get("role", "")) == "artillery" or layer == "air"
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
		if team == 0 and not c.spotted:
			continue                               # fog of war: you cannot shoot what nobody has seen
		var d := position.distance_to(c.position) - c.radius
		if d > sight or d < min_rng:
			continue
		if d > 80.0 and c.layer == "ground" and not indirect and battle.in_smoke(c.position, c.team):
			continue                               # hidden by a smoke screen
		if water_only and not c.in_water():
			continue                           # torpedoes and shore guns only fire at things in the water
		if d > rng:
			if walker and c.in_water():
				continue                       # land units don't chase targets out at sea
			if swimmer and not c.in_water() and c.coast_dist(draft) > rng - 8.0:
				continue                       # inland target that no ship can reach
		var stealth := float(c.def.get("stealth", 0.0))
		if stealth > 0.0 and d > rng * stealth and not battle.is_detected(team, c):
			continue                           # stealth aircraft are only seen up close (or by radar)
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
	if retreating:
		goal_pos = repair_spot
		return
	if resupplying:
		goal_pos = supply_spot
		return
	if order == "board":
		goal_pos = position if board_target == null or not is_instance_valid(board_target) else board_target.position
		return
	if is_logistics():
		goal_pos = _truck_goal()
		return
	if is_transport():
		goal_pos = _transport_goal()
		return
	if bool(def.get("scout", false)):
		goal_pos = _scout_goal()
		return
	if def.has("aura") and bool(def.get("follow", false)):
		goal_pos = _follow_goal()
	elif def.has("heal") and bool(def.get("follow", false)):
		goal_pos = _support_goal()
	elif domain == "water" or domain == "sub":
		goal_pos = battle.naval_goal(team, position, _range(), draft)
	else:
		goal_pos = battle.objective_for(team, position, layer == "ground" and domain == "land" and str(def.get("role", "")) != "artillery")


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
	if is_fixed_wing():
		_fly(delta, speed)
		return
	if order == "board":
		if board_target == null or not is_instance_valid(board_target) or board_target.dead or board_target.free_seats() <= 0:
			board_target = null
			order = "auto" if (team == 1 or (battle != null and battle.stance == "assault")) else "hold"
			return
		var bd := position.distance_to(board_target.position)
		if bd <= radius + board_target.radius + float(GameData.logi("transport", "board_range", 26.0)):
			board_target.load_passenger(self)
			return
		_move_toward(board_target.position, speed, delta)
		return
	if resupplying and speed > 0.0 and layer != "air":
		if position.distance_to(supply_spot) > 70.0:
			_move_toward(supply_spot, speed, delta)
		return
	if def.get("strafe", false):
		_strafe(delta, speed)
		if target != null and is_instance_valid(target) and not target.dead:
			_try_fire()
		return
	if retreating and speed > 0.0:
		if position.distance_to(repair_spot) > 80.0:
			_move_toward(repair_spot, speed, delta)
		if target != null and is_instance_valid(target) and not target.dead:
			if position.distance_to(target.position) - target.radius <= rng:
				_try_fire()
		return
	if order == "move" and speed > 0.0:
		if position.distance_to(order_pos) < 22.0:
			order = "hold"
			if drop_set:
				drop_set = false
				unload_all()
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
		if ((def.has("heal") or def.has("aura")) and bool(def.get("follow", false))) or is_logistics() or is_transport():
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
		# convoys: long trips take the roads when that is clearly faster than driving cross-country
		if level == 4 and road_mult > 1.3 and position.distance_to(goal) > 520.0:
			var rp := RoadNet.route(position, goal, road_mult / maxf(off_mult, 0.1))
			if rp.size() > 1:
				path = _road_path(rp, goal)
	if path.size() == 0:
		return goal
	var last := path.size() - 1
	while path_i < last and position.distance_to(path[path_i]) < 20.0:
		path_i += 1
	if level >= 4 and path_i >= last and position.distance_to(path[last]) < 20.0:
		return goal
	return path[path_i]


## Cross-country leg to the first road node, the road itself, then the cross-country leg to the goal.
func _road_path(rp: PackedVector2Array, goal: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var first: Vector2 = rp[0]
	if not Water.line_clear(position, first, 4):
		out.append_array(Water.find_path(position, first, 4))
	out.append_array(rp)
	var last: Vector2 = rp[rp.size() - 1]
	if not Water.line_clear(last, goal, 4):
		out.append_array(Water.find_path(last, goal, 4))
	return out


func _terrain_speed() -> float:
	match domain:
		"land":
			if layer == "air":
				return 1.0
			var tm := Water.speed_mult(position, cls == "infantry")
			if RoadNet.on_road(position):
				return tm * road_mult
			return tm * off_mult
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
	if ammo_max >= 0.0:
		if ammo < 1.0:
			return
		ammo -= 1.0
	cooldown_t = float(def.get("cooldown", 1.0)) * randf_range(0.95, 1.08)
	reveal_t = 2.5
	if target.cls == "infantry" and abilities.has("suppress"):
		target.slow_m = 0.5
		target.slow_t = 0.9
	if bool(def.get("kamikaze", false)):
		_kamikaze()
		return
	if not def.get("strafe", false) and not is_fixed_wing():
		desired_angle = (target.position - position).angle()
	battle.fire_projectile(self, target)


func _kamikaze() -> void:
	var vsd: Dictionary = def.get("vs", {})
	battle.explode(position, float(def.get("splash", 50.0)), float(def.get("damage", 100.0)), team,
		["ground"], 0.5, false, float(def.get("pierce", 0.0)), vsd)
	die(-1)


# ---------------------------------------------------------- v6: facing, abilities, scouting

func can_rotate() -> bool:
	return not rotates and kind != "unit" and kind != "base" and kind != "strategic" and not is_trap()


func set_facing(a: float) -> void:
	facing = wrapf(a, -PI, PI)
	if sprite != null and not rotates:
		sprite.rotation = facing
	queue_redraw()


## While the preparation phase runs the world is frozen: only keep the picture up to date.
func _prep_tick() -> void:
	if sprite != null:
		sprite.modulate = SpriteLib.team_tint(team)
		if not rotates:
			sprite.rotation = facing
		else:
			sprite.rotation = lerp_angle(sprite.rotation, desired_angle, 0.5)
	_maybe_redraw()


func can_use(id: String) -> bool:
	if dead or not abilities.has(id) or not Abilities.is_active(id):
		return false
	if id == "unload" and passengers.is_empty():
		return false
	return float(ab_cd.get(id, 0.0)) <= 0.0


## The first active ability this unit has (what the Z key triggers).
func primary_active() -> String:
	for a in abilities:
		if Abilities.is_active(str(a)):
			return str(a)
	return ""


func use_ability(id: String) -> bool:
	if not can_use(id):
		return false
	match id:
		"smoke":
			battle.add_smoke(position, team, float(def.get("smoke_radius", 105.0)))
			if team == 0:
				Sfx.play("smoke", -6.0, 0.3)
				Radio.say("smoke", {"unit": self})
		"fortify":
			var nd: Dictionary = GameData.def_for(team, "structure", "sandbag_nest")
			if nd.is_empty():
				return false
			var p := position + Vector2.from_angle(desired_angle) * (radius + 26.0)
			if not battle.can_place_structure(p, float(nd.get("size", 36)) * 0.34 * GameData.sprite_scale()):
				return false
			if battle.unit_count(team, true) >= int(GameData.settings.get("structure_cap", 30)):
				return false
			var n: Combatant = battle.spawn_entity("structure", "sandbag_nest", team, p)
			if n == null:
				return false
			if team == 0:
				Sfx.play("dig", -6.0, 0.2)
				Radio.say("fortify", {"unit": self})
		"unload":
			if passengers.is_empty():
				return false
			unload_all()
		_:
			return false
	ab_cd[id] = float(Abilities.INFO[id].get("cd", 20.0))
	return true


func _tick_abilities(delta: float) -> void:
	if reveal_t > 0.0:
		reveal_t -= delta
	if mark_t > 0.0:
		mark_t -= delta
	if scout_wp_t > 0.0:
		scout_wp_t -= delta
	if abilities.is_empty():
		return
	for k in ab_cd.keys():
		ab_cd[k] = maxf(0.0, float(ab_cd[k]) - delta)
	if vel.length_squared() < 1.0:
		still_t += delta
	else:
		still_t = 0.0
	var want_dig := abilities.has("dig_in") and still_t >= 2.5
	if want_dig != dug_in:
		dug_in = want_dig
		queue_redraw()
	var want_siege := abilities.has("siege") and still_t >= 3.0
	if want_siege != sieged:
		sieged = want_siege
		queue_redraw()
	ab_t -= delta
	if ab_t > 0.0:
		return
	ab_t = 0.5
	_scan_abilities()


func _scan_abilities() -> void:
	# smoke: pop it when hurt and in a fight (the player can also press Z)
	if abilities.has("smoke") and target != null and hp < max_hp * 0.55 and can_use("smoke"):
		use_ability("smoke")
	# engineers on the enemy side fortify automatically
	if team == 1 and abilities.has("fortify") and can_use("fortify") and target == null and vel.length_squared() < 1.0:
		var ne: Array = battle.near_team(0, position, 600.0)
		if not ne.is_empty():
			use_ability("fortify")
	# designate: paint the nearest enemies
	if abilities.has("designate") and online():
		var rad := float(def.get("mark_radius", 0.0))
		if rad <= 0.0:
			rad = vision * 0.65 if bool(def.get("scout", false)) else minf(maxf(_range(), 0.0), 320.0)
		if rad <= 0.0:
			rad = vision * 0.5
		var painted := 0
		for n in battle.near_team(1 - team, position, rad):
			var c := n as Combatant
			if c == null or c.dead or c.layer == "missile" or c.is_trap() or c.kind == "base":
				continue
			if position.distance_to(c.position) > rad:
				continue
			c.mark_t = 2.2
			painted += 1
			if painted >= 3:
				break
	# withdraw: fall back when badly hurt, get repaired, return
	if abilities.has("withdraw") and kind == "unit":
		if not retreating:
			if hp < max_hp * 0.28 and (team == 1 or order == "auto"):
				var spot: Vector2 = battle.repair_spot_for(self)
				if spot.distance_to(position) > 120.0:
					retreating = true
					repair_spot = spot
					target = null
					if overlay != null:
						overlay.queue_redraw()
					if team == 0:
						Radio.say("retreat", {"unit": self})
		else:
			if position.distance_to(repair_spot) < 170.0:
				hp = minf(max_hp, hp + max_hp * 0.07)
				if hp >= max_hp * 0.85:
					retreating = false
					if team == 0:
						Radio.say("repaired", {"unit": self})
					if overlay != null:
						overlay.queue_redraw()
			elif hp >= max_hp * 0.85:
				retreating = false


## Scouts roam the enemy half of the map on their own (patrol points ahead of the army).
func _scout_goal() -> Vector2:
	if scout_wp == Vector2.ZERO or position.distance_to(scout_wp) < maxf(80.0, float(def.get("turn_radius", 0.0)) * 1.15) or scout_wp_t <= 0.0:
		scout_wp = battle.next_scout_waypoint(team, position)
		scout_wp_t = 30.0
	return scout_wp


# ------------------------------------------------------------------ v7: ammo, supply, transport, drive

func _derive_drive() -> String:
	if def.has("drive"):
		return str(def["drive"])
	if layer == "air":
		return "air"
	if domain == "water" or domain == "sub":
		return "ship"
	if cls == "infantry" or domain == "amphib":
		return "foot"
	return "tracked"


func has_ammo() -> bool:
	return ammo_max < 0.0 or ammo >= 1.0


func ammo_frac() -> float:
	if ammo_max <= 0.0:
		return 1.0
	return clampf(ammo / ammo_max, 0.0, 1.0)


func is_logistics() -> bool:
	return kind == "unit" and str(def.get("role", "")) == "logistics"


func is_transport() -> bool:
	return kind == "unit" and str(def.get("role", "")) == "transport"


func speed_known() -> bool:
	return _speed() > 0.0


func road_speed() -> float:
	return _speed() * road_mult


func off_speed() -> float:
	return _speed() * off_mult


func is_fixed_wing() -> bool:
	return layer == "air" and flight != "" and flight != "heli"


func free_seats() -> int:
	return maxi(0, seats - passengers.size())


func supply_radius() -> float:
	var sp: Variant = def.get("supply", null)
	if typeof(sp) == TYPE_DICTIONARY:
		var spd: Dictionary = sp
		return float(spd.get("radius", 250.0))
	if supply_max > 0.0:
		return float(def.get("supply_radius", 160.0))
	return 0.0


func supply_rate() -> float:
	var sp: Variant = def.get("supply", null)
	if typeof(sp) == TYPE_DICTIONARY:
		var spd: Dictionary = sp
		return float(spd.get("rate", 0.07))
	return float(GameData.logi("ammo", "reload_rate", 0.07))


func can_supply() -> bool:
	if dead or is_queued_for_deletion() or parked:
		return false
	if def.has("supply"):
		return online()
	return supply_max > 0.0 and supply >= 1.0


## True for buildings / carriers that restock and rearm (not supply trucks).
func is_depot() -> bool:
	return def.has("supply") and supply_max <= 0.0


func order_board(t: Combatant) -> void:
	if not can_take_orders() or cls != "infantry" or t == null or t == self:
		return
	order = "board"
	board_target = t
	retreating = false
	resupplying = false
	path = PackedVector2Array()
	path_t = 0.0
	target = null


func load_passenger(c: Combatant) -> bool:
	if c == null or c.dead or free_seats() <= 0 or c.kind != "unit" or c.cls != "infantry":
		return false
	passengers.append({"id": c.id, "hp": c.hp, "ammo": c.ammo})
	cargo_loaded = true
	c.silent_remove()
	if overlay != null:
		overlay.queue_redraw()
	if team == 0:
		Sfx.play("click", -9.0, 0.05)
	return true


## Removes a unit without death effects (it boarded a vehicle).
func silent_remove() -> void:
	if dead:
		return
	dead = true
	selected = false
	queue_free()


## Puts every passenger on the ground around the vehicle. Returns how many got out.
func unload_all() -> int:
	if passengers.is_empty() or battle == null:
		return 0
	var cap := int(GameData.settings.get("unit_cap", 90))
	var remaining: Array = []
	var n := 0
	for p in passengers:
		var pd: Dictionary = p
		if battle.unit_count(team, false) >= cap:
			remaining.append(pd)
			continue
		var off := Vector2.from_angle(randf() * TAU) * (radius + 16.0 + randf() * 12.0)
		var u: Combatant = battle.spawn_entity("unit", str(pd.get("id", "rifleman")), team, position + off)
		if u == null:
			continue
		var ph := float(pd.get("hp", -1.0))
		if ph > 0.0:
			u.hp = minf(u.max_hp, ph)
		var pa := float(pd.get("ammo", -1.0))
		if pa >= 0.0 and u.ammo_max >= 0.0:
			u.ammo = minf(u.ammo_max, pa)
		u.board_cd = 6.0
		n += 1
	passengers = remaining
	cargo_loaded = not passengers.is_empty()
	if n > 0 and team == 0:
		Radio.say("dropoff", {"unit": self})
	if overlay != null:
		overlay.queue_redraw()
	return n


## The vehicle is destroyed: some riders get out wounded, the rest die with it.
func release_passengers_on_death() -> void:
	if passengers.is_empty() or battle == null:
		return
	var chance := float(def.get("survive", GameData.logi("transport", "survive_chance", 0.55)))
	if layer == "air":
		chance = float(GameData.logi("transport", "heli_survive_chance", 0.12))
	var cap := int(GameData.settings.get("unit_cap", 90))
	for p in passengers:
		var pd: Dictionary = p
		if randf() > chance or battle.unit_count(team, false) >= cap:
			continue
		var u: Combatant = battle.spawn_entity("unit", str(pd.get("id", "rifleman")), team,
			position + Vector2(randf_range(-24.0, 24.0), randf_range(-24.0, 24.0)))
		if u != null:
			u.hp = maxf(u.max_hp * 0.35, 1.0)
			u.board_cd = 6.0
	passengers = []
	cargo_loaded = false


func _tick_logistics(delta: float) -> void:
	if kind != "unit" or battle == null:
		return
	if board_cd > 0.0:
		board_cd -= delta
	logi_t -= delta
	if logi_t > 0.0:
		return
	var dt := 0.5
	logi_t = dt
	if parked:
		return
	var srcs: Array = battle.supply_sources(team)
	var supplied_now := false
	# 1. receive ammunition from depots and supply trucks around us
	if ammo_max >= 0.0 and layer != "air":
		for sn in srcs:
			var s := sn as Combatant
			if s == null or s == self or not s.can_supply():
				continue
			if position.distance_to(s.position) > s.supply_radius() + s.radius:
				continue
			supplied_now = true
			if ammo >= ammo_max:
				break
			var give := minf(ammo_max * s.supply_rate() * dt, ammo_max - ammo)
			if s.supply_max > 0.0:
				var cost := GameData.supply_cost(cls) * give / maxf(ammo_max, 1.0)
				if cost > s.supply:
					give *= s.supply / maxf(cost, 0.001)
					cost = s.supply
				s.supply -= cost
			ammo += give
			break
	if ammo_max >= 0.0 and layer != "air" and not supplied_now and ammo < ammo_max and battle.in_owned_sector(team, position):
		supplied_now = true
		ammo = minf(ammo_max, ammo + ammo_max * 0.025 * dt)
	# 2. trucks and helicopters refill at depots
	if supply_max > 0.0 and supply < supply_max:
		for sn in srcs:
			var d := sn as Combatant
			if d == null or d == self or not d.is_depot() or not d.can_supply():
				continue
			if position.distance_to(d.position) <= d.supply_radius() + d.radius:
				supply = minf(supply_max, supply + float(def.get("supply_rate", 40.0)) * dt)
				break
	# 3. low on ammunition: free-roaming units walk back to a supply point
	if ammo_max >= 0.0 and layer != "air" and _speed() > 0.0:
		var f := ammo_frac()
		var low := float(GameData.logi("ammo", "low_fraction", 0.25))
		if f < low and team == 0 and not low_ammo_said:
			low_ammo_said = true
			Radio.say("low_ammo", {"unit": self})
		elif f > 0.6:
			low_ammo_said = false
		if resupplying:
			supply_spot = battle.supply_spot_for(self)
			if f >= 0.85 or order != "auto" and team == 0:
				resupplying = false
		elif f < low and not supplied_now and (order == "auto" or team == 1) and not retreating and not is_logistics() and not is_transport():
			resupplying = true
			supply_spot = battle.supply_spot_for(self)
			target = null
	# 4. auto transports shuttle infantry; APCs dismount their squad when a fight starts
	if order == "auto" and kind == "unit":
		if is_transport():
			_tick_transport(dt)
		elif not passengers.is_empty() and seats > 0 and not is_logistics():
			if target != null and is_instance_valid(target) and not target.dead:
				if position.distance_to(target.position) < _range() + 80.0:
					unload_all()


func _tick_transport(dt: float) -> void:
	var dism := float(GameData.logi("transport", "dismount_range", 330.0))
	var wait := float(GameData.logi("transport", "wait_for_load", 18.0))
	match tr_state:
		"load":
			load_wait -= dt
			battle.recruit_riders(self)
			if passengers.size() >= seats or (load_wait <= 0.0 and not passengers.is_empty()):
				tr_state = "go"
			elif load_wait <= 0.0:
				load_wait = wait
		"go":
			if passengers.is_empty():
				tr_state = "return"
			else:
				var contact := false
				for n in battle.near_team(1 - team, position, 380.0):
					var c := n as Combatant
					if c != null and not c.dead and not c.is_trap():
						contact = true
						break
				if contact or position.distance_to(goal_pos) < dism:
					unload_all()
					tr_state = "return"
		"return":
			if position.distance_to(battle.base_pos(team)) < 460.0:
				tr_state = "load"
				load_wait = wait


func _transport_goal() -> Vector2:
	match tr_state:
		"go":
			return battle.objective_for(team, position, layer == "ground" and domain == "land" and str(def.get("role", "")) != "artillery")
		"return":
			return battle.base_pos(team) + Vector2(260.0 if team == 0 else -260.0, 0.0)
	return position


## Supply trucks: refill at a depot when low, otherwise drive to the neediest friendly unit, else trail the army.
func _truck_goal() -> Vector2:
	var depot: Combatant = null
	var depot_d := INF
	for sn in battle.supply_sources(team):
		var d := sn as Combatant
		if d == null or d == self or not d.is_depot() or d.dead or d.layer == "air":
			continue
		var dd := position.distance_to(d.position)
		if dd < depot_d:
			depot_d = dd
			depot = d
	var low_t := float(GameData.logi("ammo", "truck_refill_below", 0.2)) * supply_max
	if supply < low_t and depot != null:
		return depot.position
	var rad := float(GameData.logi("ammo", "truck_search_radius", 1900.0))
	var needy: Combatant = null
	var nd := INF
	var front: Combatant = null
	var front_v := -INF
	var dirx := 1.0 if team == 0 else -1.0
	for n in get_tree().get_nodes_in_group("team%d" % team):
		var c := n as Combatant
		if c == null or c == self or c.dead or c.kind != "unit" or c.layer != "ground" or c.domain != "land":
			continue
		if c.is_logistics() or c.is_transport() or c._speed() <= 0.0:
			continue
		var v := c.position.x * dirx
		if v > front_v:
			front_v = v
			front = c
		if c.ammo_max >= 0.0 and c.ammo_frac() < 0.55:
			var d2 := position.distance_to(c.position)
			if d2 < nd and d2 < rad:
				nd = d2
				needy = c
	if needy != null and supply > 20.0:
		return needy.position
	if depot != null and supply < supply_max * 0.9:
		return depot.position
	if front != null:
		return front.position - Vector2(dirx * 150.0, 0.0)
	return position


# ------------------------------------------------------------------ v7: flight model

func _begin_takeoff() -> void:
	fl_mode = "takeoff"
	fl_t = float(GameData.logi("flight", "takeoff_time", 1.4))
	heading = 0.0 if team == 0 else PI
	fspeed = _speed() * 0.35
	desired_angle = heading


func _tick_parked(delta: float) -> void:
	rearm_left -= delta
	hp = minf(max_hp, hp + max_hp * 0.08 * delta)
	if rearm_left <= 0.0:
		parked = false
		modulate.a = 1.0
		ammo = ammo_max
		hp = max_hp
		_begin_takeoff()
		if overlay != null:
			overlay.queue_redraw()


func _park_at(p: Vector2) -> void:
	parked = true
	position = p
	target = null
	fl_mode = "rearm"
	rearm_left = float(def.get("rearm_time", GameData.logi("flight", "default_rearm_time", 10.0)))
	modulate.a = 0.0
	selected = false
	if team == 0:
		Radio.say("rearm", {"unit": self})


func _fly(delta: float, top: float) -> void:
	if parked:
		_tick_parked(delta)
		return
	var turn_r := maxf(float(def.get("turn_radius", 160.0)), 40.0)
	var cones: Dictionary = GameData.logistics.get("flight", {}).get("gun_cone_deg", {})
	var minf_ := float(GameData.logi("flight", "min_speed_factor", 0.72))
	var scouting := bool(def.get("scout", false))
	var tight := 1.0
	var aim := position + Vector2.from_angle(heading) * 400.0
	var has_target := target != null and is_instance_valid(target) and not target.dead
	# --- return to base when out of ammunition or badly hurt
	if fl_mode != "rtb" and fl_mode != "takeoff" and not scouting and flight != "drone" and ammo_max >= 0.0:
		var bingo := float(GameData.logi("flight", "bingo_hp", 0.35))
		if ammo < 1.0 or hp < max_hp * bingo:
			fl_mode = "rtb"
			fl_goal = battle.rearm_point(team, position)
			fl_t = 0.0
			target = null
			has_target = false
	match fl_mode:
		"takeoff":
			fl_t -= delta
			aim = position + Vector2.from_angle(heading) * 500.0
			if fl_t <= 0.0:
				fl_mode = "ingress"
		"rtb":
			fl_t -= delta
			if fl_t <= 0.0:
				fl_t = 1.0
				fl_goal = battle.rearm_point(team, position)
			aim = fl_goal
			if position.distance_to(fl_goal) < maxf(turn_r * 0.5, 90.0):
				_park_at(fl_goal)
				return
		"extend":
			fl_t -= delta
			aim = position + Vector2.from_angle(heading) * 600.0
			if fl_t <= 0.0:
				fl_mode = "ingress"
		_:
			var ordered := order == "move" or order == "attack_move" or order == "hold"
			if flight == "orbit":
				if has_target:
					var tp := target.position
					var off := position - tp
					if off.length() > turn_r * 1.6:
						aim = tp
					else:
						aim = tp + Vector2.from_angle(off.angle() + 0.6) * turn_r
				else:
					aim = _loiter_aim(_air_goal(ordered), turn_r)
			elif flight == "bomber":
				aim = _air_goal(ordered)
				var tov := aim - position
				var past := absf(angle_difference(heading, tov.angle())) > deg_to_rad(100.0) and tov.length() < turn_r * 2.2
				if tov.length() < 70.0 or past:
					fl_mode = "extend"
					fl_t = turn_r * 2.4 / maxf(fspeed, 60.0)
					goal_pos = battle.pick_bombing_goal(team, position)
			elif has_target:
				var tvv := target.position + target.vel * 0.35
				aim = tvv
				var to_t := tvv - position
				var aerr := absf(angle_difference(heading, to_t.angle()))
				if flight == "drone":
					tight = 2.2 if (to_t.length() < turn_r * 1.5 and aerr > 0.8) else 1.0
				elif to_t.length() < turn_r * 1.5 and aerr > deg_to_rad(75.0):
					fl_mode = "extend"
					fl_t = turn_r * 2.3 / maxf(fspeed, 60.0)
			else:
				aim = _loiter_aim(_air_goal(ordered), turn_r)
	# --- keep inside the theatre
	var m := 140.0
	if position.x < -m or position.x > float(battle.W) + m or position.y < float(Water.Y_MIN) - m or position.y > float(Water.Y_MAX) + m:
		aim = Vector2(float(battle.W) * 0.5, Water.MID_Y)
	# --- steering with a turn-rate limit (v / R): wide turns for big aircraft, instant reversals are impossible
	var desired := (aim - position).angle()
	var diff := angle_difference(heading, desired)
	var max_turn := fspeed / turn_r * tight
	var step := clampf(diff, -max_turn * delta, max_turn * delta)
	heading = wrapf(heading + step, -PI, PI)
	bank = lerpf(bank, clampf(step / maxf(delta, 0.001) / 2.2, -1.0, 1.0), minf(1.0, delta * 5.0))
	var goal_speed := top * lerpf(1.0, minf_, clampf(absf(bank), 0.0, 1.0) * 0.6)
	if fl_mode == "takeoff":
		goal_speed = top
	fspeed = move_toward(fspeed, goal_speed, top * 0.5 * delta)
	vel = Vector2.from_angle(heading) * fspeed
	position += vel * delta
	desired_angle = heading
	# --- guns / bombs: only inside the weapon cone, so aircraft have to line up their passes
	if has_target and fl_mode != "rtb" and fl_mode != "takeoff":
		var tv := target.position - position
		var dd := tv.length() - target.radius
		var cone := deg_to_rad(float(cones.get(flight, 20.0)))
		if dd <= _range() and (cone >= TAU - 0.01 or absf(angle_difference(heading, tv.angle())) <= cone * 0.5):
			_try_fire()


func _air_goal(ordered: bool) -> Vector2:
	if ordered:
		return order_pos
	return goal_pos


## Holding pattern: fly a circle around the point instead of hovering on it.
func _loiter_aim(p: Vector2, turn_r: float) -> Vector2:
	var off := position - p
	if off.length() > turn_r * 1.5:
		return p
	return p + Vector2.from_angle(off.angle() + 0.7) * turn_r


# ------------------------------------------------------------------- damage

## `pierce` is subtracted from armor for this hit (armor-piercing weapons).
func take_damage(amount: float, source_team: int, pierce: float = 0.0) -> void:
	if dead:
		return
	if mark_t > 0.0:
		amount *= 1.25
	var eff_armor := maxf(armor + (3.0 if dug_in else 0.0) - pierce, 0.0)
	var dmg := maxf(amount * 0.2, amount - eff_armor)
	if dug_in:
		dmg *= 0.8
	hp -= dmg
	flash = 1.0
	if team == 0 and hp > 0.0 and battle != null:
		battle.note_hit(self)
	if hp <= 0.0:
		die(source_team)


func die(source_team: int) -> void:
	if dead:
		return
	dead = true
	release_passengers_on_death()
	battle.on_combatant_died(self, source_team)
	queue_free()


# ------------------------------------------------------------------- saving

func to_dict() -> Dictionary:
	return {"t": kind, "id": id, "team": team, "x": position.x, "y": position.y,
		"hp": hp, "cd": cooldown_t, "rot": desired_angle, "sdir": strafe_dir, "lane": lane_y, "st": spawn_t,
		"ord": order, "ox": order_pos.x, "oy": order_pos.y,
		"face": facing, "cl": cargo_loaded, "pb": prep_bought, "exp": explored,
		"am": ammo, "sup": supply, "ps": passengers, "hd": heading, "fm": fl_mode, "pk": parked, "rl": rearm_left, "tr": tr_state}


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
	facing = float(d.get("face", facing))
	cargo_loaded = bool(d.get("cl", false))
	if d.has("ps"):
		var psv: Variant = d["ps"]
		if typeof(psv) == TYPE_ARRAY:
			passengers = psv
	cargo_loaded = not passengers.is_empty()
	if d.has("am"):
		ammo = float(d["am"])
	supply = float(d.get("sup", supply))
	heading = float(d.get("hd", desired_angle))
	tr_state = str(d.get("tr", "load"))
	if is_fixed_wing():
		fspeed = _speed()
		fl_mode = str(d.get("fm", "ingress"))
		if fl_mode == "takeoff":
			fl_mode = "ingress"
		parked = bool(d.get("pk", false))
		rearm_left = float(d.get("rl", 0.0))
		if parked:
			modulate.a = 0.0
	prep_bought = bool(d.get("pb", false))
	explored = bool(d.get("exp", false))
	if sprite != null:
		sprite.rotation = desired_angle if rotates else facing


# ------------------------------------------------------------------- drawing

func _draw() -> void:
	var tcol := SpriteLib.team_color(team)
	if is_trap():
		if team == 0:
			var cfg: Dictionary = def.get("trap", {})
			var tr := float(cfg.get("slow", {}).get("radius", cfg.get("radius", 20.0)))
			draw_arc(Vector2.ZERO, tr, 0.0, TAU, 24, Color(tcol, 0.35), 1.0)
		return
	if parked:
		return
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
	if dug_in:
		draw_arc(Vector2.ZERO, radius + 8.0, PI * 0.15, PI * 0.85, 8, Color(MilTheme.AMBER, 0.7), 2.0)
		draw_arc(Vector2.ZERO, radius + 8.0, PI * 1.15, PI * 1.85, 8, Color(MilTheme.AMBER, 0.7), 2.0)
	if sieged:
		MilTheme.draw_brackets(self, Rect2(Vector2(-radius, -radius), Vector2(radius, radius) * 2.0), Color(MilTheme.AMBER, 0.6), 5.0, 1.4)
	if mark_t > 0.0:
		draw_arc(Vector2.ZERO, radius + 5.0, 0.0, TAU, 20, Color(MilTheme.BAD, 0.85), 1.5)
		draw_line(Vector2(-radius - 9.0, 0), Vector2(-radius - 2.0, 0), Color(MilTheme.BAD, 0.9), 1.5)
		draw_line(Vector2(radius + 9.0, 0), Vector2(radius + 2.0, 0), Color(MilTheme.BAD, 0.9), 1.5)
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
	if parked:
		return
	if kind == "unit" and (selected or (ammo_max >= 0.0 and ammo_frac() < 0.25 and team == 0)):
		var bw := maxf(radius * 2.0, 28.0)
		var by := -(radius + 12.0) + 7.0
		if ammo_max >= 0.0:
			var af := ammo_frac()
			ci.draw_rect(Rect2(-bw * 0.5, by, bw, 3.0), Color(0, 0, 0, 0.7))
			ci.draw_rect(Rect2(-bw * 0.5, by, bw * af, 3.0), Color(0.95, 0.78, 0.25) if af > 0.25 else Color(0.95, 0.3, 0.2))
			by += 5.0
		if supply_max > 0.0:
			ci.draw_rect(Rect2(-bw * 0.5, by, bw, 3.0), Color(0, 0, 0, 0.7))
			ci.draw_rect(Rect2(-bw * 0.5, by, bw * clampf(supply / supply_max, 0.0, 1.0), 3.0), Color(0.4, 0.75, 0.95))
	var font := MilTheme.font_bold()
	if seats > 0 and kind == "unit" and (selected or not passengers.is_empty()):
		var seat_txt := "%d/%d" % [passengers.size(), seats]
		var sp := Vector2(-20.0, radius + 14.0)
		ci.draw_string_outline(font, sp, seat_txt, HORIZONTAL_ALIGNMENT_CENTER, 40.0, 11, 4, Color(0, 0, 0, 0.9))
		ci.draw_string(font, sp, seat_txt, HORIZONTAL_ALIGNMENT_CENTER, 40.0, 11, Color(0.85, 0.95, 1.0))
	if resupplying:
		var rw2 := 110.0
		var rp3 := Vector2(-rw2 * 0.5, -(radius + 24.0))
		ci.draw_string_outline(font, rp3, "RESUPPLYING", HORIZONTAL_ALIGNMENT_CENTER, rw2, 10, 4, Color(0, 0, 0, 0.9))
		ci.draw_string(font, rp3, "RESUPPLYING", HORIZONTAL_ALIGNMENT_CENTER, rw2, 10, Color(0.95, 0.78, 0.25))
	if kind == "national" or kind == "base":
		var lw := maxf(radius * 2.0 + 70.0, 110.0)
		var lp := Vector2(-lw * 0.5, radius + 17.0)
		var nm := str(def.get("name", id)).to_upper()
		ci.draw_string_outline(font, lp, nm, HORIZONTAL_ALIGNMENT_CENTER, lw, 12, 5, Color(0, 0, 0, 0.9))
		ci.draw_string(font, lp, nm, HORIZONTAL_ALIGNMENT_CENTER, lw, 12, tcol.lightened(0.5))
	if retreating:
		var rw := 110.0
		var rp2 := Vector2(-rw * 0.5, -(radius + 22.0))
		ci.draw_string_outline(font, rp2, "FALLING BACK", HORIZONTAL_ALIGNMENT_CENTER, rw, 10, 4, Color(0, 0, 0, 0.9))
		ci.draw_string(font, rp2, "FALLING BACK", HORIZONTAL_ALIGNMENT_CENTER, rw, 10, MilTheme.WARN)
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
