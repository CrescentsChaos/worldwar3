extends Node
## Central sprite lookup. EVERY sprite in the game goes through get_texture().
##
## Lookup order for a sprite id such as "tank":
##   1. user://sprites/tank.png      <- drop-in replacements, no re-export needed
##   2. res://assets/sprites/tank.png <- bundled placeholder art
##   3. a generated placeholder shape (so the game never breaks)
##
## Art guidelines: top-down view, unit FACING RIGHT (east). Any resolution -
## the game scales it to the "size" value in data/units.json. Sprites are
## tinted slightly with the team colour (see "team_tint" in the data file).

const USER_DIR := "user://sprites/"
const RES_DIR := "res://assets/sprites/"

var cache: Dictionary = {}

const TEAM_COLORS := [Color(0.33, 0.58, 0.86), Color(0.88, 0.30, 0.25)]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(USER_DIR)


func clear_cache() -> void:
	cache.clear()


func team_color(team: int) -> Color:
	return TEAM_COLORS[clampi(team, 0, 1)]


func team_tint(team: int) -> Color:
	var strength := float(GameData.settings.get("team_tint", 0.55))
	return Color.WHITE.lerp(team_color(team), strength)


## Returns the texture or null if no real image file exists (no placeholder).
func get_optional(id: String) -> Texture2D:
	var key := "opt:" + id
	if cache.has(key):
		return cache[key]
	var tex: Texture2D = _load_real(id)
	cache[key] = tex
	return tex


func get_texture(id: String, shape: String = "box") -> Texture2D:
	if cache.has(id):
		return cache[id]
	var tex: Texture2D = _load_real(id)
	if tex == null:
		tex = _placeholder(shape)
	cache[id] = tex
	return tex


func _load_real(id: String) -> Texture2D:
	var upath := USER_DIR + id + ".png"
	if FileAccess.file_exists(upath):
		var img := Image.load_from_file(upath)
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
	var rpath := RES_DIR + id + ".png"
	if ResourceLoader.exists(rpath):
		var res: Resource = load(rpath)
		if res is Texture2D:
			return res
	return null


# ---------------------------------------------------------------- placeholders

func _placeholder(shape: String) -> Texture2D:
	var s := 64
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var body := Color(0.86, 0.88, 0.83)
	var dark := Color(0.32, 0.35, 0.30)
	match shape:
		"infantry":
			_circle(img, Vector2(30, 32), 15, body)
			_circle(img, Vector2(30, 32), 8, dark)
			_rect(img, Rect2i(34, 29, 26, 6), dark)
		"vehicle":
			_rect(img, Rect2i(8, 14, 44, 36), body)
			_rect(img, Rect2i(8, 14, 44, 6), dark)
			_rect(img, Rect2i(8, 44, 44, 6), dark)
			_circle(img, Vector2(28, 32), 11, dark)
			_rect(img, Rect2i(28, 29, 34, 6), dark)
		"air":
			_poly(img, PackedVector2Array([Vector2(62, 32), Vector2(8, 4), Vector2(18, 32), Vector2(8, 60)]), body)
			_poly(img, PackedVector2Array([Vector2(46, 32), Vector2(24, 26), Vector2(24, 38)]), dark)
		"missile":
			_rect(img, Rect2i(8, 26, 40, 12), body)
			_poly(img, PackedVector2Array([Vector2(48, 26), Vector2(62, 32), Vector2(48, 38)]), dark)
			_poly(img, PackedVector2Array([Vector2(8, 26), Vector2(2, 14), Vector2(18, 26)]), dark)
			_poly(img, PackedVector2Array([Vector2(8, 38), Vector2(2, 50), Vector2(18, 38)]), dark)
		"structure":
			_rect(img, Rect2i(8, 8, 48, 48), body)
			_rect(img, Rect2i(8, 8, 48, 5), dark)
			_rect(img, Rect2i(8, 51, 48, 5), dark)
			_circle(img, Vector2(30, 32), 12, dark)
			_rect(img, Rect2i(30, 29, 30, 6), dark)
		"ship":
			_poly(img, PackedVector2Array([Vector2(62, 32), Vector2(48, 23), Vector2(6, 23), Vector2(2, 32), Vector2(6, 41), Vector2(48, 41)]), body)
			_rect(img, Rect2i(20, 28, 18, 8), dark)
		"mine":
			_circle(img, Vector2(32, 32), 22, dark)
			_circle(img, Vector2(32, 32), 17, body)
			_circle(img, Vector2(32, 32), 7, dark)
			for k in 8:
				var a2 := float(k) * TAU / 8.0
				_circle(img, Vector2(32, 32) + Vector2.from_angle(a2) * 24.0, 3.5, dark)
		"tower":
			_rect(img, Rect2i(10, 10, 44, 44), dark)
			_rect(img, Rect2i(15, 15, 34, 34), body)
			_rect(img, Rect2i(15, 31, 34, 3), dark)
			_rect(img, Rect2i(31, 15, 3, 34), dark)
			_circle(img, Vector2(32, 32), 6, dark)
			_rect(img, Rect2i(32, 30, 28, 4), dark)
		"proj":
			_circle(img, Vector2(32, 32), 8, body)
		_:
			_rect(img, Rect2i(10, 10, 44, 44), body)
			_rect(img, Rect2i(10, 10, 44, 4), dark)
	return ImageTexture.create_from_image(img)


func _circle(img: Image, c: Vector2, r: float, col: Color) -> void:
	for y in range(maxi(0, int(c.y - r)), mini(img.get_height(), int(c.y + r) + 1)):
		for x in range(maxi(0, int(c.x - r)), mini(img.get_width(), int(c.x + r) + 1)):
			if Vector2(x, y).distance_to(c) <= r:
				img.set_pixel(x, y, col)


func _rect(img: Image, r: Rect2i, col: Color) -> void:
	for y in range(maxi(0, r.position.y), mini(img.get_height(), r.end.y)):
		for x in range(maxi(0, r.position.x), mini(img.get_width(), r.end.x)):
			img.set_pixel(x, y, col)


func _poly(img: Image, pts: PackedVector2Array, col: Color) -> void:
	var minp := Vector2(INF, INF)
	var maxp := Vector2(-INF, -INF)
	for p in pts:
		minp = minp.min(p)
		maxp = maxp.max(p)
	for y in range(maxi(0, int(minp.y)), mini(img.get_height(), int(maxp.y) + 1)):
		for x in range(maxi(0, int(minp.x)), mini(img.get_width(), int(maxp.x) + 1)):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), pts):
				img.set_pixel(x, y, col)
