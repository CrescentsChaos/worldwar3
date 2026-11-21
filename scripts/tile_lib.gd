class_name TileLib
extends RefCounted
## Drop-in map tiles, looked up by NAME and, first, by MAP:
##   user://tiles/<map>_<name>.png   (only that battlefield, e.g. carpathian_ground.png)
##   user://tiles/<name>.png         (every battlefield)
##   res://assets/tiles/...          (same two names, bundled)
## Tiles repeat across the map. Missing tiles fall back to a generated look that follows the map's "biome"
## (data/maps/<id>.json -> "biome"), so every battlefield looks different even with zero art files.
## Optional per-tile settings live in tiles.json (currently: "scale", how big one repeat is drawn).
## Tile names: ground, water_deep, water_shallow, river, river_bank, road, bridge, crater, tree, rock.

const USER_DIR := "user://tiles/"
const RES_DIR := "res://assets/tiles/"
const EXTS := ["png", "webp", "jpg"]

const PROC_SCALE := {"ground": 3.0, "water_deep": 2.0, "water_shallow": 2.0}

static var map_id := ""
static var biome: Dictionary = {}
static var _proc: Dictionary = {}       # tiles that came from the built-in generator (not from a file)
static var _cache: Dictionary = {}
static var _cfg: Dictionary = {}
static var _cfg_loaded := false


## Call once per battle, before the terrain is built.
static func set_map(id: String, b: Dictionary) -> void:
	map_id = id
	biome = b
	clear_cache()


static func _try_files(name: String) -> Texture2D:
	for ext in EXTS:
		var up: String = USER_DIR + name + "." + ext
		if FileAccess.file_exists(up):
			var img := Image.load_from_file(up)
			if img != null and not img.is_empty():
				return ImageTexture.create_from_image(img)
	for ext in EXTS:
		var rp: String = RES_DIR + name + "." + ext
		if ResourceLoader.exists(rp):
			var t := load(rp) as Texture2D
			if t != null:
				return t
	return null


static func get_tile(tile: String) -> Texture2D:
	if tile == "":
		return null
	var key := map_id + "/" + tile
	if _cache.has(key):
		return _cache[key]
	var t: Texture2D = null
	if map_id != "":
		t = _try_files(map_id + "_" + tile)
	if t == null:
		t = _try_files(tile)
	if t == null:
		t = _procedural(tile)
		if t != null:
			_proc[key] = true
	_cache[key] = t
	return t


static func scale_of(tile: String) -> float:
	if not _cfg_loaded:
		_cfg_loaded = true
		for path in [RES_DIR + "tiles.json", USER_DIR + "tiles.json"]:
			if FileAccess.file_exists(path):
				var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
				if parsed is Dictionary:
					for k in parsed:
						if not str(k).begins_with("_"):
							_cfg[k] = parsed[k]
	var c: Dictionary = _cfg.get(map_id + "_" + tile, _cfg.get(tile, {}))
	var dflt := float(PROC_SCALE.get(tile, 1.0)) if _proc.has(map_id + "/" + tile) else 1.0
	return maxf(float(c.get("scale", dflt)), 0.05)


static func clear_cache() -> void:
	_cache.clear()
	_proc.clear()
	_cfg.clear()
	_cfg_loaded = false


## Fills a polygon with the tile (repeating, anchored to world coordinates) or with `fallback`.
## The CanvasItem must have texture_repeat enabled.
static func fill(ci: CanvasItem, pts: PackedVector2Array, tile: String, fallback: Color, mod: Color = Color.WHITE) -> void:
	var tex := get_tile(tile)
	if tex == null:
		ci.draw_colored_polygon(pts, Color(fallback.r, fallback.g, fallback.b, fallback.a * mod.a))
		return
	var sz := tex.get_size() * scale_of(tile)
	var uvs := PackedVector2Array()
	for p in pts:
		uvs.append(Vector2(p.x / sz.x, p.y / sz.y))
	ci.draw_colored_polygon(pts, mod, uvs, tex)


# ------------------------------------------------------------ built-in terrain art
## Used when no ground / water file exists, so the battlefield is never a flat colour.

static func _noise(seed_value: int, freq: float, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = seed_value
	n.frequency = freq
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = octaves
	return n


static func _col(d: Dictionary, key: String, fallback: Color) -> Color:
	var a: Variant = d.get(key, null)
	if typeof(a) == TYPE_ARRAY and (a as Array).size() >= 3:
		var arr: Array = a
		return Color(float(arr[0]), float(arr[1]), float(arr[2]))
	return fallback


static func _procedural(tile: String) -> Texture2D:
	match tile:
		"ground":
			return _make_ground()
		"water_deep":
			return _make_water(true)
		"water_shallow":
			return _make_water(false)
	return null


## Ground for the current biome: base grass / soil mix, earth and mud patches, optional snow and puddles, fine grain.
static func _make_ground() -> Texture2D:
	var g: Dictionary = biome.get("ground", {})
	var so := int(biome.get("tile_seed", 0))
	var sz := 256
	var big := _noise(11 + so, float(g.get("big_freq", 0.011)), 4).get_seamless_image(sz, sz)
	var mid := _noise(23 + so, float(g.get("mid_freq", 0.035)), 3).get_seamless_image(sz, sz)
	var fine := _noise(37 + so, float(g.get("fine_freq", 0.18)), 2).get_seamless_image(sz, sz)
	var dirt := _noise(51 + so, 0.02, 3).get_seamless_image(sz, sz)
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var grass_a := _col(g, "a", Color(0.115, 0.15, 0.085))
	var grass_b := _col(g, "b", Color(0.255, 0.285, 0.145))
	var earth := _col(g, "earth", Color(0.29, 0.24, 0.155))
	var mud := _col(g, "mud", Color(0.155, 0.125, 0.085))
	var snow := _col(g, "snow", Color(0, 0, 0))
	var snow_amt := float(g.get("snow_amount", 0.0))
	var pud := _col(g, "puddle", Color(0, 0, 0))
	var pud_amt := float(g.get("puddle_amount", 0.0))
	var grain := float(g.get("grain", 0.28))
	var dirt_amt := float(g.get("dirt_amount", 0.8))
	for y in sz:
		for x in sz:
			var b := big.get_pixel(x, y).r
			var m := mid.get_pixel(x, y).r
			var f := fine.get_pixel(x, y).r
			var d := dirt.get_pixel(x, y).r
			var col := grass_a.lerp(grass_b, clampf(b * 0.85 + m * 0.5 - 0.15, 0.0, 1.0))
			var dm := smoothstep(0.56, 0.74, d)
			col = col.lerp(earth.lerp(mud, m), dm * dirt_amt)
			if snow_amt > 0.0:
				var sn := smoothstep(1.0 - snow_amt - 0.06, 1.0 - snow_amt + 0.06, b * 0.7 + m * 0.4)
				col = col.lerp(snow, sn * 0.9)
			if pud_amt > 0.0:
				var pm := smoothstep(1.0 - pud_amt - 0.04, 1.0 - pud_amt + 0.04, d * 0.6 + b * 0.5)
				col = col.lerp(pud, pm * 0.85)
			var k := (1.0 - grain * 0.5) + f * grain
			img.set_pixel(x, y, Color(col.r * k, col.g * k, col.b * k, 1.0))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _make_water(deep: bool) -> Texture2D:
	var w: Dictionary = biome.get("water", {})
	var so := int(biome.get("tile_seed", 0))
	var sz := 128
	var n1 := _noise((71 if deep else 72) + so, 0.03, 3).get_seamless_image(sz, sz)
	var n2 := _noise((83 if deep else 84) + so, 0.10, 2).get_seamless_image(sz, sz)
	var a := _col(w, "deep_a" if deep else "shallow_a", Color(0.032, 0.080, 0.118) if deep else Color(0.085, 0.175, 0.195))
	var b := _col(w, "deep_b" if deep else "shallow_b", Color(0.070, 0.150, 0.200) if deep else Color(0.165, 0.290, 0.300))
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	for y in sz:
		for x in sz:
			var v := n1.get_pixel(x, y).r
			var wv := n2.get_pixel(x, y).r
			var col := a.lerp(b, clampf(v * 0.75 + wv * 0.25, 0.0, 1.0))
			if wv > 0.74:
				col = col.lightened(0.07)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, 1.0))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
