# Map tiles - drop your terrain art here

Put images in this folder (`assets/tiles/`) and the map uses them automatically. Missing tiles keep the
built-in look, so you can replace them one at a time.
(Quick testing without re-exporting: use the game's `user://tiles/` folder, *Project > Open User Data Folder*.)
Formats: `.png`, `.webp`, `.jpg`.

| File name | Used for | Notes |
|---|---|---|
| `ground.png` | all the land | **Seamless / tileable** texture, repeats across the map |
| `water_deep.png` | open sea | seamless, repeats |
| `water_shallow.png` | the shallow band along the coast | seamless, repeats |
| `river.png` | the central river and the streams | seamless, repeats along each river piece |
| `road.png` | roads | seamless; repeats along the road |
| `bridge.png` | the bridges over the river | one image stretched over the bridge (108 x 44) |
| `crater.png` | shell craters in no-man's land | one image per crater (transparent background) |
| `tree.png` | forest trees | one image per tree (transparent background) |
| `background.png` | *(optional, goes in `assets/sprites/`)* one big picture of the whole land strip | replaces ground / roads / craters / trees |

The animated sparkles on the water are still drawn on top of your water tiles.

## tiles.json (optional)
`{ "ground": { "scale": 2.0 } }` makes one repeat of the ground tile twice as big (default 1.0).
Works for `ground`, `water_deep`, `water_shallow`, `river`.
