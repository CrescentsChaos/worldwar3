# Audio - drop your sounds here

Put sound files in this folder (`assets/audio/`) and the game uses them automatically. No code changes.
The file **name** decides when it plays. Formats: `.ogg` (best), `.wav`, `.mp3`.

* Godot imports files in `res://assets/audio/` the next time you open the project.
* Want to test without re-exporting? Put `.ogg` / `.mp3` files in the game's `user://audio/` folder instead
  (it is created on first run; in Godot use *Project > Open User Data Folder*). `user://` wins over `res://`.
* If a file is missing the game plays its built-in beep/noise, so you can add sounds one at a time.
* Loudness: edit the file's volume. Each play gets a tiny random pitch change so repeats don't sound robotic.

## Sound names (most specific name wins)

| File name | Plays when |
|---|---|
| `fire_<unit_id>` | that unit/structure fires, e.g. `fire_tank`, `fire_battleship`, `fire_ciws` |
| `shot_<projectile>` | any weapon using that projectile fires. Projectiles: `atgm`, `big_bomb`, `bomb`, `bullet`, `depth_charge`, `flak`, `flame`, `grenade`, `heavy_shell`, `interceptor`, `mortar`, `rail`, `rocket`, `shell`, `sniper`, `torpedo` |
| `explosion_small` / `explosion_medium` / `explosion_large` | blasts by size (falls back to the built-in `boom`) |
| `explosion_nuke` | nuclear blast |
| `die_<id>` | that unit/building is destroyed, e.g. `die_tank`, `die_barracks` |
| `die_unit`, `die_building`, `die_base` | generic destruction sounds (used when there is no `die_<id>`) |
| `deploy_<id>` / `deploy` | you place a unit or building |
| `launch_<id>` / `launch` | a strategic missile is launched, e.g. `launch_nuke` |
| `intercept` | a missile is shot down |
| `alarm` | incoming-missile warning |
| `click` | UI click |
| `music_menu` | main-menu music (loops) |
| `music_battle` | battle music (loops) |
| `ambient_battle` | quiet background ambience during battle (loops, e.g. wind / sea) |

## All ids you can use for `<id>`
`aa_truck, aircraft_carrier, apc, armored_car, artillery, assault, battleship, bazooka, bomber, commando, cruiser, destroyer, diver, drone, engineer, fighter, flame_tank, flamer, grenadier, gunboat, gunship, heavy_bomber, heavy_tank, helicopter, howitzer, interceptor_jet, jeep, light_bomber, light_tank, mammoth, manpads, medic, mg_gunner, missile_boat, mlrs, patrol_boat, repair_vehicle, rifleman, sam_truck, sniper, stealth_bomber, stealth_fighter, strike_jet, submarine, tank, tank_destroyer, abm_battery, at_gun, barricade, cannon_turret, ciws, coastal_battery, flak_battery, heavy_battery, interceptor_battery, mg_turret, mortar_pit, pillbox, railgun, repair_depot, sam_site, airbase, barracks, factory, fortress, metropolis, missile_silo, naval_port, oil_refinery, power_plant, radar_station, tech_center, town, ballistic_missile, bunker_buster, cluster_missile, cruise_missile, hypersonic, mega_nuke, nuke, tactical_missile, tactical_nuke`
