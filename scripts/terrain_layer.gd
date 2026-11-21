class_name TerrainLayer
extends Node2D
## The battlefield scenery, built from the current map (data/maps/<id>.json): ground, dirt, scorched front line,
## roads, craters, rocks, forests, rivers, sea and bridges.
##
## PERFORMANCE: the map is cut into 800 px chunks and every kind of scenery lives in its own layer of chunks.
## Godot skips chunks that are off screen, so a 6400 px map costs about as much as what the camera can see
## (the old version replayed ~10 000 draw commands every frame). Items belong to exactly one chunk (by their
## centre), so semi-transparent blobs are never drawn twice.

const CH := 800.0
const LAYER_Z := {"ground": -40, "blots": -39, "decor": -38, "roads": -37, "marks": -36, "trees": -35, "banks": -34,
	"rivers": -33, "sea": -32, "shore": -30, "bridges": -29}

const WATER_SHADER := """
shader_type canvas_item;
varying vec2 wp;
uniform vec3 hi = vec3(0.78, 0.90, 0.96);
uniform float speed = 0.35;
uniform float amount = 0.20;
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() {
	wp = VERTEX;
}
void fragment() {
	vec2 p = wp * 0.03;
	float t = TIME * speed;
	float a = vnoise(p * vec2(1.0, 0.55) + vec2(t * 0.4, t));
	float b = vnoise(p * 2.4 + vec2(-t * 0.7, t * 0.5));
	float glint = smoothstep(0.66, 0.92, a * 0.55 + b * 0.55);
	COLOR.rgb = mix(COLOR.rgb, hi, glint * amount);
	COLOR.rgb *= 0.93 + 0.14 * a;
}
"""

static var _water_mat: ShaderMaterial = null


static func water_material() -> ShaderMaterial:
	if _water_mat == null:
		var sh := Shader.new()
		sh.code = WATER_SHADER
		_water_mat = ShaderMaterial.new()
		_water_mat.shader = sh
	return _water_mat


## The battlefield picture for the current map: user://sprites/background_<map>.png, else background.png, else null.
static func map_background() -> Texture2D:
	if TileLib.map_id != "":
		var t: Texture2D = SpriteLib.get_optional("background_" + TileLib.map_id)
		if t != null:
			return t
	return SpriteLib.get_optional("background")

var pal: Dictionary = {}
var biome: Dictionary = {}
var _buckets: Dictionary = {}       # layer -> {Vector2i: Array of items}
var _chunk_nodes: Array = []


func _init() -> void:
	z_index = 0


func _color(key: String, fallback: Color) -> Color:
	var a: Variant = pal.get(key, null)
	if typeof(a) == TYPE_ARRAY and (a as Array).size() >= 3:
		var arr: Array = a
		return Color(float(arr[0]), float(arr[1]), float(arr[2]))
	return fallback


func _bcol(d: Dictionary, key: String, fallback: Color) -> Color:
	return TileLib._col(d, key, fallback)


func _key(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CH), floori((p.y - float(Water.Y_MIN)) / CH))


func _add(layer: String, p: Vector2, item: Array) -> void:
	if not _buckets.has(layer):
		_buckets[layer] = {}
	var d: Dictionary = _buckets[layer]
	var k := _key(p)
	if not d.has(k):
		d[k] = []
	(d[k] as Array).append(item)


## Splits a polyline into runs that belong to one chunk each (by segment midpoint) and files them.
func _add_runs(layer: String, pts: PackedVector2Array, extra: Array) -> void:
	if pts.size() < 2:
		return
	var run := PackedVector2Array([pts[0]])
	var run_key := _key((pts[0] + pts[1]) * 0.5)
	for i in range(pts.size() - 1):
		var k := _key((pts[i] + pts[i + 1]) * 0.5)
		if k != run_key:
			_flush_run(layer, run, run_key, extra)
			run = PackedVector2Array([pts[i]])
			run_key = k
		run.append(pts[i + 1])
	_flush_run(layer, run, run_key, extra)


func _flush_run(layer: String, run: PackedVector2Array, k: Vector2i, extra: Array) -> void:
	if run.size() < 2:
		return
	if not _buckets.has(layer):
		_buckets[layer] = {}
	var d: Dictionary = _buckets[layer]
	if not d.has(k):
		d[k] = []
	var item: Array = [run]
	item.append_array(extra)
	(d[k] as Array).append(item)


func _near_water(p: Vector2, r: float) -> bool:
	if Water.kind_at(p) != 0:
		return true
	for a in 8:
		if Water.kind_at(p + Vector2.from_angle(float(a) * TAU / 8.0) * r) != 0:
			return true
	return false


func setup_terrain(m: Dictionary) -> void:
	for c in _chunk_nodes:
		if is_instance_valid(c):
			c.queue_free()
	_chunk_nodes.clear()
	_buckets.clear()
	pal = m.get("palette_def", {})
	biome = m.get("biome", {})
	var rng := RandomNumberGenerator.new()
	rng.seed = int(m.get("seed", 1914))
	var w := float(Battle.W)
	var ft := Battle.FIELD_TOP
	var fb := Battle.FIELD_BOTTOM
	var mid_y := (ft + fb) * 0.5
	var shade_col := _color("shade", Color(0.04, 0.06, 0.03))
	var dirt_col := _color("dirt", Color(0.34, 0.30, 0.16))
	# ---- sites the scenery keeps clear (country buildings, sectors)
	var sites: Array = [Vector2(Battle.BASE_MARGIN, mid_y), Vector2(w - Battle.BASE_MARGIN, mid_y)]
	for e in GameData.country:
		var lx := float(e[1])
		var ly := float(e[2])
		sites.append(Vector2(lx, ly))
		sites.append(Vector2(w - lx, ft + fb - ly))
	var sl: Array = m.get("sectors", [])
	for sc in sl:
		var sd: Dictionary = sc
		sites.append(Vector2(float(sd.get("x", 0.0)), float(sd.get("y", 0.0))))
	# ---- ground blotches (small) and big colour patches that break up the repeating ground tile
	for i in 1100:
		var p := Vector2(rng.randf_range(-40, w + 40), rng.randf_range(ft - 30, fb + 30))
		var r := rng.randf_range(30, 130)
		var sh := rng.randf_range(-1.0, 1.0)
		_add("blots", p, ["patch", p, r, sh, shade_col, dirt_col])
	var macro: Array = biome.get("macro", [])
	if not macro.is_empty():
		for i in 650:
			var mp := Vector2(rng.randf_range(-100, w + 100), rng.randf_range(ft - 80, fb + 80))
			var mc: Array = macro[rng.randi() % macro.size()]
			_add("blots", mp, ["macro", mp, rng.randf_range(90.0, 300.0), Color(float(mc[0]), float(mc[1]), float(mc[2]), float(mc[3]))])
	# ---- churned earth along the front line, craters, rocks
	for i in 340:
		var sp := Vector2(rng.randf_range(1500, w - 1500.0), rng.randf_range(ft + 20, fb - 20))
		if _near_water(sp, 50.0):
			continue
		_add("blots", sp, ["scar", sp, rng.randf_range(24, 70)])
	var n_craters := int(m.get("craters", 520))
	for i in n_craters:
		var cp := Vector2(rng.randf_range(1500, w - 1500.0), rng.randf_range(ft + 20, fb - 20))
		var cr := rng.randf_range(6, 22)
		if _near_water(cp, cr + 30.0):
			continue
		_add("marks", cp, ["crater", cp, cr])
	var rock_n := int(biome.get("rocks", 650))
	var rsz: Array = biome.get("rock_size", [2.5, 6.5])
	for i in rock_n:
		var rp := Vector2(rng.randf_range(0, w), rng.randf_range(ft + 10, fb - 10))
		if _near_water(rp, 24.0):
			continue
		_add("marks", rp, ["rock", rp, rng.randf_range(float(rsz[0]), float(rsz[1]))])
	_make_decor(rng, sites, ft, fb, w)
	# ---- roads (from the map; the classic map falls back to a main road with spurs)
	var road_list: Array = m.get("roads", [])
	if road_list.is_empty():
		_add_runs("roads", PackedVector2Array([Vector2(0, mid_y), Vector2(w, mid_y)]), [22.0])
		for s: Vector2 in sites:
			if absf(s.y - mid_y) > 24.0:
				_add_runs("roads", PackedVector2Array([s, Vector2(s.x, mid_y)]), [9.0])
	for r in road_list:
		var rd: Dictionary = r
		var raw: Array = rd.get("pts", [])
		var pts := PackedVector2Array()
		for q in raw:
			var qa: Array = q
			pts.append(Vector2(float(qa[0]), float(qa[1])))
		_add_runs("roads", pts, [float(rd.get("w", 12.0))])
	# ---- forests
	var fcfg: Dictionary = m.get("forests", {})
	var f_count := int(fcfg.get("count", 420))
	var f_min := int(fcfg.get("min", 4))
	var f_max := int(fcfg.get("max", 8))
	var tree_base := _color("tree", Color(0.05, 0.105, 0.045))
	for i in f_count:
		var c := Vector2(rng.randf_range(0, w), rng.randf_range(ft + 20, fb - 20))
		var ok := not _near_water(c, 70.0) and not RoadNet.on_road(c)
		if ok:
			for off in [Vector2(55, 0), Vector2(-55, 0), Vector2(0, 45), Vector2(0, -45)]:
				if RoadNet.on_road(c + off):
					ok = false
					break
		if ok and not RoadNet.has_roads():
			ok = absf(c.y - mid_y) > 36.0
		if ok:
			for s: Vector2 in sites:
				if c.distance_to(s) < 130.0:
					ok = false
					break
		if not ok:
			continue
		var cluster: Array = []
		for k in rng.randi_range(f_min, f_max):
			cluster.append([c + Vector2(rng.randf_range(-45, 45), rng.randf_range(-35, 35)), rng.randf_range(12, 26), rng.randf()])
		_add("trees", c, ["forest", cluster, tree_base, str(biome.get("tree_style", "round")), bool(biome.get("tree_snow", false))])
	# ---- rivers and lakes
	var wcfg: Dictionary = biome.get("water", {})
	var wi := 0
	for ww in Water.waterways:
		wi += 1
		var wpts: PackedVector2Array = ww[0]
		var ww_w: float = ww[1]
		var ww_k: int = ww[2]
		if ww_w > 150.0:
			_make_lake(rng, wpts, ww_w, ww_k, wcfg)
		else:
			_make_river(rng, wpts, ww_w, ww_k, wcfg)
	# ---- the sea: beach, shallows, mid water and deep water; polygons are clipped per chunk
	var beach_col := _bcol(wcfg, "beach", Color(0.42, 0.38, 0.27))
	var foam_col := _bcol(wcfg, "foam", Color(0.82, 0.9, 0.9))
	for sgn in [-1.0, 1.0]:
		var far := float(Water.Y_MIN) - 60.0 if sgn < 0.0 else float(Water.Y_MAX) + 60.0
		var coast := PackedVector2Array()
		var inland := PackedVector2Array()
		var s1 := PackedVector2Array()
		var s2 := PackedVector2Array()
		var x := -60.0
		while x <= w + 60.0:
			var cd := Water.coast_dy(clampf(x, 0.0, w))
			coast.append(Vector2(x, Water.MID_Y + sgn * cd))
			inland.append(Vector2(x, Water.MID_Y + sgn * (cd - 26.0)))
			s1.append(Vector2(x, Water.MID_Y + sgn * (cd + 34.0)))
			s2.append(Vector2(x, Water.MID_Y + sgn * (cd + 110.0)))
			x += 16.0
		var beach := PackedVector2Array(coast)
		for bi in range(inland.size() - 1, -1, -1):
			beach.append(inland[bi])
		_file_polygon("sea", beach, "", beach_col, 0.9)
		var poly_a := PackedVector2Array(coast)
		poly_a.append(Vector2(w + 60.0, far))
		poly_a.append(Vector2(-60.0, far))
		_file_polygon("sea", poly_a, "water_shallow", Color(0.12, 0.235, 0.265), 1.0)
		var poly_b := PackedVector2Array(s1)
		poly_b.append(Vector2(w + 60.0, far))
		poly_b.append(Vector2(-60.0, far))
		_file_polygon("sea", poly_b, "water_deep", Color(0.045, 0.11, 0.16), 0.55)
		var poly_c := PackedVector2Array(s2)
		poly_c.append(Vector2(w + 60.0, far))
		poly_c.append(Vector2(-60.0, far))
		_file_polygon("sea", poly_c, "water_deep", Color(0.045, 0.11, 0.16), 1.0)
		_add_runs("sea", coast, [0, foam_col])
	for r in Water.bridge_rects:
		var rect: Rect2 = r
		_add("bridges", rect.get_center(), ["bridge", rect])
	_build_chunks()


## Scenery that gives each battlefield its own character (all driven by the map's "biome" block).
func _make_decor(rng: RandomNumberGenerator, sites: Array, ft: float, fb: float, w: float) -> void:
	var dc: Dictionary = biome.get("decor", {})
	var fcols: Array = biome.get("field_cols", [])
	var nf := int(dc.get("fields", 0))
	if nf > 0 and not fcols.is_empty():
		var placed := 0
		var tries := 0
		while placed < nf and tries < nf * 16:
			tries += 1
			var c := Vector2(rng.randf_range(200.0, w - 200.0), rng.randf_range(ft + 40.0, fb - 40.0))
			var hw := rng.randf_range(55.0, 130.0)
			var hh := rng.randf_range(40.0, 90.0)
			var ang := float(rng.randi_range(-2, 2)) * 0.12 + (PI * 0.5 if rng.randf() < 0.35 else 0.0)
			var corners := PackedVector2Array([
				c + Vector2(-hw, -hh).rotated(ang), c + Vector2(hw, -hh).rotated(ang),
				c + Vector2(hw, hh).rotated(ang), c + Vector2(-hw, hh).rotated(ang)])
			var ok := not _near_water(c, 40.0) and not RoadNet.on_road(c)
			if ok:
				for cp in corners:
					if _near_water(cp, 40.0) or RoadNet.on_road(cp):
						ok = false
						break
			if ok:
				for s: Vector2 in sites:
					if c.distance_to(s) < 170.0 + hw:
						ok = false
						break
			if not ok:
				continue
			placed += 1
			var fc: Array = fcols[rng.randi() % fcols.size()]
			var col := Color(float(fc[0]), float(fc[1]), float(fc[2]), 0.92)
			var lines := PackedVector2Array()
			var yy := -hh + 5.0
			while yy < hh - 3.0:
				lines.append(c + Vector2(-hw + 2.0, yy).rotated(ang))
				lines.append(c + Vector2(hw - 2.0, yy).rotated(ang))
				yy += 9.0
			_add("decor", c, ["field", corners, col, lines, Color(col.r * 0.72, col.g * 0.72, col.b * 0.72, 0.55)])
	var nm := int(dc.get("marsh", 0))
	if nm > 0:
		var gcfg: Dictionary = biome.get("ground", {})
		var pcol := _bcol(gcfg, "puddle", Color(0.17, 0.30, 0.30))
		var made := 0
		var tries2 := 0
		while made < nm and tries2 < nm * 12:
			tries2 += 1
			var p := Vector2(rng.randf_range(0.0, w), rng.randf_range(ft + 10.0, fb - 10.0))
			if Water.kind_at(p) != 0 or not _near_water(p, 220.0) or RoadNet.on_road(p):
				continue
			var near_site := false
			for s2: Vector2 in sites:
				if p.distance_to(s2) < 110.0:
					near_site = true
					break
			if near_site:
				continue
			made += 1
			if made % 2 == 0:
				_add("decor", p, ["puddle", p, rng.randf_range(12.0, 40.0), rng.randf_range(0.4, 0.8), rng.randf() * PI, pcol])
			else:
				_add("decor", p, ["tuft", p, rng.randi_range(5, 9), rng.randf() * TAU, Color(0.36, 0.40, 0.18)])
	var ns := int(dc.get("snow", 0))
	for i in ns:
		var sp := Vector2(rng.randf_range(0.0, w), rng.randf_range(ft + 10.0, fb - 10.0))
		if _near_water(sp, 30.0):
			continue
		_add("decor", sp, ["snowpatch", sp, rng.randf_range(30.0, 110.0)])
	var nb := int(dc.get("boulders", 0))
	for i in nb:
		var bp := Vector2(rng.randf_range(0.0, w), rng.randf_range(ft + 10.0, fb - 10.0))
		if _near_water(bp, 40.0) or RoadNet.on_road(bp):
			continue
		var br := rng.randf_range(9.0, 24.0)
		var poly := PackedVector2Array()
		for k in 9:
			poly.append(bp + Vector2.from_angle(float(k) * TAU / 9.0 + rng.randf() * 0.3) * br * rng.randf_range(0.75, 1.08))
		_add("marks", bp, ["boulder", bp, br, poly])


## A river becomes a ribbon of segments that share their edge vertices (no gaps at bends, width varies a little).
func _make_river(rng: RandomNumberGenerator, pts: PackedVector2Array, w: float, kind: int, wcfg: Dictionary) -> void:
	var n := pts.size()
	if n < 2:
		return
	var norms := PackedVector2Array()
	var halves := PackedFloat32Array()
	var ph := rng.randf() * TAU
	for i in n:
		var tdir := pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
		var nrm := Vector2(0.0, 1.0)
		if tdir.length() > 0.001:
			nrm = tdir.normalized().orthogonal()
		norms.append(nrm)
		halves.append(w * 0.5 * (1.0 + 0.08 * sin(float(i) * 0.21 + ph)))
	for i in range(n - 1):
		var mid := (pts[i] + pts[i + 1]) * 0.5
		var item: Array = ["seg", pts[i], pts[i + 1], norms[i], norms[i + 1], float(halves[i]), float(halves[i + 1]), kind]
		_add("banks", mid, item)
		_add("rivers", mid, item)
	for e in [0, n - 1]:
		var cap: Array = ["cap", pts[e], float(halves[e]), kind]
		_add("banks", pts[e], cap)
		_add("rivers", pts[e], cap)
	# sand bars, pebbles and reed tufts along the banks
	var bank_col := _bcol(wcfg, "river_bank", Color(0.30, 0.25, 0.15))
	var tuft_col := Color(0.34, 0.40, 0.17)
	var i2 := 2
	while i2 < n - 2:
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		var pos := pts[i2] + norms[i2] * side * (float(halves[i2]) + rng.randf_range(3.0, 16.0))
		if Water.kind_at(pos) == 0:
			if rng.randf() < 0.5:
				var rx := rng.randf_range(8.0, 22.0)
				var ry := rng.randf_range(4.0, 9.0)
				var poly := PackedVector2Array()
				var rot := norms[i2].orthogonal().angle()
				for k in 10:
					var a := float(k) * TAU / 10.0
					poly.append(pos + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
				_add("shore", pos, ["bar", poly, Color(bank_col.r * 1.25, bank_col.g * 1.2, bank_col.b * 1.1, 0.75)])
			else:
				_add("shore", pos, ["tuft", pos, rng.randi_range(4, 8), rng.randf() * TAU, tuft_col])
		i2 += 3 + rng.randi_range(0, 3)


## Wide "rivers" (lakes, estuaries) become soft, irregular water bodies instead of fat capsules.
func _make_lake(rng: RandomNumberGenerator, pts: PackedVector2Array, w: float, kind: int, wcfg: Dictionary) -> void:
	var a := pts[0]
	var b := pts[pts.size() - 1]
	var dir := (b - a)
	var dang := dir.angle() if dir.length() > 1.0 else 0.0
	var r := w * 0.5
	var ph1 := rng.randf() * TAU
	var ph2 := rng.randf() * TAU
	var ph3 := rng.randf() * TAU
	var bank := PackedVector2Array()
	var shallow := PackedVector2Array()
	var deep := PackedVector2Array()
	var core := PackedVector2Array()
	var m := 72
	for k in m:
		var t := float(k) * TAU / float(m)
		var u := Vector2.from_angle(t)
		var base := b if u.dot(Vector2.from_angle(dang)) >= 0.0 else a
		var wob := 1.0 + 0.07 * sin(3.0 * t + ph1) + 0.05 * sin(5.0 * t + ph2) + 0.03 * sin(9.0 * t + ph3)
		bank.append(base + u * (r * wob + 12.0))
		shallow.append(base + u * (r * wob))
		deep.append(base + u * (r * wob * 0.80))
		core.append(base + u * (r * wob * 0.55))
	var c := (a + b) * 0.5
	_add("banks", c, ["lakebank", bank])
	_add("rivers", c, ["lake", shallow, deep, core, kind])
	# reeds around the rim
	var tuft_col := Color(0.34, 0.40, 0.17)
	for k in range(0, m, 3):
		if rng.randf() < 0.6:
			var rim: Vector2 = bank[k]
			var out := (rim - ((b if k * 2 < m else a))).normalized()
			_add("shore", rim, ["tuft", rim + out * rng.randf_range(2.0, 12.0), rng.randi_range(4, 8), rng.randf() * TAU, tuft_col])


## Files a (possibly huge) polygon into every chunk it touches, clipped to the chunk.
func _file_polygon(layer: String, poly: PackedVector2Array, tile: String, col: Color, alpha: float = 1.0) -> void:
	var cols := int(ceil(float(Battle.W + 120) / CH))
	var rows := int(ceil(float(Water.Y_MAX - Water.Y_MIN + 120) / CH))
	for gy in rows:
		for gx in cols:
			var rect := Rect2(float(gx) * CH - 60.0, float(Water.Y_MIN) - 60.0 + float(gy) * CH, CH, CH)
			var rp := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
			var clipped: Array = Geometry2D.intersect_polygons(poly, rp)
			for cp in clipped:
				var cpoly: PackedVector2Array = cp
				if cpoly.size() < 3:
					continue
				var k := _key(rect.get_center())
				if not _buckets.has(layer):
					_buckets[layer] = {}
				var d: Dictionary = _buckets[layer]
				if not d.has(k):
					d[k] = []
				(d[k] as Array).append(["poly", cpoly, tile, col, alpha])


func _build_chunks() -> void:
	var cols := int(ceil(float(Battle.W) / CH))
	var rows := int(ceil(float(Water.Y_MAX - Water.Y_MIN) / CH))
	var ground_col := _color("ground", Color(0.18, 0.22, 0.12))
	var wtint := _color("water_tint", Color(0, 0, 0))
	for layer in LAYER_Z:
		var d: Dictionary = {}
		if _buckets.has(layer):
			d = _buckets[layer]
		if layer == "ground":
			for gy in rows:
				for gx in cols:
					d[Vector2i(gx, gy)] = [["ground", ground_col]]
		for k in d:
			var key: Vector2i = k
			var chunk := TerrainChunk.new()
			chunk.layer_name = str(layer)
			chunk.items = d[k]
			chunk.cell = key
			chunk.ground_col = ground_col
			chunk.tint = wtint
			chunk.z_index = int(LAYER_Z[layer])
			if layer == "rivers" or layer == "sea":
				chunk.material = water_material()
			add_child(chunk)
			_chunk_nodes.append(chunk)
	queue_redraw()


func _draw() -> void:
	# thin dark border around the playfield
	var ft := Battle.FIELD_TOP
	var fb := Battle.FIELD_BOTTOM
	var w := float(Battle.W)
	draw_rect(Rect2(-3, ft - 3, w + 6, fb - ft + 6), Color(0, 0, 0, 0.8), false, 6.0)


## One 800 px square of one scenery layer.
class TerrainChunk extends Node2D:
	var layer_name := ""
	var items: Array = []
	var cell := Vector2i.ZERO
	var ground_col := Color(0.18, 0.22, 0.12)
	var tint := Color(0, 0, 0)

	func _init() -> void:
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	func _tinted(c: Color) -> Color:
		return Color(clampf(c.r + tint.r, 0.0, 1.0), clampf(c.g + tint.g, 0.0, 1.0), clampf(c.b + tint.b, 0.0, 1.0), c.a)

	func _blob(p: Vector2, r: float, col: Color) -> void:
		for k in 4:
			draw_circle(p, r * (1.0 - float(k) * 0.22), Color(col, col.a * 0.45))

	func _draw() -> void:
		match layer_name:
			"ground": _draw_ground()
			"blots": _draw_blots()
			"decor": _draw_decor()
			"roads": _draw_roads()
			"marks": _draw_marks()
			"trees": _draw_trees()
			"banks": _draw_banks()
			"rivers": _draw_rivers()
			"shore": _draw_shore()
			"sea": _draw_sea()
			"bridges": _draw_bridges()

	func _draw_ground() -> void:
		var x0 := float(cell.x) * TerrainLayer.CH
		var y0 := float(Water.Y_MIN) + float(cell.y) * TerrainLayer.CH
		var x1 := minf(x0 + TerrainLayer.CH, float(Battle.W))
		var y1 := minf(y0 + TerrainLayer.CH, float(Water.Y_MAX))
		if cell.x == 0:
			x0 -= 60.0
		if cell.y == 0:
			y0 -= 60.0
		if x1 >= float(Battle.W):
			x1 += 60.0
		if y1 >= float(Water.Y_MAX):
			y1 += 60.0
		x1 += 1.0
		y1 += 1.0
		var bg := TerrainLayer.map_background()
		if bg != null:
			draw_rect(Rect2(x0, y0, x1 - x0, y1 - y0), Color(0.04, 0.05, 0.04))
			var ft := Battle.FIELD_TOP
			var fb := Battle.FIELD_BOTTOM
			var field := Rect2(0.0, ft, float(Battle.W), fb - ft)
			var chunk := Rect2(x0, y0, x1 - x0, y1 - y0).intersection(field)
			if chunk.size.x > 0.0 and chunk.size.y > 0.0:
				var ts := bg.get_size()
				var src := Rect2((chunk.position.x - field.position.x) / field.size.x * ts.x,
					(chunk.position.y - field.position.y) / field.size.y * ts.y,
					chunk.size.x / field.size.x * ts.x, chunk.size.y / field.size.y * ts.y)
				draw_texture_rect_region(bg, chunk, src)
			return
		var poly := PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])
		TileLib.fill(self, poly, "ground", ground_col)

	func _draw_blots() -> void:
		if TerrainLayer.map_background() != null:
			return
		for it in items:
			var item: Array = it
			if str(item[0]) == "macro":
				var mp: Vector2 = item[1]
				var mr: float = item[2]
				var mc: Color = item[3]
				for k in 5:
					draw_circle(mp, mr * (1.0 - float(k) * 0.17), Color(mc, mc.a * 0.33))
			elif str(item[0]) == "patch":
				var p: Vector2 = item[1]
				var r: float = item[2]
				var shade: float = item[3]
				if shade < 0.0:
					var sc: Color = item[4]
					_blob(p, r, Color(sc.r, sc.g, sc.b, 0.30))
				else:
					var dc: Color = item[5]
					_blob(p, r * 0.8, Color(dc.r, dc.g, dc.b, 0.16))
			else:
				var sp: Vector2 = item[1]
				var sr: float = item[2]
				_blob(sp, sr, Color(0.05, 0.04, 0.03, 0.42))
				_blob(sp + Vector2(sr * 0.2, -sr * 0.1), sr * 0.55, Color(0.16, 0.12, 0.08, 0.40))

	func _draw_roads() -> void:
		var road_tex := TileLib.get_tile("road")
		# pass 1: dark outlines and verges of every road in the chunk (so crossings look joined)
		for it in items:
			var item: Array = it
			var pts: PackedVector2Array = item[0]
			var wd: float = item[1]
			if wd >= 20.0:
				draw_polyline(pts, Color(0.04, 0.04, 0.035, 0.75), wd + 9.0, true)
				draw_polyline(pts, Color(0.27, 0.24, 0.17, 0.60), wd + 4.0, true)
			else:
				draw_polyline(pts, Color(0.06, 0.05, 0.035, 0.55), wd + 4.0, true)
		# pass 2: the surfaces
		for it in items:
			var item2: Array = it
			var pts2: PackedVector2Array = item2[0]
			var wd2: float = item2[1]
			if wd2 >= 20.0:
				draw_polyline(pts2, Color(0.125, 0.125, 0.12), wd2, true)
				draw_polyline(pts2, Color(0.16, 0.16, 0.15, 0.7), wd2 * 0.45, true)
				_dashes(pts2)
			elif wd2 >= 11.0:
				draw_polyline(pts2, Color(0.17, 0.165, 0.15, 0.95), wd2, true)
				_dashes(pts2, 0.35)
			else:
				draw_polyline(pts2, Color(0.25, 0.205, 0.14, 0.92), wd2, true)
				draw_polyline(pts2, Color(0.13, 0.10, 0.07, 0.35), wd2 * 0.30, true)
		# round off the joints
		for it in items:
			var item3: Array = it
			var pts3: PackedVector2Array = item3[0]
			var wd3: float = item3[1]
			var col := Color(0.125, 0.125, 0.12) if wd3 >= 20.0 else (Color(0.17, 0.165, 0.15, 0.95) if wd3 >= 11.0 else Color(0.25, 0.205, 0.14, 0.92))
			draw_circle(pts3[0], wd3 * 0.5, col)
			draw_circle(pts3[pts3.size() - 1], wd3 * 0.5, col)

	func _dashes(pts: PackedVector2Array, alpha: float = 0.5) -> void:
		var acc := 0.0
		for i in range(pts.size() - 1):
			var a := pts[i]
			var b := pts[i + 1]
			var seg := a.distance_to(b)
			if seg < 1.0:
				continue
			var dir := (b - a) / seg
			var t := fmod(acc, 36.0)
			while t < seg:
				draw_line(a + dir * t, a + dir * minf(t + 14.0, seg), Color(0.62, 0.56, 0.32, alpha), 1.6)
				t += 36.0
			acc += seg

	func _draw_marks() -> void:
		var crater_tex := TileLib.get_tile("crater")
		for it in items:
			var item: Array = it
			if str(item[0]) == "crater":
				var cp: Vector2 = item[1]
				var rad: float = item[2]
				if crater_tex != null:
					var cs := Vector2(rad, rad) * 3.2
					draw_texture_rect(crater_tex, Rect2(cp - cs * 0.5, cs), false)
				else:
					draw_circle(cp, rad * 2.1, Color(0.02, 0.02, 0.015, 0.10))
					draw_circle(cp, rad * 1.5, Color(0.03, 0.025, 0.02, 0.18))
					draw_circle(cp, rad * 1.12, Color(0.31, 0.26, 0.18, 0.55))
					draw_circle(cp, rad * 0.92, Color(0.075, 0.062, 0.045, 0.96))
					draw_circle(cp + Vector2(rad * 0.12, rad * 0.16), rad * 0.62, Color(0.03, 0.025, 0.02, 0.7))
					draw_arc(cp, rad * 1.0, PI * 1.05, PI * 1.78, 10, Color(0.52, 0.46, 0.33, 0.55), 1.6)
			elif str(item[0]) == "boulder":
				var bpoly: PackedVector2Array = item[3]
				var bsh := PackedVector2Array()
				for bp in bpoly:
					bsh.append(bp + Vector2(3.0, 4.0))
				draw_colored_polygon(bsh, Color(0, 0, 0, 0.3))
				draw_colored_polygon(bpoly, Color(0.30, 0.30, 0.28))
				var bc: Vector2 = item[1]
				var br: float = item[2]
				draw_circle(bc + Vector2(-br * 0.25, -br * 0.3), br * 0.5, Color(0.46, 0.46, 0.42, 0.85))
			else:
				var rp: Vector2 = item[1]
				var rs: float = item[2]
				var rock_tex := TileLib.get_tile("rock")
				if rock_tex != null:
					var rts := Vector2(rs, rs) * 3.0
					draw_texture_rect(rock_tex, Rect2(rp - rts * 0.5, rts), false)
					continue
				draw_circle(rp + Vector2(1.5, 2.0), rs, Color(0, 0, 0, 0.3))
				draw_circle(rp, rs, Color(0.23, 0.23, 0.21))
				draw_circle(rp + Vector2(-rs * 0.25, -rs * 0.3), rs * 0.55, Color(0.38, 0.38, 0.34))

	func _draw_trees() -> void:
		var tree_tex := TileLib.get_tile("tree")
		for it in items:
			var item: Array = it
			var cl: Array = item[1]
			var base: Color = item[2]
			var style := str(item[3])
			var snowy: bool = item[4]
			if tree_tex == null:
				for tt in cl:
					var t0: Array = tt
					var sp: Vector2 = t0[0]
					var sr: float = t0[1]
					draw_circle(sp + Vector2(sr * 0.35, sr * 0.5), sr * 1.05, Color(0, 0, 0, 0.28))
			for tt in cl:
				var t1: Array = tt
				var tp: Vector2 = t1[0]
				var tr: float = t1[1]
				var sh: float = t1[2]
				if tree_tex != null:
					var ts := Vector2(tr, tr) * 2.8
					draw_texture_rect(tree_tex, Rect2(tp - ts * 0.5, ts), false)
					continue
				if style == "pine":
					_draw_pine(tp, tr * 1.15, sh, base, snowy)
					continue
				draw_circle(tp, tr, Color(base.r + 0.03 * sh, base.g + 0.04 * sh, base.b))
				draw_circle(tp + Vector2(-tr * 0.12, -tr * 0.15), tr * 0.78, Color(base.r + 0.035 + 0.04 * sh, base.g + 0.07 + 0.05 * sh, base.b + 0.02))
				draw_circle(tp + Vector2(-tr * 0.26, -tr * 0.32), tr * 0.42, Color(base.r + 0.10 + 0.04 * sh, base.g + 0.155 + 0.05 * sh, base.b + 0.055, 0.9))
				for k in 5:
					var ang := sh * 10.0 + float(k) * 1.9
					draw_circle(tp + Vector2.from_angle(ang) * tr * 0.55, tr * 0.12, Color(base.r - 0.01, base.g - 0.02, base.b - 0.01, 0.7))

	## Conifer seen from above: a spiky star in two shades, optionally frosted.
	func _draw_pine(p: Vector2, r: float, sh: float, base: Color, snowy: bool) -> void:
		var outer := PackedVector2Array()
		var inner := PackedVector2Array()
		var spikes := 9
		var rot := sh * 6.0
		for k in spikes * 2:
			var a := rot + float(k) * PI / float(spikes)
			var rr := r if k % 2 == 0 else r * 0.52
			outer.append(p + Vector2.from_angle(a) * rr)
			inner.append(p + Vector2.from_angle(a) * rr * 0.62)
		draw_colored_polygon(outer, Color(base.r, base.g + 0.01, base.b + 0.005))
		draw_colored_polygon(inner, Color(base.r + 0.03 + 0.03 * sh, base.g + 0.07 + 0.04 * sh, base.b + 0.035))
		draw_circle(p + Vector2(-r * 0.12, -r * 0.14), r * 0.2, Color(base.r + 0.08, base.g + 0.13, base.b + 0.07, 0.9))
		if snowy:
			draw_circle(p + Vector2(-r * 0.1, -r * 0.12), r * 0.34, Color(0.85, 0.9, 0.94, 0.55))

	func _quad(pa: Vector2, pb: Vector2, na: Vector2, nb: Vector2, ha: float, hb: float, col: Color) -> void:
		var a1 := pa + na * ha
		var a2 := pa - na * ha
		var b1 := pb + nb * hb
		var b2 := pb - nb * hb
		var cols := PackedColorArray([col, col, col])
		draw_primitive(PackedVector2Array([a1, b1, b2]), cols, PackedVector2Array())
		draw_primitive(PackedVector2Array([a1, b2, a2]), cols, PackedVector2Array())

	func _wcol(key: String, fallback: Color) -> Color:
		var wcfg: Dictionary = TileLib.biome.get("water", {})
		return _tinted(TileLib._col(wcfg, key, fallback))

	func _draw_banks() -> void:
		var bank := _wcol("river_bank", Color(0.30, 0.25, 0.15))
		var bank_tex := TileLib.get_tile("river_bank")
		for it in items:
			var item: Array = it
			var t := str(item[0])
			if t == "seg":
				var k: int = item[7]
				var extra := 12.0 if k == 2 else 8.0
				if bank_tex != null:
					var sa: Vector2 = item[1]
					var sb: Vector2 = item[2]
					var sd := (sb - sa).normalized()
					var sn := sd.orthogonal() * (float(item[5]) + extra)
					TileLib.fill(self, PackedVector2Array([sa - sd + sn, sb + sd + sn, sb + sd - sn, sa - sd - sn]), "river_bank", bank)
				else:
					_quad(item[1], item[2], item[3], item[4], float(item[5]) + extra, float(item[6]) + extra, Color(bank, 0.92))
			elif t == "cap":
				var k2: int = item[3]
				draw_circle(item[1], float(item[2]) + (12.0 if k2 == 2 else 8.0), Color(bank, 0.92))
			elif t == "lakebank":
				draw_colored_polygon(item[1], Color(bank, 0.92))

	func _draw_rivers() -> void:
		var shallow := _wcol("river_shallow", Color(0.14, 0.27, 0.30))
		var deep := _wcol("river_deep", Color(0.075, 0.17, 0.215))
		var core := _wcol("river_core", Color(0.06, 0.14, 0.19))
		var river_tex := TileLib.get_tile("river")
		# pass 1: shallow edge of everything (so crossings and junctions merge), pass 2: deeper body, pass 3: core
		for it in items:
			var item: Array = it
			var t := str(item[0])
			if t == "seg":
				if river_tex != null:
					var sa: Vector2 = item[1]
					var sb: Vector2 = item[2]
					var sd := (sb - sa).normalized()
					var sn := sd.orthogonal() * float(item[5])
					TileLib.fill(self, PackedVector2Array([sa - sd + sn, sb + sd + sn, sb + sd - sn, sa - sd - sn]), "river", shallow)
				else:
					_quad(item[1], item[2], item[3], item[4], float(item[5]), float(item[6]), shallow)
			elif t == "cap":
				draw_circle(item[1], float(item[2]), shallow)
			elif t == "lake":
				draw_colored_polygon(item[1], shallow)
		if river_tex != null:
			return
		for it in items:
			var item2: Array = it
			var t2 := str(item2[0])
			if t2 == "seg":
				var k: int = item2[7]
				var f := 0.80 if k == 2 else 0.66
				_quad(item2[1], item2[2], item2[3], item2[4], float(item2[5]) * f, float(item2[6]) * f, deep)
			elif t2 == "cap":
				draw_circle(item2[1], float(item2[2]) * 0.78, deep)
			elif t2 == "lake":
				draw_colored_polygon(item2[2], deep)
		for it in items:
			var item3: Array = it
			var t3 := str(item3[0])
			if t3 == "seg" and int(item3[7]) == 2:
				_quad(item3[1], item3[2], item3[3], item3[4], float(item3[5]) * 0.42, float(item3[6]) * 0.42, Color(core, 0.75))
			elif t3 == "lake":
				draw_colored_polygon(item3[3], Color(core, 0.6))

	func _draw_shore() -> void:
		for it in items:
			var item: Array = it
			var t := str(item[0])
			if t == "bar":
				draw_colored_polygon(item[1], item[2])
			elif t == "tuft":
				_draw_tuft(item[1], int(item[2]), float(item[3]), item[4])

	func _draw_tuft(p: Vector2, n: int, seed_a: float, col: Color) -> void:
		for k in n:
			var a := seed_a + float(k) * 2.4
			var ln := 5.0 + float(k % 3) * 2.5
			var dirv := Vector2.from_angle(a)
			draw_line(p, p + dirv * ln, Color(col.r * 0.8, col.g * 0.8, col.b * 0.8, 0.9), 1.6)
			draw_line(p + dirv * ln * 0.5, p + dirv * ln + Vector2(0.0, -2.0), Color(col.r * 1.2, col.g * 1.15, col.b, 0.85), 1.2)

	func _draw_decor() -> void:
		for it in items:
			var item: Array = it
			var t := str(item[0])
			if t == "field":
				draw_colored_polygon(item[1], item[2])
				draw_multiline(item[3], item[4], 1.2)
				draw_polyline(PackedVector2Array([item[1][0], item[1][1], item[1][2], item[1][3], item[1][0]]), Color(0.05, 0.05, 0.03, 0.35), 2.0)
			elif t == "puddle":
				var p: Vector2 = item[1]
				var rx: float = item[2]
				var sy: float = item[3]
				var pc: Color = item[5]
				draw_set_transform(p, float(item[4]), Vector2(1.0, sy))
				draw_circle(Vector2.ZERO, rx * 1.18, Color(0.10, 0.09, 0.05, 0.35))
				draw_circle(Vector2.ZERO, rx, Color(pc.r, pc.g, pc.b, 0.92))
				draw_circle(Vector2(-rx * 0.2, -rx * 0.2), rx * 0.55, Color(pc.r * 1.25, pc.g * 1.2, pc.b * 1.15, 0.5))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			elif t == "tuft":
				_draw_tuft(item[1], int(item[2]), float(item[3]), item[4])
			elif t == "snowpatch":
				var sp: Vector2 = item[1]
				var sr: float = item[2]
				for k in 4:
					draw_circle(sp + Vector2(float(k) * 3.0, float(k) * -2.0), sr * (1.0 - float(k) * 0.2), Color(0.88, 0.92, 0.96, 0.16))

	func _draw_sea() -> void:
		for it in items:
			var item: Array = it
			if str(item[0]) == "poly":
				var poly: PackedVector2Array = item[1]
				var col: Color = item[3]
				var alpha: float = item[4]
				var tl := str(item[2])
				if tl == "":
					draw_colored_polygon(poly, Color(col.r, col.g, col.b, alpha))
				else:
					TileLib.fill(self, poly, tl, _tinted(col), Color(1, 1, 1, alpha))
			else:
				var pts: PackedVector2Array = item[0]
				var foam: Color = item[2]
				draw_polyline(pts, Color(foam, 0.10), 10.0, true)
				draw_polyline(pts, Color(foam, 0.45), 2.2, true)

	func _draw_bridges() -> void:
		for it in items:
			var item: Array = it
			var rect: Rect2 = item[1]
			if TileLib.get_tile("bridge") != null:
				draw_texture_rect(TileLib.get_tile("bridge"), rect, false)
				continue
			draw_rect(rect.grow(3.0), Color(0.04, 0.035, 0.03, 0.9))
			draw_rect(rect, Color(0.24, 0.20, 0.14))
			var vertical := rect.size.y > rect.size.x
			if vertical:
				var by := rect.position.y + 5.0
				while by < rect.end.y - 3.0:
					draw_line(Vector2(rect.position.x + 2.0, by), Vector2(rect.end.x - 2.0, by), Color(0.13, 0.10, 0.07, 0.9), 1.5)
					by += 8.0
				draw_line(rect.position, Vector2(rect.position.x, rect.end.y), Color(0.52, 0.5, 0.43), 3.0)
				draw_line(Vector2(rect.end.x, rect.position.y), rect.end, Color(0.52, 0.5, 0.43), 3.0)
			else:
				var bx := rect.position.x + 5.0
				while bx < rect.end.x - 3.0:
					draw_line(Vector2(bx, rect.position.y + 2.0), Vector2(bx, rect.end.y - 2.0), Color(0.13, 0.10, 0.07, 0.9), 1.5)
					bx += 8.0
				draw_line(rect.position, Vector2(rect.end.x, rect.position.y), Color(0.52, 0.5, 0.43), 3.0)
				draw_line(Vector2(rect.position.x, rect.end.y), rect.end, Color(0.52, 0.5, 0.43), 3.0)
