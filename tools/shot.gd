extends Node
## Renders screenshots (needs a display, e.g. xvfb-run). Dev helper only.
var battle: Battle
var frame := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveManager.pending_load = ""
	SaveManager.pending_difficulty = "normal"
	battle = load("res://scenes/battle.tscn").instantiate()
	add_child(battle)


func _process(_d: float) -> void:
	frame += 1
	if frame == 3:
		battle.money[0] = 50000.0
		battle.money[1] = 50000.0
		var i := 0
		for id in ["rifleman", "sniper", "flamer", "jeep", "light_tank", "tank", "mammoth", "howitzer", "aa_truck", "fighter", "stealth_bomber", "gunship"]:
			battle.deploy_cd[0].clear()
			battle.deploy(0, "unit", id, Vector2(700 + (i % 4) * 80, 150 + (i / 4) * 250))
			battle.deploy_cd[1].clear()
			battle.deploy(1, "unit", id, Vector2(2500 - (i % 4) * 80, 150 + (i / 4) * 250))
			i += 1
		battle.focus_camera(Vector2(900, 520))
		battle.hud._show_tab("vehicles")
		battle.select("unit", "tank")
	if frame == 400:
		battle.deploy(1, "strategic", "ballistic_missile", Vector2(300, 300))
		battle.deploy(0, "strategic", "cruise_missile", Vector2(2700, 250))
	if frame == 470:
		_save("/tmp/shot_battle.png")
		battle.hud._show_tab("strategic")
		battle.select("strategic", "nuke")
	if frame == 500:
		battle.deploy(1, "strategic", "nuke", Vector2(300, 300))
		battle.hud._open_menu()
	if frame == 540:
		_save("/tmp/shot_menu.png")
		battle.hud._close_menu()
	if frame == 700:
		_save("/tmp/shot_nuke.png")
		get_tree().quit()


func _save(path: String) -> void:
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
