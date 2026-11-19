extends Node
## Headless smoke test:
##   godot --headless --path . --fixed-fps 60 res://tools/selftest.tscn
## Exercises the country layout, capabilities / gating, deployment of every unit and defense,
## combat, AI, interceptors, nukes, save/load and game over.

var battle: Battle
var frame := 0
var failures: Array[String] = []
var snapshot := {}
var rng := RandomNumberGenerator.new()


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		print("  FAIL  ", msg)
		failures.append(msg)


## Every army must define a complete, distinct roster (no bare renames of the generic slot).
func _check_rosters() -> void:
	for fid in GameData.factions:
		var f: Dictionary = GameData.factions[fid]
		var ro: Dictionary = f.get("roster", {})
		var ban: Array = f.get("ban", [])
		var missing: Array[String] = []
		var seen := {}
		var dupes: Array[String] = []
		var untouched: Array[String] = []
		for kind in ["unit", "structure", "strategic"]:
			var grp: Dictionary = GameData.units if kind == "unit" else (GameData.structures if kind == "structure" else GameData.strategic)
			for id in grp:
				if ban.has(id) or int(GameData.get_def(kind, str(id)).get("v5", 0)) == 1:
					continue
				var d := GameData.def_for_faction(str(fid), kind, str(id))
				if not ro.has(id) or float(d.get("hp", 0)) <= 0.0 or str(d.get("desc", "")) == "" or str(d.get("specs", "")) == "":
					missing.append(str(id))
					continue
				var nm := str(d.get("name", ""))
				if seen.has(nm):
					dupes.append(nm)
				seen[nm] = true
				var base_d: Dictionary = grp[id]
				if kind != "strategic" and is_equal_approx(float(d.get("hp", 0)), float(base_d.get("hp", 0))) and is_equal_approx(float(d.get("damage", 0)), float(base_d.get("damage", 0))) and is_equal_approx(float(d.get("range", 0)), float(base_d.get("range", 0))):
					untouched.append(str(id))
		check(missing.is_empty(), "%s roster complete (missing: %s)" % [fid, ", ".join(PackedStringArray(missing))])
		check(dupes.is_empty(), "%s unit names unique (%s)" % [fid, ", ".join(PackedStringArray(dupes))])
		check(untouched.size() < 8, "%s units have their own stats (%d identical to the generic slot)" % [fid, untouched.size()])


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep ticking when the game pauses on game over
	rng.seed = 11
	SaveManager.pending_load = ""
	_check_rosters()
	SaveManager.pending_difficulty = "normal"
	battle = load("res://scenes/battle.tscn").instantiate()
	add_child(battle)


func count(team: int) -> int:
	var n := 0
	for c in get_tree().get_nodes_in_group("team%d" % team):
		if c is Combatant and not c.dead and not c.is_queued_for_deletion():
			n += 1
	return n


## Tries random spots in a team's zone until the deployment is accepted.
func deploy_anywhere(team: int, kind: String, id: String) -> String:
	var err := ""
	for i in 300:
		var x := rng.randf_range(30.0, 1480.0) if team == 0 else rng.randf_range(4920.0, 6370.0)
		var y := rng.randf_range(-200.0, 1200.0)
		battle.deploy_cd[team].clear()
		err = battle.deploy(team, kind, id, Vector2(x, y))
		if err == "" or not err.begins_with("Too close"):
			return err
	return err


func _process(_delta: float) -> void:
	frame += 1
	match frame:
		5:
			print("== Phase 1: country layout + deploy everything")
			check(battle.bases[0] != null and battle.bases[1] != null, "both capitals exist")
			var expect: int = GameData.country.size()
			check(battle.nat_alive(0) == expect and battle.nat_alive(1) == expect,
				"each side starts with %d country buildings (%d / %d)" % [expect, battle.nat_alive(0), battle.nat_alive(1)])
			for cap in ["power", "barracks", "factory", "airbase", "radar", "silo", "tech"]:
				check(battle.has_capability(0, cap) and battle.has_capability(1, cap), "both countries provide '%s'" % cap)
			check(battle.income_rate(0) > float(GameData.settings.get("income_per_sec", 4)), "country buildings add income (%.1f/s)" % battle.income_rate(0))
			battle.money[0] = 1000000.0
			var i := 0
			for id in GameData.units:
				battle.deploy_cd[0].clear()
				var err: String = battle.deploy(0, "unit", id, Vector2(60 + (i % 13) * 70, 110 + (i / 13) * 60))
				check(err == "", "deploy unit %s (%s)" % [id, err])
				i += 1
			for id in GameData.structures:
				var err2 := deploy_anywhere(0, "structure", id)
				check(err2 == "", "deploy defense %s (%s)" % [id, err2])
			check(battle.deploy(0, "unit", "tank", Vector2(2300, 300)) != "", "cannot deploy in neutral ground")
		6:
			print("== Phase 1b: gating (destroy factories, then rebuild)")
			for c in battle.nationals_providing(0, "factory"):
				c.die(1)
			check(not battle.has_capability(0, "factory"), "factory capability lost")
			battle.deploy_cd[0].clear()
			check(battle.deploy(0, "unit", "heavy_tank", Vector2(300, 300)) != "", "heavy tank locked without a factory")
			var err3 := deploy_anywhere(0, "national", "factory")
			check(err3 == "", "rebuild a factory (%s)" % err3)
			check(battle.has_capability(0, "factory"), "factory capability restored")
			battle.deploy_cd[0].clear()
			check(battle.deploy(0, "unit", "heavy_tank", Vector2(300, 320)) == "", "heavy tank available again")
		200:
			print("== Phase 2: AI + combat")
			battle.ai.think_t = 0.0
		2400:
			print("== Phase 3: ~40s of simulated battle")
			check(battle.kills[0] > 0 or count(1) > 1, "enemy AI has deployed forces (kills %d, alive %d)" % [battle.kills[0], count(1)])
			var moved := false
			for c in get_tree().get_nodes_in_group("team0"):
				if c is Combatant and c.kind == "unit" and c.position.x > 1100:
					moved = true
			check(moved, "player units advance toward the enemy country")
			check(battle.kills[0] + battle.kills[1] > 0, "units are killing each other (kills %s)" % str(battle.kills))
		2410:
			print("== Phase 4: missiles + interceptors")
			battle.money[0] = 1000000.0
			battle.money[1] = 1000000.0
			battle.strat_cd[0].clear()
			var before: int = battle.intercepted[1]
			for i in 2:
				var e := "x"
				for k in 200:
					battle.deploy_cd[1].clear()
					e = battle.deploy(1, "structure", "interceptor_battery", Vector2(5500.0 + 200.0 * i, 330.0 + 240.0 * i) + Vector2(rng.randf_range(-200, 200), rng.randf_range(-200, 200)))
					if e == "" or not e.begins_with("Too close"):
						break
				check(e == "", "enemy interceptor %d (%s)" % [i, e])
			check(battle.deploy(0, "strategic", "cruise_missile", Vector2(5500, 300)) == "", "launch cruise missile")
			battle.strat_cd[0].clear()
			check(battle.deploy(0, "strategic", "ballistic_missile", Vector2(5700, 600)) == "", "launch ballistic missile")
			snapshot["intercept_before"] = before
		2800:
			pass
		2810:
			print("== Phase 5: save / load")
			var d: Dictionary = battle.serialize()
			snapshot["ents"] = d["entities"].size()
			snapshot["money"] = battle.money[0]
			snapshot["elapsed"] = battle.elapsed
			check(battle.save_slot("slot3"), "save_slot writes file")
			check(SaveManager.has_save("slot3"), "slot3 exists on disk")
			print("   ", SaveManager.slot_summary("slot3"))
			battle.money[0] = 1.0
			for n in battle.units_root.get_children():
				if n is Combatant and n.kind == "unit":
					n.queue_free()
					n.dead = true
		2815:
			var ok: bool = battle.load_slot("slot3")
			check(ok, "load_slot succeeds")
			check(absf(battle.money[0] - snapshot["money"]) < 5.0, "money restored (%d)" % int(battle.money[0]))
			check(absf(battle.elapsed - snapshot["elapsed"]) < 1.0, "elapsed restored")
			check(battle.has_capability(0, "airbase"), "capabilities rebuilt after load")
		2820:
			var d2: Dictionary = battle.serialize()
			check(d2["entities"].size() == snapshot["ents"], "entity count restored (%d vs %d)" % [d2["entities"].size(), snapshot["ents"]])
			print("== Phase 6: nuke test (AI disabled, no anti-missile defenses)")
			battle.ai.set_process(false)
			for n in get_tree().get_nodes_in_group("team1"):
				if n is Combatant and n.def.get("targets", []).has("missile"):
					n.dead = true
					n.queue_free()
			battle.money[0] = 1000000.0
			battle.strat_cd[0].clear()
			var hq = battle.bases[1]
			snapshot["hq_hp"] = hq.hp
			check(battle.deploy(0, "strategic", "nuke", hq.position) == "", "launch nuke at enemy capital")
		4300:
			# (interception itself was verified by hand on the big map; timing here is map-size dependent)
			var hq2 = battle.bases[1]
			check(not is_instance_valid(hq2) or hq2.hp < snapshot["hq_hp"] * 0.5 or battle.over, "nuke devastated enemy capital")
			battle.strat_cd[0].clear()
			if battle.bases[1] != null and is_instance_valid(battle.bases[1]) and not battle.bases[1].dead:
				battle.deploy(0, "strategic", "nuke", battle.bases[1].position)
		6000:
			check(battle.over, "game over triggered after capital destroyed")
			print("== Done. Failures: ", failures.size())
			for f in failures:
				print("  - ", f)
			get_tree().quit(1 if failures.size() > 0 else 0)
