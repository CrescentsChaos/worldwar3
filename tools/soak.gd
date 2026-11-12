extends Node
## Long-running soak test: random player play vs the hard AI for ~8 simulated minutes.
##   godot --headless --path . --fixed-fps 60 res://tools/soak.tscn
var battle: Battle
var frame := 0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.seed = 7
	SaveManager.pending_load = ""
	SaveManager.pending_difficulty = "hard"
	battle = load("res://scenes/battle.tscn").instantiate()
	add_child(battle)


func _process(_d: float) -> void:
	frame += 1
	if battle.over:
		report("GAME OVER")
		return
	if frame % 600 == 0:
		var a = battle.bases[0]
		var b = battle.bases[1]
		print("  t=", int(battle.elapsed), " hq ", int(a.hp) if is_instance_valid(a) else -1, "/", int(b.hp) if is_instance_valid(b) else -1, " units ", battle.unit_count(0,false), "/", battle.unit_count(1,false), " money ", int(battle.money[0]), "/", int(battle.money[1]))
	if frame % 90 == 0:
		var cat := rng.randi() % 12
		if cat < 6:
			var ids: Array = GameData.units.keys()
			var uid: String = ids[rng.randi() % ids.size()]
			var udom := str(GameData.units[uid].get("domain", "land"))
			var upos := Vector2(rng.randf_range(30, 980), rng.randf_range(80, 930))
			if udom == "water" or udom == "sub":
				upos.y = rng.randf_range(-150, 20) if rng.randi() % 2 == 0 else rng.randf_range(990, 1150)
			battle.deploy(0, "unit", uid, upos)
		elif cat < 8:
			var sids: Array = GameData.structures.keys()
			battle.deploy(0, "structure", sids[rng.randi() % sids.size()], Vector2(rng.randf_range(30, 980), rng.randf_range(80, 930)))
		elif cat < 9:
			var nids: Array = GameData.national.keys()
			battle.deploy(0, "national", nids[rng.randi() % nids.size()], Vector2(rng.randf_range(30, 980), rng.randf_range(80, 930)))
		else:
			var mids: Array = GameData.strategic.keys()
			battle.deploy(0, "strategic", mids[rng.randi() % mids.size()], Vector2(rng.randf_range(2200, 3150), rng.randf_range(80, 930)))
	if frame == 9000:
		# save while stuff is in flight and reload it
		var n_missiles := 0
		for n in get_tree().get_nodes_in_group("combatants"):
			if n is Missile:
				n_missiles += 1
		battle.save_slot("slot2")
		var ok: bool = battle.load_slot("slot2")
		print("mid-soak save/load ok=", ok, " missiles in flight at save=", n_missiles)
	if frame >= 28800:
		report("TIME UP")


func report(why: String) -> void:
	print("== soak ended: ", why, " t=", int(battle.elapsed), "s  money=", int(battle.money[0]), "/", int(battle.money[1]))
	print("   launched ", battle.launched, " intercepted ", battle.intercepted, " kills ", battle.kills)
	get_tree().quit(0)
