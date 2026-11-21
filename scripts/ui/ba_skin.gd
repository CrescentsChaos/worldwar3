class_name BASkin
extends RefCounted
## Panel "skins" for the whole interface (Broken Arrow style: cut corners, thin lines, one accent edge).
##
## Every panel / button / card is drawn from a small 9-slice image. By default that image is generated here in code.
## To use your own art, drop a PNG with the id below into  user://sprites/  (or res://assets/sprites/):
##
##   ui_panel            big floating panels (top bar, dock, selection card, menus)
##   ui_panel_dark       inset / list backgrounds
##   ui_button           button, normal          ui_button_hover   hover        ui_button_pressed   pressed / toggled on
##   ui_card             unit card, normal       ui_card_selected  unit card selected
##
## Your image is cut in a 3 x 3 grid (corners stay as they are, edges and centre stretch), so draw it
## with corners about one third of the width. Any size works (64 x 64 is a good start). See ASSET_GUIDE.md.

const SIZE := 32
const SLICE := 10

static var _cache: Dictionary = {}


static func clear_cache() -> void:
	_cache.clear()


## A 9-slice panel style. `skin_id` names the optional replacement image (see above).
static func style(bg: Color, border: Color, accent: Color, cut: int, bw: int, mx: int, my: int, skin_id: String = "") -> StyleBox:
	if skin_id != "":
		var custom: Texture2D = SpriteLib.get_optional(skin_id)
		if custom != null:
			var st := StyleBoxTexture.new()
			st.texture = custom
			var m := maxi(2, int(minf(custom.get_width(), custom.get_height()) / 3.0))
			st.texture_margin_left = m
			st.texture_margin_right = m
			st.texture_margin_top = m
			st.texture_margin_bottom = m
			st.content_margin_left = mx
			st.content_margin_right = mx
			st.content_margin_top = my
			st.content_margin_bottom = my
			return st
	var key := "%s|%s|%s|%d|%d" % [bg.to_html(true), border.to_html(true), accent.to_html(true), cut, bw]
	var tex: Texture2D = null
	if _cache.has(key):
		tex = _cache[key]
	else:
		tex = _build(bg, border, accent, cut, bw)
		_cache[key] = tex
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = SLICE
	sb.texture_margin_right = SLICE
	sb.texture_margin_top = SLICE
	sb.texture_margin_bottom = SLICE
	sb.content_margin_left = mx
	sb.content_margin_right = mx
	sb.content_margin_top = my
	sb.content_margin_bottom = my
	return sb


static func _inside(x: float, y: float, s: float, cut: float, inset: float) -> bool:
	if x < inset or x > s - inset or y < inset or y > s - inset:
		return false
	var k := inset * 1.4142
	if cut > 0.0:
		if x + y < cut + k:
			return false
		if (s - x) + (s - y) < cut + k:
			return false
		var c2 := cut * 0.45
		if (s - x) + y < c2 + k:
			return false
		if x + (s - y) < c2 + k:
			return false
	return true


static func _build(bg: Color, border: Color, accent: Color, cut: int, bw: int) -> Texture2D:
	var s := float(SIZE)
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var fcut := float(cut)
	var fbw := float(maxi(bw, 0))
	for py in SIZE:
		for px in SIZE:
			var x := float(px) + 0.5
			var y := float(py) + 0.5
			if not _inside(x, y, s, fcut, 0.0):
				continue
			var col := bg
			if fbw > 0.0 and not _inside(x, y, s, fcut, fbw):
				col = border
			elif accent.a > 0.01 and y < 2.6:
				col = accent
			img.set_pixel(px, py, col)
	return ImageTexture.create_from_image(img)
