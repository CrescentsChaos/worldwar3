class_name Battle
extends Node2D
## The battlefield. Owns money, countries, deployment, projectiles/explosions,
## the camera, the enemy AI and save / load. Team 0 = player (left), team 1 = enemy (right).
## Each side is a whole country: a capital plus cities, factories, airbases, silos...

const W := 3200
const H := 720
const FIELD_TOP := 64.0
const FIELD_BOTTOM := 944.0
const BASE_MARGIN := 90.0
const AUTOSAVE_INTERVAL := 60.0
const ZOOM_MIN := 0.4
const ZOOM_MAX := 2.5

var units_root: Node2D
var proj_root: Node2D
var fx_root: Node2D
var terrain: TerrainLayer
var cam: Camera2D
var hud: HUD
var ai: AICommander

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
		var spd := 900.0 / cam.zoom.x * (2.2 if Input.is_key_pressed(KEY_SHIFT) else 1.0)
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
	_caps = caps
	_income = inc
	_objectives = objs
	_nat_count = nat


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
	return c


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
	p.damage = float(src.def.get("sub_damage" if vs_sub else "damage", 10))
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
	for n in get_tree().get_nodes_in_group("team%d" % (1 - team)):
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
	var is_missile := c.layer == "missile"
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


func in_zone(team: int, p: Vector2) -> bool:
	if p.y < FIELD_TOP + 10.0 or p.y > FIELD_BOTTOM - 10.0:
		return false
	var S := GameData.settings
	if team == 0:
		return p.x >= 14.0 and p.x <= float(S.get("player_zone_x", 1000))
	return p.x <= float(W) - 14.0 and p.x >= float(S.get("enemy_zone_x", 2200))


## Water a team may deploy ships into: the sea / rivers on its own side of the map.
func in_water_zone(team: int, p: Vector2, draft: int) -> bool:
	if p.y < float(Water.Y_MIN) + 10.0 or p.y > float(Water.Y_MAX) - 10.0:
		return false
	var S := GameData.settings
	if team == 0:
		if p.x < 14.0 or p.x > float(S.get("player_zone_x", 1000)):
			return false
	elif p.x > float(W) - 14.0 or p.x < float(S.get("enemy_zone_x", 2200)):
		return false
	return Water.kind_at(p) >= draft


## Is `p` a legal deployment spot for this item (land zone, or own waters for ships)?
func zone_ok(team: int, d: Dictionary, p: Vector2) -> bool:
	var dom := str(d.get("domain", "land"))
	if dom == "water" or dom == "sub":
		return in_water_zone(team, p, int(d.get("draft", 1)))
	if dom == "amphib":
		return in_zone(team, p) or in_water_zone(team, p, 1)
	return in_zone(team, p)


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
		if structures and c.kind == "structure":
			n += 1
		elif not structures and c.kind == "unit":
			n += 1
	return n


func can_place_structure(pos: Vector2, new_radius: float = 22.0) -> bool:
	for node in get_tree().get_nodes_in_group("combatants"):
		var c := node as Combatant
		if c == null or c.dead or c.layer == "air" or c.layer == "missile":
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
		return "Deploy inside your territory (shaded area)"
	var S := GameData.settings
	var nr := float(d.get("size", 40)) * 0.42 * GameData.sprite_scale()
	if kind == "unit" and unit_count(team, false) >= int(S.get("unit_cap", 90)):
		return "Unit cap reached"
	if kind == "structure":
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
	if event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		if not b.pressed:
			return
		if b.button_index == MOUSE_BUTTON_LEFT and sel_kind != "":
			var mp := get_local_mouse_position()
			if mp.y > float(Water.Y_MAX) or mp.y < float(Water.Y_MIN) or mp.x < 0.0 or mp.x > float(W):
				return
			var err := deploy(0, sel_kind, sel_id, mp)
			if err != "":
				hud.toast(err)
				Sfx.play("click", -2.0, 0.1)
			elif sel_kind == "strategic":
				select("", "")      # missiles are one-shot: avoid accidental double launches
		elif b.button_index == MOUSE_BUTTON_RIGHT:
			select("", "")


# ------------------------------------------------------------------- drawing
# (the static terrain lives in TerrainLayer; this draws the moving overlays)

func _draw() -> void:
	var pz := float(GameData.settings.get("player_zone_x", 1000))
	var ez := float(GameData.settings.get("enemy_zone_x", 2200))
	var hl := 0.14 if sel_kind != "" and sel_kind != "strategic" else 0.06
	draw_rect(Rect2(0, FIELD_TOP, pz, FIELD_BOTTOM - FIELD_TOP), Color(0.3, 0.55, 1.0, hl))
	draw_rect(Rect2(ez, FIELD_TOP, float(W) - ez, FIELD_BOTTOM - FIELD_TOP), Color(1.0, 0.3, 0.25, 0.06))
	draw_line(Vector2(pz, FIELD_TOP), Vector2(pz, FIELD_BOTTOM), Color(0.4, 0.65, 1.0, 0.35), 2.0)
	draw_line(Vector2(ez, FIELD_TOP), Vector2(ez, FIELD_BOTTOM), Color(1.0, 0.4, 0.3, 0.3), 2.0)

	# Shade your own waters while a ship / diver is selected.
	if sel_kind == "unit":
		var sdom := str(GameData.def_for(0, sel_kind, sel_id).get("domain", "land"))
		if sdom == "water" or sdom == "sub" or sdom == "amphib":
			_draw_water_zone(0.0, pz, Color(0.3, 0.6, 1.0, 0.16))

	# Incoming / outgoing missile impact markers.
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 130.0)
	for n in get_tree().get_nodes_in_group("combatants"):
		var m := n as Missile
		if m == null or m.dead:
			continue
		var col := Color(1.0, 0.25, 0.2) if m.team == 1 else Color(0.4, 1.0, 0.5)
		var a := (0.35 + 0.4 * pulse) if m.team == 1 else 0.35
		draw_arc(m.target_pos, m.splash, 0.0, TAU, 56, Color(col, a), 2.0)
		draw_line(m.target_pos + Vector2(-12, 0), m.target_pos + Vector2(12, 0), Color(col, 0.9), 2.0)
		draw_line(m.target_pos + Vector2(0, -12), m.target_pos + Vector2(0, 12), Color(col, 0.9), 2.0)

	_draw_ghost()


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
		draw_line(Vector2(x1, edge), Vector2(x1, Water.MID_Y + sgn * Water.coast_dy(x1)), Color(0.4, 0.65, 1.0, 0.35), 2.0)


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
		var col := Color(1.0, 0.3, 0.2) if ok else Color(0.6, 0.6, 0.6)
		var sp := float(d.get("splash", 100))
		draw_circle(mp, sp, Color(col, 0.12))
		draw_arc(mp, sp, 0.0, TAU, 64, Color(col, 0.9), 2.0)
		draw_line(mp + Vector2(-18, 0), mp + Vector2(18, 0), col, 2.0)
		draw_line(mp + Vector2(0, -18), mp + Vector2(0, 18), col, 2.0)
		return
	var valid: bool = zone_ok(0, d, mp) and money[0] >= float(d.get("cost", 0)) and missing_requirement(0, d) == ""
	if valid and d.has("coastal"):
		valid = Water.dist_to_water(mp, 2) <= float(d.get("coastal", 150))
	if (sel_kind == "structure" or sel_kind == "national") and valid:
		valid = can_place_structure(mp, float(d.get("size", 40)) * 0.42 * GameData.sprite_scale())
	var tint := Color(0.5, 1.0, 0.5, 0.7) if valid else Color(1.0, 0.4, 0.4, 0.6)
	var tex := SpriteLib.get_texture(str(d.get("sprite", sel_id)), str(d.get("shape", "box")))
	var sz := float(d.get("size", 32)) * GameData.sprite_scale()
	var asp := float(tex.get_height()) / maxf(float(tex.get_width()), 1.0)
	draw_texture_rect(tex, Rect2(mp - Vector2(sz, sz * asp) * 0.5, Vector2(sz, sz * asp)), false, tint)
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
		"entities": ents,
		"ai": ai.to_dict() if ai != null else {},
	}


func deserialize(data: Dictionary) -> bool:
	if data.is_empty() or int(data.get("version", 0)) < 2:
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
	if nat_start[0] == 0 and nat_start[1] == 0:
		nat_start = _nat_count.duplicate()
	_setup_ai(difficulty)
	ai.from_dict(data.get("ai", {}))
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

## Static scenery: grass, forests, roads between the country buildings, craters. Drawn once.
class TerrainLayer extends Node2D:
	var patches: Array = []
	var craters: Array = []
	var forests: Array = []
	var roads: Array = []

	func _init() -> void:
		z_index = -10
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

	func setup_terrain() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1914
		var w := float(Battle.W)
		var mid_y := (Battle.FIELD_TOP + Battle.FIELD_BOTTOM) * 0.5
		for i in 280:
			patches.append([Vector2(rng.randf_range(-40, w + 40), rng.randf_range(Battle.FIELD_TOP - 30, Battle.FIELD_BOTTOM + 30)),
				rng.randf_range(30, 130), rng.randf_range(-1.0, 1.0)])
		for i in 130:
			var cp := Vector2(rng.randf_range(1050, 2150), rng.randf_range(Battle.FIELD_TOP + 20, Battle.FIELD_BOTTOM - 20))
			var cr := rng.randf_range(6, 22)
			if Water.kind_at(cp) != 0 or Water.dist_to_water(cp, 1) < cr + 30.0:
				continue
			craters.append([cp, cr])
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
		for i in 80:
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
				cluster.append([c + Vector2(rng.randf_range(-45, 45), rng.randf_range(-35, 35)), rng.randf_range(12, 26)])
			forests.append(cluster)

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
			Vector2(w + 60, fb + 60), Vector2(-60, fb + 60)]), "ground", Color(0.25, 0.34, 0.21))
		for p in (patches if TileLib.get_tile("ground") == null else []):
			var shade: float = p[2]
			var col := Color(0.15, 0.22, 0.12, 0.22) if shade < 0.0 else Color(0.42, 0.5, 0.28, 0.16)
			draw_circle(p[0], p[1], col)
		var road_tex := TileLib.get_tile("road")
		var crater_tex := TileLib.get_tile("crater")
		var tree_tex := TileLib.get_tile("tree")
		for r in roads:
			if road_tex != null:
				var a: Vector2 = r[0]
				var b: Vector2 = r[1]
				var hw: float = float(r[2]) * 0.5
				draw_texture_rect(road_tex, Rect2(minf(a.x, b.x) - (0.0 if a.y != b.y else 0.0) - (hw if a.x == b.x else 0.0),
					minf(a.y, b.y) - (hw if a.y == b.y else 0.0), absf(b.x - a.x) + (hw * 2.0 if a.x == b.x else 0.0),
					absf(b.y - a.y) + (hw * 2.0 if a.y == b.y else 0.0)), true)
			else:
				draw_line(r[0], r[1], Color(0.3, 0.28, 0.23, 0.95), r[2])
				draw_line(r[0], r[1], Color(0.55, 0.52, 0.42, 0.45), maxf(r[2] * 0.2, 1.5))
		for cr in craters:
			if crater_tex != null:
				var cs := Vector2(cr[1], cr[1]) * 3.2
				draw_texture_rect(crater_tex, Rect2(cr[0] - cs * 0.5, cs), false)
			else:
				draw_circle(cr[0], cr[1], Color(0.14, 0.15, 0.11, 0.55))
				draw_arc(cr[0], cr[1], 0.0, TAU, 16, Color(0.4, 0.38, 0.28, 0.5), 1.5)
		for cl in forests:
			for t in cl:
				if tree_tex != null:
					var ts := Vector2(t[1], t[1]) * 2.8
					draw_texture_rect(tree_tex, Rect2(t[0] - ts * 0.5, ts), false)
				else:
					draw_circle(t[0], t[1], Color(0.11, 0.21, 0.1, 0.92))
					draw_circle(t[0] + Vector2(-3, -3), t[1] * 0.68, Color(0.17, 0.3, 0.14, 0.92))
		for x in range(0, Battle.W + 1, 80):
			draw_line(Vector2(x, ft), Vector2(x, fb), Color(1, 1, 1, 0.03), 1.0)
		for y in range(int(ft), int(fb) + 1, 80):
			draw_line(Vector2(0, y), Vector2(w, y), Color(1, 1, 1, 0.03), 1.0)
		draw_rect(Rect2(0, ft, w, fb - ft), Color(0, 0, 0, 0), false, 3.0)
		_draw_water()

	## Rivers, the sea, bridges and the foam line. Drawn once (the animated waves are in WaterFX).
	func _draw_water() -> void:
		var w := float(Battle.W)
		var deep := Color(0.06, 0.18, 0.33)
		var shallow := Color(0.17, 0.38, 0.5)
		var bank := Color(0.46, 0.42, 0.3, 0.55)
		# rivers first: the sea is drawn over their mouths
		for ww in Water.waterways:
			var pts: PackedVector2Array = ww[0]
			var wd := float(ww[1])
			var k := int(ww[2])
			draw_polyline(pts, bank, wd + (12.0 if k == 2 else 8.0), true)
			if TileLib.get_tile("river") != null:
				for si in range(pts.size() - 1):
					var sa := pts[si]
					var sb := pts[si + 1]
					var sd := (sb - sa).normalized()
					var sn := sd.orthogonal() * wd * 0.5
					TileLib.fill(self, PackedVector2Array([sa - sd + sn, sb + sd + sn, sb + sd - sn, sa - sd - sn]), "river", Color.WHITE)
			else:
				draw_polyline(pts, Color(0.12, 0.3, 0.46) if k == 2 else Color(0.2, 0.42, 0.54), wd, true)
				if k == 2:
					draw_polyline(pts, deep.lerp(shallow, 0.15), wd * 0.6, true)
			draw_circle(pts[0], wd * 0.5, Color(0.2, 0.42, 0.54))
			draw_circle(pts[pts.size() - 1], wd * 0.5, Color(0.12, 0.3, 0.46) if k == 2 else Color(0.2, 0.42, 0.54))
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
			draw_polyline(coast, Color(0.85, 0.95, 1.0, 0.45), 2.0, true)
		# bridges over the central river
		for r in Water.bridge_rects:
			var rect: Rect2 = r
			if TileLib.get_tile("bridge") != null:
				draw_texture_rect(TileLib.get_tile("bridge"), rect, false)
				continue
			draw_rect(rect.grow(2.0), Color(0.12, 0.11, 0.09, 0.9))
			draw_rect(rect, Color(0.43, 0.39, 0.31))
			var bx := rect.position.x + 6.0
			while bx < rect.end.x - 4.0:
				draw_line(Vector2(bx, rect.position.y + 2.0), Vector2(bx, rect.end.y - 2.0), Color(0.3, 0.27, 0.21, 0.8), 1.5)
				bx += 9.0
			draw_line(rect.position, Vector2(rect.end.x, rect.position.y), Color(0.72, 0.7, 0.62), 3.0)
			draw_line(Vector2(rect.position.x, rect.end.y), rect.end, Color(0.72, 0.7, 0.62), 3.0)


## Animated sparkles on the open water.
class WaterFX extends Node2D:
	var marks: Array = []

	func _init() -> void:
		z_index = -9

	func setup() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		for i in 700:
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
			draw_line(p, p + Vector2(float(m[2]), 0.0), Color(0.75, 0.9, 1.0, 0.05 + 0.15 * a), 1.5)
