# WORLD WAR 3

A 2D real-time war game for **Godot 4.3+** (GDScript, GL Compatibility renderer).
You run a whole **country**: a capital plus cities, refineries, power plants, barracks, war factories,
an airbase, radar stations, missile silos, a tech center and fortresses - spread over a scrolling 3200 px map.
Field armies, aircraft and defenses, fire missiles and **nukes**, build **interceptors**, and destroy the enemy
capital to win. Wrecking the enemy's infrastructure cripples their economy and what they can build.

## Run it
1. Open Godot 4.3 or newer -> **Import** -> select `project.godot` -> **Run** (F5).
2. First open imports the PNGs; nothing else to set up.
3. Old (v1) save files are not compatible with the bigger map.

## Controls
| Input | Action |
|---|---|
| `W A S D` / arrows (hold `Shift` = fast) | Move the camera |
| Mouse wheel | Zoom (battlefield) / scroll the card strip when over the cards |
| Middle-mouse drag | Pan |
| Click / drag the **minimap** (bottom right) | Jump the camera |
| `Home` / `End` | Jump to your / the enemy capital |
| Click a card (or `1-9`) | Select; `Q` / `E` switch tabs; `<` `>` scroll the card strip |
| Left-click battlefield | Deploy (inside the blue zone) or target a missile |
| Right-click / `Esc` | Cancel selection / pause + save menu |
| `F5` / `F9` | Quick-save / quick-load (slot 1) |
| `F10` | Reload sprites while running |
| `1x 2x 3x` | Game speed |

## Your country
Both sides start with the same layout (the enemy's is rotated 180 degrees). Every building has a role:

| Building | Effect |
|---|---|
| **Capital** | Lose it and you lose the game. Shoots back, +2 income. |
| **Metropolis / Town** | Income (+4 / +1.5 per second). |
| **Oil Refinery** | +3 income. Explodes when destroyed (hurts neighbours!). |
| **Power Plant** | Powers SAM sites, interceptors, ABMs, railguns, CIWS and repair depots. No power = they go offline. |
| **Barracks** | Unlocks elite infantry (sniper, flamer, grenadier, MG, medic, engineer); trains free troops. |
| **War Factory** | Unlocks heavy vehicles (APC, heavy tank, tank destroyer, flame tank, artillery, MLRS, SAM, repair); builds free light vehicles. |
| **Airbase** | **Required for every aircraft.** Scrambles free drones and fighters. |
| **Radar Station** | +30% range for SAMs / interceptors / ABMs; required by the Heavy Howitzer. |
| **Missile Silo** | Required for ballistic / hypersonic missiles and every nuke. Missiles launch from your silos. |
| **Tech Center** | Unlocks stealth aircraft, Mammoth tank, Commandos, Railgun, ABM, Hypersonic, Doomsday Device. |
| **Fortress** | Huge, heavily armored stronghold with a heavy cannon. |

Lost something? The **Infrastructure** tab lets you rebuild (with per-type limits), and the AI does the same.
Idle units march on the nearest enemy building, so where you deploy decides which part of the enemy country you attack.

## Units (37), defenses (14), missiles (9)
* **Infantry:** Rifleman, Assault Trooper, Bazooka, AA Trooper, Machine Gunner, Grenadier, Sniper, Flamethrower,
  Medic (heals), Engineer (repairs), Special Forces.
* **Vehicles:** Jeep, Armored Car, APC (unloads troops), Light Tank, Battle Tank, Heavy Tank, Mammoth Tank,
  Tank Destroyer, Flame Tank, Artillery, Heavy Howitzer, Rocket Launcher, Mobile AA, SAM Launcher, Repair Vehicle.
* **Air:** Kamikaze Drone, Fighter, Air Superiority Jet, Stealth Fighter, Strike Jet, Attack Helicopter, Heavy Gunship,
  Light Bomber, Bomber, Strategic Bomber, Stealth Bomber. Stealth aircraft are only spotted at close range.
* **Defenses:** MG Turret, Pillbox, Anti-Tank Gun, Cannon Bunker, Mortar Pit, Flak Battery, SAM Site, Heavy Battery,
  Railgun, CIWS (shoots missiles too), Missile Interceptor, ABM Battery, Barricade, Repair Depot.
* **Missiles:** Tactical, Cruise, Cluster, Bunker Buster (x2.6 vs buildings), Ballistic, Hypersonic,
  Tactical Nuke, Nuclear Missile, Doomsday Device. Interceptors fire at every missile in range.

Damage has **bonuses by target class** (infantry / vehicle / armor / air / structure), **armor piercing** and
**target preferences** - snipers and flamers hunt infantry, tank destroyers hunt armor, bunker busters hunt buildings.
Armor reduces every hit. The card info panel shows the numbers.

## Saving
Pause menu (`Esc`): 3 manual slots; autosave every 60 s. Files: `user://saves/*.json`.

## Replacing sprites (no code needed)
Every image goes through `scripts/autoload/sprite_lib.gd`, which looks for `<id>.png`:
1. `user://sprites/<id>.png` - drop-in folder (main menu -> *Open sprites folder*)
2. `res://assets/sprites/<id>.png` - bundled placeholder art
3. a generated placeholder shape

Rules: top-down, art **facing right (east)**, any resolution (scaled to the `size` in `data/units.json`),
transparent PNG. Team tint: set `team_tint` to `0` for full-colour art. `F10` reloads. Optional `background.png`
(3200x880) replaces the procedural terrain. The sprite id of every item is its key in `units.json`
(projectiles use the names in the `projectiles` block, e.g. `proj_flame.png`).

## Changing / adding things (no code needed)
Everything lives in `data/units.json`: `units`, `structures` (defenses), `national` (country buildings),
`strategic` (missiles), `projectiles`, `country` (the layout), `settings` (money, income, zones, caps, AI).
Copy an entry, give it a new key and a `tab`, drop `<key>.png` in the sprites folder - it appears automatically.
Handy fields: `requires` (a capability such as `"factory"`, or a list), `vs` (damage multipliers),
`pierce`, `prefer`, `stealth`, `kamikaze`, `cargo`, `heal`, `spawns`, `needs_power`, `radar_boost`, `income`, `provides`.
A modified copy placed at `user://units.json` overrides the bundled file.

## Project layout
```
data/units.json            all balance + unit / building definitions + country layout
scripts/battle.gd          map, camera, deployment, country, capabilities, explosions, save/load
scripts/combatant.gd       units, defenses, country buildings, capital (targeting, movement, healing, production)
scripts/missile.gd         missiles / nukes in flight (interceptable)
scripts/projectile.gd      bullets, shells, rockets, bombs, flames, rails...
scripts/ai_commander.gd    enemy AI (counter-picks units, rebuilds infrastructure, strikes, builds shields)
scripts/hud.gd, minimap.gd all UI (built in code)
scripts/autoload/          GameData, SpriteLib, SaveManager, Sfx
tools/                     sprite generator (Pillow) + headless tests
```

## Dev tools
```
python3 tools/generate_placeholder_sprites.py                       # regenerate placeholder art (Pillow)
godot --headless --path . --fixed-fps 60 res://tools/selftest.tscn  # smoke test (~100 s of game time)
godot --headless --path . --fixed-fps 60 res://tools/soak.tscn      # 8-minute random-play soak test
```
