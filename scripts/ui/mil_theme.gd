class_name MilTheme
extends RefCounted
## One place for the whole game's look: a dark, desaturated "command console" palette with a single
## amber accent, sharp corners, thin lines and a condensed industrial font. Every UI root calls
## `MilTheme.theme()` and assigns it to its top-level Control so buttons, lists, bars... all match.

const BG := Color(0.050, 0.060, 0.080, 0.84)
const BG_SOLID := Color(0.045, 0.054, 0.072, 1.0)
const BG_DEEP := Color(0.032, 0.040, 0.056, 0.94)
const PANEL := Color(0.086, 0.102, 0.130, 0.90)
const PANEL_HI := Color(0.135, 0.158, 0.200, 0.95)
const LINE := Color(0.32, 0.38, 0.48, 0.55)
const LINE_HI := Color(0.50, 0.60, 0.74, 0.85)
const AMBER := Color(0.27, 0.78, 0.88)          # the single accent colour (kept under its old name for the older screens)
const AMBER_DIM := Color(0.14, 0.44, 0.52)
const ACCENT := AMBER
const GOLD := Color(1.0, 0.80, 0.30)            # money
const TEXT := Color(0.91, 0.93, 0.96)
const DIM := Color(0.58, 0.64, 0.72)
const FRIEND := Color(0.36, 0.62, 0.95)
const ENEMY := Color(0.95, 0.35, 0.32)
const GOOD := Color(0.42, 0.86, 0.55)
const WARN := Color(1.0, 0.76, 0.28)
const BAD := Color(0.97, 0.36, 0.33)
const ACCENT_HEX := "#45c7e0"
const CORNER := 8

const UI_FONTS := ["Inter", "Segoe UI Variable Text", "Segoe UI", "SF Pro Text", "Helvetica Neue", "Roboto", "Noto Sans", "DejaVu Sans", "Arial"]
const MONO_FONTS := ["JetBrains Mono", "Cascadia Mono", "Consolas", "SF Mono", "Menlo", "DejaVu Sans Mono", "Liberation Mono", "Courier New"]

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


## Forget the cached fonts; screens opened afterwards use the new ones.
static func reload_fonts() -> void:
	_font_ui = null
	_font_bold = null
	_font_mono = null


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


## Rounded flat box. `mx` / `my` are the content margins, `r` the corner radius.
static func box(bg: Color, border: Color = Color(0, 0, 0, 0), bw: int = 0, mx: int = 0, my: int = 0, r: int = CORNER) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(r)
	sb.anti_aliasing = true
	sb.anti_aliasing_size = 0.8
	sb.content_margin_left = mx
	sb.content_margin_right = mx
	sb.content_margin_top = my
	sb.content_margin_bottom = my
	return sb


## Floating "glass" panel: translucent, rounded, with a soft drop shadow.
static func glass(bg: Color = BG, border: Color = LINE, r: int = 12, mx: int = 0, my: int = 0) -> StyleBoxFlat:
	var sb := box(bg, border, 1, mx, my, r)
	sb.shadow_color = Color(0, 0, 0, 0.38)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 2)
	return sb


## Box whose only visible border is one edge (kept for older screens; now softly rounded).
static func edge_box(bg: Color, border: Color, side: int, bw: int, mx: int = 0, my: int = 0) -> StyleBoxFlat:
	var sb := box(bg, border, 0, mx, my, 6)
	match side:
		SIDE_TOP: sb.border_width_top = bw
		SIDE_BOTTOM: sb.border_width_bottom = bw
		SIDE_LEFT: sb.border_width_left = bw
		SIDE_RIGHT: sb.border_width_right = bw
	return sb


static func _button_styles(t: Theme, type_name: String) -> void:
	t.set_stylebox("normal", type_name, box(PANEL, LINE, 1, 14, 7, 7))
	t.set_stylebox("hover", type_name, box(PANEL_HI, AMBER, 1, 14, 7, 7))
	t.set_stylebox("pressed", type_name, box(Color(AMBER, 0.9), AMBER, 1, 14, 7, 7))
	t.set_stylebox("hover_pressed", type_name, box(AMBER.lightened(0.12), AMBER, 1, 14, 7, 7))
	t.set_stylebox("disabled", type_name, box(Color(0.06, 0.07, 0.09, 0.7), Color(0.2, 0.23, 0.28, 0.5), 1, 14, 7, 7))
	t.set_stylebox("focus", type_name, StyleBoxEmpty.new())
	t.set_color("font_color", type_name, TEXT)
	t.set_color("font_hover_color", type_name, Color.WHITE)
	t.set_color("font_pressed_color", type_name, BG_SOLID)
	t.set_color("font_hover_pressed_color", type_name, BG_SOLID)
	t.set_color("font_focus_color", type_name, TEXT)
	t.set_color("font_disabled_color", type_name, Color(0.38, 0.42, 0.48))


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

	t.set_stylebox("background", "ProgressBar", box(Color(0, 0, 0, 0.5), Color(0, 0, 0, 0), 0, 0, 0, 5))
	t.set_stylebox("fill", "ProgressBar", box(AMBER, Color(0, 0, 0, 0), 0, 0, 0, 5))

	var sep := StyleBoxLine.new()
	sep.color = LINE
	sep.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_constant("separation", "HSeparator", 8)

	# ItemList (arsenal)
	t.set_stylebox("panel", "ItemList", box(BG_DEEP, LINE, 1, 6, 6, 8))
	t.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	t.set_stylebox("selected", "ItemList", box(Color(AMBER, 0.28), AMBER_DIM, 1, 0, 0, 6))
	t.set_stylebox("selected_focus", "ItemList", box(Color(AMBER, 0.34), AMBER, 1, 0, 0, 6))
	t.set_stylebox("hovered", "ItemList", box(Color(1, 1, 1, 0.07), Color(0, 0, 0, 0), 0, 0, 0, 6))
	t.set_stylebox("hovered_selected", "ItemList", box(Color(AMBER, 0.40), AMBER, 1, 0, 0, 6))
	t.set_stylebox("hovered_selected_focus", "ItemList", box(Color(AMBER, 0.40), AMBER, 1, 0, 0, 6))
	t.set_color("font_color", "ItemList", TEXT)
	t.set_color("font_hovered_color", "ItemList", Color.WHITE)
	t.set_color("font_selected_color", "ItemList", Color.WHITE)
	t.set_constant("v_separation", "ItemList", 4)

	# Popup (option dropdown)
	t.set_stylebox("panel", "PopupMenu", box(BG_DEEP, AMBER_DIM, 1, 6, 6, 8))
	t.set_stylebox("hover", "PopupMenu", box(Color(AMBER, 0.28), Color(0, 0, 0, 0), 0, 0, 0, 5))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)

	# Rich text + scrollbars
	t.set_color("default_color", "RichTextLabel", TEXT)
	for sb_type in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", sb_type, box(Color(0, 0, 0, 0.25), Color(0, 0, 0, 0), 0, 0, 0, 4))
		t.set_stylebox("grabber", sb_type, box(Color(LINE_HI, 0.55), Color(0, 0, 0, 0), 0, 0, 0, 4))
		t.set_stylebox("grabber_highlight", sb_type, box(AMBER_DIM, Color(0, 0, 0, 0), 0, 0, 0, 4))
		t.set_stylebox("grabber_pressed", sb_type, box(AMBER, Color(0, 0, 0, 0), 0, 0, 0, 4))

	_theme = t
	return _theme


## Tab button: transparent pill, accent-tinted when toggled on.
static func style_tab(b: Button) -> void:
	b.add_theme_stylebox_override("normal", box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 10, 5, 14))
	b.add_theme_stylebox_override("hover", box(Color(1, 1, 1, 0.08), Color(0, 0, 0, 0), 0, 10, 5, 14))
	b.add_theme_stylebox_override("pressed", box(Color(AMBER, 0.22), Color(AMBER, 0.85), 1, 10, 5, 14))
	b.add_theme_stylebox_override("hover_pressed", box(Color(AMBER, 0.30), AMBER, 1, 10, 5, 14))
	b.add_theme_color_override("font_color", DIM)
	b.add_theme_color_override("font_hover_color", TEXT)
	b.add_theme_color_override("font_pressed_color", AMBER)
	b.add_theme_color_override("font_hover_pressed_color", AMBER)


## Wide menu button: glass pill with an accent edge when hovered / selected.
static func style_menu(b: Button) -> void:
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_stylebox_override("normal", box(Color(0.07, 0.085, 0.11, 0.78), Color(LINE, 0.6), 1, 20, 9, 10))
	b.add_theme_stylebox_override("hover", box(Color(AMBER, 0.16), AMBER, 1, 20, 9, 10))
	b.add_theme_stylebox_override("pressed", box(Color(AMBER, 0.9), AMBER, 1, 20, 9, 10))
	b.add_theme_stylebox_override("hover_pressed", box(Color(AMBER, 0.9), AMBER, 1, 20, 9, 10))
	b.add_theme_stylebox_override("disabled", box(Color(0.05, 0.06, 0.08, 0.55), Color(LINE, 0.25), 1, 20, 9, 10))
	b.add_theme_font_size_override("font_size", 17)


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


## Selection frame (the old "targeting brackets"): a soft rounded outline with brighter corner ticks.
static func draw_brackets(ci: CanvasItem, rect: Rect2, col: Color, arm: float = 10.0, w: float = 1.5) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Color(col, col.a * 0.55)
	sb.set_border_width_all(maxi(1, int(w)))
	sb.set_corner_radius_all(CORNER)
	sb.anti_aliasing = true
	ci.draw_style_box(sb, rect)


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
