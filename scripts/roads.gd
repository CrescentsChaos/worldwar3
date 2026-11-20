class_name RoadNet
extends RefCounted
## The map's road network. Roads come from data/maps/<id>.json ("roads": polylines that share end points).
##  * on_road(p)  is a cheap grid lookup used by every moving unit (road speed vs off-road speed).
##  * route(...)  plans a convoy route along the roads when that beats driving cross-country.

const CELL := 16

static var built := false
static var cols := 0
static var rows := 0
static var grid := PackedByteArray()          # 1 = road surface
static var polylines: Array = []              # [PackedVector2Array, width]
static var astar := AStar2D.new()
static var node_pos: Array = []               # id -> Vector2
static var _lookup: Dictionary = {}           # snapped key -> id


static func configure(m: Dictionary) -> void:
	built = true
	cols = int(ceil(float(Water.W) / float(CELL)))
	rows = int(ceil(float(Water.Y_MAX - Water.Y_MIN) / float(CELL)))
	grid = PackedByteArray()
	grid.resize(cols * rows)
	grid.fill(0)
	polylines = []
	astar = AStar2D.new()
	node_pos = []
	_lookup = {}
	var rl: Array = m.get("roads", [])
	for r in rl:
		var rd: Dictionary = r
		var raw: Array = rd.get("pts", [])
		var w := float(rd.get("w", 12.0))
		var pts := PackedVector2Array()
		for q in raw:
			var qa: Array = q
			pts.append(Vector2(float(qa[0]), float(qa[1])))
		if pts.size() < 2:
			continue
		polylines.append([pts, w])
		var prev := -1
		for i in pts.size():
			var id := _node_for(pts[i])
			if prev >= 0 and prev != id:
				if not astar.are_points_connected(prev, id):
					astar.connect_points(prev, id, true)
			prev = id
			if i > 0:
				_stamp(pts[i - 1], pts[i], w * 0.5 + 3.0)


static func _key(p: Vector2) -> Vector2i:
	return Vector2i(roundi(p.x / 10.0), roundi(p.y / 10.0))


static func _node_for(p: Vector2) -> int:
	var k := _key(p)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var kk := Vector2i(k.x + dx, k.y + dy)
			if _lookup.has(kk):
				return int(_lookup[kk])
	var id := node_pos.size()
	node_pos.append(p)
	astar.add_point(id, p)
	_lookup[k] = id
	return id


static func _stamp(a: Vector2, b: Vector2, r: float) -> void:
	var n := maxi(1, int(a.distance_to(b) / 6.0))
	for s in range(n + 1):
		var p := a.lerp(b, float(s) / float(n))
		var cx0 := maxi(0, int(floorf((p.x - r) / float(CELL))))
		var cx1 := mini(cols - 1, int(floorf((p.x + r) / float(CELL))))
		var cy0 := maxi(0, int(floorf((p.y - r - float(Water.Y_MIN)) / float(CELL))))
		var cy1 := mini(rows - 1, int(floorf((p.y + r - float(Water.Y_MIN)) / float(CELL))))
		for cy in range(cy0, cy1 + 1):
			for cx in range(cx0, cx1 + 1):
				var c := Vector2((float(cx) + 0.5) * float(CELL), float(Water.Y_MIN) + (float(cy) + 0.5) * float(CELL))
				if c.distance_to(p) <= r:
					grid[cy * cols + cx] = 1


static func on_road(p: Vector2) -> bool:
	if not built:
		return false
	var cx := int(floorf(p.x / float(CELL)))
	var cy := int(floorf((p.y - float(Water.Y_MIN)) / float(CELL)))
	if cx < 0 or cx >= cols or cy < 0 or cy >= rows:
		return false
	return grid[cy * cols + cx] == 1


static func has_roads() -> bool:
	return built and node_pos.size() > 1


## Convoy route from `from` to `to` along the roads, or an empty array when driving cross-country is as good.
## `road_mult` is the unit's road speed divided by its off-road speed. The result starts at the road node nearest
## to `from` and ends at the one nearest to `to`.
static func route(from: Vector2, to: Vector2, road_mult: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if not has_roads() or road_mult < 1.2:
		return out
	var a := astar.get_closest_point(from)
	var b := astar.get_closest_point(to)
	if a < 0 or b < 0 or a == b:
		return out
	var pa: Vector2 = node_pos[a]
	var pb: Vector2 = node_pos[b]
	if from.distance_to(pa) > 650.0 or to.distance_to(pb) > 650.0:
		return out
	var ids := astar.get_id_path(a, b)
	if ids.size() < 2:
		return out
	var road_len := 0.0
	var prev: Vector2 = node_pos[ids[0]]
	for i in range(1, ids.size()):
		var cur: Vector2 = node_pos[ids[i]]
		road_len += prev.distance_to(cur)
		prev = cur
	var t_road := from.distance_to(pa) + to.distance_to(pb) + road_len / road_mult
	var t_direct := from.distance_to(to)
	if not Water.line_clear(from, to, 4):
		t_direct *= 1.45                       # a river in the way means a bridge detour anyway
	if t_road >= t_direct * 0.88:
		return out
	for id in ids:
		out.append(node_pos[id])
	return out


static func nearest_node(p: Vector2) -> Vector2:
	if not has_roads():
		return p
	var id := astar.get_closest_point(p)
	if id < 0:
		return p
	var q: Vector2 = node_pos[id]
	return q
