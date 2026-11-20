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
const LAYER_Z := {"ground": -20, "blots": -19, "roads": -18, "marks": -17, "trees": -16, "rivers": -15, "sea": -14, "bridges": -13}

var pal: Dictionary = {}
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
	# ---- ground blotches
	for i in 1100:
		var p := Vector2(rng.randf_range(-40, w + 40), rng.randf_range(ft - 30, fb + 30))
		var r := rng.randf_range(30, 130)
		var sh := rng.randf_range(-1.0, 1.0)
		_add("blots", p, ["patch", p, r, sh, shade_col, dirt_col])
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
	for i in 650:
		var rp := Vector2(rng.randf_range(0, w), rng.randf_range(ft + 10, fb - 10))
		if _near_water(rp, 24.0):
			continue
		_add("marks", rp, ["rock", rp, rng.randf_range(2.5, 6.5)])
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
		_add("trees", c, ["forest", cluster, tree_base])
	# ---- rivers and lakes
	for ww in Water.waterways:
		var pts2: PackedVector2Array = ww[0]
		_add_runs("rivers", pts2, [float(ww[1]), int(ww[2]), false])
		_add("rivers", pts2[0], ["cap", pts2[0], float(ww[1]) * 0.5, int(ww[2])])
		_add("rivers", pts2[pts2.size() - 1], ["cap", pts2[pts2.size() - 1], float(ww[1]) * 0.5, int(ww[2])])
	# ---- the sea: polygons are clipped per chunk, the coast line is split into runs
	for sgn in [-1.0, 1.0]:
		var far := float(Water.Y_MIN) - 60.0 if sgn < 0.0 else float(Water.Y_MAX) + 60.0
		var coast := PackedVector2Array()
		var offs := PackedVector2Array()
		var x := -60.0
		while x <= w + 60.0:
			var cd := Water.coast_dy(clampf(x, 0.0, w))
			coast.append(Vector2(x, Water.MID_Y + sgn * cd))
			offs.append(Vector2(x, Water.MID_Y + sgn * (cd + 24.0)))
			x += 16.0
		var poly_a := PackedVector2Array(coast)
		poly_a.append(Vector2(w + 60.0, far))
		poly_a.append(Vector2(-60.0, far))
		var poly_b := PackedVector2Array(offs)
		poly_b.append(Vector2(w + 60.0, far))
		poly_b.append(Vector2(-60.0, far))
		_file_polygon("sea", poly_a, "water_shallow", Color(0.12, 0.235, 0.265))
		_file_polygon("sea", poly_b, "water_deep", Color(0.045, 0.11, 0.16))
		_add_runs("sea", coast, [0])
	for r in Water.bridge_rects:
		var rect: Rect2 = r
		_add("bridges", rect.get_center(), ["bridge", rect])
	_build_chunks()


## Files a (possibly huge) polygon into every chunk it touches, clipped to the chunk.
func _file_polygon(layer: String, poly: PackedVector2Array, tile: String, col: Color) -> void:
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
				(d[k] as Array).append(["poly", cpoly, tile, col])


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
			"roads": _draw_roads()
			"marks": _draw_marks()
			"trees": _draw_trees()
			"rivers": _draw_rivers()
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
		var bg := SpriteLib.get_optional("background")
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
		if SpriteLib.get_optional("background") != null:
			return
		for it in items:
			var item: Array = it
			if str(item[0]) == "patch":
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
			else:
				var rp: Vector2 = item[1]
				var rs: float = item[2]
				draw_circle(rp + Vector2(1.5, 2.0), rs, Color(0, 0, 0, 0.3))
				draw_circle(rp, rs, Color(0.23, 0.23, 0.21))
				draw_circle(rp + Vector2(-rs * 0.25, -rs * 0.3), rs * 0.55, Color(0.38, 0.38, 0.34))

	func _draw_trees() -> void:
		var tree_tex := TileLib.get_tile("tree")
		for it in items:
			var item: Array = it
			var cl: Array = item[1]
			var base: Color = item[2]
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
				draw_circle(tp, tr, Color(base.r + 0.03 * sh, base.g + 0.04 * sh, base.b))
				draw_circle(tp + Vector2(-tr * 0.12, -tr * 0.15), tr * 0.78, Color(base.r + 0.035 + 0.04 * sh, base.g + 0.07 + 0.05 * sh, base.b + 0.02))
				draw_circle(tp + Vector2(-tr * 0.26, -tr * 0.32), tr * 0.42, Color(base.r + 0.10 + 0.04 * sh, base.g + 0.155 + 0.05 * sh, base.b + 0.055, 0.9))
				for k in 5:
					var ang := sh * 10.0 + float(k) * 1.9
					draw_circle(tp + Vector2.from_angle(ang) * tr * 0.55, tr * 0.12, Color(base.r - 0.01, base.g - 0.02, base.b - 0.01, 0.7))

	func _draw_rivers() -> void:
		var bank := Color(0.17, 0.14, 0.09, 0.80)
		var river_tex := TileLib.get_tile("river")
		for it in items:
			var item: Array = it
			if str(item[0]) == "cap":
				var cp: Vector2 = item[1]
				var cr: float = item[2]
				var ck: int = item[3]
				draw_circle(cp, cr, _tinted(Color(0.075, 0.17, 0.215) if ck == 2 else Color(0.14, 0.27, 0.30)))
				continue
			var pts: PackedVector2Array = item[0]
			var wd: float = item[1]
			var k: int = item[2]
			draw_polyline(pts, bank, wd + (14.0 if k == 2 else 9.0), true)
		for it in items:
			var item2: Array = it
			if str(item2[0]) == "cap":
				continue
			var pts2: PackedVector2Array = item2[0]
			var wd2: float = item2[1]
			var k2: int = item2[2]
			if river_tex != null:
				for si in range(pts2.size() - 1):
					var sa := pts2[si]
					var sb := pts2[si + 1]
					var sd := (sb - sa).normalized()
					var sn := sd.orthogonal() * wd2 * 0.5
					TileLib.fill(self, PackedVector2Array([sa - sd + sn, sb + sd + sn, sb + sd - sn, sa - sd - sn]), "river", Color.WHITE)
			else:
				draw_polyline(pts2, _tinted(Color(0.075, 0.17, 0.215) if k2 == 2 else Color(0.14, 0.27, 0.30)), wd2, true)
				if k2 == 2:
					draw_polyline(pts2, _tinted(Color(0.06, 0.14, 0.19)), wd2 * 0.6, true)
					draw_polyline(pts2, Color(0.12, 0.24, 0.29, 0.5), wd2 * 0.18, true)

	func _draw_sea() -> void:
		for it in items:
			var item: Array = it
			if str(item[0]) == "poly":
				var poly: PackedVector2Array = item[1]
				var col: Color = item[3]
				TileLib.fill(self, poly, str(item[2]), _tinted(col))
			else:
				var pts: PackedVector2Array = item[0]
				draw_polyline(pts, Color(0.42, 0.38, 0.27, 0.5), 12.0, true)
				draw_polyline(pts, Color(0.82, 0.9, 0.9, 0.32), 2.0, true)

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
