class_name AICommander
extends Node
## Enemy commander. Every few seconds it looks at what the player has, then:
##   1. fires missiles / nukes where they will do the most damage,
##   2. rebuilds lost country buildings (power, factories, airbase, silos...),
##   3. builds interceptors / AA / turrets when threatened,
##   4. spends the rest of its money on a counter-picked army.

var battle
var team := 1
var think_interval := 2.2
var allow_nukes := true
var strategic_after := 80.0
var think_t := 4.0
var save_until := 0.0
var reserve := 0.0


func configure(dd: Dictionary) -> void:
	think_interval = float(dd.get("ai_think", 2.2))
	allow_nukes = bool(dd.get("ai_nukes", true))
	strategic_after = float(dd.get("ai_strategic_after", 80.0))


func _process(delta: float) -> void:
	if battle == null or battle.over:
		return
	think_t -= delta
	if think_t <= 0.0:
		think_t = think_interval * randf_range(0.8, 1.2)
		_think()


func _think() -> void:
	var enemy := 1 - team
	var info: Dictionary = battle.intel(enemy)
	var mine: Dictionary = battle.intel(team)
	if _try_strategic(info):
		return
	if _try_infrastructure():
		return
	if _try_defense(info, mine):
		return
	_build_army(info)


func _spawn_pos(front: bool = false) -> Vector2:
	var zone_x := float(GameData.settings.get("enemy_zone_x", 2200))
	var x := randf_range(zone_x + 20.0, zone_x + 520.0)
	if front:
		x = randf_range(zone_x + 10.0, zone_x + 180.0)
	return Vector2(x, randf_range(battle.FIELD_TOP + 30.0, battle.FIELD_BOTTOM - 30.0))


func _rear_pos() -> Vector2:
	var zone_x := float(GameData.settings.get("enemy_zone_x", 2200))
	return Vector2(randf_range(zone_x + 250.0, float(battle.W) - 120.0),
		randf_range(battle.FIELD_TOP + 60.0, battle.FIELD_BOTTOM - 60.0))


func _kind_of(id: String) -> String:
	return "structure" if GameData.structures.has(id) else "unit"


func _try_strategic(_info: Dictionary) -> bool:
	if battle.elapsed < strategic_after:
		return false
	var money: float = battle.money[team]
	var enemy := 1 - team
	var ids: Array = GameData.strategic.keys()
	ids.sort_custom(func(a, b): return float(GameData.strategic[a].cost) > float(GameData.strategic[b].cost))
	for id in ids:
		var m: Dictionary = GameData.strategic[id]
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
			if randf() > (0.5 if is_nuke else 0.6):
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


## Rebuild lost power / factories / airbase / radar / silos / tech center.
func _try_infrastructure() -> bool:
	if battle.elapsed < 20.0:
		return false
	var money: float = battle.money[team]
	for cap in ["power", "barracks", "factory", "airbase", "radar", "silo", "tech"]:
		if battle.has_capability(team, cap):
			continue
		var nid := GameData.national_providing(cap)
		if nid == "":
			continue
		var d := GameData.get_def("national", nid)
		var need := float(d.get("cost", 0)) + 150.0
		if money < need:
			if battle.elapsed >= save_until and cap in ["power", "barracks", "factory", "airbase"]:
				_save_for(need, 25.0)
			continue
		for attempt in 6:
			if battle.deploy(team, "national", nid, _rear_pos()) == "":
				return true
	return false


func _try_defense(info: Dictionary, mine: Dictionary) -> bool:
	var enemy := 1 - team
	var ids: Dictionary = mine["ids"]
	# Anti-missile shield once the player starts launching things.
	var launched: int = battle.launched[enemy]
	var want_int := 0
	if launched > 0:
		want_int = clampi(1 + launched / 2, 1, 5)
	elif battle.elapsed > 240.0:
		want_int = 1
	var have_int := int(ids.get("interceptor_battery", 0)) + int(ids.get("abm_battery", 0))
	if have_int < want_int:
		var pick_i := "abm_battery" if (launched > 4 and randf() < 0.5) else "interceptor_battery"
		if battle.deploy(team, "structure", pick_i, _spawn_pos()) == "":
			return true
		if pick_i != "interceptor_battery" and battle.deploy(team, "structure", "interceptor_battery", _spawn_pos()) == "":
			return true
	# Air defense.
	var air_enemy: int = info["air"]
	var aa_ids := ["sam_site", "flak_battery", "ciws", "aa_truck", "manpads", "sam_truck", "interceptor_jet"]
	var aa_count := 0
	for aid in aa_ids:
		aa_count += int(ids.get(aid, 0))
	if air_enemy >= 1 and aa_count < air_enemy + 1:
		var pick: String = aa_ids[randi() % aa_ids.size()]
		var front := pick != "interceptor_jet"
		if battle.deploy(team, _kind_of(pick), pick, _spawn_pos(front)) == "":
			return true
	# Static defenses near the front; the line grows over time.
	var want_def := clampi(3 + int(battle.elapsed / 120.0), 3, 12)
	if battle.elapsed > 50.0 and int(mine["structures"]) < want_def and randf() < 0.35:
		var pool: Array = []
		for sid in GameData.structures:
			var sd: Dictionary = GameData.structures[sid]
			if str(sd.get("role", "")) == "defense" and bool(sd.get("ai", true)):
				pool.append(sid)
		if not pool.is_empty():
			var pick2: String = pool[randi() % pool.size()]
			if battle.deploy(team, "structure", pick2, _spawn_pos(true)) == "":
				return true
	return false


func _pick_group(info: Dictionary) -> String:
	var w_inf := 0.9
	var w_veh := 1.2
	var w_air := 0.8 if battle.elapsed >= 40.0 else 0.0
	w_air += float(info["vehicles"]) * 0.02 if w_air > 0.0 else 0.0
	var roll := randf() * (w_inf + w_veh + w_air)
	if roll < w_inf:
		return "infantry"
	if roll < w_inf + w_veh:
		return "vehicles"
	return "air"


func _role_weight(role: String, info: Dictionary) -> float:
	match role:
		"anti_air": return 0.1 + float(info["air"]) * 1.2
		"anti_armor": return 0.8 + float(info["vehicles"]) * 0.6
		"light", "bomber": return 0.8 + float(info["infantry"]) * 0.3
		"artillery": return 0.7 + float(info["structures"]) * 0.4 + float(info["infantry"]) * 0.15
		"air": return 0.6 + float(info["vehicles"]) * 0.25
		"armor": return 1.2
		"support": return 0.3
	return 1.0


func _build_army(info: Dictionary) -> void:
	for attempt in 3:
		var money: float = battle.money[team]
		if battle.elapsed < save_until:
			money -= reserve
		var group := _pick_group(info)
		var options: Array = []
		var total := 0.0
		for id in GameData.units:
			var d: Dictionary = GameData.units[id]
			if str(d.get("tab", "")) != group:
				continue
			if float(d.cost) > money:
				continue
			if battle.missing_requirement(team, d) != "":
				continue
			if battle.get_cooldown(team, "unit", id) > 0.0:
				continue
			if battle.elapsed < 25.0 and float(d.cost) > 250.0:
				continue
			var w := _role_weight(str(d.get("role", "")), info) * float(d.get("ai_weight", 1.0)) * (0.6 + float(d.cost) / 500.0)
			if w > 0.0:
				options.append([id, w])
				total += w
		if options.is_empty():
			continue
		var roll := randf() * total
		var chosen: String = options[0][0]
		for o in options:
			roll -= float(o[1])
			if roll <= 0.0:
				chosen = o[0]
				break
		battle.deploy(team, "unit", chosen, _spawn_pos(false))


func to_dict() -> Dictionary:
	return {"think_t": think_t, "save_until": save_until, "reserve": reserve}


func from_dict(d: Dictionary) -> void:
	think_t = float(d.get("think_t", 2.0))
	save_until = float(d.get("save_until", 0.0))
	reserve = float(d.get("reserve", 0.0))
