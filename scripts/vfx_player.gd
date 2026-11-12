class_name VfxPlayer
extends Node2D
## Plays one effect found by VfxLib (frame folder, sprite sheet or single image), then frees itself.

var frames: Array = []
var cols := 1
var rows := 1
var count := 1
var duration := 0.5
var size := 64.0
var age := 0.0
var offset := Vector2.ZERO


func setup(eff: Dictionary, cfg: Dictionary, world_size: float, rot: float) -> void:
	frames = eff.get("frames", [])
	cols = int(eff.get("cols", 1))
	rows = int(eff.get("rows", 1))
	var sheet := cols > 1 or rows > 1
	count = int(cfg.get("frames", cols * rows)) if sheet else frames.size()
	count = maxi(count, 1)
	var fps := float(cfg.get("fps", 24.0))
	size = world_size * float(cfg.get("scale", 1.0))
	duration = float(cfg.get("duration", float(count) / fps if count > 1 else 0.5))
	duration = maxf(duration, 0.05)
	var off: Array = cfg.get("offset", [0, 0])
	if off.size() >= 2:
		offset = Vector2(float(off[0]), float(off[1]))
	if bool(cfg.get("rotate", false)):
		rotation = rot
	if bool(cfg.get("additive", false)):
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = m
	z_index = int(cfg.get("z", 55))


func _process(delta: float) -> void:
	age += delta
	if age >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	if frames.is_empty():
		return
	var t := clampf(age / duration, 0.0, 1.0)
	if cols > 1 or rows > 1:
		var tex := frames[0] as Texture2D
		var idx := mini(int(t * float(count)), count - 1)
		var fw := float(tex.get_width()) / float(cols)
		var fh := float(tex.get_height()) / float(rows)
		var src := Rect2(float(idx % cols) * fw, float(floori(float(idx) / float(cols))) * fh, fw, fh)
		var h := size * fh / fw
		draw_texture_rect_region(tex, Rect2(Vector2(-size * 0.5, -h * 0.5) + offset, Vector2(size, h)), src)
	elif frames.size() > 1:
		var tex := frames[mini(int(t * float(frames.size())), frames.size() - 1)] as Texture2D
		var h := size * float(tex.get_height()) / float(tex.get_width())
		draw_texture_rect(tex, Rect2(Vector2(-size * 0.5, -h * 0.5) + offset, Vector2(size, h)), false)
	else:
		var tex := frames[0] as Texture2D
		var s := size * (0.7 + 0.4 * t)
		var h := s * float(tex.get_height()) / float(tex.get_width())
		draw_texture_rect(tex, Rect2(Vector2(-s * 0.5, -h * 0.5) + offset, Vector2(s, h)), false, Color(1, 1, 1, 1.0 - t))
