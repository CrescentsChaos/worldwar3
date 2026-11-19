class_name Battle
extends Node2D
## The battlefield. Owns money, countries, deployment, projectiles/explosions,
## the camera, the enemy AI and save / load. Team 0 = player (left), team 1 = enemy (right).
## Each side is a whole country: a capital plus cities, factories, airbases, silos...

const W := 6400
const H := 720
const FIELD_TOP := -240.0
const FIELD_BOTTOM := 1248.0
const BASE_MARGIN := 90.0
const AUTOSAVE_INTERVAL := 60.0
const ZOOM_MIN := 0.17
const ZOOM_MAX := 2.5

var units_root: Node2D
var proj_root: Node2D
var fx_root: Node2D
var terrain: TerrainLayer
var decals: DecalLayer

# --- command & control: production queues, selection, orders
var queues: Array = [[], []]                       # per team: [{id, prod, total, left, cost}]
var rally: Array = [Vector2(1250.0, 504.0), Vector2(5150.0, 504.0)]
var selected: Array = []                           # player Combatants under command
var order_marks: Array = []                        # [pos, age, color] feedback rings
var _box_active := false
var _box_moved := false
var _box_start := Vector2.ZERO
var _cmd_mode := ""                                # "" | "attack_move" | "rally"
var cam: Camera2D
var hud: HUD
var ai: AICommander
var auto_ai: AICommander                           # optional autopilot: buys units for the player
var stance := "assault"                            # army stance: assault (auto-advance) | defend | manual
var autopilot := false

# --- spatial grid: per team, cell -> combatants. Rebuilt 8x a second; makes targeting O(nearby) instead of O(all).
const GRID := 256.0
var _grid: Array = [{}, {}]
var _grid_t := 0.0

var money: Array = [0.0, 0.0]
var bases: Array = [null, null]
var strat_cd: Array = [{}, {}]
var deploy_cd: Array = [{}, {}]
var launched: Array = [0, 0]
var kills: Array = [0, 0]
var intercepted: Array = [0, 0]
var elapsed := 0.0
var difficulty := "normal"
var over := false
var sel_kind := ""
var sel_id := ""
var shake := 0.0
var autosave_t := AUTOSAVE_INTERVAL
var ai_income_mult := 1.0
var income_mult: Array = [1.0, 1.0]   # faction / strategy economy multipliers

var nat_start: Array = [0, 0]           # country buildings each side started with
var _caps: Array = [{}, {}]             # capability id -> count of living providers
var _income: Array = [4.0, 4.0]         # money per second (before the AI multiplier)
var _objectives: Array = [[], []]       # living capital + country buildings per team
var _nat_count: Array = [0, 0]
var _world_t := 0.0
var _drag_cam := false


func _ready() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	Water.ensure_built()
	Sfx.play_music("music_battle")
	Sfx.play_ambient("ambient_battle")
	terrain = TerrainLayer.new()
	add_child(terrain)
	terrain.setup_terrain()
	decals = DecalLayer.new()
	add_child(decals)
	var wave_fx := WaterFX.new()
	add_child(wave_fx)
	wave_fx.setup()
	units_root = Node2D.new()
	proj_root = Node2D.new()
	fx_root = Node2D.new()
	add_child(units_root)
	add_child(proj_root)
	add_child(fx_root)
	cam = Camera2D.new()
	add_child(cam)
	var z0 := clampf(float(GameData.settings.get("default_zoom", 1.0)), ZOOM_MIN, float(GameData.settings.get("zoom_max", ZOOM_MAX)))
	cam.zoom = Vector2(z0, z0)
	cam.position = Vector2(820.0, 520.0)
	cam.make_current()
	add_child(ScreenFX.new())
	hud = HUD.new()
	hud.battle = self
	add_child(hud)

	var loaded := false
	if SaveManager.pending_load != "":
		var slot := SaveManager.pending_load
		SaveManager.pending_load = ""
		loaded = deserialize(SaveManager.load_game(slot))
		if loaded:
			hud.toast("Loaded %s" % SaveManager.slot_label(slot))
	if not loaded:
		new_game(SaveManager.pending_difficulty)
	hud.rebuild_cards()


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	if get_tree() != null:
		get_tree().paused = false


# ------------------------------------------------------------------- camera

func focus_camera(world_pos: Vector2) -> void:
	if cam == null:
		return
	cam.position = world_pos
	_clamp_camera()


func _clamp_camera() -> void:
	var vp := get_viewport_rect().size
	var half := vp * 0.5 / cam.zoom.x
	var top := float(Water.Y_MIN) - 30.0
	var bottom := float(Water.Y_MAX) + 160.0
	var x := cam.position.x
	var y := cam.position.y
	if half.x * 2.0 >= float(W):
		x = float(W) * 0.5
	else:
		x = clampf(x, half.x, float(W) - half.x)
	if half.y * 2.0 >= bottom - top:
		y = (top + bottom) * 0.5
	else:
		y = clampf(y, top + half.y, bottom - half.y)
	cam.position = Vector2(x, y)


func _zoom_by(f: float) -> void:
	var z := clampf(cam.zoom.x * f, ZOOM_MIN, float(GameData.settings.get("zoom_max", ZOOM_MAX)))
	cam.zoom = Vector2(z, z)
	_clamp_camera()


func _update_camera(delta: float) -> void:
	if cam == null:
		return
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if dir != Vector2.ZERO:
		var spd := 1500.0 / cam.zoom.x * (2.4 if Input.is_key_pressed(KEY_SHIFT) else 1.0)
		cam.position += dir.normalized() * spd * delta
	_clamp_camera()
	if shake > 0.0:
		shake = maxf(0.0, shake - delta * 26.0)
		cam.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake
	elif cam.offset != Vector2.ZERO:
		cam.offset = Vector2.ZERO


# ------------------------------------------------------------------ new game

func new_game(diff: String) -> void:
	_clear_all()
	stance = str(GameData.settings.get("auto_stance", "assault"))
	autopilot = false
	if auto_ai != null:
		auto_ai.active = false
		auto_ai.queue.clear()
	difficulty = diff
	GameData.set_teams(SaveManager.pending_p_faction, SaveManager.pending_p_strategy,
		SaveManager.pending_e_faction, SaveManager.pending_e_strategy)
	income_mult = [GameData.income_mult(0), GameData.income_mult(1)]
	var S := GameData.settings
	var dd: Dictionary = S.get("difficulty", {}).get(diff, {})
	money = [float(S.get("start_money", 800)) * GameData.money_mult(0),
		float(dd.get("ai_start_money", S.get("start_money", 800))) * GameData.money_mult(1)]
	strat_cd = [{}, {}]
	deploy_cd = [{}, {}]
	launched = [0, 0]
	kills = [0, 0]
	intercepted = [0, 0]
	elapsed = 0.0
	over = false
	var mid_y := (FIELD_TOP + FIELD_BOTTOM) * 0.5
	bases[0] = spawn_entity("base", "hq", 0, Vector2(BASE_MARGIN, mid_y))
	bases[1] = spawn_entity("base", "hq", 1, Vector2(float(W) - BASE_MARGIN, mid_y))
	_build_country(0)
	_build_country(1)
	_refresh_world()
	nat_start = _nat_count.duplicate()
	_apply_setup(0)
	_apply_setup(1)
	_refresh_world()
	_setup_ai(diff)
	focus_camera(Vector2(820.0, 520.0))
	if str(GameData.team_faction[0]) != "":
		hud.toast("%s  vs  %s.  Destroy the enemy capital to win." % [GameData.team_label(0), GameData.team_label(1)])
	else:
		hud.toast("Defend your country, Commander. Destroy the enemy capital to win.")


## Places the pre-built country buildings. The enemy country is the same layout rotated 180 degrees.
func _build_country(team: int) -> void:
	for e in GameData.country:
		var id := str(e[0])
		var lx := float(e[1])
		var ly := float(e[2])
		var pos := Vector2(lx, ly)
		if team == 1:
			pos = Vector2(float(W) - lx, FIELD_TOP + FIELD_BOTTOM - ly)
		spawn_entity("national", id, team, pos)


## Free starting forces from the chosen strategy. Coordinates are in the team's own space
## (mirrored for the enemy); structures slide to the nearest free spot, ships snap to water.
func _apply_setup(team: int) -> void:
	var dirx := 1.0 if team == 0 else -1.0
	for e in GameData.setup_for(team):
		var kind := str(e[0])
		var id := str(e[1])
		var d: Dictionary = GameData.def_for(team, kind, id)
		if d.is_empty() or bool(d.get("banned", false)):
			continue
		var count := int(e[4]) if e.size() > 4 else 1
		for i in count:
			var pos := Vector2(float(e[2]), float(e[3]))
			if team == 1:
				pos = Vector2(float(W) - pos.x, FIELD_TOP + FIELD_BOTTOM - pos.y)
			pos += Vector2(-float(i % 4) * 22.0 * dirx, float(i / 4) * 24.0)
			pos.y = clampf(pos.y, FIELD_TOP + 14.0, FIELD_BOTTOM - 14.0)
			var dom := str(d.get("domain", "land"))
			if kind == "unit" and (dom == "water" or dom == "sub"):
				var wp := Water.nearest_water(pos, int(d.get("draft", 1)))
				if wp.x < -1000.0:
					continue
				pos = wp + Vector2(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0))
			elif kind == "structure":
				pos = _free_spot(d, pos)
				if pos.x < 0.0:
					continue
			spawn_entity(kind, id, team, pos)


func _free_spot(d: Dictionary, pos: Vector2) -> Vector2:
	var nr := float(d.get("size", 40)) * 0.42 * GameData.sprite_scale()
	for ring in 10:
		for k in 8:
			var p := pos + Vector2.from_angle(float(k) * TAU / 8.0) * float(ring) * 32.0
			p.y = clampf(p.y, FIELD_TOP + 20.0, FIELD_BOTTOM - 20.0)
			if can_place_structure(p, nr):
				return p
	return Vector2(-1.0, -1.0)


func _setup_ai(diff: String) -> void:
	if ai != null and is_instance_valid(ai):
		ai.queue_free()
	var dd: Dictionary = GameData.settings.get("difficulty", {}).get(diff, {})
	ai_income_mult = float(dd.get("ai_income_mult", 1.0))
	ai = AICommander.new()
	ai.battle = self
	ai.team = 1
	ai.configure(dd)
	add_child(ai)


func _clear_all() -> void:
	for root in [units_root, proj_root, fx_root]:
		if root == null:
			continue
		for c in root.get_children():
			if c is Combatant:
				c.dead = true
			c.queue_free()
	bases = [null, null]
	_objectives = [[], []]
	_caps = [{}, {}]
	if decals != null:
		decals.clear()
	queues = [[], []]
	selected.clear()
	select("", "")


# ---------------------------------------------------------------- world state

## Recomputes capabilities (what each country can build), income and attack objectives.
func _refresh_world() -> void:
	_world_t = 0.25
	var caps: Array = [{}, {}]
	var base_inc := float(GameData.settings.get("income_per_sec", 4))
	var inc: Array = [base_inc, base_inc]
	var objs: Array = [[], []]
	var nat: Array = [0, 0]
	for n in get_tree().get_nodes_in_group("combatants"):
		var c := n as Combatant
		if c == null or c.dead or c.is_queued_for_deletion():
			continue
		var gives_cap: bool = c.kind == "unit" and c.def.has("provides")
		if c.kind != "base" and c.kind != "national" and not gives_cap:
			continue
		var t := c.team
		if not gives_cap:
			objs[t].append(c)
			inc[t] += float(c.def.get("income", 0.0))
		if c.kind == "national":
			nat[t] += 1
		var prov: Array = c.def.get("provides", [])
		for p in prov:
			var key := str(p)
			caps[t][key] = int(caps[t].get(key, 0)) + 1
	var econ := float(GameData.settings.get("economy_mult", 1.0))
	inc[0] *= econ
	inc[1] *= econ
	_caps = caps
	_income = inc
	_objectives = objs
	_nat_count = nat


func _rebuild_grid() -> void:
	_grid_t = 0.12
	var g: Array = [{}, {}]
	for n in get_tree().get_nodes_in_group("combatants"):
		var c := n as Combatant
		if c == null or c.dead or c.is_queued_for_deletion():
			continue
		var key := Vector2i(floori(c.position.x / GRID), floori(c.position.y / GRID))
		var cell: Dictionary = g[c.team]
		if cell.has(key):
			cell[key].append(c)
		else:
			cell[key] = [c]
	_grid = g


## Combatants of `team` within about `radius` of `pos` (callers still do the exact distance test).
func near_team(team: int, pos: Vector2, radius: float) -> Array:
	var out: Array = []
	var cell: Dictionary = _grid[team]
	if cell.is_empty():
		return out
	var x0 := floori((pos.x - radius) / GRID)
	var x1 := floori((pos.x + radius) / GRID)
	var y0 := floori((pos.y - radius) / GRID)
	var y1 := floori((pos.y + radius) / GRID)
	for gx in range(x0, x1 + 1):
		for gy in range(y0, y1 + 1):
			var l: Variant = cell.get(Vector2i(gx, gy))
			if l != null:
				for c in l:
					if is_instance_valid(c):
						out.append(c)
	return out


func has_capability(team: int, cap: String) -> bool:
	return int(_caps[team].get(cap, 0)) > 0


func income_rate(team: int) -> float:
	return float(_income[team]) * (ai_income_mult if team == 1 else 1.0) * float(income_mult[team])


func nat_alive(team: int) -> int:
	return int(_nat_count[team])


## Returns "" or the first missing capability an item needs.
func missing_requirement(team: int, d: Dictionary) -> String:
	for req in GameData.requirements(d):
		if not has_capability(team, str(req)):
			return str(req)
	return ""


## Nearest living enemy capital / country building: where units march when idle.
func objective_for(team: int, from: Vector2) -> Vector2:
	var best := base_pos(1 - team)
	var best_d := INF
	for c in _objectives[1 - team]:
		if not is_instance_valid(c) or c.dead:
			continue
		var d := from.distance_to(c.position)
		if d < best_d:
			best_d = d
			best = c.position
	return best


func nationals_providing(team: int, cap: String) -> Array:
	var out: Array = []
	for c in _objectives[team]:
		if not is_instance_valid(c) or c.dead:
			continue
		var prov: Array = c.def.get("provides", [])
		if prov.has(cap):
			out.append(c)
	return out


## Where a ship should sail when it has nothing to shoot: the shoreline closest to the nearest
## enemy objective it can actually shell from the water (falls back to the enemy capital's coast).
func naval_goal(team: int, from: Vector2, rng: float, draft: int) -> Vector2:
	var best := base_pos(1 - team)
	var best_d := INF
	for c in _objectives[1 - team]:
		if not is_instance_valid(c) or c.dead:
			continue
		if c.coast_dist(draft) > rng - 12.0:
			continue
		var d := from.distance_to(c.position)
		if d < best_d:
			best_d = d
			best = c.position
	var w := Water.nearest_water(best, draft)
	if w.x < -1000.0:
		return from
	return w


func national_count(team: int, id: String) -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group("team%d" % team):
		var c := node as Combatant
		if c == null or c.dead or c.is_queued_for_deletion() or c.kind != "national":
			continue
		if id == "" or c.id == id:
			n += 1
	return n


# ----------------------------------------------------------------- spawning

func spawn_entity(kind: String, id: String, team: int, pos: Vector2) -> Combatant:
	var d := GameData.def_for(team, kind, id)
	if d.is_empty():
		return null
	var c := Combatant.new()
	c.position = pos
	c.setup(self, kind, id, d, team)
	units_root.add_child(c)
	if team == 0 and c.can_take_orders():
		_apply_stance(c, false)
	return c


## Orders a player unit according to the army stance. assault = march on the enemy by itself (like the AI),
## defend = guard the rally point and fight whatever comes, manual = wait for explicit orders.
func _apply_stance(c: Combatant, jitter: bool = true) -> void:
	var swim := c.domain == "water" or c.domain == "sub"
	match stance:
		"assault":
			c.order = "auto"
			c.order_pos = c.position
			c.path = PackedVector2Array()
		"defend":
			if swim:
				c.set_order("hold")
			else:
				var rp: Vector2 = rally[0] + Vector2(randf_range(-90.0, 90.0), randf_range(-170.0, 170.0))
				rp.y = clampf(rp.y, FIELD_TOP + 20.0, FIELD_BOTTOM - 20.0)
				c.set_order("attack_move", rp)
		_:
			c.set_order("hold")


func set_stance(st: String, announce: bool = true) -> void:
	stance = st
	for n in get_tree().get_nodes_in_group("team0"):
		var c := n as Combatant
		if c != null and not c.dead and c.can_take_orders():
			_apply_stance(c)
	if announce and hud != null:
		hud.toast({"assault": "ARMY: AUTO-ASSAULT - units advance and fight on their own",
			"defend": "ARMY: DEFEND - units guard the rally flag",
			"manual": "ARMY: MANUAL - units wait for your orders"}.get(st, st))
	if hud != null:
		hud.refresh_modes()


func cycle_stance() -> void:
	set_stance({"assault": "defend", "defend": "manual", "manual": "assault"}.get(stance, "assault"))


func set_autopilot(on: bool, announce: bool = true) -> void:
	autopilot = on
	if on and auto_ai == null:
		auto_ai = AICommander.new()
		auto_ai.battle = self
		auto_ai.team = 0
		auto_ai.autopilot = true
		auto_ai.configure(GameData.settings.get("difficulty", {}).get("normal", {}))
		auto_ai.think_interval = 2.5
		add_child(auto_ai)
	if auto_ai != null:
		auto_ai.active = on
	if announce and hud != null:
		hud.toast("AUTOPILOT ON - the staff buys units for you (you keep a cash reserve)" if on else "AUTOPILOT OFF")
	if hud != null:
		hud.refresh_modes()


func spawn_explosion(pos: Vector2, radius: float, nuke: bool = false, duration: float = -1.0) -> void:
	var names: Array = ["explosion_small"]
	if nuke:
		names = ["explosion_nuke"]
	elif radius >= 150.0:
		names = ["explosion_large"]
	elif radius >= 60.0:
		names = ["explosion_medium"]
	elif radius < 14.0:
		names = ["hit_spark", "explosion_small"]
	if radius >= 14.0 and Water.kind_at(pos) >= 1:
		VfxLib.spawn(fx_root, "water_splash", pos, radius * 2.4)
	if VfxLib.spawn_any(fx_root, names, pos, radius * 2.4):
		return
	var e := Explosion.new()
	e.position = pos
	e.radius = radius
	e.nuke = nuke
	e.duration = duration if duration > 0.0 else (2.6 if nuke else clampf(0.25 + radius / 260.0, 0.3, 0.9))
	fx_root.add_child(e)


func fire_projectile(src: Combatant, tgt: Combatant) -> void:
	var pname: String = str(src.def.get("proj", "bullet"))
	var vs_sub: bool = tgt.layer == "sub" and src.def.has("sub_proj")
	if vs_sub:
		pname = str(src.def.get("sub_proj", "depth_charge"))
	var pt: Dictionary = GameData.projectiles.get(pname, {})
	if pt.is_empty():
		return
	var p := Projectile.new()
	p.battle = self
	p.ptype = pt
	p.team = src.team
	p.damage = float(src.def.get("sub_damage" if vs_sub else "damage", 10)) * (src.buff_m if src.buff_t > 0.0 else 1.0)
	p.splash = float(src.def.get("sub_splash" if vs_sub else "splash", 0.0))
	p.speed = float(pt.get("speed", 500))
	p.homing = bool(pt.get("homing", false))
	p.quiet = bool(pt.get("quiet", false))
	p.pierce = float(src.def.get("pierce", 0.0))
	var vsd: Dictionary = src.def.get("vs", {})
	p.vs = vsd
	p.is_interceptor = pname == "interceptor"
	if vs_sub:
		p.layers = ["sub"]
	elif bool(src.def.get("splash_air_only", false)):
		p.layers = ["air"]
	elif bool(src.def.get("splash_air", false)):
		p.layers = ["ground", "air"]
	else:
		p.layers = ["ground"]
	p.target = tgt
	p.position = src.position + Vector2.from_angle(src.desired_angle) * src.radius * 0.7
	var aim := tgt.position
	if not p.homing and tgt.layer != "missile":
		var t := p.position.distance_to(aim) / maxf(p.speed, 1.0)
		aim += tgt.vel * t          # lead moving targets
	p.target_pos = aim
	proj_root.add_child(p)
	if p.is_interceptor:
		p.pend_amount = p.damage
		tgt.pending += p.damage
	if pname != "bullet" or randf() < 0.35:
		VfxLib.spawn_any(fx_root, ["muzzle_" + src.id, "muzzle_flash"], p.position, maxf(src.radius * 1.3, 18.0), src.desired_angle)
	if Sfx.play_any(["fire_" + src.id, "shot_" + pname], -8.0, 0.06):
		return
	match pname:
		"bullet", "sniper": Sfx.play("shot", -16.0, 0.07)
		"shell", "heavy_shell", "atgm", "rail", "mortar": Sfx.play("shot", -8.0, 0.08)
		"bomb", "big_bomb": Sfx.play("deploy", -8.0, 0.1)
		"flame", "flak", "grenade": Sfx.play("shot", -18.0, 0.1)
		_: Sfx.play("launch", -14.0, 0.12)


## Area damage. Never hurts the attacker's own team. `layers` says which layers the blast reaches;
## `vs` holds damage multipliers per target class; `pierce` reduces armor.
func explode(pos: Vector2, radius: float, damage: float, team: int, layers: Array = ["ground"],
		falloff: float = 0.5, nuke: bool = false, pierce: float = 0.0, vs: Dictionary = {},
		quiet: bool = false) -> void:
	if quiet:
		spawn_explosion(pos, maxf(radius * 0.9, 10.0), false, 0.2)
	else:
		spawn_explosion(pos, maxf(radius * 0.9, 16.0), nuke)
		if nuke:
			shake = 24.0
			hud.flash(0.95)
			Sfx.play_any(["explosion_nuke", "nuke"], 0.0, 0.5)
		elif radius >= 150.0:
			shake = maxf(shake, 9.0)
			Sfx.play_any(["explosion_large", "boom"], -1.0, 0.1)
		elif radius >= 60.0:
			Sfx.play_any(["explosion_medium", "boom"], -8.0, 0.08)
		else:
			Sfx.play_any(["explosion_small", "boom"], -14.0, 0.06)
	if radius >= 22.0 and decals != null and Water.kind_at(pos) == 0:
		decals.add_scorch(pos, minf(radius * (0.95 if nuke else 0.7), 700.0))
	for n in near_team(1 - team, pos, radius + 200.0):
		var c := n as Combatant
		if c == null or c.dead or c.is_queued_for_deletion():
			continue
		if c.layer == "missile" or not layers.has(c.layer):
			continue
		var d := pos.distance_to(c.position)
		var reach := radius + c.radius * 0.5
		if d > reach:
			continue
		var f := lerpf(1.0, 1.0 - falloff, clampf(d / reach, 0.0, 1.0))
		var mult := float(vs.get(c.cls, 1.0))
		c.take_damage(damage * f * mult, team, pierce)


## Explosion that hurts everyone on the ground (burning refineries, power plants...).
func blast_all(pos: Vector2, radius: float, damage: float, source_team: int) -> void:
	spawn_explosion(pos, radius, false, 0.9)
	Sfx.play("boom", -3.0, 0.1)
	for n in get_tree().get_nodes_in_group("combatants"):
		var c := n as Combatant
		if c == null or c.dead or c.is_queued_for_deletion() or c.layer != "ground":
			continue
		if pos.distance_to(c.position) <= radius + c.radius * 0.5:
			c.take_damage(damage, source_team)


func on_combatant_died(c: Combatant, source_team: int) -> void:
	if c.is_trap():
		return                                   # mines just vanish (the blast was spawned by the trap itself)
	var is_missile := c.layer == "missile"
	_leave_wreck(c)
	VfxLib.spawn(fx_root, "death_" + c.id, c.position, maxf(c.radius * 2.6, 40.0))
	if c.kind == "base":
		spawn_explosion(c.position, 200.0, false, 1.6)
		shake = maxf(shake, 14.0)
		Sfx.play_any(["die_" + c.id, "die_base", "nuke"], -4.0, 0.2)
	elif c.kind == "national":
		spawn_explosion(c.position, maxf(c.radius * 2.4, 70.0), false, 1.1)
		shake = maxf(shake, 7.0)
		Sfx.play_any(["die_" + c.id, "die_building", "boom"], -2.0, 0.1)
		_refresh_world()
		if c.def.has("death_blast"):
			var bd: Dictionary = c.def.get("death_blast", {})
			blast_all(c.position, float(bd.get("radius", 100.0)), float(bd.get("damage", 100.0)), source_team)
		hud.toast("%s %s destroyed!" % ["Your" if c.team == 0 else "Enemy", str(c.def.get("name", c.id))])
	else:
		spawn_explosion(c.position, 30.0 if is_missile else maxf(c.radius * 1.8, 22.0), false)
		Sfx.play_any(["die_" + c.id, "die_unit" if c.kind == "unit" else "die_building", "boom"], -9.0 if c.kind == "unit" else -2.0, 0.06)
	if source_team >= 0 and source_team != c.team:
		money[source_team] += float(c.def.get("cost", 0)) * float(GameData.settings.get("bounty_ratio", 0.2))
		if is_missile:
			intercepted[source_team] += 1
		else:
			kills[source_team] += 1
	var cargo: Array = c.def.get("cargo", [])
	for cid in cargo:
		if unit_count(c.team, false) < int(GameData.settings.get("unit_cap", 90)):
			spawn_entity("unit", str(cid), c.team, c.position + Vector2(randf_range(-24.0, 24.0), randf_range(-24.0, 24.0)))
	if c.kind == "base":
		_refresh_world()
		game_over(1 - c.team)


## Burnt-out vehicles and ruined buildings stay on the field as dark wrecks.
func _leave_wreck(c: Combatant) -> void:
	if decals == null or c.layer == "missile" or c.layer == "air" or c.sprite == null or c.sprite.texture == null or c.is_trap():
		return
	if c.domain == "water" or c.domain == "sub" or Water.kind_at(c.position) != 0:
		return
	var shape := str(c.def.get("shape", ""))
	if c.kind == "unit" and shape != "vehicle":
		return
	decals.add_wreck(c.position, c.radius, c.sprite.texture, c.sprite.rotation, c.sprite.scale)


func game_over(winner: int) -> void:
	if over:
		return
	over = true
	hud.show_game_over(winner == 0)


## Free units trained by barracks / factories / airbases.
func garrison_spawn(src: Combatant) -> void:
	if over:
		return
	var ids: Array = src.def.get("spawns", [])
	if ids.is_empty():
		return
	if unit_count(src.team, false) >= int(GameData.settings.get("unit_cap", 90)):
		return
	var uid := str(ids[randi() % ids.size()])
	var ud: Dictionary = GameData.def_for(src.team, "unit", uid)
	if bool(ud.get("banned", false)):
		return
	var udom := str(ud.get("domain", "land"))
	if udom == "water" or udom == "sub":
		var wp := Water.nearest_water(src.position, int(ud.get("draft", 1)))
		if wp.x > -1000.0:
			spawn_entity("unit", uid, src.team, wp + Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0)))
		return
	if src.kind == "unit":
		spawn_entity("unit", uid, src.team, src.position + Vector2(randf_range(-22.0, 22.0), randf_range(-22.0, 22.0)))
		return
	var dx := randf_range(40.0, 70.0) * (1.0 if src.team == 0 else -1.0)
	var p := src.position + Vector2(dx, randf_range(-50.0, 50.0))
	p.y = clampf(p.y, FIELD_TOP + 12.0, FIELD_BOTTOM - 12.0)
	spawn_entity("unit", uid, src.team, p)


# ---------------------------------------------------------------- deployment

func base_pos(team: int) -> Vector2:
	var b = bases[team]          # untyped: the capital may already be freed
	if b != null and is_instance_valid(b):
		return b.position
	return Vector2(BASE_MARGIN if team == 0 else float(W) - BASE_MARGIN, (FIELD_TOP + FIELD_BOTTOM) * 0.5)


func in_zone(team: int, p: Vector2, forward: bool = false) -> bool:
	if p.y < FIELD_TOP + 10.0 or p.y > FIELD_BOTTOM - 10.0:
		return false
	var S := GameData.settings
	var reach := float(S.get("forward_reach", 0.0)) if forward else 0.0
	if team == 0:
		return p.x >= 14.0 and p.x <= float(S.get("player_zone_x", 1500)) + reach
	return p.x <= float(W) - 14.0 and p.x >= float(S.get("enemy_zone_x", 4900)) - reach


## Water a team may deploy ships into: the sea / rivers on its own side of the map.
func in_water_zone(team: int, p: Vector2, draft: int) -> bool:
	if p.y < float(Water.Y_MIN) + 10.0 or p.y > float(Water.Y_MAX) - 10.0:
		return false
	var S := GameData.settings
	if team == 0:
		if p.x < 14.0 or p.x > float(S.get("player_zone_x", 1500)):
			return false
	elif p.x > float(W) - 14.0 or p.x < float(S.get("enemy_zone_x", 4900)):
		return false
	return Water.kind_at(p) >= draft


## Is `p` a legal deployment spot for this item (land zone, or own waters for ships)?
func zone_ok(team: int, d: Dictionary, p: Vector2) -> bool:
	var dom := str(d.get("domain", "land"))
	if dom == "water" or dom == "sub":
		return in_water_zone(team, p, int(d.get("draft", 1)))
	if dom == "amphib":
		return in_zone(team, p) or in_water_zone(team, p, 1)
	return in_zone(team, p, bool(d.get("forward", false)))


func get_cooldown(team: int, kind: String, id: String) -> float:
	if kind == "strategic":
		return float(strat_cd[team].get(id, 0.0))
	return float(deploy_cd[team].get(id, 0.0))


func cooldown_total(kind: String, id: String) -> float:
	var d := GameData.def_for(0, kind, id)
	if kind == "strategic":
		return float(d.get("cooldown", 10.0))
	return float(d.get("deploy_cd", 1.0))


func unit_count(team: int, structures: bool) -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group("team%d" % team):
		var c := node as Combatant
		if c == null or c.dead or c.is_queued_for_deletion():
			continue
		if structures and c.kind == "structure" and not c.is_trap():
			n += 1
		elif not structures and c.kind == "unit":
			n += 1
	return n


func trap_count(team: int) -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group("team%d" % team):
		var c := node as Combatant
		if c != null and not c.dead and not c.is_queued_for_deletion() and c.is_trap():
			n += 1
	return n


func can_place_structure(pos: Vector2, new_radius: float = 22.0) -> bool:
	for node in get_tree().get_nodes_in_group("combatants"):
		var c := node as Combatant
		if c == null or c.dead or c.layer == "air" or c.layer == "missile":
			continue
		if c.is_trap():
			continue
		if c.kind in ["structure", "base", "national"] and c.position.distance_to(pos) < c.radius + new_radius + 10.0:
			return false
	return true


## Returns "" on success or a human-readable reason.
func deploy(team: int, kind: String, id: String, pos: Vector2) -> String:
	if over:
		return "The battle is over"
	var d := GameData.def_for(team, kind, id)
	if d.is_empty():
		return "Unknown item"
	if bool(d.get("banned", false)):
		return "Not available to this army"
	var missing := missing_requirement(team, d)
	if missing != "":
		return "Requires a %s" % GameData.cap_name(missing)
	var cost := float(d.get("cost", 0))
	if money[team] < cost:
		return "Not enough funds (need $%d)" % int(cost)
	if get_cooldown(team, kind, id) > 0.0:
		return "%s is not ready yet" % str(d.get("name", id))
	if kind == "strategic":
		return launch_strategic(team, id, pos)
	if not zone_ok(team, d, pos):
		var dom := str(d.get("domain", "land"))
		if dom == "water" or dom == "sub":
			return "Deploy ships in your own waters (shaded sea)" + (" - deep sea only" if int(d.get("draft", 1)) >= 3 else "")
		if bool(d.get("forward", false)):
			return "Forward bases can be built anywhere on your side of the river"
		return "Deploy inside your territory (shaded area)"
	var S := GameData.settings
	var nr := float(d.get("size", 40)) * 0.42 * GameData.sprite_scale()
	if kind == "unit" and unit_count(team, false) >= int(S.get("unit_cap", 90)):
		return "Unit cap reached"
	if kind == "structure" and d.has("trap"):
		if trap_count(team) >= int(S.get("trap_cap", 90)):
			return "Trap cap reached"
		if not can_place_structure(pos, nr * 0.6):
			return "Too close to a building"
	elif kind == "structure":
		if unit_count(team, true) >= int(S.get("structure_cap", 30)):
			return "Defense cap reached"
		if not can_place_structure(pos, nr):
			return "Too close to another structure"
	if kind == "national":
		if national_count(team, "") >= int(S.get("national_cap", 45)):
			return "Infrastructure cap reached"
		if national_count(team, id) >= int(d.get("limit", 99)):
			return "Limit reached: %d x %s" % [int(d.get("limit", 99)), str(d.get("name", id))]
		if not can_place_structure(pos, nr):
			return "Too close to another structure"
	if d.has("coastal") and Water.dist_to_water(pos, 2) > float(d.get("coastal", 150)):
		return "Must be built on the coast"
	if kind == "unit":
		return _enqueue(team, id, d)
	var c := spawn_entity(kind, id, team, pos)
	if c == null:
		return "Could not deploy"
	money[team] -= cost
	deploy_cd[team][id] = float(d.get("deploy_cd", 1.0))
	if kind == "national":
		_refresh_world()
	VfxLib.spawn_any(fx_root, ["deploy_" + id, "deploy_dust"], c.position, maxf(c.radius * 2.6, 40.0))
	if team == 0:
		Sfx.play_any(["deploy_" + id, "deploy"], -4.0, 0.05)
	return ""


# ------------------------------------------------------------------ production

## Units are not dropped from the sky: they are built by a Barracks / War Factory / Airbase / Naval Port
## (or the capital if you have none), one at a time per building, and appear next to it.
func _producer_for(team: int, d: Dictionary) -> Combatant:
	var caps := ["barracks", "factory", "airbase", "port"]
	var cap := ""
	for r in GameData.requirements(d):
		if caps.has(str(r)):
			cap = str(r)
			break
	if cap == "":
		match str(d.get("tab", "")):
			"infantry": cap = "barracks"
			"vehicles": cap = "factory"
			"air": cap = "airbase"
			"navy": cap = "port"
	var best: Combatant = null
	var best_len := 9999
	if cap != "":
		for c in nationals_providing(team, cap):
			var ql := _queue_len(team, c)
			if ql < best_len:
				best_len = ql
				best = c
	if best == null:
		var b = bases[team]
		if b != null and is_instance_valid(b):
			best = b
	return best


func _queue_len(team: int, prod: Combatant) -> int:
	var n := 0
	for it in queues[team]:
		if it["prod"] == prod:
			n += 1
	return n


func build_time(d: Dictionary) -> float:
	return float(d.get("build_time", clampf(float(d.get("cost", 100)) / 35.0, 2.0, 26.0)))


func _enqueue(team: int, id: String, d: Dictionary) -> String:
	var prod := _producer_for(team, d)
	if prod == null:
		return "No production building available"
	if _queue_len(team, prod) >= 8:
		return "%s production queue is full" % str(prod.def.get("name", "Building"))
	var cost := float(d.get("cost", 0))
	money[team] -= cost
	deploy_cd[team][id] = float(d.get("deploy_cd", 1.0))
	var bt := build_time(d)
	queues[team].append({"id": id, "prod": prod, "total": bt, "left": bt, "cost": cost})
	if team == 0:
		Sfx.play("click", -5.0, 0.03)
	return ""


## Player entry point (unit cards): queue a unit at the right production building.
func queue_unit(team: int, id: String) -> String:
	if over:
		return "The battle is over"
	var d := GameData.def_for(team, "unit", id)
	if d.is_empty():
		return "Unknown item"
	if bool(d.get("banned", false)):
		return "Not available to this army"
	var missing := missing_requirement(team, d)
	if missing != "":
		return "Requires a %s" % GameData.cap_name(missing)
	if money[team] < float(d.get("cost", 0)):
		return "Not enough funds (need $%d)" % int(float(d.get("cost", 0)))
	if get_cooldown(team, "unit", id) > 0.0:
		return "%s is not ready yet" % str(d.get("name", id))
	if unit_count(team, false) + queues[team].size() >= int(GameData.settings.get("unit_cap", 90)):
		return "Unit cap reached"
	return _enqueue(team, id, d)


func _tick_production(delta: float) -> void:
	for t in 2:
		var q: Array = queues[t]
		var busy: Array = []
		var i := 0
		while i < q.size():
			var it: Dictionary = q[i]
			var prod = it["prod"]
			if prod == null or not is_instance_valid(prod) or prod.dead:
				var np := _producer_for(t, GameData.def_for(t, "unit", str(it["id"])))
				if np != null:
					it["prod"] = np
					i += 1
				else:
					money[t] += float(it["cost"])
					q.remove_at(i)
				continue
			if not busy.has(prod):
				busy.append(prod)
				if prod.online():
					it["left"] = float(it["left"]) - delta
				if float(it["left"]) <= 0.0:
					_finish_unit(t, it)
					q.remove_at(i)
					continue
			i += 1


func _finish_unit(t: int, it: Dictionary) -> void:
	var id := str(it["id"])
	var ud := GameData.def_for(t, "unit", id)
	var prod: Combatant = it["prod"]
	if ud.is_empty() or unit_count(t, false) >= int(GameData.settings.get("unit_cap", 90)):
		money[t] += float(it["cost"])
		return
	var pos := prod.position
	var udom := str(ud.get("domain", "land"))
	if udom == "water" or udom == "sub":
		var wp := Water.nearest_water(prod.position, int(ud.get("draft", 1)))
		if wp.x < -1000.0:
			money[t] += float(it["cost"])
			return
		pos = wp + Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
	else:
		var dx := randf_range(40.0, 70.0) * (1.0 if t == 0 else -1.0)
		pos = prod.position + Vector2(dx, randf_range(-50.0, 50.0))
		pos.y = clampf(pos.y, FIELD_TOP + 12.0, FIELD_BOTTOM - 12.0)
	var c := spawn_entity("unit", id, t, pos)
	if c == null:
		return
	VfxLib.spawn_any(fx_root, ["deploy_" + id, "deploy_dust"], c.position, maxf(c.radius * 2.6, 40.0))
	if t == 0:
		Sfx.play_any(["deploy_" + id, "deploy"], -6.0, 0.05)
		if hud != null and hud.feed != null:
			hud.feed.push("%s ready" % str(ud.get("name", id)), MilTheme.GOOD)
		if c.can_take_orders() and udom != "water" and udom != "sub" and stance == "manual":
			var rp: Vector2 = rally[0] + Vector2(randf_range(-70.0, 70.0), randf_range(-110.0, 110.0))
			rp.y = clampf(rp.y, FIELD_TOP + 20.0, FIELD_BOTTOM - 20.0)
			c.set_order("move", rp)


# -------------------------------------------------------------- selection / orders

func clear_selection() -> void:
	for c in selected:
		if is_instance_valid(c):
			c.selected = false
			c.queue_redraw()
			if c.overlay != null:
				c.overlay.queue_redraw()
	selected.clear()


func _select_unit(c: Combatant, on: bool) -> void:
	c.selected = on
	c.queue_redraw()
	if c.overlay != null:
		c.overlay.queue_redraw()
	if on and not selected.has(c):
		selected.append(c)
	elif not on:
		selected.erase(c)


func _finish_selection(mp: Vector2, additive: bool) -> void:
	if not additive:
		clear_selection()
	var rect := Rect2(_box_start, mp - _box_start).abs()
	if not _box_moved:
		var best: Combatant = null
		var best_d := INF
		for n in get_tree().get_nodes_in_group("team0"):
			var c := n as Combatant
			if c == null or c.dead or not c.can_take_orders():
				continue
			var d := c.position.distance_to(mp)
			if d <= c.radius + 12.0 and d < best_d:
				best_d = d
				best = c
		if best != null:
			_select_unit(best, not (additive and selected.has(best)))
		return
	for n in get_tree().get_nodes_in_group("team0"):
		var c2 := n as Combatant
		if c2 != null and not c2.dead and c2.can_take_orders() and rect.has_point(c2.position):
			_select_unit(c2, true)


func select_all_units() -> void:
	clear_selection()
	for n in get_tree().get_nodes_in_group("team0"):
		var c := n as Combatant
		if c != null and not c.dead and c.can_take_orders():
			_select_unit(c, true)
	if hud != null:
		hud.toast("%d units selected" % selected.size())


func hold_selected() -> void:
	for c in selected:
		if is_instance_valid(c):
			c.set_order("hold")


## Sends the selection to `target`, spread out in a loose block so they do not pile onto one pixel.
func issue_order(mode: String, target: Vector2) -> void:
	if selected.is_empty():
		return
	var n := selected.size()
	var cols := int(ceil(sqrt(float(n))))
	var spacing := 34.0
	var col := MilTheme.GOOD if mode == "move" else MilTheme.WARN
	var tgt := Vector2(clampf(target.x, 20.0, float(W) - 20.0), clampf(target.y, float(Water.Y_MIN) + 10.0, float(Water.Y_MAX) - 10.0))
	for i in n:
		var c: Combatant = selected[i]
		if not is_instance_valid(c):
			continue
		var off := Vector2(float(i % cols) - float(cols - 1) * 0.5, float(i / cols) - float(n / cols) * 0.5) * spacing
		var p := tgt + off
		if c.domain == "water" or c.domain == "sub":
			if Water.kind_at(p) < c.draft:
				var wp := Water.nearest_water(p, c.draft)
				if wp.x > -1000.0:
					p = wp
		c.set_order(mode, p)
	order_marks.append([tgt, 0.0, col])
	Sfx.play("click", -7.0, 0.03)


func _command_key(key: int) -> void:
	match key:
		KEY_X:
			hold_selected()
			if hud != null and not selected.is_empty():
				hud.toast("Holding position")
		KEY_T:
			if not selected.is_empty():
				_cmd_mode = "attack_move"
				hud.toast("Attack-move: click the destination")
		KEY_F:
			_cmd_mode = "rally"
			hud.toast("Rally point: click where new units should gather")
		KEY_C:
			select_all_units()


func launch_strategic(team: int, id: String, target_pos: Vector2) -> String:
	var d := GameData.def_for(team, "strategic", id)
	var tp := Vector2(clampf(target_pos.x, 10.0, float(W) - 10.0), clampf(target_pos.y, float(Water.Y_MIN) + 10.0, float(Water.Y_MAX) - 10.0))
	var start := base_pos(team) + Vector2(40.0 if team == 0 else -40.0, randf_range(-30.0, 30.0))
	var silos := nationals_providing(team, "silo")
	if not silos.is_empty():
		start = silos[randi() % silos.size()].position + Vector2(0.0, randf_range(-10.0, 10.0))
	var m := Missile.new()
	m.setup_missile(self, id, d, team, start, tp)
	units_root.add_child(m)
	money[team] -= float(d.get("cost", 0))
	strat_cd[team][id] = float(d.get("cooldown", 10.0))
	launched[team] += 1
	Sfx.play_any(["launch_" + id, "launch"], -2.0, 0.1)
	if team == 1:
		if d.get("nuke", false):
			hud.alert("!!  NUCLEAR LAUNCH DETECTED  !!", true)
		else:
			hud.alert("Incoming missile: %s" % str(d.get("name", id)), false)
	return ""


func select(kind: String, id: String) -> void:
	sel_kind = kind
	sel_id = id
	if kind != "":
		Sfx.play("click", -6.0, 0.03)


# ------------------------------------------------------------ AI / info helpers

func pick_bombing_lane(team: int) -> float:
	var ys: Array = []
	for n in get_tree().get_nodes_in_group("team%d" % (1 - team)):
		var c := n as Combatant
		if c != null and not c.dead and c.layer == "ground":
			ys.append(c.position.y)
	if ys.is_empty() or randf() < 0.25:
		return randf_range(FIELD_TOP + 40.0, FIELD_BOTTOM - 40.0)
	return clampf(float(ys[randi() % ys.size()]), float(Water.Y_MIN) + 40.0, float(Water.Y_MAX) - 40.0)


func intel(team: int) -> Dictionary:
	var d := {"infantry": 0, "vehicles": 0, "air": 0, "navy": 0, "structures": 0, "missiles": 0, "ids": {}}
	for n in get_tree().get_nodes_in_group("team%d" % team):
		var c := n as Combatant
		if c == null or c.dead or c.is_queued_for_deletion():
			continue
		if c.layer == "missile":
			d["missiles"] += 1
			continue
		d["ids"][c.id] = int(d["ids"].get(c.id, 0)) + 1
		match str(c.def.get("tab", "")):
			"infantry": d["infantry"] += 1
			"vehicles": d["vehicles"] += 1
			"air": d["air"] += 1
			"navy": d["navy"] += 1
			"defenses": d["structures"] += 1
	return d


## Finds the position where a blast of `splash` radius destroys the most value.
func best_strike_point(victim_team: int, splash: float) -> Dictionary:
	var victims: Array = []
	for n in get_tree().get_nodes_in_group("team%d" % victim_team):
		var c := n as Combatant
		if c != null and not c.dead and c.layer != "missile" and not c.is_queued_for_deletion():
			victims.append(c)
	var best := {"pos": base_pos(victim_team), "score": 0.0}
	if victims.is_empty():
		return best
	for i in mini(victims.size(), 60):
		var cand: Combatant = victims[randi() % victims.size()]
		var score := 0.0
		for v: Combatant in victims:
			if cand.position.distance_to(v.position) <= splash * 0.8:
				score += 1500.0 if v.kind == "base" else float(v.def.get("cost", 50))
		if score > float(best["score"]):
			best = {"pos": cand.position, "score": score}
	return best


# --------------------------------------------------------------------- loop

func _process(delta: float) -> void:
	_update_camera(delta)
	if over:
		return
	elapsed += delta
	_tick_production(delta)
	if _box_active and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_box_active = false          # released over the HUD: finish the box select anyway
		_finish_selection(get_local_mouse_position(), Input.is_key_pressed(KEY_SHIFT))
	var k := 0
	while k < selected.size():
		var sc = selected[k]
		if not is_instance_valid(sc) or sc.dead:
			selected.remove_at(k)
		else:
			k += 1
	var mi := 0
	while mi < order_marks.size():
		order_marks[mi][1] = float(order_marks[mi][1]) + delta
		if float(order_marks[mi][1]) > 1.0:
			order_marks.remove_at(mi)
		else:
			mi += 1
	_grid_t -= delta
	if _grid_t <= 0.0:
		_rebuild_grid()
	_world_t -= delta
	if _world_t <= 0.0:
		_refresh_world()
	money[0] += float(_income[0]) * delta * float(income_mult[0])
	money[1] += float(_income[1]) * delta * ai_income_mult * float(income_mult[1])
	for t in 2:
		for key in deploy_cd[t]:
			deploy_cd[t][key] = maxf(0.0, float(deploy_cd[t][key]) - delta)
		for key in strat_cd[t]:
			strat_cd[t][key] = maxf(0.0, float(strat_cd[t][key]) - delta)
	autosave_t -= delta
	if autosave_t <= 0.0:
		autosave_t = AUTOSAVE_INTERVAL
		SaveManager.save_game("auto", serialize())
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_by(1.1)
			return
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_by(1.0 / 1.1)
			return
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_drag_cam = mb.pressed
			return
	if event is InputEventMouseMotion and _drag_cam:
		var mm := event as InputEventMouseMotion
		cam.position -= mm.relative / cam.zoom.x
		_clamp_camera()
		return
	if over:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_command_key((event as InputEventKey).keycode)
		return
	if event is InputEventMouseMotion and _box_active:
		if get_local_mouse_position().distance_to(_box_start) > 8.0:
			_box_moved = true
		return
	if event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		var mp := get_local_mouse_position()
		if b.button_index == MOUSE_BUTTON_LEFT:
			if b.pressed:
				if mp.y > float(Water.Y_MAX) or mp.y < float(Water.Y_MIN) or mp.x < 0.0 or mp.x > float(W):
					return
				if sel_kind != "":
					var err := deploy(0, sel_kind, sel_id, mp)
					if err != "":
						hud.toast(err)
						Sfx.play("click", -2.0, 0.1)
					elif sel_kind == "strategic":
						select("", "")      # missiles are one-shot: avoid accidental double launches
				elif _cmd_mode == "rally":
					rally[0] = mp
					_cmd_mode = ""
					order_marks.append([mp, 0.0, MilTheme.AMBER])
					hud.toast("Rally point set")
				elif _cmd_mode == "attack_move":
					issue_order("attack_move", mp)
					_cmd_mode = ""
				else:
					_box_active = true
					_box_moved = false
					_box_start = mp
			elif _box_active:
				_box_active = false
				_finish_selection(mp, b.shift_pressed)
		elif b.button_index == MOUSE_BUTTON_RIGHT and b.pressed:
			if sel_kind != "":
				select("", "")
			elif _cmd_mode != "":
				_cmd_mode = ""
			elif not selected.is_empty():
				issue_order("attack_move" if b.ctrl_pressed else "move", mp)


# ------------------------------------------------------------------- drawing
# (the static terrain lives in TerrainLayer; this draws the moving overlays)

func _draw() -> void:
	var pz := float(GameData.settings.get("player_zone_x", 1500))
	var ez := float(GameData.settings.get("enemy_zone_x", 4900))
	var placing: bool = sel_kind != "" and sel_kind != "strategic"
	draw_rect(Rect2(0, FIELD_TOP, pz, FIELD_BOTTOM - FIELD_TOP), Color(MilTheme.FRIEND, 0.10 if placing else 0.03))
	draw_rect(Rect2(ez, FIELD_TOP, float(W) - ez, FIELD_BOTTOM - FIELD_TOP), Color(MilTheme.ENEMY, 0.035))
	if placing and bool(GameData.def_for(0, sel_kind, sel_id).get("forward", false)):
		var fr := float(GameData.settings.get("forward_reach", 0.0))
		draw_rect(Rect2(pz, FIELD_TOP, fr, FIELD_BOTTOM - FIELD_TOP), Color(MilTheme.AMBER, 0.07))
	_dashed_vline(pz, Color(MilTheme.FRIEND, 0.65 if placing else 0.35))
	_dashed_vline(ez, Color(MilTheme.ENEMY, 0.4))

	# Shade your own waters while a ship / diver is selected.
	if sel_kind == "unit":
		var sdom := str(GameData.def_for(0, sel_kind, sel_id).get("domain", "land"))
		if sdom == "water" or sdom == "sub" or sdom == "amphib":
			_draw_water_zone(0.0, pz, Color(MilTheme.FRIEND, 0.16))

	# Incoming / outgoing missile impact markers.
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 130.0)
	for n in get_tree().get_nodes_in_group("combatants"):
		var m := n as Missile
		if m == null or m.dead:
			continue
		var col := MilTheme.BAD if m.team == 1 else MilTheme.GOOD
		var a := (0.4 + 0.45 * pulse) if m.team == 1 else 0.4
		draw_arc(m.target_pos, m.splash, 0.0, TAU, 56, Color(col, a), 2.0)
		draw_arc(m.target_pos, m.splash * 0.55, 0.0, TAU, 40, Color(col, a * 0.5), 1.0)
		draw_line(m.target_pos + Vector2(-16, 0), m.target_pos + Vector2(-5, 0), Color(col, 0.95), 2.0)
		draw_line(m.target_pos + Vector2(16, 0), m.target_pos + Vector2(5, 0), Color(col, 0.95), 2.0)
		draw_line(m.target_pos + Vector2(0, -16), m.target_pos + Vector2(0, -5), Color(col, 0.95), 2.0)
		draw_line(m.target_pos + Vector2(0, 16), m.target_pos + Vector2(0, 5), Color(col, 0.95), 2.0)

	for om in order_marks:
		var age: float = om[1]
		var oc: Color = om[2]
		draw_arc(om[0], 30.0 * (1.0 - age) + 6.0, 0.0, TAU, 24, Color(oc, 1.0 - age), 2.0)
	var rp: Vector2 = rally[0]
	var rcol := Color(MilTheme.AMBER, 0.9 if _cmd_mode == "rally" else 0.45)
	draw_line(rp, rp + Vector2(0, -34), rcol, 2.0)
	draw_colored_polygon(PackedVector2Array([rp + Vector2(0, -34), rp + Vector2(20, -28), rp + Vector2(0, -22)]), rcol)
	draw_arc(rp, 14.0, 0.0, TAU, 20, Color(rcol, 0.5), 1.5)
	if _box_active and _box_moved:
		var br := Rect2(_box_start, get_local_mouse_position() - _box_start).abs()
		draw_rect(br, Color(MilTheme.GOOD, 0.08))
		draw_rect(br, Color(MilTheme.GOOD, 0.9), false, 1.5)
	if _cmd_mode == "attack_move":
		var mp2 := get_local_mouse_position()
		draw_arc(mp2, 16.0, 0.0, TAU, 20, Color(MilTheme.WARN, 0.9), 2.0)
	_draw_ghost()


func _dashed_vline(x: float, col: Color) -> void:
	var y := FIELD_TOP
	while y < FIELD_BOTTOM:
		draw_line(Vector2(x, y), Vector2(x, minf(y + 18.0, FIELD_BOTTOM)), col, 2.0)
		y += 32.0


func _draw_water_zone(x0: float, x1: float, col: Color) -> void:
	for sgn in [-1.0, 1.0]:
		var edge := float(Water.Y_MIN) if sgn < 0.0 else float(Water.Y_MAX)
		var pts := PackedVector2Array()
		var x := x0
		while x < x1:
			pts.append(Vector2(x, Water.MID_Y + sgn * Water.coast_dy(x)))
			x += 40.0
		pts.append(Vector2(x1, Water.MID_Y + sgn * Water.coast_dy(x1)))
		pts.append(Vector2(x1, edge))
		pts.append(Vector2(x0, edge))
		draw_colored_polygon(pts, col)
		draw_line(Vector2(x1, edge), Vector2(x1, Water.MID_Y + sgn * Water.coast_dy(x1)), Color(MilTheme.FRIEND, 0.4), 2.0)


func _draw_ghost() -> void:
	if sel_kind == "" or over:
		return
	var mp := get_local_mouse_position()
	if mp.y < float(Water.Y_MIN) or mp.y > float(Water.Y_MAX) or mp.x < 0 or mp.x > float(W):
		return
	var d := GameData.def_for(0, sel_kind, sel_id)
	if d.is_empty():
		return
	if sel_kind == "strategic":
		var ok: bool = money[0] >= float(d.get("cost", 0)) and get_cooldown(0, "strategic", sel_id) <= 0.0 \
			and missing_requirement(0, d) == ""
		var col := MilTheme.BAD if ok else Color(0.6, 0.6, 0.6)
		var sp := float(d.get("splash", 100))
		draw_circle(mp, sp, Color(col, 0.10))
		draw_arc(mp, sp, 0.0, TAU, 64, Color(col, 0.9), 2.0)
		draw_arc(mp, sp * 0.5, 0.0, TAU, 48, Color(col, 0.45), 1.0)
		draw_line(mp + Vector2(-26, 0), mp + Vector2(-7, 0), col, 2.0)
		draw_line(mp + Vector2(26, 0), mp + Vector2(7, 0), col, 2.0)
		draw_line(mp + Vector2(0, -26), mp + Vector2(0, -7), col, 2.0)
		draw_line(mp + Vector2(0, 26), mp + Vector2(0, 7), col, 2.0)
		return
	var valid: bool = zone_ok(0, d, mp) and money[0] >= float(d.get("cost", 0)) and missing_requirement(0, d) == ""
	if valid and d.has("coastal"):
		valid = Water.dist_to_water(mp, 2) <= float(d.get("coastal", 150))
	if (sel_kind == "structure" or sel_kind == "national") and valid:
		valid = can_place_structure(mp, float(d.get("size", 40)) * 0.42 * GameData.sprite_scale())
	var tint := Color(0.55, 0.95, 0.45, 0.78) if valid else Color(1.0, 0.38, 0.32, 0.66)
	var tex := SpriteLib.get_texture(str(d.get("sprite", sel_id)), str(d.get("shape", "box")))
	var sz := float(d.get("size", 32)) * GameData.sprite_scale()
	var asp := float(tex.get_height()) / maxf(float(tex.get_width()), 1.0)
	draw_texture_rect(tex, Rect2(mp - Vector2(sz, sz * asp) * 0.5, Vector2(sz, sz * asp)), false, tint)
	MilTheme.draw_brackets(self, Rect2(mp - Vector2(sz, sz * asp) * 0.5, Vector2(sz, sz * asp)).grow(4.0), Color(tint, 0.95), 9.0, 2.0)
	var r := float(d.get("range", 0))
	if r > 0.0:
		draw_arc(mp, r, 0.0, TAU, 64, Color(tint, 0.55), 1.5)
	var h: Dictionary = d.get("heal", {})
	if not h.is_empty():
		draw_arc(mp, float(h.get("radius", 100)), 0.0, TAU, 48, Color(0.4, 1.0, 0.6, 0.5), 1.5)


# ---------------------------------------------------------------- save / load

func serialize() -> Dictionary:
	var ents: Array = []
	for n in units_root.get_children():
		var c := n as Combatant
		if c == null or c.dead or c.is_queued_for_deletion():
			continue
		ents.append(c.to_dict())
	return {
		"difficulty": difficulty,
		"factions": {"pf": GameData.team_faction[0], "ps": GameData.team_strategy[0],
			"ef": GameData.team_faction[1], "es": GameData.team_strategy[1]},
		"elapsed": elapsed,
		"money": money.duplicate(),
		"strat_cd": strat_cd.duplicate(true),
		"deploy_cd": deploy_cd.duplicate(true),
		"launched": launched.duplicate(),
		"kills": kills.duplicate(),
		"intercepted": intercepted.duplicate(),
		"nat_start": nat_start.duplicate(),
		"rally": [rally[0].x, rally[0].y],
		"stance": stance,
		"autopilot": autopilot,
		"queues": _queues_to_array(),
		"entities": ents,
		"ai": ai.to_dict() if ai != null else {},
	}


func _queues_to_array() -> Array:
	var out: Array = []
	for t in 2:
		for it in queues[t]:
			var pr = it["prod"]
			if pr == null or not is_instance_valid(pr):
				continue
			out.append({"t": t, "id": it["id"], "left": it["left"], "total": it["total"], "cost": it["cost"],
				"px": pr.position.x, "py": pr.position.y})
	return out


func _queues_from_array(arr: Array) -> void:
	queues = [[], []]
	for e in arr:
		var t := int(e.get("t", 0))
		var pp := Vector2(float(e.get("px", 0.0)), float(e.get("py", 0.0)))
		var prod: Combatant = null
		for n in get_tree().get_nodes_in_group("team%d" % t):
			var c := n as Combatant
			if c != null and not c.dead and (c.kind == "national" or c.kind == "base") and c.position.distance_to(pp) < 6.0:
				prod = c
				break
		if prod != null:
			queues[t].append({"id": str(e.get("id", "")), "prod": prod, "total": float(e.get("total", 5.0)),
				"left": float(e.get("left", 5.0)), "cost": float(e.get("cost", 0.0))})


func deserialize(data: Dictionary) -> bool:
	if data.is_empty() or int(data.get("version", 0)) < 3:
		return false
	var ents: Array = data.get("entities", [])
	_clear_all()
	var fs: Dictionary = data.get("factions", {})
	GameData.set_teams(str(fs.get("pf", "")), str(fs.get("ps", "")), str(fs.get("ef", "")), str(fs.get("es", "")))
	income_mult = [GameData.income_mult(0), GameData.income_mult(1)]
	difficulty = str(data.get("difficulty", "normal"))
	var m: Array = data.get("money", [0, 0])
	money = [float(m[0]), float(m[1])]
	elapsed = float(data.get("elapsed", 0.0))
	strat_cd = _cd_pair(data.get("strat_cd", []))
	deploy_cd = _cd_pair(data.get("deploy_cd", []))
	launched = _int_pair(data.get("launched", []))
	kills = _int_pair(data.get("kills", []))
	intercepted = _int_pair(data.get("intercepted", []))
	nat_start = _int_pair(data.get("nat_start", []))
	over = false
	for e in ents:
		var team := int(e.get("team", 0))
		var kind := str(e.get("t", "unit"))
		var id := str(e.get("id", ""))
		if kind == "missile":
			var md := GameData.def_for(team, "strategic", id)
			if md.is_empty():
				continue
			var mis := Missile.new()
			mis.setup_missile(self, id, md, team, Vector2(e.get("sx", 0), e.get("sy", 0)),
				Vector2(e.get("tx", 0), e.get("ty", 0)))
			mis.position = Vector2(e.get("x", 0), e.get("y", 0))
			mis.hp = float(e.get("hp", mis.hp))
			units_root.add_child(mis)
		else:
			var c := spawn_entity(kind, id, team, Vector2(e.get("x", 0), e.get("y", 0)))
			if c == null:
				continue
			c.from_dict(e)
			if kind == "base":
				bases[team] = c
	if bases[0] == null or bases[1] == null:
		push_warning("Save file has no capital - starting a new game instead")
		new_game(difficulty)
		return false
	_refresh_world()
	var rl: Array = data.get("rally", [])
	if rl.size() == 2:
		rally[0] = Vector2(float(rl[0]), float(rl[1]))
	_queues_from_array(data.get("queues", []))
	if nat_start[0] == 0 and nat_start[1] == 0:
		nat_start = _nat_count.duplicate()
	_setup_ai(difficulty)
	ai.from_dict(data.get("ai", {}))
	stance = str(data.get("stance", "assault"))
	set_autopilot(bool(data.get("autopilot", false)), false)
	autosave_t = AUTOSAVE_INTERVAL
	focus_camera(Vector2(820.0, 520.0))
	return true


func _cd_pair(arr: Variant) -> Array:
	var out: Array = [{}, {}]
	if typeof(arr) == TYPE_ARRAY and arr.size() >= 2:
		for t in 2:
			for k in arr[t]:
				out[t][str(k)] = float(arr[t][k])
	return out


func _int_pair(arr: Variant) -> Array:
	if typeof(arr) == TYPE_ARRAY and arr.size() >= 2:
		return [int(arr[0]), int(arr[1])]
	return [0, 0]


func save_slot(slot: String) -> bool:
	var ok := SaveManager.save_game(slot, serialize())
	hud.toast("Game saved to %s" % SaveManager.slot_label(slot) if ok else "Save FAILED")
	return ok


func load_slot(slot: String) -> bool:
	var data := SaveManager.load_game(slot)
	if data.is_empty():
		hud.toast("%s is empty" % SaveManager.slot_label(slot))
		return false
	var ok := deserialize(data)
	hud.toast("Loaded %s" % SaveManager.slot_label(slot) if ok else "Load failed (old save format?)")
	if ok:
		hud.rebuild_cards()
	return ok


func reload_sprites() -> void:
	SpriteLib.clear_cache()
	for n in get_tree().get_nodes_in_group("combatants"):
		var c := n as Combatant
		if c != null:
			c.refresh_sprite()
	terrain.queue_redraw()
	hud.rebuild_cards()
	hud.toast("Sprites reloaded")


# ------------------------------------------------------------------- terrain

## Static scenery: ground, dirt, scorched front line, roads between the country buildings, craters, rocks and
## forests. Drawn once (cached by the engine).
class TerrainLayer extends Node2D:
	var patches: Array = []     # soft ground blotches [pos, radius, shade]
	var craters: Array = []     # [pos, radius]
	var forests: Array = []     # clusters of trees: [[pos, radius, shade], ...]
	var roads: Array = []       # [a, b, width]
	var scars: Array = []       # churned / scorched earth on the front line [pos, radius]
	var rocks: Array = []       # [pos, size]

	func _init() -> void:
		z_index = -10
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	func setup_terrain() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1914
		var w := float(Battle.W)
		var mid_y := (Battle.FIELD_TOP + Battle.FIELD_BOTTOM) * 0.5
		for i in 1100:
			patches.append([Vector2(rng.randf_range(-40, w + 40), rng.randf_range(Battle.FIELD_TOP - 30, Battle.FIELD_BOTTOM + 30)),
				rng.randf_range(30, 130), rng.randf_range(-1.0, 1.0)])
		for i in 520:
			var cp := Vector2(rng.randf_range(1500, w - 1500.0), rng.randf_range(Battle.FIELD_TOP + 20, Battle.FIELD_BOTTOM - 20))
			var cr := rng.randf_range(6, 22)
			if Water.kind_at(cp) != 0 or Water.dist_to_water(cp, 1) < cr + 30.0:
				continue
			craters.append([cp, cr])
		for i in 340:
			var sp := Vector2(rng.randf_range(1500, w - 1500.0), rng.randf_range(Battle.FIELD_TOP + 20, Battle.FIELD_BOTTOM - 20))
			if Water.kind_at(sp) != 0 or Water.dist_to_water(sp, 1) < 50.0:
				continue
			scars.append([sp, rng.randf_range(24, 70)])
		for i in 650:
			var rp := Vector2(rng.randf_range(0, w), rng.randf_range(Battle.FIELD_TOP + 10, Battle.FIELD_BOTTOM - 10))
			if Water.kind_at(rp) != 0 or Water.dist_to_water(rp, 1) < 24.0:
				continue
			rocks.append([rp, rng.randf_range(2.5, 6.5)])
		var sites: Array = [Vector2(Battle.BASE_MARGIN, mid_y), Vector2(w - Battle.BASE_MARGIN, mid_y)]
		for e in GameData.country:
			var lx := float(e[1])
			var ly := float(e[2])
			sites.append(Vector2(lx, ly))
			sites.append(Vector2(w - lx, Battle.FIELD_TOP + Battle.FIELD_BOTTOM - ly))
		roads.append([Vector2(0, mid_y), Vector2(w, mid_y), 22.0])
		for s: Vector2 in sites:
			if absf(s.y - mid_y) > 24.0:
				roads.append([s, Vector2(s.x, mid_y), 9.0])
		for i in 420:
			var c := Vector2(rng.randf_range(0, w), rng.randf_range(Battle.FIELD_TOP + 20, Battle.FIELD_BOTTOM - 20))
			var ok := absf(c.y - mid_y) > 36.0 and Water.dist_to_water(c, 1) > 70.0
			for s: Vector2 in sites:
				if c.distance_to(s) < 120.0:
					ok = false
					break
			if not ok:
				continue
			var cluster: Array = []
			for k in rng.randi_range(4, 8):
				cluster.append([c + Vector2(rng.randf_range(-45, 45), rng.randf_range(-35, 35)), rng.randf_range(12, 26), rng.randf()])
			forests.append(cluster)

	## Soft blob: a few stacked low-alpha discs so there is no hard edge.
	func _blob(p: Vector2, r: float, col: Color) -> void:
		for k in 4:
			draw_circle(p, r * (1.0 - float(k) * 0.22), Color(col, col.a * 0.45))

	func _draw() -> void:
		var ft := Battle.FIELD_TOP
		var fb := Battle.FIELD_BOTTOM
		var w := float(Battle.W)
		var bg := SpriteLib.get_optional("background")
		if bg != null:
			draw_rect(Rect2(-60, ft - 60, w + 120, fb - ft + 120), Color(0.04, 0.05, 0.04))
			draw_texture_rect(bg, Rect2(0, ft, w, fb - ft), false)
			_draw_water()
			return
		TileLib.fill(self, PackedVector2Array([Vector2(-60, ft - 60), Vector2(w + 60, ft - 60),
			Vector2(w + 60, fb + 60), Vector2(-60, fb + 60)]), "ground", Color(0.18, 0.22, 0.12))
		for p in patches:
			var shade: float = p[2]
			if shade < 0.0:
				_blob(p[0], p[1], Color(0.04, 0.06, 0.03, 0.30))
			else:
				_blob(p[0], p[1] * 0.8, Color(0.34, 0.30, 0.16, 0.16))
		# churned and scorched earth along the front line
		for sc in scars:
			_blob(sc[0], sc[1], Color(0.05, 0.04, 0.03, 0.42))
			_blob(sc[0] + Vector2(sc[1] * 0.2, -sc[1] * 0.1), sc[1] * 0.55, Color(0.16, 0.12, 0.08, 0.40))
		var road_tex := TileLib.get_tile("road")
		var crater_tex := TileLib.get_tile("crater")
		var tree_tex := TileLib.get_tile("tree")
		for r in roads:
			var a: Vector2 = r[0]
			var b: Vector2 = r[1]
			var wd: float = r[2]
			if road_tex != null:
				var hw: float = wd * 0.5
				draw_texture_rect(road_tex, Rect2(minf(a.x, b.x) - (hw if a.x == b.x else 0.0),
					minf(a.y, b.y) - (hw if a.y == b.y else 0.0), absf(b.x - a.x) + (hw * 2.0 if a.x == b.x else 0.0),
					absf(b.y - a.y) + (hw * 2.0 if a.y == b.y else 0.0)), true)
				continue
			var dir := (b - a)
			var length := dir.length()
			if length < 1.0:
				continue
			dir = dir / length
			var nrm := dir.orthogonal()
			if wd >= 20.0:
				draw_line(a, b, Color(0.04, 0.04, 0.035, 0.75), wd + 9.0)
				draw_line(a, b, Color(0.27, 0.24, 0.17, 0.60), wd + 4.0)
				draw_line(a, b, Color(0.125, 0.125, 0.12), wd)
				draw_line(a, b, Color(0.16, 0.16, 0.15, 0.7), wd * 0.45)
				var t := 0.0
				while t < length:
					draw_line(a + dir * t, a + dir * minf(t + 15.0, length), Color(0.62, 0.56, 0.32, 0.5), 1.6)
					t += 36.0
				draw_line(a + nrm * wd * 0.5, b + nrm * wd * 0.5, Color(0.5, 0.48, 0.4, 0.28), 1.0)
				draw_line(a - nrm * wd * 0.5, b - nrm * wd * 0.5, Color(0.5, 0.48, 0.4, 0.28), 1.0)
			else:
				draw_line(a, b, Color(0.06, 0.05, 0.035, 0.55), wd + 4.0)
				draw_line(a, b, Color(0.25, 0.205, 0.14, 0.92), wd)
				draw_line(a + nrm * wd * 0.24, b + nrm * wd * 0.24, Color(0.13, 0.10, 0.07, 0.75), 1.6)
				draw_line(a - nrm * wd * 0.24, b - nrm * wd * 0.24, Color(0.13, 0.10, 0.07, 0.75), 1.6)
		for cr in craters:
			var cp: Vector2 = cr[0]
			var rad: float = cr[1]
			if crater_tex != null:
				var cs := Vector2(rad, rad) * 3.2
				draw_texture_rect(crater_tex, Rect2(cp - cs * 0.5, cs), false)
			else:
				draw_circle(cp, rad * 2.1, Color(0.02, 0.02, 0.015, 0.10))
				draw_circle(cp, rad * 1.5, Color(0.03, 0.025, 0.02, 0.18))
				draw_circle(cp, rad * 1.12, Color(0.31, 0.26, 0.18, 0.55))
				draw_circle(cp, rad * 0.92, Color(0.075, 0.062, 0.045, 0.96))
				draw_circle(cp + Vector2(rad * 0.12, rad * 0.16), rad * 0.62, Color(0.03, 0.025, 0.02, 0.7))
				draw_arc(cp, rad * 1.0, PI * 1.05, PI * 1.78, 10, Color(0.52, 0.46, 0.33, 0.55), 1.6)
		for rk in rocks:
			var rp: Vector2 = rk[0]
			var rs: float = rk[1]
			draw_circle(rp + Vector2(1.5, 2.0), rs, Color(0, 0, 0, 0.3))
			draw_circle(rp, rs, Color(0.23, 0.23, 0.21))
			draw_circle(rp + Vector2(-rs * 0.25, -rs * 0.3), rs * 0.55, Color(0.38, 0.38, 0.34))
		for cl in forests:
			for tt in cl:
				var sp: Vector2 = tt[0]
				var sr: float = tt[1]
				if tree_tex == null:
					draw_circle(sp + Vector2(sr * 0.35, sr * 0.5), sr * 1.05, Color(0, 0, 0, 0.28))
			for tt in cl:
				var tp: Vector2 = tt[0]
				var tr: float = tt[1]
				var sh: float = tt[2]
				if tree_tex != null:
					var ts := Vector2(tr, tr) * 2.8
					draw_texture_rect(tree_tex, Rect2(tp - ts * 0.5, ts), false)
					continue
				draw_circle(tp, tr, Color(0.05 + 0.03 * sh, 0.105 + 0.04 * sh, 0.045))
				draw_circle(tp + Vector2(-tr * 0.12, -tr * 0.15), tr * 0.78, Color(0.085 + 0.04 * sh, 0.175 + 0.05 * sh, 0.065))
				draw_circle(tp + Vector2(-tr * 0.26, -tr * 0.32), tr * 0.42, Color(0.15 + 0.04 * sh, 0.26 + 0.05 * sh, 0.10, 0.9))
				for k in 5:
					var ang := sh * 10.0 + float(k) * 1.9
					draw_circle(tp + Vector2.from_angle(ang) * tr * 0.55, tr * 0.12, Color(0.04, 0.085, 0.035, 0.7))
		for x in range(0, Battle.W + 1, 320):
			draw_line(Vector2(x, ft), Vector2(x, fb), Color(0.8, 0.9, 0.8, 0.022), 1.0)
		for y in range(int(ft), int(fb) + 1, 320):
			draw_line(Vector2(0, y), Vector2(w, y), Color(0.8, 0.9, 0.8, 0.022), 1.0)
		_draw_water()
		draw_rect(Rect2(-3, ft - 3, w + 6, fb - ft + 6), Color(0, 0, 0, 0.8), false, 6.0)

	## Rivers, the sea, bridges and the foam line. Drawn once (the animated waves are in WaterFX).
	func _draw_water() -> void:
		var w := float(Battle.W)
		var deep := Color(0.045, 0.11, 0.16)
		var shallow := Color(0.12, 0.235, 0.265)
		var bank := Color(0.17, 0.14, 0.09, 0.80)
		# rivers first: the sea is drawn over their mouths
		for ww in Water.waterways:
			var pts: PackedVector2Array = ww[0]
			var wd := float(ww[1])
			var k := int(ww[2])
			draw_polyline(pts, bank, wd + (14.0 if k == 2 else 9.0), true)
			if TileLib.get_tile("river") != null:
				for si in range(pts.size() - 1):
					var sa := pts[si]
					var sb := pts[si + 1]
					var sd := (sb - sa).normalized()
					var sn := sd.orthogonal() * wd * 0.5
					TileLib.fill(self, PackedVector2Array([sa - sd + sn, sb + sd + sn, sb + sd - sn, sa - sd - sn]), "river", Color.WHITE)
			else:
				draw_polyline(pts, Color(0.075, 0.17, 0.215) if k == 2 else Color(0.14, 0.27, 0.30), wd, true)
				if k == 2:
					draw_polyline(pts, Color(0.06, 0.14, 0.19), wd * 0.6, true)
					draw_polyline(pts, Color(0.12, 0.24, 0.29, 0.5), wd * 0.18, true)
			draw_circle(pts[0], wd * 0.5, Color(0.14, 0.27, 0.30))
			draw_circle(pts[pts.size() - 1], wd * 0.5, Color(0.075, 0.17, 0.215) if k == 2 else Color(0.14, 0.27, 0.30))
		# the sea: a shallow band along the coast, deep water beyond it
		for sgn in [-1.0, 1.0]:
			var far := float(Water.Y_MIN) - 60.0 if sgn < 0.0 else float(Water.Y_MAX) + 60.0
			var coast := PackedVector2Array()
			var offs := PackedVector2Array()
			var x := -60.0
			while x <= w + 60.0:
				var cd := Water.coast_dy(clampf(x, 0.0, w))
				coast.append(Vector2(x, Water.MID_Y + sgn * cd))
				offs.append(Vector2(x, Water.MID_Y + sgn * (cd + 24.0)))
				x += 16.0
			var poly_a := PackedVector2Array(coast)
			poly_a.append(Vector2(w + 60.0, far))
			poly_a.append(Vector2(-60.0, far))
			TileLib.fill(self, poly_a, "water_shallow", shallow)
			var poly_b := PackedVector2Array(offs)
			poly_b.append(Vector2(w + 60.0, far))
			poly_b.append(Vector2(-60.0, far))
			TileLib.fill(self, poly_b, "water_deep", deep)
			draw_polyline(coast, Color(0.42, 0.38, 0.27, 0.5), 12.0, true)
			draw_polyline(coast, Color(0.82, 0.9, 0.9, 0.32), 2.0, true)
		# bridges over the central river
		for r in Water.bridge_rects:
			var rect: Rect2 = r
			if TileLib.get_tile("bridge") != null:
				draw_texture_rect(TileLib.get_tile("bridge"), rect, false)
				continue
			draw_rect(rect.grow(3.0), Color(0.04, 0.035, 0.03, 0.9))
			draw_rect(rect, Color(0.24, 0.20, 0.14))
			var bx := rect.position.x + 5.0
			while bx < rect.end.x - 3.0:
				draw_line(Vector2(bx, rect.position.y + 2.0), Vector2(bx, rect.end.y - 2.0), Color(0.13, 0.10, 0.07, 0.9), 1.5)
				bx += 8.0
			draw_line(rect.position, Vector2(rect.end.x, rect.position.y), Color(0.52, 0.5, 0.43), 3.0)
			draw_line(Vector2(rect.position.x, rect.end.y), rect.end, Color(0.52, 0.5, 0.43), 3.0)


## Persistent battle damage: scorch marks from explosions and burnt-out wrecks of vehicles / buildings.
class DecalLayer extends Node2D:
	const MAX_DECALS := 260
	var items: Array = []    # {pos, r, seed, tex, rot, scl}

	func _init() -> void:
		z_index = -8

	func clear() -> void:
		items.clear()
		queue_redraw()

	func add_scorch(pos: Vector2, r: float) -> void:
		items.append({"pos": pos, "r": r, "seed": randf() * TAU, "tex": null, "rot": 0.0, "scl": Vector2.ONE})
		_trim()
		queue_redraw()

	func add_wreck(pos: Vector2, r: float, tex: Texture2D, rot: float, scl: Vector2) -> void:
		items.append({"pos": pos, "r": r * 1.3, "seed": randf() * TAU, "tex": tex, "rot": rot, "scl": scl})
		_trim()
		queue_redraw()

	func _trim() -> void:
		while items.size() > MAX_DECALS:
			items.remove_at(0)

	func _draw() -> void:
		for it in items:
			var p: Vector2 = it["pos"]
			var r: float = it["r"]
			var sd: float = it["seed"]
			draw_circle(p, r * 1.25, Color(0.03, 0.025, 0.02, 0.14))
			draw_circle(p, r * 0.85, Color(0.025, 0.02, 0.015, 0.24))
			draw_circle(p, r * 0.45, Color(0.02, 0.015, 0.012, 0.32))
			for k in 7:
				var ang := sd + float(k) * 0.9
				var reach := r * (0.95 + 0.35 * sin(sd * float(k + 1)))
				draw_line(p + Vector2.from_angle(ang) * r * 0.45, p + Vector2.from_angle(ang) * reach, Color(0.03, 0.025, 0.02, 0.2), 2.0)
			var tex: Texture2D = it["tex"]
			if tex != null:
				draw_set_transform(p, float(it["rot"]), it["scl"])
				draw_texture(tex, -tex.get_size() * 0.5, Color(0.17, 0.15, 0.13, 0.94))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Animated sparkles on the open water.
class WaterFX extends Node2D:
	var marks: Array = []

	func _init() -> void:
		z_index = -9

	func setup() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		for i in 1500:
			var p := Vector2(rng.randf_range(0.0, float(Battle.W)), rng.randf_range(float(Water.Y_MIN), float(Water.Y_MAX)))
			if Water.kind_at(p) >= 2:
				marks.append([p, rng.randf() * TAU, rng.randf_range(10.0, 26.0)])

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var t := Time.get_ticks_msec() / 1000.0
		for m in marks:
			var a := 0.5 + 0.5 * sin(t * 1.3 + float(m[1]))
			var p: Vector2 = m[0]
			p.x += sin(t * 0.4 + float(m[1])) * 5.0
			draw_line(p, p + Vector2(float(m[2]), 0.0), Color(0.7, 0.85, 0.9, 0.04 + 0.12 * a), 1.5)
