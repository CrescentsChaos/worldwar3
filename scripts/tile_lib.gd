class_name TileLib
extends RefCounted
## Drop-in map tiles. Looked up by NAME (see assets/tiles/README.md):
##   user://tiles/<name>.png   then   res://assets/tiles/<name>.png
## Tiles repeat across the map. Missing tiles fall back to the built-in procedural look.
## Optional per-tile settings live in tiles.json (currently: "scale", how big one repeat is drawn).

const USER_DIR := "user://tiles/"
const RES_DIR := "res://assets/tiles/"
const EXTS := ["png", "webp", "jpg"]

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
	return maxf(float(c.get("scale", 1.0)), 0.05)


static func clear_cache() -> void:
	_cache.clear()
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
