class_name TileLib
extends RefCounted
## Drop-in map tiles. Looked up by NAME (see assets/tiles/README.md):
##   user://tiles/<name>.png   then   res://assets/tiles/<name>.png
## Tiles repeat across the map. Missing tiles fall back to the built-in procedural look.
## Optional per-tile settings live in tiles.json (currently: "scale", how big one repeat is drawn).

const USER_DIR := "user://tiles/"
const RES_DIR := "res://assets/tiles/"
const EXTS := ["png", "webp", "jpg"]

const PROC_SCALE := {"ground": 3.0, "water_deep": 2.0, "water_shallow": 2.0}

static var _proc: Dictionary = {}       # tiles that came from the built-in generator (not from a file)
static var _cache: Dictionary = {}
static var _cfg: Dictionary = {}
static var _cfg_loaded := false


static func get_tile(tile: String) -> Texture2D:
	if _cache.has(tile):
		return _cache[tile]
	var t: Texture2D = null
	for ext in EXTS:
		var up: String = USER_DIR + tile + "." + ext
		if FileAccess.file_exists(up):
			var img := Image.load_from_file(up)
			if img != null and not img.is_empty():
				t = ImageTexture.create_from_image(img)
				break
	if t == null:
		for ext in EXTS:
			var rp: String = RES_DIR + tile + "." + ext
			if ResourceLoader.exists(rp):
				t = load(rp) as Texture2D
				if t != null:
					break
	if t == null:
		t = _procedural(tile)
		if t != null:
			_proc[tile] = true
	_cache[tile] = t
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
	var c: Dictionary = _cfg.get(tile, {})
	var dflt := float(PROC_SCALE.get(tile, 1.0)) if _proc.has(tile) else 1.0
	return maxf(float(c.get("scale", dflt)), 0.05)


static func clear_cache() -> void:
	_cache.clear()
	_proc.clear()
	_cfg.clear()
	_cfg_loaded = false


## Fills a polygon with the tile (repeating, anchored to world coordinates) or with `fallback`.
## The CanvasItem must have texture_repeat enabled.
static func fill(ci: CanvasItem, pts: PackedVector2Array, tile: String, fallback: Color) -> void:
	var tex := get_tile(tile)
	if tex == null:
		ci.draw_colored_polygon(pts, fallback)
		return
	var sz := tex.get_size() * scale_of(tile)
	var uvs := PackedVector2Array()
	for p in pts:
		uvs.append(Vector2(p.x / sz.x, p.y / sz.y))
	ci.draw_colored_polygon(pts, Color.WHITE, uvs, tex)


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


static func _procedural(tile: String) -> Texture2D:
	match tile:
		"ground":
			return _make_ground()
		"water_deep":
			return _make_water(true)
		"water_shallow":
			return _make_water(false)
	return null


## Muddy, drab European-front ground: dark grass, dry earth and churned mud with fine grain.
static func _make_ground() -> Texture2D:
	var sz := 256
	var big := _noise(11, 0.011, 4).get_seamless_image(sz, sz)
	var mid := _noise(23, 0.035, 3).get_seamless_image(sz, sz)
	var fine := _noise(37, 0.18, 2).get_seamless_image(sz, sz)
	var dirt := _noise(51, 0.02, 3).get_seamless_image(sz, sz)
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var grass_a := Color(0.115, 0.15, 0.085)
	var grass_b := Color(0.255, 0.285, 0.145)
	var earth := Color(0.29, 0.24, 0.155)
	var mud := Color(0.155, 0.125, 0.085)
	for y in sz:
		for x in sz:
			var b := big.get_pixel(x, y).r
			var m := mid.get_pixel(x, y).r
			var f := fine.get_pixel(x, y).r
			var d := dirt.get_pixel(x, y).r
			var col := grass_a.lerp(grass_b, clampf(b * 0.85 + m * 0.5 - 0.15, 0.0, 1.0))
			var dm := smoothstep(0.56, 0.74, d)
			col = col.lerp(earth.lerp(mud, m), dm * 0.8)
			var k := 0.86 + f * 0.28
			img.set_pixel(x, y, Color(col.r * k, col.g * k, col.b * k, 1.0))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _make_water(deep: bool) -> Texture2D:
	var sz := 128
	var n1 := _noise(71 if deep else 72, 0.03, 3).get_seamless_image(sz, sz)
	var n2 := _noise(83 if deep else 84, 0.10, 2).get_seamless_image(sz, sz)
	var a := Color(0.032, 0.080, 0.118) if deep else Color(0.085, 0.175, 0.195)
	var b := Color(0.070, 0.150, 0.200) if deep else Color(0.165, 0.290, 0.300)
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	for y in sz:
		for x in sz:
			var v := n1.get_pixel(x, y).r
			var w := n2.get_pixel(x, y).r
			var col := a.lerp(b, clampf(v * 0.75 + w * 0.25, 0.0, 1.0))
			if w > 0.74:
				col = col.lightened(0.07)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, 1.0))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
