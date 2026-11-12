# Visual effects - drop your VFX here

Put effects in this folder (`assets/vfx/`) and the game plays them automatically when the matching
event happens. If an effect is missing, the built-in procedural effect is used.
(Quick testing without re-exporting: use the game's `user://vfx/` folder, *Project > Open User Data Folder*.)

## Three ways to make an effect (the **name** is the event)
1. **Sprite sheet** - one PNG named `<name>_COLSxROWS.png`, e.g. `explosion_small_5x4.png` (5 columns, 4 rows,
   read left-to-right, top-to-bottom).
2. **Frame folder** - a folder `<name>/` with `0001.png`, `0002.png`, ... played in name order.
3. **Single image** - `<name>.png`; it grows slightly and fades out.

Effects are drawn centred on the spot. They are scaled to the size of the blast / unit; tweak with `scale` below.

## Event names
| Name | Plays when |
|---|---|
| `explosion_small`, `explosion_medium`, `explosion_large` | blasts by size |
| `explosion_nuke` | nuclear blast |
| `hit_spark` | a bullet or small shell hits |
| `water_splash` | a blast lands on water (plays in addition to the explosion) |
| `muzzle_flash` | something fires (also `muzzle_<unit_id>` for one unit type, e.g. `muzzle_tank`) |
| `death_<id>` | that unit/building dies (extra effect on top of the explosion), e.g. `death_battleship` |
| `deploy_dust` | you or the AI place a unit/building (also `deploy_<id>`) |

## vfx.json (optional settings)
Edit `vfx.json` in this folder (or in `user://vfx/`). Per effect:
`fps` (animation speed, default 24), `scale` (size multiplier), `additive` (true = glowing blend, great for fire),
`rotate` (true = turn to face the shot, for muzzle flashes), `duration` (seconds), `offset` ([x, y] pixels),
`z` (draw order, default 55), `frames` (use only the first N frames of a sheet).
