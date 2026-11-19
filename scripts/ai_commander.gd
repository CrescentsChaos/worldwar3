class_name AICommander
extends Node
## Enemy commander (v2). Every few seconds it scans both sides, then:
##   1. fires missiles / nukes where they will do the most damage,
##   2. rebuilds lost infrastructure (power, factories, tech, airbase, silos, ports, economy),
##   3. reacts to missile launches and air raids with interceptors / AA,
##   4. plans purchases into a queue and SAVES for them, so it can afford advanced units:
##        - defense waves: layered, placed around its important buildings and at the front,
##          balanced between anti-ground, anti-air, anti-missile and coastal needs,
##        - army waves: a premium "spearhead" unit plus counter-picked escorts, deployed together.
## Difficulty settings (data/units.json -> settings.difficulty.*):
##   ai_skill (0..1), ai_wave_secs, ai_think, ai_nukes, ai_strategic_after, ai_income_mult, ai_start_money.

const ANCHOR_VALUE := {
	"hq": 3.0, "power_plant": 2.4, "tech_center": 2.2, "fortress": 2.0, "factory": 2.0,
	"missile_silo": 1.8, "airbase": 1.6, "metropolis": 1.2, "barracks": 1.0, "radar_station": 0.9,
	"oil_refinery": 0.8, "naval_port": 0.6, "town": 0.5, "forward_base": 1.2, "supply_depot": 0.6,
	"field_hospital": 0.5, "fuel_depot": 0.4,
}
const EXTRA_BUILDINGS := ["supply_depot", "forward_base", "field_hospital", "fuel_depot", "forward_base"]
const DEF_POOL := {
	"ground": ["railgun", "heavy_battery", "cannon_turret", "at_gun", "pillbox", "mg_turret", "mortar_pit",
		"sandbag_nest", "watchtower", "sniper_nest", "flame_bunker"],
	"aa": ["sam_site", "flak_battery", "ciws"],
	"int": ["interceptor_battery", "abm_battery"],
	"coast": ["coastal_battery", "torpedo_battery"],
	"support": ["repair_depot"],
}
const ARMOR_DEF := ["railgun", "at_gun", "cannon_turret", "heavy_battery"]
const INF_DEF := ["pillbox", "mg_turret", "mortar_pit", "sandbag_nest", "sniper_nest", "flame_bunker"]
const REBUILD_ORDER := ["power_plant", "tech_center", "factory", "airbase", "missile_silo", "barracks",
	"radar_station", "naval_port", "oil_refinery", "metropolis", "town"]
const CRITICAL := ["power_plant", "tech_center", "factory", "airbase"]

var battle
var team := 1
var think_interval := 2.2
var allow_nukes := true
var strategic_after := 80.0
var skill := 0.8
var style := "balanced"           # from the chosen strategy: balanced | offense | defense | air | naval | missile | infantry
var wave_secs := 30.0
var think_t := 4.0
var save_until := 0.0
var reserve := 0.0
var queue: Array = []              # [{kind, id, slot, fails}] bought in order; the head is saved for
var queue_deadline := 0.0
var spent_def := 0.0
var spent_army := 0.0
var urgent_t := 0.0
var _initial: Dictionary = {}      # country building id -> how many we start with
var _mine: Array = []              # our defensive structures from the last scan
var autopilot := false             # true = this commander only buys UNITS for the player (team 0)
var active := true
var keep_cash := 350.0             # autopilot never spends below this, so the player always has a reserve
var mine_t := 0.0


func configure(dd: Dictionary) -> void:
	think_interval = float(dd.get("ai_think", 2.2))
	allow_nukes = bool(dd.get("ai_nukes", true))
	strategic_after = float(dd.get("ai_strategic_after", 80.0))
	skill = clampf(float(dd.get("ai_skill", 0.8)), 0.0, 1.0)
	wave_secs = float(dd.get("ai_wave_secs", 30.0))
	style = GameData.strategy_style(team)
	if style == "missile":
		strategic_after *= 0.7
	_initial = {}
	for e in GameData.country:
		var nid := str(e[0])
		_initial[nid] = int(_initial.get(nid, 0)) + 1


func _process(delta: float) -> void:
	if battle == null or battle.over or not active:
		return
	think_t -= delta
	if think_t <= 0.0:
		think_t = think_interval * randf_range(0.8, 1.2)
		_think()


func _think() -> void:
	var sc: Dictionary = _scan()
	_mine = sc["mine"]
	if autopilot:
		if queue.is_empty() and battle.elapsed > 3.0:
			_plan_army(sc)
			queue_deadline = battle.elapsed + 60.0
		_run_queue()
		return
	if _try_strategic():
		return
	if _try_infrastructure():
		return
	_urgent(sc)
	_try_minefield(sc)
	if queue.is_empty():
		_plan(sc)
	_run_queue()


# ------------------------------------------------------------------ scanning

func _scan() -> Dictionary:
	var sc := {"en_armor": 0.0, "en_inf": 0.0, "en_air": 0.0, "en_navy": 0.0, "en_struct": 0, "en_aa": 0,
		"my_units": 0, "mine": [], "my_ids": {}}
	for n in battle.get_tree().get_nodes_in_group("team%d" % (1 - team)):
		var c := n as Combatant
		if c == null or c.dead or c.is_queued_for_deletion() or c.layer == "missile":
			continue
		var cost := float(c.def.get("cost", 0))
		match str(c.def.get("tab", "")):
			"infantry":
				sc["en_inf"] += cost
			"vehicles":
				sc["en_armor"] += cost
			"air":
				sc["en_air"] += cost
			"navy":
				sc["en_navy"] += cost
			"defenses":
				sc["en_struct"] += 1
		if str(c.def.get("role", "")) == "anti_air":
			sc["en_aa"] += 1
	var mine: Array = sc["mine"]
	var ids: Dictionary = sc["my_ids"]
	for n in battle.get_tree().get_nodes_in_group("team%d" % team):
		var c := n as Combatant
		if c == null or c.dead or c.is_queued_for_deletion() or c.layer == "missile":
			continue
		ids[c.id] = int(ids.get(c.id, 0)) + 1
		if c.kind == "structure" and not c.is_trap():
			mine.append({"id": c.id, "pos": c.position, "role": str(c.def.get("role", "")), "cost": float(c.def.get("cost", 0))})
		elif c.kind == "unit":
			sc["my_units"] += 1
	return sc


# ------------------------------------------------------------------ positions

func _spawn_pos(front: bool = false) -> Vector2:
	var zone_x := float(GameData.settings.get("enemy_zone_x", 2200))
	var x := randf_range(zone_x + 20.0, zone_x + 520.0)
	if front:
		x = randf_range(zone_x + 10.0, zone_x + 180.0)
	return Vector2(x, randf_range(battle.FIELD_TOP + 30.0, battle.FIELD_BOTTOM - 30.0))


func _mid_pos() -> Vector2:
	var zone_x := float(GameData.settings.get("enemy_zone_x", 2200))
	return Vector2(randf_range(zone_x + 160.0, zone_x + 420.0), randf_range(battle.FIELD_TOP + 60.0, battle.FIELD_BOTTOM - 60.0))


func _rear_pos() -> Vector2:
	var zone_x := float(GameData.settings.get("enemy_zone_x", 2200))
	return Vector2(randf_range(zone_x + 250.0, float(battle.W) - 120.0),
		randf_range(battle.FIELD_TOP + 60.0, battle.FIELD_BOTTOM - 60.0))


## A spot on land near the coast (for the Naval Port and coastal batteries).
func _coast_pos() -> Vector2:
	var zone_x := float(GameData.settings.get("enemy_zone_x", 2200))
	var north := randf() < 0.5
	var y: float = battle.FIELD_TOP + randf_range(40.0, 120.0) if north else battle.FIELD_BOTTOM - randf_range(40.0, 120.0)
	return Vector2(randf_range(zone_x + 150.0, float(battle.W) - 150.0), y)


## A spot in the enemy-side sea deep enough for this draft (-1,-1 if none found).
func _naval_pos(draft: int) -> Vector2:
	var zone_x := float(GameData.settings.get("enemy_zone_x", 2200))
	for i in 12:
		var dy := randf_range(Water.COAST + 30.0, Water.COAST + 170.0)
		var p := Vector2(randf_range(zone_x + 20.0, float(battle.W) - 60.0), Water.MID_Y + (-dy if randf() < 0.5 else dy))
		if Water.kind_at(p) >= draft:
			return p
	return Vector2(-1.0, -1.0)


## How much defensive value (cost) of the wanted kind already stands near `pos`.
func _cover(pos: Vector2, radius: float, ground: bool) -> float:
	var v := 0.0
	for s in _mine:
		var role := str(s["role"])
		var is_ground := role == "defense"
		var is_air := role == "anti_air" or role == "interceptor"
		if (ground and not is_ground) or (not ground and not is_air):
			continue
		var sp: Vector2 = s["pos"]
		if sp.distance_to(pos) <= radius:
			v += float(s["cost"])
	return v


## Picks a defensive site. Ground defenses go between important buildings and the enemy
## (front-most, least-defended first); AA / interceptors ring the high-value buildings.
func _defense_pos(front: bool, behind: bool = false) -> Vector2:
	var zone_x := float(GameData.settings.get("enemy_zone_x", 2200))
	var span := float(battle.W) - zone_x
	var objs: Array = battle._objectives[team]
	var cands: Array = []
	var weights: Array = []
	var total := 0.0
	for o in objs:
		if not is_instance_valid(o):
			continue
		var c := o as Combatant
		if c == null or c.dead or c.is_queued_for_deletion():
			continue
		var imp := float(ANCHOR_VALUE.get(c.id, 0.6))
		var w := imp / (1.0 + _cover(c.position, 380.0, front) / 500.0)
		if front:
			w *= 0.6 + 1.4 * (1.0 - clampf((c.position.x - zone_x) / span, 0.0, 1.0))
		cands.append(c)
		weights.append(w)
		total += w
	if cands.is_empty():
		return _spawn_pos(front)
	var roll := randf() * total
	var chosen: Combatant = cands[0]
	for i in cands.size():
		roll -= float(weights[i])
		if roll <= 0.0:
			chosen = cands[i]
			break
	var off := Vector2.ZERO
	if front:
		off = Vector2(-randf_range(50.0, 170.0), randf_range(-170.0, 170.0))   # toward the player
		if behind:
			off.x = randf_range(30.0, 120.0)
	else:
		off = Vector2.from_angle(randf() * TAU) * randf_range(55.0, 150.0)
	var p := chosen.position + off
	p.x = clampf(p.x, zone_x + 12.0, float(battle.W) - 30.0)
	p.y = clampf(p.y, battle.FIELD_TOP + 30.0, battle.FIELD_BOTTOM - 30.0)
	return p


func _slot_pos(slot: String, d: Dictionary) -> Vector2:
	match slot:
		"front":
			return _spawn_pos(true)
		"mid":
			return _mid_pos()
		"air":
			return _rear_pos()
		"naval":
			return _naval_pos(int(d.get("draft", 1)))
		"coast":
			return _coast_pos()
		"ground":
			return _defense_pos(true)
		"aa", "int":
			return _defense_pos(false)
		"support":
			return _defense_pos(true, true)
	return _spawn_pos(false)


# ------------------------------------------------------------------ strategic strikes

func _try_strategic() -> bool:
	if battle.elapsed < strategic_after:
		return false
	var money: float = battle.money[team]
	var enemy := 1 - team
	var ids: Array = GameData.strategic.keys()
	ids.sort_custom(func(a, b): return float(GameData.strategic[a].cost) > float(GameData.strategic[b].cost))
	for id in ids:
		var m: Dictionary = GameData.def_for(team, "strategic", str(id))
		if bool(m.get("banned", false)):
			continue
		var is_nuke := bool(m.get("nuke", false))
		if is_nuke and not allow_nukes:
			continue
		if battle.elapsed < strategic_after + float(m.get("ai_delay", 0.0)):
			continue
		if battle.get_cooldown(team, "strategic", id) > 0.0:
			continue
		if battle.missing_requirement(team, m) != "":
			continue
		var cost := float(m.get("cost", 100))
		var need := float(m.get("ai_min", maxf(cost, 200.0)))
		var tgt: Dictionary = battle.best_strike_point(enemy, float(m.get("splash", 100)))
		if float(tgt["score"]) < need:
			continue
		if money >= cost + 60.0:
			if randf() > (0.5 if is_nuke else 0.7):
				continue
			if battle.deploy(team, "strategic", id, tgt["pos"]) == "":
				reserve = 0.0
				return true
		elif battle.elapsed >= save_until and randf() < (0.3 if is_nuke else 1.0):
			_save_for(cost + 60.0, 50.0 if is_nuke else 14.0)      # worthwhile target: put money aside
	return false


func _save_for(amount: float, seconds: float) -> void:
	reserve = amount
	save_until = battle.elapsed + seconds


# ------------------------------------------------------------------ infrastructure

## Rebuild lost power / tech / factories / airbase / silos / radar / ports and (when rich) the economy.
func _try_infrastructure() -> bool:
	if battle.elapsed < 15.0:
		return false
	var money: float = battle.money[team]
	for nid in REBUILD_ORDER:
		var want_n: int = int(_initial.get(nid, 0))
		if want_n <= 0 or battle.national_count(team, nid) >= want_n:
			continue
		var d: Dictionary = GameData.get_def("national", nid)
		if d.is_empty():
			continue
		var cost := float(d.get("cost", 0))
		var is_critical := CRITICAL.has(nid)
		var need := cost + (150.0 if is_critical else 600.0)
		if not is_critical and battle.elapsed < 90.0:
			continue
		if money < need:
			if is_critical and battle.elapsed >= save_until:
				_save_for(need, 25.0)
			continue
		for attempt in 6:
			var p := _coast_pos() if nid == "naval_port" else _rear_pos()
			if battle.deploy(team, "national", nid, p) == "":
				return true
	# once the core country stands: extra economy / support / forward bases
	if battle.elapsed > 150.0 and money > 1700.0 and randf() < 0.5:
		var nid2: String = EXTRA_BUILDINGS[randi() % EXTRA_BUILDINGS.size()]
		var d2: Dictionary = GameData.get_def("national", nid2)
		if not d2.is_empty() and battle.national_count(team, nid2) < mini(int(d2.get("limit", 2)), 2) \
				and money > float(d2.get("cost", 0)) + 900.0:
			for attempt in 6:
				var p2: Vector2
				if nid2 == "forward_base":
					p2 = Vector2(randf_range(3500.0, float(GameData.settings.get("enemy_zone_x", 4900)) - 300.0),
						randf_range(battle.FIELD_TOP + 150.0, battle.FIELD_BOTTOM - 150.0))
				else:
					p2 = _rear_pos()
				if battle.deploy(team, "national", nid2, p2) == "":
					return true
	return false


## Scatters a small minefield / wire belt in front of the defenses (and sea mines when the player has a navy).
func _try_minefield(sc: Dictionary) -> void:
	if battle.elapsed < 70.0 or battle.elapsed < mine_t:
		return
	mine_t = battle.elapsed + randf_range(14.0, 26.0)
	var money: float = battle.money[team]
	if money < 650.0 or battle.trap_count(team) >= int(GameData.settings.get("trap_cap", 90)) - 6:
		return
	var ea: float = sc["en_armor"]
	var ei: float = sc["en_inf"]
	var en: float = sc["en_navy"]
	var pool: Array = []
	if en > 400.0 and randf() < 0.3:
		pool = ["naval_mine"]
	elif ea >= ei:
		pool = ["landmine", "landmine", "tank_trap", "napalm_trap"]
	else:
		pool = ["ap_mine", "ap_mine", "claymore", "barbed_wire", "napalm_trap"]
	var id: String = pool[randi() % pool.size()]
	var d: Dictionary = GameData.def_for(team, "structure", id)
	if d.is_empty() or bool(d.get("banned", false)):
		return
	var centre: Vector2
	if id == "naval_mine":
		centre = _naval_pos(1)
		if centre.x < 0.0:
			return
	else:
		centre = _defense_pos(true) + Vector2(-randf_range(60.0, 200.0), 0.0)
		centre.x = maxf(centre.x, float(GameData.settings.get("enemy_zone_x", 4900)) + 90.0)
	var n := randi_range(3, 5)
	for i in n:
		var p := centre + Vector2(randf_range(-110.0, 110.0), randf_range(-110.0, 110.0))
		if battle.deploy(team, "structure", id, p) != "":
			continue


# ------------------------------------------------------------------ planning

func _def_have(sc: Dictionary) -> Dictionary:
	var have := {"ground": 0.0, "aa": 0.0, "int": 0.0, "coast": 0.0, "support": 0.0}
	var mine: Array = sc["mine"]
	for s in mine:
		var k := _class_of(str(s["id"]), str(s["role"]))
		have[k] = float(have[k]) + float(s["cost"])
	return have


func _class_of(id: String, role: String) -> String:
	if id == "coastal_battery":
		return "coast"
	match role:
		"anti_air":
			return "aa"
		"interceptor":
			return "int"
		"support":
			return "support"
	return "ground"


func _def_want(sc: Dictionary) -> Dictionary:
	var t: float = battle.elapsed
	var dm := 0.8 + skill * 0.6
	var ea: float = sc["en_armor"]
	var ei: float = sc["en_inf"]
	var eair: float = sc["en_air"]
	var en: float = sc["en_navy"]
	var launched_n: int = battle.launched[1 - team]
	var w_int := 0.0
	if launched_n > 0:
		w_int = 700.0 * float(clampi(1 + launched_n / 2, 1, 5))
		if launched_n >= 4:
			w_int += 1400.0
	elif t > 150.0:
		w_int = 700.0
	var w_aa := (250.0 if t > 45.0 else 0.0) + eair * 0.9 + (400.0 if t > 240.0 else 0.0)
	var mine: Array = sc["mine"]
	return {
		"ground": minf((650.0 + t * 4.0 + ea * 0.22 + ei * 0.12) * dm, 7000.0),
		"aa": minf(w_aa * dm, 4200.0),
		"int": w_int,
		"coast": clampf(en * 0.45, 0.0, 1800.0),
		"support": 350.0 if mine.size() >= 8 else 0.0,
	}


## Immediate reaction to missile launches / air raids: put the missing shield at the head of the queue.
func _urgent(sc: Dictionary) -> void:
	if battle.elapsed < urgent_t:
		return
	var have := _def_have(sc)
	var want := _def_want(sc)
	for k in ["int", "aa"]:
		var w: float = want[k]
		if w <= 0.0:
			continue
		var ratio: float = (w - float(have[k])) / w
		var triggered: bool = (k == "int" and int(battle.launched[1 - team]) > 0) or (k == "aa" and float(sc["en_air"]) >= 700.0)
		if triggered and ratio > 0.5:
			var id := _pick_defense(str(k), sc)
			if id != "":
				queue.insert(0, {"kind": "structure", "id": id, "slot": str(k), "fails": 0})
				queue_deadline = battle.elapsed + 45.0
				urgent_t = battle.elapsed + 8.0
				return


func _plan(sc: Dictionary) -> void:
	var t: float = battle.elapsed
	var def_share := clampf(0.5 - t / 1500.0 + _style_def(), 0.12, 0.65)
	var total := spent_def + spent_army + 1.0
	var queued := false
	if spent_def / total < def_share:
		queued = _plan_defense(sc)
	if not queued:
		queued = _plan_army(sc)
	if not queued:
		queued = _plan_defense(sc)
	if queued:
		queue_deadline = t + 75.0


func _plan_defense(sc: Dictionary) -> bool:
	var mine: Array = sc["mine"]
	if mine.size() >= int(GameData.settings.get("structure_cap", 30)) - 1:
		return false
	var have := _def_have(sc)
	var want := _def_want(sc)
	var budget: float = float(battle.income_rate(team)) * 30.0 + 300.0
	var spent := 0.0
	var queued := false
	for rnd in 3:
		var best_k := ""
		var best_r := 0.18
		for k in want:
			var w: float = want[k]
			if w <= 0.0:
				continue
			var r: float = (w - float(have[k])) / w
			if r > best_r:
				best_r = r
				best_k = str(k)
		if best_k == "":
			break
		var id := _pick_defense(best_k, sc)
		if id == "":
			have[best_k] = float(want[best_k])       # nothing buildable for this need right now
			continue
		var cost := float(GameData.def_for(team, "structure", id).get("cost", 0))
		queue.append({"kind": "structure", "id": id, "slot": best_k, "fails": 0})
		have[best_k] = float(have[best_k]) + cost
		spent += cost
		queued = true
		if spent >= budget:
			break
	return queued


func _pick_defense(k: String, sc: Dictionary) -> String:
	var pool: Array = DEF_POOL[k]
	var money: float = battle.money[team]
	var reach := money + float(battle.income_rate(team)) * 25.0
	var ea: float = sc["en_armor"]
	var ei: float = sc["en_inf"]
	var my_ids: Dictionary = sc["my_ids"]
	var mine: Array = sc["mine"]
	var near_cap: bool = mine.size() > int(GameData.settings.get("structure_cap", 30)) - 10
	var options: Array = []
	var total := 0.0
	for id in pool:
		var d: Dictionary = GameData.def_for(team, "structure", str(id))
		if d.is_empty() or bool(d.get("banned", false)):
			continue
		var cost := float(d.get("cost", 0))
		if cost > reach:
			continue
		if near_cap and cost < 400.0 and k != "support":
			continue        # structure slots are precious: only premium defenses now
		if battle.missing_requirement(team, d) != "":
			continue
		if bool(d.get("needs_power", false)) and not battle.has_capability(team, "power"):
			continue
		var w := float(d.get("ai_tier", 1.0))
		if ARMOR_DEF.has(id):
			w *= 0.6 + ea / 1200.0
		elif INF_DEF.has(id):
			w *= 0.6 + ei / 1000.0
		w *= pow(0.75, float(my_ids.get(id, 0)))
		w *= 1.4 if cost <= money else 0.7
		if w > 0.0:
			options.append([str(id), w])
			total += w
	if options.is_empty():
		return ""
	var roll := randf() * total
	for o in options:
		roll -= float(o[1])
		if roll <= 0.0:
			return str(o[0])
	return str(options[0][0])


func _plan_army(sc: Dictionary) -> bool:
	var inc: float = battle.income_rate(team)
	var budget := clampf(inc * wave_secs, 400.0, 4200.0)
	var picks: Array = []
	var spent := 0.0
	var tries := 0
	while budget - spent > 160.0 and picks.size() < 9 and tries < 24:
		tries += 1
		var id := _pick_unit(sc, budget - spent, picks)
		if id == "":
			break
		picks.append(id)
		spent += float(GameData.def_for(team, "unit", id).get("cost", 0))
	if picks.is_empty():
		return false
	for id in picks:
		var d: Dictionary = GameData.def_for(team, "unit", str(id))
		queue.append({"kind": "unit", "id": str(id), "slot": _unit_slot(d), "fails": 0})
	return true


func _unit_slot(d: Dictionary) -> String:
	var dom := str(d.get("domain", "land"))
	if dom == "water" or dom == "sub":
		return "naval"
	if str(d.get("tab", "")) == "air":
		return "air"
	var role := str(d.get("role", ""))
	if role == "artillery" or role == "anti_air" or role == "support":
		return "mid"
	return "front"


func _pick_unit(sc: Dictionary, remaining: float, picks: Array) -> String:
	var money: float = battle.money[team]
	var inc: float = battle.income_rate(team)
	var cap_n: int = int(GameData.settings.get("unit_cap", 90))
	var used: int = int(sc["my_units"]) + picks.size()
	if used >= cap_n:
		return ""
	var min_cost := 0.0
	if used > int(cap_n * 0.85):
		min_cost = 500.0
	elif used > int(cap_n * 0.7):
		min_cost = 250.0
	var first := picks.is_empty()
	var limit := maxf(remaining * (1.45 if first else 1.15), 120.0)
	var noise := randf() < (1.0 - skill) * 0.5          # weaker AIs sometimes just buy something random
	var options: Array = []
	var total := 0.0
	for id in GameData.units:
		var d: Dictionary = GameData.def_for(team, "unit", str(id))
		if bool(d.get("banned", false)):
			continue
		var cost := float(d.get("cost", 0))
		if cost < min_cost or cost > limit or cost > money + inc * 45.0:
			continue
		if battle.missing_requirement(team, d) != "":
			continue
		var w := 1.0
		if not noise:
			var tier := float(d.get("ai_tier", 0.5))
			if style == "infantry" and str(d.get("tab", "")) == "infantry":
				tier = maxf(tier, 0.6)
			w = tier * _role_w(str(d.get("role", "")), sc) * float(d.get("ai_weight", 1.0)) * _style_w(d)
			for pid in picks:
				if pid == id:
					w *= 0.55
		if w > 0.0:
			options.append([str(id), w])
			total += w
	if options.is_empty():
		return ""
	var roll := randf() * total
	for o in options:
		roll -= float(o[1])
		if roll <= 0.0:
			return str(o[0])
	return str(options[0][0])


## Strategy flavour: how much the chosen strategy shifts spending toward defense / certain unit types.
func _style_def() -> float:
	match style:
		"defense":
			return 0.15
		"offense":
			return -0.12
		"infantry":
			return -0.05
	return 0.0


func _style_w(d: Dictionary) -> float:
	var tab := str(d.get("tab", ""))
	var role := str(d.get("role", ""))
	match style:
		"offense":
			return 1.3 if (role == "armor" or role == "light" or tab == "air") else 1.0
		"defense":
			return 1.25 if (role == "artillery" or role == "anti_air" or role == "anti_armor") else 1.0
		"air":
			if tab == "air":
				return 1.7
			return 1.2 if role == "anti_air" else 1.0
		"naval":
			return 2.2 if tab == "navy" else 1.0
		"missile":
			return 1.25 if role == "artillery" else 1.0
		"infantry":
			return 6.0 if (tab == "infantry" and role != "support") else 1.0
	return 1.0


func _role_w(role: String, sc: Dictionary) -> float:
	var ea: float = sc["en_armor"]
	var ei: float = sc["en_inf"]
	var eair: float = sc["en_air"]
	var en: float = sc["en_navy"]
	var es: int = sc["en_struct"]
	var eaa: int = sc["en_aa"]
	var aa_pen := 1.0 / (1.0 + float(eaa) * 0.12)
	match role:
		"armor":
			return 1.3
		"anti_armor":
			return 0.5 + ea / 900.0
		"anti_air":
			return 0.15 + eair / 450.0
		"artillery":
			return 0.5 + float(es) * 0.12 + ei / 1800.0
		"air":
			return (0.9 + ea / 1400.0) * aa_pen
		"bomber":
			return (0.6 + float(es) * 0.15) * aa_pen
		"infantry":
			return 0.25
		"light":
			return 0.3
		"support":
			return 0.35 if int(sc["my_units"]) > 6 else 0.0
		"ship":
			return 0.8 + en / 1500.0
		"sub":
			return 0.45 + en / 1200.0
		"carrier":
			return 0.3
		"diver":
			return 0.15
	return 0.5


# ------------------------------------------------------------------ buying

func _run_queue() -> void:
	if queue.is_empty():
		return
	if battle.elapsed > queue_deadline:
		queue.clear()
		return
	var spare: float = battle.money[team]
	if autopilot:
		spare -= keep_cash
	if battle.elapsed < save_until:
		spare -= reserve               # a missile strike / rebuild is being saved for
	var bought := 0
	var i := 0
	while i < queue.size() and bought < 4:
		var item: Dictionary = queue[i]
		var kind := str(item["kind"])
		var id := str(item["id"])
		var d: Dictionary = GameData.def_for(team, kind, id)
		var needs_power: bool = bool(d.get("needs_power", false)) and not battle.has_capability(team, "power")
		if d.is_empty() or bool(d.get("banned", false)) or needs_power or battle.missing_requirement(team, d) != "":
			queue.remove_at(i)
			continue
		if battle.get_cooldown(team, kind, id) > 0.0:
			i += 1
			continue
		var cost := float(d.get("cost", 0))
		if spare < cost:
			return                      # saving for this one: nothing behind it is bought first
		var res := _place(kind, id, str(item.get("slot", "front")), d)
		if res == "":
			if kind == "structure":
				spent_def += cost
			else:
				spent_army += cost
			spare -= cost
			queue.remove_at(i)
			bought += 1
		elif res == "stop":
			queue.clear()
			return
		else:
			item["fails"] = int(item.get("fails", 0)) + 1
			if int(item["fails"]) >= 3:
				queue.remove_at(i)
			else:
				i += 1


## "" = deployed, "stop" = a cap / funds problem (drop the plan), "fail" = no legal spot found this time.
func _auto_unit_pos(d: Dictionary) -> Vector2:
	var dom := str(d.get("domain", "land"))
	if dom == "water" or dom == "sub":
		var pz := float(GameData.settings.get("player_zone_x", 1500))
		for i in 16:
			var dy := randf_range(Water.COAST + 30.0, Water.COAST + 260.0)
			var p := Vector2(randf_range(100.0, pz - 40.0), Water.MID_Y + (-dy if randf() < 0.5 else dy))
			if Water.kind_at(p) >= int(d.get("draft", 1)):
				return p
		return Vector2(-1.0, -1.0)
	return Vector2(randf_range(150.0, 700.0), randf_range(battle.FIELD_TOP + 200.0, battle.FIELD_BOTTOM - 200.0))


func _place(kind: String, id: String, slot: String, d: Dictionary) -> String:
	for attempt in 8:
		var p := _auto_unit_pos(d) if team == 0 else _slot_pos(slot, d)
		if p.x < 0.0:
			continue
		var r: String = battle.deploy(team, kind, id, p)
		if r == "":
			return ""
		if r.begins_with("Unit cap") or r.begins_with("Defense cap") or r.begins_with("Not enough") or r.begins_with("Requires"):
			return "stop"
		if r.contains("not ready"):
			return "fail"
	return "fail"


# ------------------------------------------------------------------ save / load

func to_dict() -> Dictionary:
	return {"think_t": think_t, "save_until": save_until, "reserve": reserve, "queue": queue.duplicate(true),
		"queue_deadline": queue_deadline, "spent_def": spent_def, "spent_army": spent_army}


func from_dict(d: Dictionary) -> void:
	think_t = float(d.get("think_t", 2.0))
	save_until = float(d.get("save_until", 0.0))
	reserve = float(d.get("reserve", 0.0))
	queue_deadline = float(d.get("queue_deadline", 0.0))
	spent_def = float(d.get("spent_def", 0.0))
	spent_army = float(d.get("spent_army", 0.0))
	queue = []
	var q: Variant = d.get("queue", [])
	if q is Array:
		for item in q:
			if item is Dictionary and item.has("kind") and item.has("id"):
				queue.append(item)
