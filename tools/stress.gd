extends Node
## Performance check: hundreds of units + traps fighting on the big map.
##   godot --headless --path . --fixed-fps 60 res://tools/stress.tscn
var battle: Battle
var frame := 0
var ms_total := 0.0
var worst := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveManager.pending_load = ""
	SaveManager.pending_difficulty = "normal"
	battle = load("res://scenes/battle.tscn").instantiate()
	add_child(battle)


func _process(_d: float) -> void:
	frame += 1
	if frame == 3:
		var ids := ["rifleman", "assault", "bazooka", "mg_gunner", "tank", "heavy_tank", "jeep", "artillery", "mortar_team", "javelin", "shotgunner", "light_tank", "apc"]
		for t in 2:
			for i in 150:
				var id: String = ids[i % ids.size()]
				var x := 2400.0 + randf() * 700.0 if t == 0 else 3300.0 + randf() * 700.0
				battle.spawn_entity("unit", id, t, Vector2(x, 100.0 + randf() * 800.0))
		for i in 70:
			battle.spawn_entity("structure", "landmine", 0, Vector2(2900.0 + randf() * 250.0, 100.0 + randf() * 800.0))
	if frame > 3 and frame % 45 == 0:
		var ids2 := ["rifleman", "assault", "bazooka", "mg_gunner", "tank", "heavy_tank", "jeep", "artillery", "mortar_team", "javelin", "shotgunner", "light_tank", "apc"]
		for t in 2:
			var n := 140 - battle.unit_count(t, false)
			for i in maxi(n, 0):
				var x := 2500.0 + randf() * 500.0 if t == 0 else 3400.0 + randf() * 500.0
				battle.spawn_entity("unit", ids2[randi() % ids2.size()], t, Vector2(x, 100.0 + randf() * 800.0))
	if frame > 120:
		var t0 := Time.get_ticks_usec()
		# measure our own frame cost by sampling the engine process time
		var pt := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		ms_total += pt
		worst = maxf(worst, pt)
	if frame % 300 == 0:
		print("  t=%ds  units %d/%d  traps %d  process ms avg %.2f worst %.2f" % [int(battle.elapsed), battle.unit_count(0, false), battle.unit_count(1, false), battle.trap_count(0), ms_total / maxf(frame - 120, 1), worst])
	if frame == 1800:
		get_tree().quit()
