class_name VfxLib
extends RefCounted
## Drop-in visual effects. Every effect is looked up by NAME (see assets/vfx/README.md):
##   user://vfx/   (no re-export needed)   then   res://assets/vfx/
## An effect can be:
##   * a folder  <name>/  with frames  0001.png, 0002.png ...   (played in file-name order)
##   * a sprite sheet  <name>_COLSxROWS.png   e.g.  explosion_small_5x4.png
##   * a single image  <name>.png   (scales up and fades out)
## Optional per-effect settings live in vfx.json (fps, scale, additive, rotate, duration, offset, z, frames).
## If no file exists for a name, nothing is drawn and the game falls back to its built-in effect.

const USER_DIR := "user://vfx/"
const RES_DIR := "res://assets/vfx/"
const IMG_EXTS := ["png", "webp", "jpg", "jpeg"]

static var _cache: Dictionary = {}
static var _cfg: Dictionary = {}
static var _cfg_loaded := false
static var _sheet_re: RegEx = null


static func config(effect: String) -> Dictionary:
	if not _cfg_loaded:
		_cfg_loaded = true
		for path in [RES_DIR + "vfx.json", USER_DIR + "vfx.json"]:
			if FileAccess.file_exists(path):
				var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
				if parsed is Dictionary:
					for k in parsed:
						if not str(k).begins_with("_"):
							_cfg[k] = parsed[k]
	return _cfg.get(effect, {})


static func get_effect(effect: String) -> Dictionary:
	if _cache.has(effect):
		return _cache[effect]
	var eff: Dictionary = {}
	for dir in [USER_DIR, RES_DIR]:
		eff = _scan(dir, effect)
		if not eff.is_empty():
			break
	_cache[effect] = eff
	return eff


static func has_effect(effect: String) -> bool:
	return not get_effect(effect).is_empty()


static func clear_cache() -> void:
	_cache.clear()
	_cfg.clear()
	_cfg_loaded = false


## Plays an effect at `pos`, about `size` world pixels wide. Returns false if no such effect exists.
static func spawn(parent: Node, effect: String, pos: Vector2, size: float, rot: float = 0.0) -> bool:
	var eff := get_effect(effect)
	if eff.is_empty() or parent == null:
		return false
	var p := VfxPlayer.new()
	p.setup(eff, config(effect), size, rot)
	p.position = pos
	parent.add_child(p)
	return true


## Plays the first effect in the list that exists (most specific name first).
static func spawn_any(parent: Node, names: Array, pos: Vector2, size: float, rot: float = 0.0) -> bool:
	for n in names:
		if spawn(parent, str(n), pos, size, rot):
			return true
	return false


static func _clean(file: String) -> String:
	return file.trim_suffix(".import").trim_suffix(".remap")


static func _is_img(file: String) -> bool:
	return IMG_EXTS.has(file.get_extension().to_lower())


static func _tex(path: String) -> Texture2D:
	if path.begins_with("user://"):
		var img := Image.load_from_file(path)
		if img == null or img.is_empty():
			return null
		return ImageTexture.create_from_image(img)
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


static func _scan(dir: String, effect: String) -> Dictionary:
	if not DirAccess.dir_exists_absolute(dir):
		return {}
	var folder := dir + effect
	if DirAccess.dir_exists_absolute(folder):
		var names: Array = []
		for f in DirAccess.get_files_at(folder):
			var n := _clean(f)
			if _is_img(n) and not names.has(n):
				names.append(n)
		names.sort()
		var frames: Array = []
		for n in names:
			var t := _tex(folder + "/" + str(n))
			if t != null:
				frames.append(t)
		if not frames.is_empty():
			return {"frames": frames, "cols": 1, "rows": 1}
	if _sheet_re == null:
		_sheet_re = RegEx.new()
		_sheet_re.compile("^(\\d+)x(\\d+)$")
	for f in DirAccess.get_files_at(dir):
		var n := _clean(f)
		if not _is_img(n):
			continue
		var base := n.get_basename()
		if base == effect:
			var t := _tex(dir + n)
			if t != null:
				return {"frames": [t], "cols": 1, "rows": 1}
		elif base.begins_with(effect + "_"):
			var m := _sheet_re.search(base.substr(effect.length() + 1))
			if m != null:
				var t := _tex(dir + n)
				if t != null:
					return {"frames": [t], "cols": int(m.get_string(1)), "rows": int(m.get_string(2))}
	return {}
