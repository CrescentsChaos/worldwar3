class_name Explosion
extends Node2D
## Purely visual blast: additive fireball, shockwave ring, flying sparks and lingering smoke.
## Damage is applied by Battle.explode(). `duration` is the fire time; smoke outlives it.

var radius := 40.0
var duration := 0.5
var age := 0.0
var nuke := false

var _smoke_t := 0.0
var _glow: Glow
var _lobes: Array = []     # [offset, size, phase]
var _sparks: Array = []    # [direction, speed, length]
var _puffs: Array = []     # [offset, size, drift]


func _ready() -> void:
	z_index = 50
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var tiny := radius < 14.0
	_smoke_t = 0.0 if tiny else clampf(radius / 45.0, 0.5, 2.5)
	if nuke:
		_smoke_t = 5.0
	var nl := 3 if tiny else (14 if nuke else 8)
	for i in nl:
		_lobes.append([Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 0.55) * radius,
			rng.randf_range(0.35, 0.7), rng.randf()])
	var ns := 5 if tiny else (40 if nuke else clampi(int(radius / 3.0), 8, 22))
	for i in ns:
		_sparks.append([Vector2.from_angle(rng.randf() * TAU), rng.randf_range(0.8, 1.9) * maxf(radius, 14.0), rng.randf_range(0.12, 0.32)])
	if _smoke_t > 0.0:
		for i in (24 if nuke else clampi(int(radius / 8.0), 3, 9)):
			_puffs.append([Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 0.6) * radius,
				rng.randf_range(0.35, 0.65), Vector2(rng.randf_range(-12.0, 12.0), rng.randf_range(-26.0, -6.0))])
	_glow = Glow.new()
	_glow.ex = self
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	add_child(_glow)


func _process(delta: float) -> void:
	age += delta
	if age >= duration + _smoke_t:
		queue_free()
		return
	queue_redraw()
	if _glow != null:
		_glow.queue_redraw()


func _draw() -> void:
	# smoke and shockwave (normal blend, under the glow)
	var ft := clampf(age / duration, 0.0, 1.0)
	if not _puffs.is_empty():
		var st := clampf((age - duration * 0.25) / (duration + _smoke_t - duration * 0.25), 0.0, 1.0)
		for pf in _puffs:
			var off: Vector2 = pf[0]
			var drift: Vector2 = pf[2]
			var sz: float = radius * float(pf[1]) * (0.55 + 0.7 * st)
			var a := (1.0 - st) * 0.5 * clampf(age / 0.25, 0.0, 1.0)
			var dark := 0.10 + 0.18 * st
			draw_circle(off + drift * st * 2.0, sz, Color(dark, dark * 0.95, dark * 0.9, a))
	if ft < 1.0:
		var e := 1.0 - pow(1.0 - ft, 3.0)
		var wr := radius * (0.6 + 1.0 * e)
		draw_arc(Vector2.ZERO, wr, 0.0, TAU, 48 if radius < 120.0 else 90, Color(1.0, 0.95, 0.8, 0.6 * (1.0 - ft)), 3.0 if nuke else 2.0)
		if nuke:
			draw_arc(Vector2.ZERO, wr * 1.35, 0.0, TAU, 96, Color(1.0, 0.8, 0.5, 0.35 * (1.0 - ft)), 6.0)
	# sparks / debris
	if ft < 1.0:
		for sp in _sparks:
			var dir: Vector2 = sp[0]
			var d: float = float(sp[1]) * (1.0 - pow(1.0 - ft, 2.0))
			var len: float = float(sp[2]) * float(sp[1]) * (1.0 - ft)
			draw_line(dir * d, dir * (d + len), Color(1.0, 0.7 - 0.3 * ft, 0.25, 1.0 - ft), 1.6)


## Additive fireball (separate node so it can use its own blend mode).
class Glow extends Node2D:
	var ex: Explosion

	func _draw() -> void:
		if ex == null or ex.age >= ex.duration:
			return
		var t := clampf(ex.age / ex.duration, 0.0, 1.0)
		var r := ex.radius * (1.0 - pow(1.0 - t, 3.0))
		var a := 1.0 - t
		var core := Color(1.0, 0.9 - 0.3 * t, 0.5 - 0.3 * t, 0.55 * a)
		draw_circle(Vector2.ZERO, r * 0.55, core)
		for lb in ex._lobes:
			var off: Vector2 = lb[0]
			var sz: float = ex.radius * float(lb[1]) * (1.0 - pow(1.0 - t, 2.0)) * (0.8 + 0.4 * float(lb[2]))
			draw_circle(off * (0.4 + t), sz, Color(1.0, 0.45 + 0.2 * (1.0 - t), 0.1, 0.28 * a))
		draw_circle(Vector2.ZERO, r * 0.3, Color(1.0, 0.97, 0.85, 0.7 * a))
		if t < 0.25:
			draw_circle(Vector2.ZERO, ex.radius * 1.3, Color(1.0, 0.85, 0.6, 0.12 * (1.0 - t * 4.0)))
