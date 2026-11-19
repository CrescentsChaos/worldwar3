class_name FogLayer
extends Node2D
## Fog of war (v6). A coarse grid over the whole theatre: cells nobody of yours can currently see are dimmed,
## cells you have seen before are lightly dimmed, the rest is dark. Enemy units outside your vision are hidden
## (Battle._update_vision decides who is shown). Scouting drones, towers and radar stations see far.

const CELL := 64.0

var cols := 0
var rows := 0
var vis := PackedByteArray()
var explored := PackedByteArray()
var img: Image
var tex: ImageTexture
var enabled := true


func setup() -> void:
	cols = int(ceil(float(Battle.W) / CELL))
	rows = int(ceil(float(Water.Y_MAX - Water.Y_MIN) / CELL))
	vis.resize(cols * rows)
	explored.resize(cols * rows)
	vis.fill(0)
	explored.fill(0)
	img = Image.create(cols, rows, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.02, 0.03, 0.04, 0.6))
	tex = ImageTexture.create_from_image(img)
	z_index = 60
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func reset() -> void:
	vis.fill(0)
	explored.fill(0)


func set_enabled(on: bool) -> void:
	enabled = on
	visible = on
	queue_redraw()


func is_visible_at(p: Vector2) -> bool:
	var gx := clampi(int(p.x / CELL), 0, cols - 1)
	var gy := clampi(int((p.y - float(Water.Y_MIN)) / CELL), 0, rows - 1)
	return vis[gy * cols + gx] == 1


## sources: [[Vector2 position, float radius], ...] - everything the player owns that can see.
func refresh(sources: Array) -> void:
	vis.fill(0)
	for s in sources:
		var p: Vector2 = s[0]
		var r: float = s[1]
		var cx := int(p.x / CELL)
		var cy := int((p.y - float(Water.Y_MIN)) / CELL)
		var rc := int(ceil(r / CELL)) + 1
		for gy in range(maxi(0, cy - rc), mini(rows, cy + rc + 1)):
			var cpy := float(Water.Y_MIN) + (float(gy) + 0.5) * CELL
			for gx in range(maxi(0, cx - rc), mini(cols, cx + rc + 1)):
				var cp := Vector2((float(gx) + 0.5) * CELL, cpy)
				if cp.distance_to(p) <= r:
					var i := gy * cols + gx
					vis[i] = 1
					explored[i] = 1
	for gy in rows:
		for gx in cols:
			var i2 := gy * cols + gx
			var a := 0.0
			if vis[i2] == 0:
				a = 0.30 if explored[i2] == 1 else 0.62
			img.set_pixel(gx, gy, Color(0.02, 0.03, 0.04, a))
	tex.update(img)
	queue_redraw()


func export_explored() -> String:
	return Marshalls.raw_to_base64(explored)


func import_explored(s: String) -> void:
	if s == "":
		return
	var raw := Marshalls.base64_to_raw(s)
	if raw.size() == explored.size():
		explored = raw


func _draw() -> void:
	if tex == null or not enabled:
		return
	draw_texture_rect(tex, Rect2(0.0, float(Water.Y_MIN), float(cols) * CELL, float(rows) * CELL), false)
