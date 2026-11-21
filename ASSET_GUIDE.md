# WW3 - Asset replacement guide

Everything visual, audible or typographic can be replaced **without touching code**. Drop a file in the right folder,
then press **F10** in a battle (or reopen the menu). In-game: **Main menu / Pause > ASSET GUIDE** and **ASSET MANAGER**
(lists every id with status CUSTOM / BUNDLED / PLACEHOLDER, has REPLACE / RESET buttons and an EXPORT CHECKLIST csv).

Your user folder (the buttons in the guide open it):
- Windows `%APPDATA%\Godot\app_userdata\<project name>\`
- Linux `~/.local/share/godot/app_userdata/<project name>/`
- macOS `~/Library/Application Support/Godot/app_userdata/<project name>/`

Lookup order for every image: `user://...` (yours) -> `res://assets/...` (bundled) -> generated placeholder.
So you can also ship art inside the project by using the `res://assets/` folders listed below.

## 1. Units, buildings, missiles  -  `user://sprites/<id>.png`
- Top-down, **facing RIGHT (east)**, transparent PNG, any size (it is scaled to the unit's `size`).
- `<id>` = the unit's `sprite` (or its key) in `data/units`, `data/structures`, `data/factions/*.json`
  (e.g. `tank`, `carrier`, `us_army_heavy_tank`). The Asset Manager > Sprites tab lists them all.
- Buildings that have a front: set `art_front` in the data file.

## 2. Interface skin (new)  -  `user://sprites/`
| file | what | notes |
|---|---|---|
| `ui_panel.png` | top bar, dock, selection card, menus | 9-slice |
| `ui_panel_dark.png` | list / inset backgrounds | 9-slice |
| `ui_button.png`, `ui_button_hover.png`, `ui_button_pressed.png` | every button | 9-slice |
| `ui_card.png`, `ui_card_selected.png` | unit cards in the dock | 9-slice |
| `ui_menu_bg.png` | main menu & briefing background | 1280 x 720 |
| `ui_logo.png` | title logo | transparent, any size |
| `ui_cursor.png` | mouse cursor | 32 x 32 |

**9-slice**: the picture is cut in a 3 x 3 grid. The four corners stay as drawn, edges and centre stretch. Draw corners
about **one third** of the image width (64 x 64 with 20 px corners is a good start). Without a file the game draws
its own cut-corner panels. Colours / sizes of the built-in look: `scripts/ui/mil_theme.gd`, `scripts/ui/ba_skin.gd`.

Fonts: `user://fonts/ui.ttf`, `bold.ttf`, `mono.ttf` (.otf works too).

## 3. Terrain  -  `user://tiles/`
Repeating tiles. Name = `<name>.png` (all maps) or `<map>_<name>.png` (one map only; the map file wins).
Maps: `dnieper`, `steppe`, `carpathian`, `delta` (and any new `data/maps/<id>.json`).

| name | used for |
|---|---|
| `ground` | the land (tileable!) |
| `water_shallow`, `water_deep` | sea near / far from the coast |
| `river` | river surface (replaces the drawn river) |
| `river_bank` | muddy banks along rivers |
| `road`, `bridge` | roads, bridges |
| `crater`, `rock`, `tree` | single decals (drawn centred, any size, transparent) |

Examples: `carpathian_ground.png` re-skins only the mountains; `delta_river.png` only the delta rivers.
Optional `tiles.json` in the same folder sets how large one repeat is drawn: `{"ground": {"scale": 2.0}}`.
Whole-battlefield picture instead of tiles: `user://sprites/background_<map>.png` (or `background.png`), 6400 x 1488.

## 4. Make a NEW look for a map without art - `data/maps/<id>.json` -> `"biome"`
`ground` colours (`a`,`b`,`earth`,`mud`, optional `snow`+`snow_amount`, `puddle`+`puddle_amount`), `water` colours,
`tree_style` (`round` / `pine`), `decor` (`fields`, `marsh`, `snow`, `boulders` counts), `field_cols`, `macro` colour
patches, `rocks`, and `grade` (`sat`, `contrast`, `tint`, `vignette`, `grain`) which colour-grades the whole screen.
`"meander": 0..2` (top level) controls how much the rivers bend (0 = straight, bridges never move).

## 5. Sound, radio, effects
- `user://audio/<id>.ogg|mp3|wav` (ids: Asset Manager > Sound / Radio, e.g. `shot`, `fire_tank`, `radio_ack_move_1`)
- `user://vfx/<id>.png` or a folder of frames `user://vfx/<id>/0001.png ...`

## Tips
- PNG with transparency for everything except tiles/backgrounds. Keep tiles seamless.
- Asset Manager > EXPORT CHECKLIST writes `user://asset_checklist.csv` with every id and where to drop it.
- Remove a replacement = delete the file (or RESET in the manager).
