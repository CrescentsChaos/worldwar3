class_name MilTheme
extends RefCounted
## One place for the whole game's look: a dark, desaturated "command console" palette with a single
## amber accent, sharp corners, thin lines and a condensed industrial font. Every UI root calls
## `MilTheme.theme()` and assigns it to its top-level Control so buttons, lists, bars... all match.

const BG := Color(0.040, 0.047, 0.050, 0.93)
const BG_SOLID := Color(0.040, 0.047, 0.050, 1.0)
const BG_DEEP := Color(0.024, 0.028, 0.031, 0.96)
const PANEL := Color(0.070, 0.080, 0.084, 0.94)
const PANEL_HI := Color(0.105, 0.118, 0.122, 0.96)
const LINE := Color(0.235, 0.265, 0.258)
const LINE_HI := Color(0.42, 0.46, 0.43)
const AMBER := Color(1.0, 0.62, 0.10)
const AMBER_DIM := Color(0.62, 0.40, 0.09)
const TEXT := Color(0.88, 0.90, 0.87)
const DIM := Color(0.54, 0.58, 0.56)
const FRIEND := Color(0.36, 0.62, 0.88)
const ENEMY := Color(0.88, 0.30, 0.25)
const GOOD := Color(0.55, 0.85, 0.40)
const WARN := Color(1.0, 0.74, 0.20)
const BAD := Color(0.95, 0.30, 0.25)

const UI_FONTS := ["Bahnschrift", "Roboto Condensed", "Arial Narrow", "Segoe UI", "DejaVu Sans Condensed", "Helvetica Neue", "Arial"]
const MONO_FONTS := ["Consolas", "Cascadia Mono", "Menlo", "DejaVu Sans Mono", "Liberation Mono", "Courier New"]

static var _theme: Theme = null
static var _font_ui: Font = null
static var _font_bold: Font = null
static var _font_mono: Font = null


static func font_ui() -> Font:
	if _font_ui == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(UI_FONTS)
		_font_ui = f
	return _font_ui


static func font_bold() -> Font:
	if _font_bold == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(UI_FONTS)
		f.font_weight = 700
		_font_bold = f
	return _font_bold


static func font_mono() -> Font:
	if _font_mono == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(MONO_FONTS)
		_font_mono = f
	return _font_mono


## Flat, sharp-cornered box. `mx` / `my` are the content margins.
static func box(bg: Color, border: Color = Color(0, 0, 0, 0), bw: int = 0, mx: int = 0, my: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(0)
	sb.anti_aliasing = false
	sb.content_margin_left = mx
	sb.content_margin_right = mx
	sb.content_margin_top = my
	sb.content_margin_bottom = my
	return sb


## Box whose only visible border is one edge (used for tabs and the HUD bars).
static func edge_box(bg: Color, border: Color, side: int, bw: int, mx: int = 0, my: int = 0) -> StyleBoxFlat:
	var sb := box(bg, border, 0, mx, my)
	match side:
		SIDE_TOP: sb.border_width_top = bw
		SIDE_BOTTOM: sb.border_width_bottom = bw
		SIDE_LEFT: sb.border_width_left = bw
		SIDE_RIGHT: sb.border_width_right = bw
	return sb


static func _button_styles(t: Theme, type_name: String) -> void:
	t.set_stylebox("normal", type_name, box(PANEL, LINE, 1, 12, 6))
	t.set_stylebox("hover", type_name, box(PANEL_HI, AMBER_DIM, 1, 12, 6))
	t.set_stylebox("pressed", type_name, box(AMBER, AMBER, 1, 12, 6))
	t.set_stylebox("hover_pressed", type_name, box(AMBER.lightened(0.12), AMBER, 1, 12, 6))
	t.set_stylebox("disabled", type_name, box(Color(0.05, 0.055, 0.058, 0.8), Color(0.15, 0.17, 0.16), 1, 12, 6))
	t.set_stylebox("focus", type_name, StyleBoxEmpty.new())
	t.set_color("font_color", type_name, TEXT)
	t.set_color("font_hover_color", type_name, Color.WHITE)
	t.set_color("font_pressed_color", type_name, BG_SOLID)
	t.set_color("font_hover_pressed_color", type_name, BG_SOLID)
	t.set_color("font_focus_color", type_name, TEXT)
	t.set_color("font_disabled_color", type_name, Color(0.3, 0.33, 0.32))


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

	t.set_stylebox("panel", "Panel", box(PANEL, LINE, 1))
	t.set_stylebox("panel", "PanelContainer", box(PANEL, LINE, 1, 10, 8))

	t.set_stylebox("background", "ProgressBar", box(Color(0, 0, 0, 0.6), LINE, 1))
	t.set_stylebox("fill", "ProgressBar", box(AMBER, Color(0, 0, 0, 0), 0))

	var sep := StyleBoxLine.new()
	sep.color = LINE
	sep.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_constant("separation", "HSeparator", 8)

	# ItemList (arsenal)
	t.set_stylebox("panel", "ItemList", box(BG_DEEP, LINE, 1, 4, 4))
	t.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	t.set_stylebox("selected", "ItemList", box(Color(0.62, 0.40, 0.09, 0.55), AMBER_DIM, 1))
	t.set_stylebox("selected_focus", "ItemList", box(Color(0.62, 0.40, 0.09, 0.55), AMBER, 1))
	t.set_stylebox("hovered", "ItemList", box(Color(1, 1, 1, 0.06)))
	t.set_stylebox("hovered_selected", "ItemList", box(Color(0.62, 0.40, 0.09, 0.65), AMBER, 1))
	t.set_stylebox("hovered_selected_focus", "ItemList", box(Color(0.62, 0.40, 0.09, 0.65), AMBER, 1))
	t.set_color("font_color", "ItemList", TEXT)
	t.set_color("font_hovered_color", "ItemList", Color.WHITE)
	t.set_color("font_selected_color", "ItemList", Color.WHITE)
	t.set_constant("v_separation", "ItemList", 4)

	# Popup (option dropdown)
	t.set_stylebox("panel", "PopupMenu", box(BG_DEEP, AMBER_DIM, 1, 4, 4))
	t.set_stylebox("hover", "PopupMenu", box(Color(0.62, 0.40, 0.09, 0.55)))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)

	# Rich text + scrollbars
	t.set_color("default_color", "RichTextLabel", TEXT)
	for sb_type in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", sb_type, box(Color(0, 0, 0, 0.35)))
		t.set_stylebox("grabber", sb_type, box(LINE_HI.darkened(0.2)))
		t.set_stylebox("grabber_highlight", sb_type, box(AMBER_DIM))
		t.set_stylebox("grabber_pressed", sb_type, box(AMBER))

	_theme = t
	return _theme


## Tab-strip button look: flat, dim text, amber underline when toggled on.
static func style_tab(b: Button) -> void:
	b.add_theme_stylebox_override("normal", edge_box(Color(0, 0, 0, 0.0), Color(0, 0, 0, 0), SIDE_BOTTOM, 3, 10, 5))
	b.add_theme_stylebox_override("hover", edge_box(Color(1, 1, 1, 0.05), LINE_HI, SIDE_BOTTOM, 3, 10, 5))
	b.add_theme_stylebox_override("pressed", edge_box(Color(1, 0.62, 0.1, 0.10), AMBER, SIDE_BOTTOM, 3, 10, 5))
	b.add_theme_stylebox_override("hover_pressed", edge_box(Color(1, 0.62, 0.1, 0.16), AMBER, SIDE_BOTTOM, 3, 10, 5))
	b.add_theme_color_override("font_color", DIM)
	b.add_theme_color_override("font_hover_color", TEXT)
	b.add_theme_color_override("font_pressed_color", AMBER)
	b.add_theme_color_override("font_hover_pressed_color", AMBER)


## Wide menu-strip button: dark glass with a hard amber bar on the left when hovered / selected.
static func style_menu(b: Button) -> void:
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_stylebox_override("normal", edge_box(Color(0.05, 0.058, 0.06, 0.78), Color(0.3, 0.33, 0.32), SIDE_LEFT, 3, 16, 8))
	b.add_theme_stylebox_override("hover", edge_box(Color(0.16, 0.11, 0.04, 0.92), AMBER, SIDE_LEFT, 6, 16, 8))
	b.add_theme_stylebox_override("pressed", edge_box(AMBER, AMBER, SIDE_LEFT, 6, 16, 8))
	b.add_theme_stylebox_override("hover_pressed", edge_box(AMBER, AMBER, SIDE_LEFT, 6, 16, 8))
	b.add_theme_stylebox_override("disabled", edge_box(Color(0.04, 0.045, 0.047, 0.6), Color(0.14, 0.16, 0.15), SIDE_LEFT, 3, 16, 8))
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


## Draws L-shaped corner brackets (the "targeting frame" look) on any CanvasItem.
static func draw_brackets(ci: CanvasItem, rect: Rect2, col: Color, arm: float = 10.0, w: float = 1.5) -> void:
	var tl := rect.position
	var tr := Vector2(rect.end.x, rect.position.y)
	var bl := Vector2(rect.position.x, rect.end.y)
	var br := rect.end
	ci.draw_line(tl, tl + Vector2(arm, 0), col, w)
	ci.draw_line(tl, tl + Vector2(0, arm), col, w)
	ci.draw_line(tr, tr + Vector2(-arm, 0), col, w)
	ci.draw_line(tr, tr + Vector2(0, arm), col, w)
	ci.draw_line(bl, bl + Vector2(arm, 0), col, w)
	ci.draw_line(bl, bl + Vector2(0, -arm), col, w)
	ci.draw_line(br, br + Vector2(-arm, 0), col, w)
	ci.draw_line(br, br + Vector2(0, -arm), col, w)


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
