class_name AssetCatalog
extends RefCounted
## The list of EVERY replaceable asset (v6): sprites, sound effects, radio voice lines, visual effects, map tiles,
## interface images and fonts. The Asset Manager shows this list; drop-in files work with or without the manager.

const CATS := [
	["sprites", "Sprites"],
	["audio", "Sound effects & music"],
	["radio", "Radio voice lines"],
	["vfx", "Visual effects"],
	["tiles", "Map tiles"],
	["ui", "Interface & map"],
	["fonts", "Fonts"],
]
const SPRITE_DIR := "user://sprites/"
const CORE_AUDIO := [
	"shot", "boom", "nuke", "launch", "intercept", "alarm", "click", "deploy", "smoke", "dig", "ping",
	"explosion_small", "explosion_medium", "explosion_large", "explosion_nuke", "die_base", "die_building", "die_unit",
	"music_menu", "music_battle", "ambient_battle",
]
const CORE_VFX := ["explosion_small", "explosion_medium", "explosion_large", "explosion_nuke", "muzzle_flash", "hit_spark",
	"water_splash", "deploy_dust", "smoke_puff"]
const TILES := ["ground", "water_deep", "water_shallow", "river", "road", "bridge", "crater", "tree"]
const UI_IMAGES := [["background", "Battlefield background"], ["ui_menu_bg", "Main menu background"], ["ui_cursor", "Mouse cursor"]]
const FONTS := [["font_ui", "Interface font (.ttf / .otf)"], ["font_bold", "Bold font"], ["font_mono", "Monospace font"]]


## Every entry is {id, label}. `cat` is one of CATS[i][0].
static func entries(cat: String) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	match cat:
		"sprites":
			var groups: Array = [GameData.units, GameData.structures, GameData.national, GameData.strategic, GameData.projectiles]
			for g in groups:
				for id in g:
					var d: Dictionary = g[id]
					_add(out, seen, str(d.get("sprite", id)), str(d.get("name", id)))
			_add(out, seen, str(GameData.base.get("sprite", "hq")), "Capital")
			for fid in GameData.factions:
				var ro: Dictionary = GameData.factions[fid].get("roster", {})
				for rid in ro:
					var rd: Dictionary = ro[rid]
					if rd.has("sprite"):
						_add(out, seen, str(rd["sprite"]), "%s (%s)" % [str(rd.get("name", rid)), fid])
		"audio":
			for n in CORE_AUDIO:
				_add(out, seen, n, "core sound")
			for g in [GameData.units, GameData.structures, GameData.national, GameData.strategic]:
				for id in g:
					var nm := str(g[id].get("name", id))
					_add(out, seen, "fire_" + id, "fire: " + nm)
					_add(out, seen, "die_" + id, "destroyed: " + nm)
					_add(out, seen, "deploy_" + id, "deployed: " + nm)
			for id in GameData.strategic:
				_add(out, seen, "launch_" + id, "launch: " + str(GameData.strategic[id].get("name", id)))
		"radio":
			for ev in Radio.LINES:
				var variants: Array = Radio.LINES[ev][1]
				for i in variants.size():
					_add(out, seen, "radio_%s_%d" % [ev, i + 1], str(variants[i]).substr(0, 70))
		"vfx":
			for n in CORE_VFX:
				_add(out, seen, n, "core effect")
			for g in [GameData.units, GameData.structures, GameData.national]:
				for id in g:
					var nm2 := str(g[id].get("name", id))
					_add(out, seen, "muzzle_" + id, "muzzle flash: " + nm2)
					_add(out, seen, "death_" + id, "death: " + nm2)
					_add(out, seen, "deploy_" + id, "deploy: " + nm2)
		"tiles":
			for t in TILES:
				_add(out, seen, t, "repeating map tile")
		"ui":
			for u in UI_IMAGES:
				_add(out, seen, u[0], u[1])
		"fonts":
			for f in FONTS:
				_add(out, seen, f[0], f[1])
	return out


static func _add(out: Array, seen: Dictionary, id: String, label: String) -> void:
	if id == "" or seen.has(id):
		return
	seen[id] = true
	out.append({"id": id, "label": label})


static func user_dir(cat: String) -> String:
	match cat:
		"sprites", "ui":
			return SPRITE_DIR
		"audio", "radio":
			return "user://audio/"
		"vfx":
			return "user://vfx/"
		"tiles":
			return "user://tiles/"
		"fonts":
			return "user://fonts/"
	return "user://"


static func _user_file(cat: String, id: String) -> String:
	var exts: Array = ["png", "webp", "jpg"]
	if cat == "audio" or cat == "radio":
		exts = ["ogg", "mp3", "wav"]
	elif cat == "fonts":
		exts = ["ttf", "otf"]
		id = id.trim_prefix("font_")
	for e in exts:
		var p: String = user_dir(cat) + id + "." + str(e)
		if FileAccess.file_exists(p):
			return p
	if cat == "vfx" and DirAccess.dir_exists_absolute(user_dir(cat) + id):
		return user_dir(cat) + id
	return ""


static func status(cat: String, id: String) -> String:
	if _user_file(cat, id) != "":
		return "CUSTOM"
	match cat:
		"sprites", "ui":
			return "BUNDLED" if ResourceLoader.exists("res://assets/sprites/" + id + ".png") else "PLACEHOLDER"
		"audio", "radio":
			for e in ["ogg", "wav", "mp3"]:
				if ResourceLoader.exists("res://assets/audio/%s.%s" % [id, e]):
					return "BUNDLED"
			if cat == "radio":
				return "SYNTH"
			return "BUILT-IN" if Sfx.streams.has(id) else "SILENT"
		"vfx":
			return "BUNDLED" if (ResourceLoader.exists("res://assets/vfx/" + id + ".png") or DirAccess.dir_exists_absolute("res://assets/vfx/" + id)) else "BUILT-IN"
		"tiles":
			return "BUNDLED" if ResourceLoader.exists("res://assets/tiles/" + id + ".png") else "BUILT-IN"
		"fonts":
			return "SYSTEM"
	return "?"


## Copies / converts a file the player picked into the right user:// folder. Returns "" or an error message.
static func import_file(cat: String, id: String, path: String) -> String:
	var ext := path.get_extension().to_lower()
	var dir := user_dir(cat)
	DirAccess.make_dir_recursive_absolute(dir)
	reset_file(cat, id)
	match cat:
		"sprites", "ui", "vfx", "tiles":
			var img := Image.load_from_file(path)
			if img == null or img.is_empty():
				return "That is not a readable image (use PNG / JPG / WEBP)"
			if img.save_png(dir + id + ".png") != OK:
				return "Could not write the image"
		"audio", "radio":
			if not ["ogg", "mp3", "wav"].has(ext):
				return "Use an .ogg, .mp3 or .wav file"
			var bytes := FileAccess.get_file_as_bytes(path)
			var f := FileAccess.open(dir + id + "." + ext, FileAccess.WRITE)
			if f == null:
				return "Could not write the sound"
			f.store_buffer(bytes)
			f.close()
		"fonts":
			if not ["ttf", "otf"].has(ext):
				return "Use a .ttf or .otf font"
			var fb := FileAccess.get_file_as_bytes(path)
			var ff := FileAccess.open(dir + id.trim_prefix("font_") + "." + ext, FileAccess.WRITE)
			if ff == null:
				return "Could not write the font"
			ff.store_buffer(fb)
			ff.close()
	return ""


static func reset_file(cat: String, id: String) -> void:
	for _i in 6:
		var p := _user_file(cat, id)
		if p == "":
			return
		if DirAccess.dir_exists_absolute(p):
			for fn in DirAccess.get_files_at(p):
				DirAccess.remove_absolute(p + "/" + fn)
		DirAccess.remove_absolute(p)


static func refresh_caches() -> void:
	SpriteLib.clear_cache()
	VfxLib.clear_cache()
	TileLib.clear_cache()
	Sfx.reload()
	MilTheme.reload_fonts()


static func export_checklist() -> String:
	var f := FileAccess.open("user://asset_checklist.csv", FileAccess.WRITE)
	if f == null:
		return ""
	f.store_line("category,id,status,label,drop_file_in")
	for c in CATS:
		for e in entries(c[0]):
			f.store_line("%s,%s,%s,\"%s\",%s" % [c[0], e["id"], status(c[0], e["id"]), str(e["label"]).replace("\"", "'"), user_dir(c[0])])
	f.close()
	return ProjectSettings.globalize_path("user://asset_checklist.csv")
