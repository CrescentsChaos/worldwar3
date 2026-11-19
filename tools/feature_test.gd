extends Node
## Tests the v5 expansion: big map, traps, auras, stances, autopilot, new units/buildings.
##   godot --headless --path . --fixed-fps 60 res://tools/feature_test.tscn
var battle: Battle
var frame := 0
var failures: Array[String] = []
var phase := 0
var t0 := 0
var ctx := {}


func check(cond: bool, msg: String) -> void:
	print(("  PASS  " if cond else "  FAIL  "), msg)
	if not cond:
		failures.append(msg)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveManager.pending_load = ""
	SaveManager.pending_difficulty = "normal"
	battle = load("res://scenes/battle.tscn").instantiate()
	add_child(battle)


func at(sec: float) -> bool:
	return frame == int(sec * 60.0)


func mk(kind: String, id: String, team: int, pos: Vector2) -> Combatant:
	return battle.spawn_entity(kind, id, team, pos)


func _process(_d: float) -> void:
	frame += 1
	if frame == 5:
		print("== Phase 1: map & country")
		check(Battle.W == 6400 and Water.W == 6400, "map is 6400 wide")
		check(Water.kind_at(Vector2(3200, 504)) == 2, "river runs down the centre")
		check(Water.is_bridge(Vector2(3200, 504)) and Water.is_bridge(Vector2(3200, 30)) and Water.is_bridge(Vector2(3200, 978)), "five bridges incl. north and south")
		check(Water.kind_at(Vector2(3200, -300)) == 3 and Water.kind_at(Vector2(3200, 1300)) == 3, "sea north and south")
		var bad := 0
		var ports := 0
		for n in get_tree().get_nodes_in_group("combatants"):
			var c := n as Combatant
			if c.kind == "national":
				if Water.kind_at(c.position) != 0:
					bad += 1
					print("    in water: ", c.id, c.position)
				if c.id == "naval_port":
					ports += 1
					check(Water.dist_to_water(c.position, 2) <= 150.0, "port at %s is on the coast (%.0f)" % [c.position, Water.dist_to_water(c.position, 2)])
		check(bad == 0, "no country building stands in water")
		check(ports == 4, "four naval ports")
		var pth := Water.find_path(Vector2(1000, 300), Vector2(5000, 700), 4)
		check(pth.size() > 1, "vehicle path exists across the big map (%d wp)" % pth.size())
		var sp := Water.find_path(Vector2(1200, -400), Vector2(5200, -400), 3)
		check(sp.size() > 1, "ship path exists along the north sea")
		check(battle.stance == "assault", "default stance is auto-assault")
	if frame == 10:
		print("== Phase 2: deploy every new item")
		battle.money[0] = 99999.0
		var ids_s: Array = ["sandbag_nest", "watchtower", "sniper_nest", "flame_bunker", "observation_post", "landmine", "ap_mine", "claymore", "napalm_trap", "barbed_wire", "tank_trap", "decoy_tank"]
		for id in ids_s:
			var err := "x"
			for k in 200:
				battle.deploy_cd[0].clear()
				err = battle.deploy(0, "structure", id, Vector2(randf_range(40.0, 1450.0), randf_range(-200.0, 1200.0)))
				if err == "" or not err.begins_with("Too close"):
					break
			check(err == "", "deploy %s (%s)" % [id, err])
		battle.deploy_cd[0].clear()
		var err2: String = battle.deploy(0, "structure", "naval_mine", Vector2(900, -330))
		check(err2 == "", "deploy naval_mine in own sea (%s)" % err2)
		battle.deploy_cd[0].clear()
		var err3: String = battle.deploy(0, "structure", "torpedo_battery", Vector2(700, -190))
		check(err3 == "", "deploy torpedo_battery on coast (%s)" % err3)
		for nid in ["field_hospital", "supply_depot", "fuel_depot"]:
			var e4 := "x"
			for k in 300:
				battle.deploy_cd[0].clear()
				e4 = battle.deploy(0, "national", nid, Vector2(randf_range(40.0, 1450.0), randf_range(-200.0, 1200.0)))
				if e4 == "" or not e4.begins_with("Too close"):
					break
			check(e4 == "", "deploy %s (%s)" % [nid, e4])
		battle.deploy_cd[0].clear()
		var e5: String = battle.deploy(0, "national", "forward_base", Vector2(2900, 400))
		check(e5 == "", "forward base far forward (%s)" % e5)
		var e6: String = battle.deploy(0, "national", "forward_base", Vector2(3300, 400))
		check(e6 != "", "forward base past the river is refused")
		check(battle.trap_count(0) >= 7, "traps counted separately (%d)" % battle.trap_count(0))
		check(battle.unit_count(0, true) < 25, "traps do not eat the defense cap (%d structs)" % battle.unit_count(0, true))
	if frame == 30:
		print("== Phase 3: mines / wire / sweepers / aura")
		for n in get_tree().get_nodes_in_group("team0"):
			if n is Combatant and n.is_trap():
				n.queue_free()
		# anti-tank mine vs enemy tank
		battle.money[0] = 99999.0
		var m := mk("structure", "landmine", 0, Vector2(2000, 300))
		var tank := mk("unit", "tank", 1, Vector2(2000, 300))
		tank.order = "hold"
		ctx["tank"] = tank
		ctx["mine"] = m
		# mine does not trigger on infantry
		var m2 := mk("structure", "landmine", 0, Vector2(2000, 600))
		var rif := mk("unit", "rifleman", 1, Vector2(2000, 600))
		rif.order = "hold"
		ctx["m2"] = m2
		ctx["rif"] = rif
		# wire slows infantry
		var w := mk("structure", "barbed_wire", 0, Vector2(2400, 300))
		var runner := mk("unit", "rifleman", 1, Vector2(2430, 300))
		runner.order = "move"
		runner.order_pos = Vector2(2000, 300)
		ctx["runner"] = runner
		ctx["wire"] = w
		# sapper sweeps enemy mines
		var em := mk("structure", "landmine", 1, Vector2(1600, 900))
		var sap := mk("unit", "sapper", 0, Vector2(1620, 900))
		sap.order = "hold"
		ctx["em"] = em
		# officer aura
		var off := mk("unit", "officer", 0, Vector2(1500, 1000))
		off.order = "hold"
		var rf := mk("unit", "rifleman", 0, Vector2(1540, 1000))
		rf.order = "hold"
		ctx["rf"] = rf
	if frame == 90:
		var tank = ctx["tank"]
		check(not is_instance_valid(tank) or tank.hp < tank.max_hp, "enemy tank hurt by anti-tank mine")
		check(not is_instance_valid(ctx["mine"]) or ctx["mine"].dead, "triggered mine is consumed")
		var rif = ctx["rif"]
		check(is_instance_valid(rif) and rif.hp >= rif.max_hp, "infantry does not trigger anti-tank mine")
		check(is_instance_valid(ctx["m2"]) and not ctx["m2"].dead, "unused mine remains")
		var runner = ctx["runner"]
		check(is_instance_valid(runner) and (runner.position.x > 2150.0), "wire slowed the runner (x=%.0f)" % (runner.position.x if is_instance_valid(runner) else -1.0))
		check(not is_instance_valid(ctx["em"]) or ctx["em"].dead, "sapper defused the enemy mine")
		var rf = ctx["rf"]
		check(rf.buff_t > 0.0 and rf.buff_m > 1.1, "officer aura buffs nearby troops (x%.2f)" % rf.buff_m)
		for n in get_tree().get_nodes_in_group("combatants"):
			if n is Combatant and n.kind == "unit":
				n.queue_free()
	if frame == 100:
		print("== Phase 4: spawn each new unit & run")
		var land := ["shotgunner", "marksman", "mortar_team", "javelin", "riot_trooper", "sapper", "officer", "k9", "mine_flail"]
		var i := 0
		for id in land:
			var c := mk("unit", id, 0, Vector2(1200 + i * 40, 500))
			check(c != null, "spawn %s" % id)
			i += 1
		for id in ["torpedo_boat", "frigate", "minelayer", "midget_sub", "cruise_sub"]:
			var d := GameData.get_def("unit", id)
			var wp := Water.nearest_water(Vector2(1500, -300), int(d.get("draft", 1)))
			var c2 := mk("unit", id, 0, wp + Vector2(randf_range(-6, 6), randf_range(-6, 6)))
			check(c2 != null and Water.kind_at(c2.position) >= int(d.get("draft", 1)), "spawn %s in water" % id)
		# enemy armour column for the javelin / mines to chew on
		for k in 4:
			mk("unit", "tank", 1, Vector2(2600, 300 + k * 60))
	if frame == 700:
		var sap_n := 0
		for n in get_tree().get_nodes_in_group("combatants"):
			var c := n as Combatant
			if c != null and c.is_trap() and c.team == 0:
				sap_n += 1
		check(sap_n >= 1, "sapper / minelayer laid mines while advancing (%d traps)" % sap_n)
		var moved := 0
		for n in get_tree().get_nodes_in_group("team0"):
			var c := n as Combatant
			if c != null and c.kind == "unit" and c.position.x > 1500.0:
				moved += 1
		check(moved >= 3, "auto-assault: units advanced on their own (%d beyond x=1500)" % moved)
	if frame == 710:
		print("== Phase 5: stance + production + autopilot")
		for n in get_tree().get_nodes_in_group("combatants"):
			if n is Combatant and n.kind == "unit":
				n.queue_free()
		battle.set_stance("defend", false)
		battle.money[0] = 5000.0
		battle.deploy_cd[0].clear()
		check(battle.queue_unit(0, "rifleman") == "", "queue rifleman")
	if frame == 1100:
		var found := false
		for n in get_tree().get_nodes_in_group("team0"):
			var c := n as Combatant
			if c != null and c.kind == "unit" and c.id == "rifleman":
				found = true
				check(c.order == "attack_move" or c.order == "hold", "defend stance sends new units to the rally (order=%s)" % c.order)
		check(found, "rifleman was produced")
		battle.set_stance("assault", false)
		for n in get_tree().get_nodes_in_group("team0"):
			var c := n as Combatant
			if c != null and c.kind == "unit" and c.can_take_orders():
				check(c.order == "auto", "assault stance sets units to auto")
		battle.money[0] = 3000.0
		battle.set_autopilot(true, false)
		ctx["units_before"] = battle.unit_count(0, false) + battle.queues[0].size()
		ctx["money_before"] = battle.money[0]
	if frame == 1100 + 60 * 40:
		var after: int = battle.unit_count(0, false) + battle.queues[0].size()
		check(after > int(ctx["units_before"]) + 3, "autopilot bought units (%d -> %d)" % [ctx["units_before"], after])
		check(battle.money[0] >= 300.0, "autopilot keeps a cash reserve (%.0f)" % battle.money[0])
		battle.set_autopilot(false, false)
		battle.save_slot("slot3")
		var ok: bool = battle.load_slot("slot3")
		check(ok, "save/load round trip with stance + traps")
		print("   fps check: ", Engine.get_frames_per_second())
	if frame == 1100 + 60 * 40 + 5:
		print("== Done. Failures: ", failures.size())
		for f in failures:
			print("  - ", f)
		get_tree().quit()
