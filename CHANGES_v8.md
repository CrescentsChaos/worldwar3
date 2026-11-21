# v8 changes (only these files are in this zip - copy over your project, same paths)
- UI: Broken Arrow style skin (scripts/ui/ba_skin.gd, mil_theme.gd, hud.gd, main_menu.gd, prematch.gd, unit_sheet.gd, asset_guide.gd)
- Units: no stacking (combatant.gd `_traffic`), group-move slots follow hull size (battle.gd `issue_order`)
- Ships: real heading / speed / turn radius; carrier turns slowly, accelerates and brakes over distance
- Rivers: bend between bridges (water.gd `_meander`), ribbon rendering with banks, bars, reeds, animated shimmer
- Maps: per-map "biome" in data/maps/*.json, new tile_lib.gd / terrain_layer.gd, per-map colour grade (screen_fx.gd)
- Assets: asset_catalog.gd, ASSET_GUIDE.md
