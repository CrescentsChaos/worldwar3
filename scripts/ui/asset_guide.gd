class_name AssetGuide
extends Control
## In-game "how do I replace X?" guide (the long version is ASSET_GUIDE.md in the project root).
## Opens from the main menu and from the pause menu.

const GUIDE := """[b][color=#f5991f]WHERE FILES GO[/color][/b]
Drop files into the game's user folder (buttons below open it). No export or code needed - press [b]F10[/b] in a battle, or reopen the screen, to reload.

[b][color=#f5991f]UNITS, BUILDINGS, MISSILES[/color][/b]
  user://sprites/<sprite id>.png   - top-down, facing RIGHT (east), transparent PNG, any size.
  The id is the unit's key in data/units, data/factions or data/structures (e.g. [b]tank[/b], [b]us_army_heavy_tank[/b]).
  Asset Manager > Sprites lists every id.

[b][color=#f5991f]INTERFACE SKIN (v8)[/color][/b]
  user://sprites/ui_panel.png, ui_panel_dark.png     - panels (9-slice: corners = 1/3 of the picture)
  user://sprites/ui_button.png, ui_button_hover.png, ui_button_pressed.png
  user://sprites/ui_card.png, ui_card_selected.png   - unit cards
  user://sprites/ui_menu_bg.png                      - main menu / briefing background (1280 x 720)
  user://sprites/ui_logo.png                         - title logo (any size, transparent)
  user://sprites/ui_cursor.png                       - mouse cursor
  user://fonts/ui.ttf, bold.ttf, mono.ttf            - fonts

[b][color=#f5991f]TERRAIN[/color][/b]
  user://tiles/<name>.png  for every map, or  user://tiles/<map>_<name>.png  for ONE map only.
  Names: ground, ground_dirt, ground_alt, water_deep, water_shallow, river, river_bank, road, bridge, crater, tree, rock.
  Maps: dnieper, steppe, carpathian, delta.   Example: [b]carpathian_ground.png[/b] only changes the Carpathian Gorge.
  Whole-map picture: user://sprites/background_<map>.png (6400 x 1488) or background.png for all maps.

[b][color=#f5991f]SOUND, RADIO, EFFECTS[/color][/b]
  user://audio/<id>.ogg|wav|mp3   user://vfx/<id>.png   (ids: Asset Manager)

Use [b]Asset Manager > EXPORT CHECKLIST[/b] to get a CSV of every id and whether it is custom, bundled or placeholder."""

var _rich: RichTextLabel


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	theme = MilTheme.theme()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var panel := Panel.new()
	panel.position = Vector2(190, 50)
	panel.size = Vector2(900, 620)
	panel.add_theme_stylebox_override("panel", MilTheme.glass(MilTheme.BG_SOLID, MilTheme.LINE_HI, 12))
	add_child(panel)
	var title := MilTheme.caption("Asset guide  -  replace any picture, sound or font", Vector2(24, 16), Vector2(840, 24), MilTheme.AMBER, 15)
	panel.add_child(title)
	_rich = RichTextLabel.new()
	_rich.bbcode_enabled = true
	_rich.position = Vector2(24, 52)
	_rich.size = Vector2(852, 480)
	_rich.add_theme_font_size_override("normal_font_size", 14)
	_rich.add_theme_font_size_override("bold_font_size", 14)
	_rich.text = GUIDE
	panel.add_child(_rich)
	var folders := [["Sprites + UI", "user://sprites/"], ["Tiles", "user://tiles/"], ["Audio", "user://audio/"], ["Fonts", "user://fonts/"], ["Effects", "user://vfx/"]]
	var x := 24.0
	for f in folders:
		var path: String = f[1]
		var b := Button.new()
		b.text = "Open " + str(f[0])
		b.position = Vector2(x, 540)
		b.size = Vector2(158, 32)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): _open(path))
		panel.add_child(b)
		x += 166.0
	var close := Button.new()
	close.text = "CLOSE"
	close.position = Vector2(760, 576)
	close.size = Vector2(116, 34)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(queue_free)
	panel.add_child(close)


func _open(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path)
	OS.shell_open(ProjectSettings.globalize_path(path))
