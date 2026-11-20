class_name Water
extends RefCounted
## The map's water: a sea along the north and south coasts (with a bay in the middle), a central
## river with four tributaries, and bridges over the river. Everything that asks "is this water?"
## goes through here, so the terrain art, the minimap, movement and pathfinding all agree.
##
## kind_at():  0 land | 1 stream (shallow, everyone can wade it slowly)
##             2 river (deep: boats sail it, infantry wade it, vehicles need a bridge)
##             3 sea / bay (deep: ships only)
## Ships have a "draft" = the lowest kind they can sail on
## (boats 1, destroyers and missile boats 2, big ships and submarines 3).
## Path levels used by find_path(): 1-3 = ship drafts, 4 = land vehicles, 5 = infantry.

const W := 6400
const CELL := 16
const Y_MIN := -560
const Y_MAX := 1568            # symmetric around MID_Y with Y_MIN
const COLS := 400              # W / CELL
const ROWS := 133              # (Y_MAX - Y_MIN) / CELL
const MID_Y := 504.0
static var COAST := 760.0      # half-height of the land strip (the field itself is 744); set by the map
static var RIVER_X := 3200.0   # x of the bay / procedural river
static var BAY_DEPTH := 250.0
static var BAY_SIGMA := 420.0
const RIVER_W := 72.0
const STREAM_W := 40.0
const BRIDGE_YS := [30.0, 267.0, 504.0, 741.0, 978.0]

static var built := false
static var kinds := PackedByteArray()
static var bridge_cells := PackedByteArray()
static var waterways: Array = []       # [PackedVector2Array points, float width, int kind]
static var bridge_rects: Array = []    # Rect2
static var _astars: Array = [null, null, null, null, null, null]
static var _shores: Array = [null, null, null, null]
static var cfg: Dictionary = {}        # the map definition (data/maps/<id>.json); empty / procedural = the classic layout


## Loads a map's geography (coast, rivers, bridges). Call before ensure_built(); safe to call again for a new map.
static func configure(m: Dictionary) -> void:
	cfg = m
	var c: Dictionary = m.get("coast", {})
	COAST = float(c.get("half", 760.0))
	BAY_DEPTH = float(c.get("bay_depth", 250.0))
	BAY_SIGMA = float(c.get("bay_sigma", 420.0))
	RIVER_X = float(c.get("bay_x", 3200.0))
	built = false
	kinds = PackedByteArray()
	bridge_cells = PackedByteArray()
	waterways = []
	bridge_rects = []
	_astars = [null, null, null, null, null, null]
	_shores = [null, null, null, null]
	ensure_built()


static func ensure_built() -> void:
	if built:
		return
	built = true
	kinds.resize(COLS * ROWS)
	bridge_cells.resize(COLS * ROWS)
	kinds.fill(0)
	bridge_cells.fill(0)
	for cy in ROWS:
		var py := float(Y_MIN) + (float(cy) + 0.5) * float(CELL)
		for cx in COLS:
			var px := (float(cx) + 0.5) * float(CELL)
			if absf(py - MID_Y) > coast_dy(px):
				kinds[cy * COLS + cx] = 3
	if bool(cfg.get("procedural", cfg.is_empty())):
		_make_waterways()
		for by in BRIDGE_YS:
			bridge_rects.append(Rect2(RIVER_X - 54.0, float(by) - 22.0, 108.0, 44.0))
	else:
		var wl: Array = cfg.get("waterways", [])
		for ww in wl:
			var wd: Dictionary = ww
			var pts := PackedVector2Array()
			var raw: Array = wd.get("pts", [])
			for q in raw:
				var qa: Array = q
				pts.append(Vector2(float(qa[0]), float(qa[1])))
			if pts.size() >= 2:
				waterways.append([pts, float(wd.get("w", 40.0)), int(wd.get("kind", 1))])
		var bl: Array = cfg.get("bridges", [])
		for b in bl:
			var ba: Array = b
			bridge_rects.append(Rect2(float(ba[0]), float(ba[1]), float(ba[2]), float(ba[3])))
	for w in waterways:
		_stamp(w[0], float(w[1]) * 0.5, int(w[2]))
	for r in bridge_rects:
		_mark_bridge(r)


## Distance from the map's centre line to the coast at world x (the sea is beyond it).
static func coast_dy(x: float) -> float:
	var wob := 6.0 * sin(x / 71.0) + 4.0 * sin(x / 37.0 + 1.3)
	var t := (x - RIVER_X) / BAY_SIGMA
	return COAST + wob - BAY_DEPTH * exp(-t * t)


static func _make_waterways() -> void:
	waterways.clear()
	var half := COAST - BAY_DEPTH + 40.0
	var main := PackedVector2Array([Vector2(RIVER_X, MID_Y - half), Vector2(RIVER_X, MID_Y + half)])
	waterways.append([main, RIVER_W, 2])
	# four tributaries (the original shape, stretched to the bigger map)
	var ctrl_src: Array = [Vector2(1228, 44), Vector2(1244, 120), Vector2(1300, 215), Vector2(1390, 285),
		Vector2(1480, 345), Vector2(1560, 392), Vector2(1600, 410)]
	var ctrl: Array = []
	for c in ctrl_src:
		ctrl.append(Vector2(RIVER_X + (c.x - 1600.0) * 2.4, MID_Y + (c.y - 504.0) * 1.7))
	ctrl[ctrl.size() - 1] = Vector2(RIVER_X, ctrl[ctrl.size() - 1].y)
	var base_line := _spline(ctrl, 8)
	# two long creeks crossing the land between each country and the river (wadable, slow)
	for cx in [2150.0, 4250.0]:
		var creek: Array = []
		for k in range(0, 9):
			var yy := MID_Y - 700.0 + float(k) * 175.0
			creek.append(Vector2(cx + 70.0 * sin(float(k) * 1.1 + cx), yy))
		waterways.append([_spline(creek, 6), STREAM_W * 0.8, 1])
	for flip_x in [false, true]:
		for flip_y in [false, true]:
			var line := PackedVector2Array()
			for p in base_line:
				var q: Vector2 = p
				if flip_x:
					q.x = float(W) - q.x
				if flip_y:
					q.y = 2.0 * MID_Y - q.y
				line.append(q)
			waterways.append([line, STREAM_W, 1])


## Catmull-Rom spline through the control points.
static func _spline(pts: Array, samples: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := pts.size()
	for i in range(n - 1):
		var p0: Vector2 = pts[maxi(i - 1, 0)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[mini(i + 2, n - 1)]
		for s in samples:
			var t := float(s) / float(samples)
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
				+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3))
	out.append(pts[n - 1])
	return out


static func _stamp(pts: PackedVector2Array, r: float, kind: int) -> void:
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var n := maxi(1, int(a.distance_to(b) / 6.0))
		for s in range(n + 1):
			var p := a.lerp(b, float(s) / float(n))
			var cx0 := maxi(0, int(floorf((p.x - r) / float(CELL))))
			var cx1 := mini(COLS - 1, int(floorf((p.x + r) / float(CELL))))
			var cy0 := maxi(0, int(floorf((p.y - r - float(Y_MIN)) / float(CELL))))
			var cy1 := mini(ROWS - 1, int(floorf((p.y + r - float(Y_MIN)) / float(CELL))))
			for cy in range(cy0, cy1 + 1):
				for cx in range(cx0, cx1 + 1):
					if _center_of(Vector2i(cx, cy)).distance_to(p) > r:
						continue
					var idx := cy * COLS + cx
					var cur := int(kinds[idx])
					if cur != 3 and cur < kind:
						kinds[idx] = kind


static func _mark_bridge(r: Rect2) -> void:
	var cx0 := maxi(0, int(floorf(r.position.x / float(CELL))))
	var cx1 := mini(COLS - 1, int(floorf(r.end.x / float(CELL))))
	var cy0 := maxi(0, int(floorf((r.position.y - float(Y_MIN)) / float(CELL))))
	var cy1 := mini(ROWS - 1, int(floorf((r.end.y - float(Y_MIN)) / float(CELL))))
	for cy in range(cy0, cy1 + 1):
		for cx in range(cx0, cx1 + 1):
			if r.has_point(_center_of(Vector2i(cx, cy))):
				bridge_cells[cy * COLS + cx] = 1


# ------------------------------------------------------------------ queries

static func _cell_of(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(floorf(p.x / float(CELL))), 0, COLS - 1),
		clampi(int(floorf((p.y - float(Y_MIN)) / float(CELL))), 0, ROWS - 1))


static func _center_of(c: Vector2i) -> Vector2:
	return Vector2((float(c.x) + 0.5) * float(CELL), float(Y_MIN) + (float(c.y) + 0.5) * float(CELL))


static func kind_at(p: Vector2) -> int:
	if not built:
		ensure_built()
	var cx := int(floorf(p.x / float(CELL)))
	var cy := int(floorf((p.y - float(Y_MIN)) / float(CELL)))
	if cx < 0 or cx >= COLS or cy < 0 or cy >= ROWS:
		return 0
	return int(kinds[cy * COLS + cx])


static func is_bridge(p: Vector2) -> bool:
	if not built:
		ensure_built()
	var cx := int(floorf(p.x / float(CELL)))
	var cy := int(floorf((p.y - float(Y_MIN)) / float(CELL)))
	if cx < 0 or cx >= COLS or cy < 0 or cy >= ROWS:
		return false
	return bridge_cells[cy * COLS + cx] == 1


## Can a land unit stand here? Infantry (`wader`) can wade rivers, vehicles need a bridge.
static func land_ok(p: Vector2, wader: bool) -> bool:
	var k := kind_at(p)
	if k <= 1:
		return true
	if is_bridge(p):
		return true
	return wader and k == 2


static func speed_mult(p: Vector2, wader: bool) -> float:
	var k := kind_at(p)
	if k == 1:
		return 0.6
	if k == 2 and not is_bridge(p):
		return 0.4 if wader else 1.0
	return 1.0


static func navigable(p: Vector2, draft: int) -> bool:
	return kind_at(p) >= draft


static func _open(p: Vector2, level: int) -> bool:
	if level <= 3:
		return kind_at(p) >= level
	return land_ok(p, level == 5)


static func line_clear(a: Vector2, b: Vector2, level: int) -> bool:
	var n := int(a.distance_to(b) / 12.0) + 1
	for i in range(1, n + 1):
		if not _open(a.lerp(b, float(i) / float(n)), level):
			return false
	return true


# ----------------------------------------------------------- shores / nearest

static func _is_edge(cx: int, cy: int, draft: int) -> bool:
	if cx > 0 and int(kinds[cy * COLS + cx - 1]) < draft:
		return true
	if cx < COLS - 1 and int(kinds[cy * COLS + cx + 1]) < draft:
		return true
	if cy > 0 and int(kinds[(cy - 1) * COLS + cx]) < draft:
		return true
	if cy < ROWS - 1 and int(kinds[(cy + 1) * COLS + cx]) < draft:
		return true
	return false


## Centres of navigable cells that touch land / shallower water (the "shoreline" for this draft).
static func _shore(draft: int) -> PackedVector2Array:
	ensure_built()
	if _shores[draft] != null:
		return _shores[draft]
	var out := PackedVector2Array()
	for cy in ROWS:
		for cx in COLS:
			if int(kinds[cy * COLS + cx]) >= draft and _is_edge(cx, cy, draft):
				out.append(_center_of(Vector2i(cx, cy)))
	_shores[draft] = out
	return out


## Centre of the nearest shoreline cell a ship of this draft can reach. x < -1000 means none.
static func nearest_water(p: Vector2, draft: int) -> Vector2:
	var best := Vector2(-9999.0, -9999.0)
	var best_d := INF
	for q in _shore(clampi(draft, 1, 3)):
		var d := p.distance_squared_to(q)
		if d < best_d:
			best_d = d
			best = q
	return best


static func dist_to_water(p: Vector2, draft: int) -> float:
	var q := nearest_water(p, draft)
	if q.x < -1000.0:
		return INF
	return p.distance_to(q)


# -------------------------------------------------------------- pathfinding

static func _cell_open(cx: int, cy: int, level: int) -> bool:
	var i := cy * COLS + cx
	var k := int(kinds[i])
	if level <= 3:
		return k >= level
	if level == 4:
		return k <= 1 or bridge_cells[i] == 1
	return k <= 2 or bridge_cells[i] == 1


static func _astar(level: int) -> AStarGrid2D:
	ensure_built()
	if _astars[level] != null:
		return _astars[level]
	var a := AStarGrid2D.new()
	a.region = Rect2i(0, 0, COLS, ROWS)
	a.cell_size = Vector2(float(CELL), float(CELL))
	a.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	a.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	a.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	a.update()
	for cy in ROWS:
		for cx in COLS:
			if not _cell_open(cx, cy, level):
				a.set_point_solid(Vector2i(cx, cy), true)
	_astars[level] = a
	return a


static func _snap_open(a: AStarGrid2D, c: Vector2i) -> Vector2i:
	if not a.is_point_solid(c):
		return c
	for r in range(1, 11):
		var best := Vector2i(-1, -1)
		var best_d := INF
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var n := Vector2i(c.x + dx, c.y + dy)
				if n.x < 0 or n.y < 0 or n.x >= COLS or n.y >= ROWS:
					continue
				if a.is_point_solid(n):
					continue
				var d := float(dx * dx + dy * dy)
				if d < best_d:
					best_d = d
					best = n
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)


## Waypoints (world positions) from `from` to `to` for a path level; empty if there is no route.
static func find_path(from: Vector2, to: Vector2, level: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var a := _astar(level)
	var s := _snap_open(a, _cell_of(from))
	var e := _snap_open(a, _cell_of(to))
	if s.x < 0 or e.x < 0:
		return out
	var ids = a.get_id_path(s, e)
	if ids.is_empty():
		return out
	var pts: Array = []
	for id in ids:
		pts.append(_center_of(id))
	return _smooth(pts, level)


## Drops waypoints that a straight line can skip (looks a few points ahead each time).
static func _smooth(pts: Array, level: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := pts.size()
	if n == 0:
		return out
	out.append(pts[0])
	var i := 0
	while i < n - 1:
		var j := mini(n - 1, i + 14)
		while j > i + 1 and not line_clear(pts[i], pts[j], level):
			j -= 1
		out.append(pts[j])
		i = j
	return out


# ------------------------------------------------------------------ minimap

static func minimap_image(w: int, h: int) -> Image:
	ensure_built()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var p := Vector2((float(x) + 0.5) / float(w) * float(W),
				float(Y_MIN) + (float(y) + 0.5) / float(h) * float(Y_MAX - Y_MIN))
			var col := Color(0.10, 0.17, 0.09, 1.0)
			match kind_at(p):
				3: col = Color(0.05, 0.15, 0.29, 1.0)
				2: col = Color(0.10, 0.26, 0.44, 1.0)
				1: col = Color(0.16, 0.34, 0.46, 1.0)
			img.set_pixel(x, y, col)
	return img
