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

## Units (46), defenses (15), missiles (9)
Every item is a real-world system; the class (e.g. "Stealth bomber") is the first words of its info-panel text.
* **Infantry:** M4 Rifleman, SCAR-H Assault, Carl Gustaf Trooper (AT), Stinger AA Trooper, M240 Machine Gunner,
  M320 Grenadier, M82 Barrett Sniper, M2 Flamethrower, CLS Combat Medic, Combat Engineer, Delta Force SOF.
* **Vehicles:** HMMWV Humvee, LAV-25 Scout Car, M2 Bradley IFV, M10 Booker, M1A2 Abrams, Leopard 2A7, T-14 Armata,
  B1 Centauro TD, M132 Flame Tank, M109 Paladin, PzH 2000, M142 HIMARS, M1097 Avenger AA, Patriot PAC-3 SAM, M88 Hercules ARV.
* **Air:** Switchblade Drone, F-16 Fighting Falcon, F-15C Eagle, F-22 Raptor, F-15E Strike Eagle, AH-64E Apache,
  AC-130J Ghostrider, Su-34 Fullback, B-1B Lancer, B-52 Stratofortress, **B-2 Stealth Bomber**. Stealth aircraft are only spotted at close range.
* **Navy:** Navy SEAL Diver, Mk VI Patrol Boat, CB90 Assault Boat, Hamina Missile Boat, Arleigh Burke DDG, Ticonderoga Cruiser,
  USS Iowa Battleship, Virginia Class Sub, USS Nimitz Carrier.
* **Defenses:** M2 Browning Turret, Hardened Pillbox, TOW-2 AT Emplacement, M68 105mm Bunker, M252 Mortar Pit, Oerlikon Skynex Flak,
  NASAMS SAM Site, M777 155mm Battery, ONR EMRG Railgun, Mk 15 Phalanx CIWS, Iron Dome Battery, THAAD ABM Battery,
  Jersey Barrier, Field Repair Depot, NSM Coastal Battery.
* **Missiles:** M39 ATACMS, BGM-109 Tomahawk, Iskander-M Cluster, GBU-57 Bunker Buster (x2.6 vs buildings), Pershing II,
  Kh-47M2 Kinzhal, B61 Tactical Nuke, LGM-30 Minuteman III, RDS-220 Tsar Bomba. Interceptors fire at every missile in range.

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
scripts/ai_commander.gd    enemy AI v2 (saves for advanced units, layered defense, wave attacks, strikes, rebuilds)
scripts/hud.gd, minimap.gd all UI (built in code)
scripts/autoload/          GameData, SpriteLib, SaveManager, Sfx
tools/                     sprite generator (Pillow) + headless tests
```

## Dev tools
```
python3 tools/generate_placeholder_sprites.py                       # regenerate placeholder art (Pillow)
python3 tools/build_rosters.py                                      # rebuild every army's roster in data/units.json from tools/rosters/*.py
godot --headless --path . --fixed-fps 60 res://tools/selftest.tscn  # smoke test (~100 s of game time)
godot --headless --path . --fixed-fps 60 res://tools/soak.tscn      # 8-minute random-play soak test
```

## Rivers, sea and the Navy

**Map.** A sea runs along the north and south coasts (with a bay in the middle of each), a river
runs down the centre of the map with four streams joining it, and three bridges cross the river
(the middle one is on the main road). All water logic lives in `scripts/water.gd`; the terrain art,
minimap, movement and pathfinding all read from it.

- Streams (light blue): everyone can wade them, slowly.
- Central river (dark blue): infantry wade slowly, **vehicles must use a bridge** (they path to one automatically).
- Sea / bays: land units can't enter.
- The camera and the minimap now cover the sea too. Missiles can be aimed at ships.

**Navy tab** (needs a **Naval Port**; each country starts with two, one per coast; you can rebuild
one on the coast from the Infrastructure tab). Deploy ships in your own waters (shaded sea, your
half of the map).

| Unit | Notes |
|---|---|
| Combat Diver | Walks on land, swims submerged (hard to see, only sonar weapons hit it), mines ships/structures |
| Patrol Boat, River Gunboat | Shallow draft: sail streams, river and sea |
| Missile Boat, Destroyer | Need river or sea. Destroyer drops depth charges on submarines and divers |
| Cruiser, Battleship | Deep sea only. Long-range shore bombardment |
| Submarine | Submerged; torpedoes hit only things in the water; hit only by destroyers, helicopters, other subs |
| Aircraft Carrier | Launches free aircraft and counts as an Airbase for your build menu |

The Naval Port also launches free patrol boats / gunboats. The **Coastal Battery** (Defenses tab)
is a shore gun that only fires at things in the water. Helicopters now also drop depth charges.
The AI builds a port, a navy, and coastal batteries when you send ships.

Data: new keys in `data/units.json` - `domain` (land / water / sub / amphib), `draft`, `water_only`,
`coastal`, `provides`, `sub_proj` / `sub_damage` / `sub_splash`, `radius_k`, `swim_mult`.
Sprites: `tools/generate_naval_sprites.py` regenerates only the naval art (existing sprites are untouched).
Godot imports the new PNGs and the new `water.gd` the first time you open the project.

## Size, text, audio, VFX and map tiles

- **Size:** `data/units.json` > `settings`: `sprite_scale` (1.4 = everything is 40% bigger, including hit
  radius), `default_zoom` (1.0) and `zoom_max` (2.5). Raise `sprite_scale` if things still look small.
- **Text on top:** health bars and name labels are drawn by a separate node (z-index 100), so no sprite,
  aircraft or explosion ever covers them.
- **Audio:** drop sounds into `assets/audio/` (see its README for the file names: per-unit weapon sounds,
  explosions, deaths, music, ambience). Missing files fall back to the built-in noises.
- **VFX:** drop effects into `assets/vfx/` (sprite sheets, frame folders or single images; names for
  explosions, muzzle flashes, hit sparks, water splashes, deaths, deploy dust). Tune them in `vfx.json`.
- **Tiles:** drop terrain art into `assets/tiles/` (`ground`, `water_deep`, `water_shallow`, `river`, `road`,
  `bridge`, `crater`, `tree`). Tune repeat size in `tiles.json`.
- Every folder also has a twin under the game's `user://` folder (Project > Open User Data Folder) for testing
  without re-exporting.

## Enemy AI (v2)
* **Saves up** instead of spending on whatever is affordable: it queues a purchase plan and waits for the money, so it fields
  Abrams / Leopard / Armata, F-22 / F-15E / AC-130, B-52 / B-2, destroyers and battleships (units carry an `ai_tier` in `units.json`).
* **Army waves:** a premium unit plus counter-picked escorts, deployed together (AA vs your air, tank destroyers vs your armor, bombers vs your defenses).
* **Layered defense:** ground defenses sit between its key buildings and you (front-most, least-defended first); SAMs / CIWS / interceptors ring its
  power plants, tech center, silos and capital; coastal batteries answer your navy; railguns and ABMs once it can afford them.
* **Reacts** to missile launches and air raids by putting interceptors / AA at the front of its buy queue, and rebuilds lost power, tech, factories, airbase, silos and economy.
* **Difficulty** (`settings.difficulty` in `units.json`): `ai_income_mult`, `ai_start_money`, `ai_think`, `ai_skill` (0-1; lower = sloppier picks),
  `ai_wave_secs` (seconds of income per wave), `ai_strategic_after`, `ai_nukes`. Hard = 1.6x income, $1600 start, thinks every 1.2 s, nukes from 50 s.

## Prematch build: armies and strategies
After choosing a difficulty you pick an **army** and a **strategy**; the enemy gets an army and strategy too (random by default, or pick one).
Armies: **Wehrmacht, Red Army, Imperial Japanese Army, British Army, US Army, French Army, Italian Royal Army, Russian Ground Forces.**
* **Roster:** every army fields its OWN units, not renamed generics. Each of the ~70 slots (infantry, vehicles, aircraft, ships, defenses, missiles) is a separate, realistic design per army with its own HP / armor / damage / rate of fire / range / speed / size, a class, a real-world spec line and a realistic description (Tiger II, IS-2, Type 97 Chi-Ha, Challenger 2, M1A2 Abrams, Leclerc, M13/40, T-90M ...). Costs are derived from the stats. Where an army had no real equivalent the slot is banned (UK/France: no battleship; UK: no cluster munitions) or, for WW2 armies, filled with a late-war prototype or an explicit what-if.
* **Datasheets:** hover any card in battle for a full datasheet (stat bars comparable across armies, strengths / weaknesses, requirements, real-world data). The prematch screen has an **Arsenal** browser for every army's full roster.
  Stats stay on the shared baseline; the differences are the army perks below. The four WW2 armies use late-war prototypes in the tech slots (Maus, Me 262, Ho 229, V-weapons...).
* **Army perks and bans:** e.g. Wehrmacht tanks +10% HP but +8% cost; Red Army infantry -20% cost, no carriers; Italian army has no rocket artillery, drones, helicopters or stealth bomber.
* **Strategies (3 per army):** each adds perks (cost / HP / speed / damage / cooldown modifiers, economy), a **unique free starting setup** (a fortified front line, a tank spearhead, an infantry horde, a fleet, a missile shield ...) and steers the AI (offense / defense / air / naval / missile / infantry).
* The enemy AI uses the same system: its army's names, bans, perks and starting setup, and it plays to its strategy.
* All of it is data in `units.json` -> `factions` (`roster`, `ban`, `mods`, `income`, `money`, `strategies[].setup`; `names` is only a fallback). Saves remember both armies. If `factions` is missing the game skips the screen and uses the generic roster.


## Army rosters (data/units.json -> factions.<id>.roster)
Edit `tools/rosters/<army>.py` and run `python3 tools/build_rosters.py`. A row is
`U(slot_id, name, class, description, "real | world | specs", hp=.., ar=.., sp=.., rg=.., dm=.., cd=.., ...)`.
Anything omitted is inherited from the slot; any engine field (`splash`, `pierce`, `vs`, `proj`, `targets`, `cargo`, `heal`, `size`,
`stealth`, `kamikaze`, `spawn_every` ...) can be overridden. Cost is computed from the final stats unless `cost=` is given
(or listed in `COST` in the build script). Optional `sprite=` points an army-specific unit at its own art.

## Look & feel (battlefield restyle)
- **UI:** `scripts/ui/mil_theme.gd` holds the whole palette (graphite panels, one amber accent, sharp corners, condensed
  system font). Every screen assigns `MilTheme.theme()`; change colours / fonts there. Helpers: `seg_bar.gd`, `bracket_frame.gd`,
  `alert_banner.gd`, `feed_log.gd`.
- **Colour grade:** `scripts/screen_fx.gd` (desaturation, contrast, vignette, grain) sits under the HUD. Tune the shader uniforms there.
- **Sprites:** `python3 tools/generate_placeholder_sprites.py && python3 tools/generate_naval_sprites.py && python3 tools/style_sprites.py`
  (Pillow, numpy, scipy). Run the stylizer once on fresh generator output; the bundled `assets/sprites` is already styled.
- **Terrain:** ground and water are generated in `tile_lib.gd` when no tile files exist; dirt, scorched front line, roads, craters, rocks and
  forests are drawn in `battle.gd` (`TerrainLayer`). Explosions leave scorch marks and burnt wrecks (`DecalLayer`).
- `settings.team_tint` is now 0.28 (sprites are drab; team shows via tint, corner ticks and a marker on aircraft).

## Command & control (v3: no more card-dropping)
Units are no longer teleported onto the map. They are **produced** and then **commanded**:
- **Production:** a unit card queues the unit at a Barracks (infantry), War Factory (vehicles), Airbase (aircraft) or Naval Port (ships);
  with none standing, the capital builds it. Each building builds one item at a time (time = cost / 35 s, 2-26 s; override with `build_time`
  in `units.json`), so more factories = more throughput, and destroying a factory stalls the queue (it moves to another one or refunds).
  Shift-click a card = queue 5. A power cut stops powered producers. The AI uses the same queues.
- **Orders:** your units wait where they are built (they rally to the flag). Drag a box (or click) to select; **RMB** move,
  **Ctrl+RMB / T + click** attack-move (advance and engage), **X** hold position (fire in range, never advance), **F + click** set the rally flag,
  **C** select every unit, **Esc** deselect. Move = ignore targets and fire only in passing; attack-move stops to fight, then holds on arrival.
- Defenses, infrastructure and missiles are still placed by clicking the map. Orders and queues are saved with the game.
- Strafing aircraft and suicide drones still fly their own sorties (air orders are the next step).

## Unique sprites per army (v4)
Every unit of every army now has its **own sprite** (`assets/sprites/<faction>_<slot>.png`, 543 files) and each roster entry in
`units.json` points at it with `"sprite": "<faction>_<slot>"` (the armies' `roster` already replaced name / stats, now the art too).
- Art is generated from each unit's real-world identity by `python3 tools/fsprites/build_all.py` (Pillow, numpy, scipy; ~70 s).
  Modules: `infantry.py` (helmet + kit per army, weapon per unit), `vehicles.py`, `air.py` (incl. rotorcraft), `navy.py`, `defenses.py`,
  `missiles.py`; `schemes.py` holds each army's paint / camouflage / national insignia; `core.py` does the shading.
- To change one unit's look, edit its entry in the module's `CAT` list (matched on the unit's name) and re-run. Hand-drawn PNGs dropped in
  `user://sprites/<faction>_<slot>.png` still override the generated ones, exactly like before.
- `build_rosters.py` now writes the `sprite` field automatically, so rebuilding rosters keeps the links.
- The generic slot sprites (`assets/sprites/<slot>.png`) are still used for national buildings and as a fallback.


## v5 expansion: big battlefield, automation, traps

**Map** - now 6400 x 1488 land (4x the area), longer river with 5 bridges, two extra creeks, deeper seas. Camera zooms out to see the whole theatre; Shift+WASD pans fast. Units move 1.5x faster and missiles 1.8x to cover the distance.

**Less manual** - your units now start in **AUTO-ASSAULT** (they march and fight like the AI). `V` cycles the army stance: AUTO-ASSAULT / DEFEND RALLY / MANUAL (the old behaviour). `P` toggles **AUTOPILOT**: the staff keeps buying units for you but never spends your last 350 funds, so you can still buy defenses, buildings and missiles. Economy is 1.7x so armies are bigger.

**New infantry** - Mossberg Breacher (shotgun), Marksman, Mortar Team, Javelin/AT Team, Heavy Assault Trooper, Combat Sapper (lays mines, clears mines), Squad Commander (+25% damage aura), K9 Demolition Dog.
**New vehicles / navy** - Mine Flail Tank, Torpedo Boat, ASW Frigate, Minelayer, Midget Submarine, SSGN cruise-missile sub.
**New defenses** - Sandbag Nest, Watchtower, Sniper Nest, Flamethrower Bunker, Shore Torpedo Battery, Observation Post (+20% damage aura).
**Traps & Mines tab** - AT Mine, AP Mine, Claymore, Napalm Trap, Barbed Wire, Dragon's Teeth, Naval Mine, Decoy Tank. Enemy traps are almost invisible; sappers and flail tanks defuse them. Traps have their own cap (90) and don't use the defense cap.
**New buildings** - Field Hospital, Supply Depot, Fuel Depot, **Forward Operating Base** (can be built anywhere on your side of the river; acts as a barracks).
All new items are themed per army (partial roster rows). `tools/expand_content.py` regenerates this data; `tools/feature_test.tscn` and `tools/stress.tscn` test it.

## v6: preparation phase, scouts, fog of war, utility abilities, radio, asset manager

**Preparation phase** (new games; `settings.prep_phase`, `prep_seconds` in units.json). The war is frozen; you can:
click a building and **drag** it to move it, **R** rotates it (Shift+R the other way), **Del** sells what you bought
this phase (starting buildings can only be moved / rotated), place new buildings from the cards (R rotates the ghost),
queue units, set the army stance, the **army objective** (nearest / capital / economy / industry), fog of war and
autopilot. **Build designs**: SAVE / LOAD slots A-C store your layout (user://layouts/), MIRROR flips it north-south,
RESET restores the country layout. Loading a design moves what you own and buys what is missing if you can afford it.
Enter or START BATTLE ends the phase (a countdown does it automatically).

**Rotation.** Every building that does not turn by itself (country buildings, walls...) can be rotated, also during the
battle (hover + R). Coastal buildings with directional art face the water automatically: `art_front` (degrees, 0 = east,
90 = south) is the side of the art that must point at the sea; the Naval Port has `art_front: 90` and `face_water`.

**Scouting drones** (units.json, `scout: true`): Raven Recon Quad (barracks), RQ-11 Scout UAV (airbase), RQ-4 High-Altitude
Recon (airbase + radar station), MQ-8 Naval Recon UAV (port, has sonar), Talon Scout UGV (factory, defuses mines).
They roam the enemy half on their own, see far (`vision`), and paint targets (+25% damage taken). Airbases, carriers, ports
and barracks also launch them for free (max 5 alive). Sprites: `tools/generate_scout_sprites.py` (replace freely).

**Fog of war** (`settings.fog_of_war`, toggle in the prep panel). Enemy units are hidden outside your vision; your units
cannot shoot what nobody sees (artillery needs spotters!). Enemy buildings stay on the map once seen, the enemy country
is known from the start. Stealth aircraft need radar, submarines need sonar, mines need a sweeper / scout nearby.
Anything that fires is revealed for a moment. `vision` per unit and `settings.vision_mult` tune it.

**Utility abilities** (scripts/abilities.gd; override per unit with `"abilities": [...]`):
dig_in, siege, suppress, designate, radar, sonar, withdraw (fall back, repair, return), smoke (Z), fortify (Z), unload (Z).
Z uses the selection's active ability; the unit info panel lists each unit's utility.

**Radio** (scripts/autoload/radio.gd): contact reports, under-attack calls, order acknowledgements, missile / nuke
warnings, kill confirms, enemy intercepts... shown on the RADIO NET panel (click or Space = jump to the event, M = mute
voices). Voices: drop `radio_<event>_<n>.ogg` (see the Asset Manager, RADIO category) or `radio_<event>.ogg`; otherwise a
synthesised radio babble plays. All lines are in `Radio.LINES`.

**Audio no longer cuts off.** 48 voices with priorities: a playing sound is only ever replaced by a more important one
(nukes > explosions > deaths > shots), extra copies of the same sound are skipped instead of cutting the first, the
sound system keeps running while paused / on the game-over screen, and the radio has its own channel + the music ducks.
Separate buses: Music, SFX, Radio. `.wav` files can now be dropped into user://audio/ too.

**Asset Manager** (main menu or pause menu): replace every sprite, sound effect, radio line, visual effect, map tile,
interface image (background, menu background, mouse cursor) and font from inside the game; RESET removes a replacement,
EXPORT CHECKLIST writes user://asset_checklist.csv with every asset id and whether it is custom / bundled / placeholder.
Fonts: user://fonts/ui.ttf, bold.ttf, mono.ttf (restart or reopen screens to apply).

Keys added: **R** rotate, **Z** ability, **M** radio mute, **Space** jump to last radio report, **Enter** start battle (prep), **Del** sell (prep).
