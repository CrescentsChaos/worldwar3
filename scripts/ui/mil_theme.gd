class_name MilTheme
extends RefCounted
## One place for the whole game's look (v8 "Broken Arrow" restyle): dark olive-graphite panels with cut corners,
## thin hard lines and ONE warm orange accent, blue / red for the two sides, a condensed military font.
## Every UI root calls `MilTheme.theme()`; change colours here, or replace the panel images (see ba_skin.gd).

const BG := Color(0.066, 0.074, 0.070, 0.90)
const BG_SOLID := Color(0.060, 0.068, 0.064, 1.0)
const BG_DEEP := Color(0.040, 0.046, 0.044, 0.95)
const PANEL := Color(0.098, 0.110, 0.102, 0.94)
const PANEL_HI := Color(0.165, 0.180, 0.160, 0.97)
const LINE := Color(0.30, 0.33, 0.28, 0.80)
const LINE_HI := Color(0.56, 0.59, 0.46, 0.95)
const AMBER := Color(0.96, 0.60, 0.14)          # the single accent colour (name kept for the older screens)
const AMBER_DIM := Color(0.58, 0.36, 0.10)
const ACCENT := AMBER
const GOLD := Color(1.0, 0.82, 0.36)            # money
const TEXT := Color(0.91, 0.92, 0.87)
const DIM := Color(0.60, 0.63, 0.55)
const FRIEND := Color(0.30, 0.60, 0.95)
const ENEMY := Color(0.93, 0.30, 0.25)
const GOOD := Color(0.52, 0.84, 0.36)
const WARN := Color(1.0, 0.76, 0.28)
const BAD := Color(0.95, 0.33, 0.28)
const ACCENT_HEX := "#f5991f"
const CORNER := 8

const UI_FONTS := ["Bahnschrift", "Barlow Semi Condensed", "Rajdhani", "Roboto Condensed", "Oswald", "Segoe UI Semibold", "Segoe UI", "SF Pro Text", "Helvetica Neue", "Roboto", "Noto Sans", "DejaVu Sans", "Arial"]
const MONO_FONTS := ["Bahnschrift", "JetBrains Mono", "Cascadia Mono", "Consolas", "SF Mono", "Menlo", "DejaVu Sans Mono", "Liberation Mono", "Courier New"]

static var _theme: Theme = null
static var _font_ui: Font = null
static var _font_bold: Font = null
static var _font_mono: Font = null


## A font the player dropped into user://fonts/ (ui.ttf, bold.ttf, mono.ttf; .otf works too), or null.
static func _custom_font(nm: String) -> Font:
	for ext in ["ttf", "otf"]:
		var p := "user://fonts/%s.%s" % [nm, ext]
		if FileAccess.file_exists(p):
			var ff := FontFile.new()
			ff.data = FileAccess.get_file_as_bytes(p)
			return ff
	return null


## Forget the cached fonts and skins; screens opened afterwards use the new ones.
static func reload_fonts() -> void:
	_font_ui = null
	_font_bold = null
	_font_mono = null
	_theme = null
	BASkin.clear_cache()


static func font_ui() -> Font:
	if _font_ui == null:
		_font_ui = _custom_font("ui")
	if _font_ui == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(UI_FONTS)
		_font_ui = f
	return _font_ui


static func font_bold() -> Font:
	if _font_bold == null:
		_font_bold = _custom_font("bold")
	if _font_bold == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(UI_FONTS)
		f.font_weight = 700
		_font_bold = f
	return _font_bold


static func font_mono() -> Font:
	if _font_mono == null:
		_font_mono = _custom_font("mono")
	if _font_mono == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(MONO_FONTS)
		_font_mono = f
	return _font_mono


## Flat rectangle (bars, small chips). Corners stay nearly square.
static func flat(bg: Color, border: Color = Color(0, 0, 0, 0), bw: int = 0, mx: int = 0, my: int = 0, r: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(r)
	sb.content_margin_left = mx
	sb.content_margin_right = mx
	sb.content_margin_top = my
	sb.content_margin_bottom = my
	return sb


## Box with cut corners (the old `radius` now only decides how big the cut is). Small radii stay flat.
static func box(bg: Color, border: Color = Color(0, 0, 0, 0), bw: int = 0, mx: int = 0, my: int = 0, r: int = CORNER) -> StyleBox:
	if r < 6:
		return flat(bg, border, bw, mx, my, r)
	return BASkin.style(bg, border, Color(0, 0, 0, 0), clampi(int(float(r) * 0.55), 3, 7), bw, mx, my, "")


## Floating panel: cut corners, a thin accent line along the top edge.
static func glass(bg: Color = BG, border: Color = LINE, r: int = 12, mx: int = 0, my: int = 0) -> StyleBox:
	return BASkin.style(bg, border, Color(AMBER, 0.85), clampi(int(float(r) * 0.7), 5, 9), 1, mx, my, "ui_panel")


## Panel without the accent line (lists, inset areas).
static func inset(bg: Color = BG_DEEP, border: Color = LINE, mx: int = 0, my: int = 0) -> StyleBox:
	return BASkin.style(bg, border, Color(0, 0, 0, 0), 6, 1, mx, my, "ui_panel_dark")


## Box whose only visible border is one edge.
static func edge_box(bg: Color, border: Color, side: int, bw: int, mx: int = 0, my: int = 0) -> StyleBoxFlat:
	var sb := flat(bg, Color(0, 0, 0, 0), 0, mx, my, 0)
	sb.border_color = border
	match side:
		SIDE_TOP: sb.border_width_top = bw
		SIDE_BOTTOM: sb.border_width_bottom = bw
		SIDE_LEFT: sb.border_width_left = bw
		SIDE_RIGHT: sb.border_width_right = bw
	return sb


static func _button_styles(t: Theme, type_name: String) -> void:
	t.set_stylebox("normal", type_name, BASkin.style(PANEL, LINE, Color(0, 0, 0, 0), 6, 1, 14, 7, "ui_button"))
	t.set_stylebox("hover", type_name, BASkin.style(PANEL_HI, AMBER, Color(0, 0, 0, 0), 6, 1, 14, 7, "ui_button_hover"))
	t.set_stylebox("pressed", type_name, BASkin.style(Color(AMBER, 0.95), AMBER, Color(0, 0, 0, 0), 6, 1, 14, 7, "ui_button_pressed"))
	t.set_stylebox("hover_pressed", type_name, BASkin.style(AMBER.lightened(0.14), AMBER, Color(0, 0, 0, 0), 6, 1, 14, 7, "ui_button_pressed"))
	t.set_stylebox("disabled", type_name, BASkin.style(Color(0.06, 0.065, 0.06, 0.75), Color(0.2, 0.22, 0.19, 0.6), Color(0, 0, 0, 0), 6, 1, 14, 7, "ui_button"))
	t.set_stylebox("focus", type_name, StyleBoxEmpty.new())
	t.set_color("font_color", type_name, TEXT)
	t.set_color("font_hover_color", type_name, Color.WHITE)
	t.set_color("font_pressed_color", type_name, BG_SOLID)
	t.set_color("font_hover_pressed_color", type_name, BG_SOLID)
	t.set_color("font_focus_color", type_name, TEXT)
	t.set_color("font_disabled_color", type_name, Color(0.38, 0.40, 0.35))


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font_ui()
	t.default_font_size = 14

	t.set_color("font_color", "Label", TEXT)

	_button_styles(t, "Button")
	_button_styles(t, "OptionButton")
	t.set_color("font_color", "OptionButton", TEXT)

	t.set_stylebox("panel", "Panel", glass(PANEL, LINE, 12))
	t.set_stylebox("panel", "PanelContainer", glass(PANEL, LINE, 12, 14, 12))

	t.set_stylebox("background", "ProgressBar", flat(Color(0, 0, 0, 0.55), Color(0, 0, 0, 0), 0, 0, 0, 1))
	t.set_stylebox("fill", "ProgressBar", flat(AMBER, Color(0, 0, 0, 0), 0, 0, 0, 1))

	var sep := StyleBoxLine.new()
	sep.color = LINE
	sep.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_constant("separation", "HSeparator", 8)

	# ItemList (arsenal)
	t.set_stylebox("panel", "ItemList", inset(BG_DEEP, LINE, 6, 6))
	t.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	t.set_stylebox("selected", "ItemList", flat(Color(AMBER, 0.24), AMBER_DIM, 1, 0, 0, 0))
	t.set_stylebox("selected_focus", "ItemList", flat(Color(AMBER, 0.30), AMBER, 1, 0, 0, 0))
	t.set_stylebox("hovered", "ItemList", flat(Color(1, 1, 1, 0.07), Color(0, 0, 0, 0), 0, 0, 0, 0))
	t.set_stylebox("hovered_selected", "ItemList", flat(Color(AMBER, 0.36), AMBER, 1, 0, 0, 0))
	t.set_stylebox("hovered_selected_focus", "ItemList", flat(Color(AMBER, 0.36), AMBER, 1, 0, 0, 0))
	t.set_color("font_color", "ItemList", TEXT)
	t.set_color("font_hovered_color", "ItemList", Color.WHITE)
	t.set_color("font_selected_color", "ItemList", Color.WHITE)
	t.set_constant("v_separation", "ItemList", 4)

	# Popup (option dropdown)
	t.set_stylebox("panel", "PopupMenu", flat(BG_DEEP, AMBER_DIM, 1, 6, 6, 0))
	t.set_stylebox("hover", "PopupMenu", flat(Color(AMBER, 0.26), Color(0, 0, 0, 0), 0, 0, 0, 0))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)

	# Rich text + scrollbars
	t.set_color("default_color", "RichTextLabel", TEXT)
	for sb_type in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", sb_type, flat(Color(0, 0, 0, 0.30), Color(0, 0, 0, 0), 0, 0, 0, 0))
		t.set_stylebox("grabber", sb_type, flat(Color(LINE_HI, 0.55), Color(0, 0, 0, 0), 0, 0, 0, 0))
		t.set_stylebox("grabber_highlight", sb_type, flat(AMBER_DIM, Color(0, 0, 0, 0), 0, 0, 0, 0))
		t.set_stylebox("grabber_pressed", sb_type, flat(AMBER, Color(0, 0, 0, 0), 0, 0, 0, 0))

	_theme = t
	return _theme


## Dock tab: flat, dim text, bright accent underline when selected.
static func style_tab(b: Button) -> void:
	var none := Color(0, 0, 0, 0)
	b.add_theme_stylebox_override("normal", flat(none, none, 0, 10, 5, 0))
	b.add_theme_stylebox_override("hover", flat(Color(1, 1, 1, 0.07), none, 0, 10, 5, 0))
	var on := flat(Color(AMBER, 0.14), none, 0, 10, 5, 0)
	on.border_color = AMBER
	on.border_width_bottom = 3
	b.add_theme_stylebox_override("pressed", on)
	var on_hi := flat(Color(AMBER, 0.22), none, 0, 10, 5, 0)
	on_hi.border_color = AMBER
	on_hi.border_width_bottom = 3
	b.add_theme_stylebox_override("hover_pressed", on_hi)
	b.add_theme_color_override("font_color", DIM)
	b.add_theme_color_override("font_hover_color", TEXT)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_hover_pressed_color", Color.WHITE)


## Wide menu button: dark slab with an orange bar on the left when hovered / selected.
static func style_menu(b: Button) -> void:
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var n := flat(Color(0.07, 0.078, 0.072, 0.82), Color(LINE, 0.7), 1, 22, 9, 0)
	b.add_theme_stylebox_override("normal", n)
	var h := flat(Color(AMBER, 0.14), AMBER_DIM, 1, 22, 9, 0)
	h.border_color = AMBER
	h.border_width_left = 5
	b.add_theme_stylebox_override("hover", h)
	var p := flat(Color(AMBER, 0.92), AMBER, 1, 22, 9, 0)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("hover_pressed", p)
	b.add_theme_stylebox_override("disabled", flat(Color(0.05, 0.055, 0.05, 0.6), Color(LINE, 0.25), 1, 22, 9, 0))
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_pressed_color", BG_SOLID)
	b.add_theme_color_override("font_hover_pressed_color", BG_SOLID)


## Small all-caps caption (section headers, readout captions).
static func caption(text: String, pos: Vector2, size: Vector2, col: Color = DIM, fs: int = 11) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.position = pos
	l.size = size
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func readout(text: String, pos: Vector2, size: Vector2, col: Color = TEXT, fs: int = 22) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = size
	l.add_theme_font_override("font", font_mono())
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Selection frame: four L-shaped corner brackets (no full outline).
static func draw_brackets(ci: CanvasItem, rect: Rect2, col: Color, arm: float = 10.0, w: float = 1.5) -> void:
	var a := minf(arm, minf(rect.size.x, rect.size.y) * 0.45)
	var tl := rect.position
	var br := rect.end
	var tr := Vector2(br.x, tl.y)
	var bl := Vector2(tl.x, br.y)
	ci.draw_polyline(PackedVector2Array([tl + Vector2(0, a), tl, tl + Vector2(a, 0)]), col, w)
	ci.draw_polyline(PackedVector2Array([tr + Vector2(-a, 0), tr, tr + Vector2(0, a)]), col, w)
	ci.draw_polyline(PackedVector2Array([br + Vector2(0, -a), br, br + Vector2(-a, 0)]), col, w)
	ci.draw_polyline(PackedVector2Array([bl + Vector2(a, 0), bl, bl + Vector2(0, -a)]), col, w)


## Diagonal hazard stripes over a rect. The caller must set clip_contents = true on its Control.
static func draw_hazard(ci: CanvasItem, rect: Rect2, col_a: Color, col_b: Color, stripe: float = 10.0) -> void:
	ci.draw_rect(rect, col_b)
	var x := rect.position.x - rect.size.y
	while x < rect.end.x:
		var pts := PackedVector2Array([
			Vector2(x, rect.end.y), Vector2(x + stripe, rect.end.y),
			Vector2(x + stripe + rect.size.y, rect.position.y), Vector2(x + rect.size.y, rect.position.y)])
		ci.draw_colored_polygon(pts, col_a)
		x += stripe * 2.0
