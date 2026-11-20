#!/usr/bin/env python3
"""One-shot content expansion for data/units.json (idempotent: re-running just rewrites the same entries).
Adds: bigger map settings, Traps tab, new infantry / vehicles / naval units, new defenses and country buildings."""
import json, sys, os
P = os.path.join(os.path.dirname(__file__), "..", "data", "units.json")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import datafiles as df
d = df.load_all()
S = d["settings"]

# ------------------------------------------------------------ map / economy / caps
S.update({"unit_cap": 170, "structure_cap": 60, "national_cap": 70, "trap_cap": 90,
          "player_zone_x": 1500, "enemy_zone_x": 4900, "forward_reach": 1500,
          "move_speed_mult": 1.5, "economy_mult": 1.7, "start_money": 1500, "missile_speed_mult": 1.8, "zoom_max": 2.5, "auto_stance": "assault"})

# country layout: spread north-south (x unchanged), ports moved out to the new coast
ORIGINAL_COUNTRY = [["missile_silo", 110, 200], ["missile_silo", 110, 810], ["oil_refinery", 235, 350], ["oil_refinery", 235, 660], ["town", 255, 130], ["town", 255, 880], ["metropolis", 410, 240], ["metropolis", 410, 770], ["power_plant", 360, 505], ["tech_center", 500, 505], ["barracks", 570, 355], ["barracks", 570, 655], ["radar_station", 640, 145], ["radar_station", 640, 865], ["power_plant", 650, 505], ["town", 230, 505], ["factory", 790, 330], ["factory", 790, 680], ["airbase", 830, 505], ["fortress", 945, 255], ["fortress", 945, 755], ["naval_port", 450, 895], ["naval_port", 450, 113]]   # layout of the 3200-wide map (kept so this script stays idempotent)
new_country = []
for nid, x, y in ORIGINAL_COUNTRY:
    if nid == "naval_port":
        y = 1224 if y > 504 else -216
    else:
        y = round(504 + (y - 504) * 1.3)
    new_country.append([nid, x, y])
d["country"] = new_country

# ------------------------------------------------------------ tabs
if not any(t["id"] == "traps" for t in d["tabs"]):
    i = [t["id"] for t in d["tabs"]].index("strategic")
    d["tabs"].insert(i, {"id": "traps", "name": "Traps & Mines"})

# ------------------------------------------------------------ helpers
def inf(name, cost, hp, speed, rng, dmg, cd, proj, desc, **kw):
    e = {"name": name, "tab": "infantry", "role": "infantry", "shape": "infantry", "layer": "ground",
         "cost": cost, "hp": hp, "armor": 0, "speed": speed, "size": 26, "range": rng, "damage": dmg,
         "cooldown": cd, "proj": proj, "targets": ["ground"], "deploy_cd": 1.0, "desc": desc, "ai_tier": 0.5}
    e.update(kw); return e

U = d["units"]
U["shotgunner"] = inf("Mossberg Breacher", 70, 85, 50, 80, 17, 0.9, "bullet",
    "Close-quarters infantry. Devastating shotgun blasts at point-blank range, useless at distance.",
    armor=1, vs={"infantry": 1.7, "vehicle": 0.4, "armor": 0.15, "structure": 0.25}, prefer=["infantry"], ai_tier=0.3)
U["marksman"] = inf("M110 Marksman", 115, 60, 46, 270, 24, 1.2, "bullet",
    "Designated marksman. Accurate mid-range rifle, strong against infantry.",
    vs={"infantry": 1.5, "vehicle": 0.5, "armor": 0.15, "structure": 0.3}, prefer=["infantry"], requires="barracks", ai_tier=0.45)
U["mortar_team"] = inf("M224 Mortar Team", 140, 60, 34, 400, 34, 2.6, "mortar",
    "Indirect-fire support. Lobs mortar rounds over obstacles; cannot hit anything close.",
    min_range=90, splash=48, vs={"infantry": 1.4, "vehicle": 0.8, "armor": 0.4, "structure": 0.6}, requires="barracks", ai_tier=0.55, role="artillery")
U["javelin"] = inf("FGM-148 Javelin Team", 190, 65, 44, 310, 125, 3.6, "atgm",
    "Fire-and-forget anti-tank team. Top-attack missiles punch through armor.",
    pierce=14, vs={"infantry": 0.2, "vehicle": 1.2, "armor": 1.5, "structure": 0.5}, prefer=["armor", "vehicle"], requires="barracks", ai_tier=0.75, role="anti_armor")
U["riot_trooper"] = inf("Heavy Assault Trooper", 150, 280, 38, 95, 12, 0.5, "bullet",
    "Shielded heavy infantry. Very tough, short-ranged. Soaks damage for the squad.",
    armor=7, vs={"infantry": 1.2, "structure": 0.3}, requires="barracks", ai_tier=0.5)
U["sapper"] = inf("Combat Sapper", 120, 75, 48, 70, 10, 1.0, "bullet",
    "Combat engineer. Lays anti-tank mines as it advances and safely clears enemy minefields.",
    role="support", lays_trap="landmine", lay_every=13, sweeper=120, requires="barracks", ai_tier=0.35)
U["officer"] = inf("Squad Commander", 230, 95, 50, 130, 9, 0.7, "bullet",
    "Field officer. Nearby friendly units fire 25% harder. Follows the troops.",
    role="support", aura={"radius": 280, "dmg": 1.25}, follow=True, requires="barracks", ai_tier=0.4)
U["k9"] = inf("K9 Demolition Dog", 60, 30, 120, 22, 95, 1.0, "bullet",
    "Fast explosive-laden dog. Sprints at the enemy and detonates.",
    size=20, kamikaze=True, splash=42, vs={"infantry": 1.7, "vehicle": 1.0, "armor": 0.5, "structure": 0.5}, ai_tier=0.35, role="light")

def veh(name, cost, hp, armor, speed, rng, dmg, cd, proj, desc, **kw):
    e = {"name": name, "tab": "vehicles", "role": "support", "shape": "vehicle", "layer": "ground",
         "cost": cost, "hp": hp, "armor": armor, "speed": speed, "size": 52, "range": rng, "damage": dmg,
         "cooldown": cd, "proj": proj, "targets": ["ground"], "deploy_cd": 2.5, "desc": desc, "ai_tier": 0.5}
    e.update(kw); return e
U["mine_flail"] = veh("Mine Flail Tank", 260, 520, 8, 44, 150, 6, 0.3, "bullet",
    "Mine-clearing tank. Detonates enemy mines and traps around it safely, with a light MG.",
    sweeper=170, requires="factory", ai_tier=0.35)

def ship(name, cost, hp, armor, speed, size, rng, dmg, cd, proj, desc, draft, **kw):
    e = {"name": name, "tab": "navy", "role": "ship", "shape": "ship", "layer": "ground", "domain": "water",
         "draft": draft, "cost": cost, "hp": hp, "armor": armor, "speed": speed, "size": size, "radius_k": 0.3,
         "range": rng, "damage": dmg, "cooldown": cd, "proj": proj, "targets": ["ground"], "deploy_cd": 3.0,
         "desc": desc, "requires": "port", "ai_tier": 0.8}
    e.update(kw); return e
U["torpedo_boat"] = ship("PT Torpedo Boat", 280, 260, 2, 125, 70, 300, 150, 5.0, "torpedo",
    "Fast attack boat. Launches torpedoes that only hit things in the water. Deadly to ships.", 2,
    water_only=True, vs={"ship": 1.6}, prefer=["ship"], ai_tier=0.9)
U["frigate"] = ship("ASW Frigate", 420, 600, 6, 78, 90, 270, 26, 1.0, "shell",
    "Anti-submarine frigate. Guns for land and air, depth charges for subs and divers.", 2,
    targets=["ground", "air", "sub"], splash=25, sub_proj="depth_charge", sub_damage=150, sub_splash=60, ai_tier=0.9)
U["minelayer"] = ship("Minelayer", 330, 400, 4, 60, 88, 0, 0, 1.0, "bullet",
    "Sows naval mines as it sails. Mines sink ships and subs that wander into them.", 2,
    lays_trap="naval_mine", lay_every=7, ai_tier=0.4)
U["midget_sub"] = ship("Midget Submarine", 320, 160, 2, 70, 56, 220, 190, 5.0, "torpedo",
    "Tiny stealth submarine. Hard to spot; one torpedo can cripple a ship.", 2,
    layer="sub", domain="sub", role="sub", targets=["ground", "sub"], water_only=True, vs={"ship": 1.8},
    prefer=["ship"], stealth=0.35, ai_tier=0.8)
U["cruise_sub"] = ship("Ohio-class SSGN", 1300, 700, 8, 50, 112, 560, 85, 3.2, "rocket",
    "Guided-missile submarine. Launches cruise missiles at land and sea targets from hiding.", 3,
    layer="sub", domain="sub", role="sub", requires=["port", "tech"], splash=55, vs={"structure": 1.4},
    stealth=0.4, ai_tier=1.4)

# ------------------------------------------------------------ defenses
S_ = d["structures"]
def dfn(name, cost, hp, armor, size, rng, dmg, cd, proj, desc, **kw):
    e = {"name": name, "tab": "defenses", "role": "defense", "shape": "structure", "layer": "ground",
         "cost": cost, "hp": hp, "armor": armor, "speed": 0, "size": size, "range": rng, "damage": dmg,
         "cooldown": cd, "proj": proj, "targets": ["ground"], "deploy_cd": 1.0, "desc": desc, "ai_tier": 0.5}
    e.update(kw); return e
S_["sandbag_nest"] = dfn("Sandbag MG Nest", 90, 300, 2, 36, 190, 6, 0.2, "bullet",
    "Cheap sandbagged machine-gun nest. Good value against infantry.", ai_tier=0.4, vs={"infantry": 1.3})
S_["watchtower"] = dfn("Watchtower", 180, 260, 1, 34, 330, 14, 0.5, "bullet",
    "Tall wooden tower with a long-range rifle post. Weak armor.", shape="tower", ai_tier=0.45)
S_["sniper_nest"] = dfn("Sniper Nest", 240, 220, 2, 34, 400, 50, 2.2, "sniper",
    "Hidden sniper post. Kills infantry at long range, useless against armor.", shape="tower",
    vs={"infantry": 3.0, "vehicle": 0.3, "armor": 0.1, "structure": 0.1}, prefer=["infantry"], ai_tier=0.5)
S_["flame_bunker"] = dfn("Flamethrower Bunker", 300, 700, 8, 44, 125, 14, 0.15, "flame",
    "Fortified flamethrower pit. Roasts infantry and light vehicles that get close.", splash=20,
    vs={"infantry": 2.4, "vehicle": 1.0, "armor": 0.5}, prefer=["infantry"], ai_tier=0.55)
S_["torpedo_battery"] = dfn("Shore Torpedo Battery", 420, 600, 8, 54, 380, 170, 4.0, "torpedo",
    "Coastal torpedo tubes. Only fires at ships and subs in the water. Build near the coast.",
    water_only=True, coastal=230, vs={"ship": 1.6}, prefer=["ship"], ai_tier=0.9)
S_["observation_post"] = dfn("Observation Post", 260, 300, 2, 40, 0, 0, 1.0, "bullet",
    "Spotter tower. All friendly units and defenses within range fire 20% harder.", shape="tower",
    role="support", aura={"radius": 480, "dmg": 1.2}, ai_tier=0.3)

# ------------------------------------------------------------ traps (tab "traps")
def trap(name, cost, desc, trap_cfg, size=22, **kw):
    e = {"name": name, "tab": "traps", "role": "trap", "shape": "mine", "layer": "ground", "cost": cost, "hp": 60,
         "armor": 0, "speed": 0, "size": size, "range": 0, "damage": 0, "deploy_cd": 0.4, "desc": desc,
         "trap": trap_cfg, "ai": False, "ai_tier": 0.3}
    e.update(kw); return e
S_["landmine"] = trap("Anti-Tank Mine", 40,
    "Buried mine. Detonates under vehicles; infantry are too light to trigger it. Hidden from view of the enemy until it goes off.",
    {"triggers": ["vehicle", "armor"], "radius": 24, "splash": 55, "damage": 230, "pierce": 10, "vs": {"vehicle": 1.2, "infantry": 0.3}})
S_["ap_mine"] = trap("Anti-Personnel Mine", 25,
    "Cheap mine that shreds infantry. Vehicles roll over it safely.",
    {"triggers": ["infantry"], "radius": 16, "splash": 48, "damage": 95, "vs": {"infantry": 1.6, "vehicle": 0.2}}, size=18)
S_["claymore"] = trap("Claymore Array", 75,
    "Directional charges with a wide trigger area. Lethal to infantry that walk into the kill zone.",
    {"triggers": ["infantry", "vehicle"], "radius": 70, "splash": 75, "damage": 130, "vs": {"infantry": 1.9, "vehicle": 0.5}}, size=26)
S_["napalm_trap"] = trap("Napalm Trap", 120,
    "Buried fuel drums. Explodes in a huge fireball when enemy ground units approach.",
    {"triggers": ["infantry", "vehicle", "armor"], "radius": 50, "splash": 95, "damage": 80, "vs": {"infantry": 2.2, "vehicle": 1.0}}, size=28)
S_["barbed_wire"] = trap("Barbed Wire", 30,
    "Entangles infantry: slows them a lot and cuts them slowly.",
    {"slow": {"classes": ["infantry"], "radius": 38, "mult": 0.3, "dps": 6}}, size=40, hp=120)
S_["tank_trap"] = trap("Dragon's Teeth", 60,
    "Concrete tank traps. Vehicles crawl through them.",
    {"slow": {"classes": ["vehicle", "armor"], "radius": 46, "mult": 0.3}}, size=36, hp=800, armor=14)
S_["naval_mine"] = trap("Naval Mine", 90,
    "Moored sea mine. Sinks ships and subs that touch it. Deploy in your own waters.",
    {"triggers": ["ship"], "radius": 38, "splash": 70, "damage": 270, "layers": ["ground", "sub"], "vs": {"ship": 1.5}},
    domain="water", draft=1, size=24)
S_["decoy_tank"] = {"name": "Inflatable Decoy Tank", "tab": "traps", "role": "decoy", "shape": "vehicle", "layer": "ground",
    "cost": 55, "hp": 420, "armor": 0, "speed": 0, "size": 52, "range": 0, "damage": 0, "deploy_cd": 1.0,
    "desc": "Looks like a real tank from afar. Enemy units waste ammunition on it.", "ai": False, "ai_tier": 0.2}

# ------------------------------------------------------------ country buildings
N = d["national"]
def nat(name, cost, hp, size, desc, **kw):
    e = {"name": name, "tab": "infrastructure", "role": "national", "shape": "structure", "layer": "ground",
         "cost": cost, "hp": hp, "armor": 5, "speed": 0, "size": size, "range": 0, "damage": 0, "deploy_cd": 8.0,
         "limit": 3, "desc": desc, "rotate": False}
    e.update(kw); return e
N["field_hospital"] = nat("Field Hospital", 650, 700, 72,
    "Heals wounded infantry nearby. Keeps your troops in the fight.", heal={"rate": 16, "radius": 250, "cls": ["infantry"]})
N["supply_depot"] = nat("Supply Depot", 700, 800, 76, "Stockpiles materiel: +3 income per second.", income=3, limit=4)
N["fuel_depot"] = nat("Fuel Depot", 500, 500, 66, "Bulk fuel storage: +2 income. Explodes violently when destroyed!",
    income=2, death_blast={"radius": 130, "damage": 170})
N["forward_base"] = nat("Forward Operating Base", 1200, 1500, 92,
    "Fortified outpost that can be built far forward. Acts as a Barracks, trains free troops and has its own gun.",
    armor=8, provides=["barracks"], spawns=["rifleman", "shotgunner", "mg_gunner"], spawn_every=18,
    range=250, damage=10, cooldown=0.25, proj="bullet", targets=["ground"], forward=True, deploy_cd=12.0)

df.save_all(d)
print("units", len(U), "structures", len(S_), "national", len(N), "tabs", [t["id"] for t in d["tabs"]])


# ------------------------------------------------------------ per-army names (partial roster rows: name merges over the generic slot)
# Order: wehrmacht, red_army, ija, british_army, us_army, french_army, italian_army, russian_gf
FIDS = ["wehrmacht", "red_army", "ija", "british_army", "us_army", "french_army", "italian_army", "russian_gf"]
NAMES = {
 "shotgunner":   ["Grabenkaempfer Trench Fighter", "Shturmovik Trench Raider", "Type 100 Close-Combat Trooper", "Trench Raider (Lanchester)", "M97 Trench Gunner", "Fusilier de Choc", "Arditi Raider", "Spetsnaz Breacher (Saiga-12)"],
 "marksman":     ["G43 Scharfschuetze", "SVT-40 Marksman", "Type 99 Marksman", "No.4 (T) Marksman", "M14 Designated Marksman", "FR-F2 Tireur d'Elite", "Carcano Tiratore Scelto", "SVD Marksman"],
 "mortar_team":  ["8 cm GrW 34 Mortar Team", "82-BM-37 Mortar Crew", "Type 97 81mm Mortar Team", "3-inch Mortar Team", "M224 Mortar Team", "MO-81 Mortar Crew", "Mortaio da 81 Team", "2B14 Podnos Mortar Crew"],
 "javelin":      ["Panzerschreck Team", "PTRD Anti-Tank Rifle Team", "Type 4 70mm AT Launcher Team", "PIAT Team", "FGM-148 Javelin Team", "ERYX Missile Team", "Cannone da 47/32 AT Team", "9M133 Kornet Team"],
 "riot_trooper": ["Sturmpionier Assault Trooper", "SN-42 Steel-Breastplate Trooper", "Armoured Assault Soldier", "Heavy Assault Sapper", "Ballistic-Shield Trooper", "Fantassin Blinde", "Corazzato Assault Trooper", "Ratnik Heavy Trooper"],
 "sapper":       ["Pionier Mine Layer", "Saper Sapper Squad", "IJA Engineer Sapper", "Royal Engineer Sapper", "Combat Engineer Sapper", "Sapeur du Genie", "Guastatore Sapper", "Engineer-Sapper (Mine Clearer)"],
 "officer":      ["Zugfuehrer Platoon Leader", "Platoon Commander (Politruk)", "Shoi Platoon Commander", "Platoon Commander", "Platoon Leader (2LT)", "Chef de Section", "Capitano Company Commander", "Platoon Commander (Ratnik)"],
 "k9":           ["Minenhund Mine Dog", "Anti-Tank Dog", "Explosive Dog", "Demolition Dog", "K9 Demolition Dog", "Chien Piege", "Cane Esplosivo", "Demolition Dog"],
 "mine_flail":   ["Raeumpanzer Mine Clearer", "PT-3 Mine-Roller Tank", "Type 97 Mine-Roller Tank", "Sherman Crab Flail Tank", "M1 Panther Mine Clearer", "AMX-30 EBG Engineer Tank", "L6/40 Mine Roller", "BMR-3M Mine Clearer"],
 "torpedo_boat": ["S-100 Schnellboot", "G-5 Torpedo Cutter", "Type 5 Torpedo Boat", "Vosper MTB", "PT Torpedo Boat", "Vedette Lance-Torpilles", "MAS 500 Torpedo Boat", "Project 206 Shershen"],
 "frigate":      ["Flottenbegleiter Escort", "Kronshtadt SKR Escort", "Type C Kaibokan Escort", "River-class Frigate", "Knox-class Frigate", "Floreal-class Frigate", "Spica-class Escort", "Admiral Gorshkov Frigate"],
 "minelayer":    ["Kriegsmarine Minenleger", "Marti-class Minelayer", "Okinoshima-class Minelayer", "Abdiel-class Fast Minelayer", "Terror-class Minelayer", "Marine Nationale Minelayer", "Regia Marina Minelayer", "Russian Navy Minelayer"],
 "midget_sub":   ["Seehund Midget Submarine", "Malyutka-class Midget Sub", "Type A Ko-hyoteki Midget Sub", "X-craft Midget Submarine", "Advanced SEAL Mini-Sub", "Minisous-marin Gnome", "CB-class Midget Submarine", "Triton-1M Midget Sub"],
 "cruise_sub":   ["Type XXI V-Weapon U-boat (what-if)", "Project 651 Cruise-Missile Sub", "I-400 Sen-Toku Missile Sub (what-if)", "Trafalgar-class SSN (Tomahawk)", "Ohio-class SSGN", "Suffren-class SSN (SCALP Naval)", "Toti-class Missile Sub (what-if)", "Oscar-II SSGN"],
}
DNAMES = {
 "sandbag_nest": ["MG 34 Sandbag Nest", "Maxim Sandbag Nest", "Type 92 Sandbag Nest", "Vickers Sandbag Nest", "M60 Sandbag Nest", "AAT-52 Sandbag Nest", "Breda 37 Sandbag Nest", "PKM Sandbag Nest"],
 "watchtower": ["Beobachtungsturm", "Soviet Watchtower", "IJA Watchtower", "Observation Watchtower", "Guard Tower", "Mirador de Garde", "Torre di Guardia", "Border Watchtower"],
 "sniper_nest": ["Scharfschuetzen Nest", "Sniper Nest (Mosin)", "Sniper Nest (Type 97)", "Sniper Nest (Enfield)", "M82 Sniper Nest", "FR-F2 Sniper Nest", "Nido del Tiratore", "SVD Sniper Nest"],
 "flame_bunker": ["Flammenwerfer-Bunker", "ATO Flame Bunker", "Type 93 Flame Bunker", "Wasp Flame Bunker", "M2 Flame Bunker", "Bunker Lance-Flammes", "Lanciafiamme Bunker", "TOS Flame Bunker"],
 "torpedo_battery": ["Kuesten Torpedo Battery", "Coastal Torpedo Battery", "Type 93 Shore Torpedo Tubes", "Coastal Torpedo Battery", "Shore Torpedo Battery", "Batterie Lance-Torpilles", "Batteria Siluranti", "Coastal Torpedo Battery"],
 "observation_post": ["Artillerie-Beobachter Post", "Forward Observer Post", "Observation Post", "Forward Observation Post", "Forward Observer Post", "Poste d'Observation", "Osservatorio Avanzato", "Forward Observer Post"],
}
for i, fid in enumerate(FIDS):
    ro = d["factions"][fid].setdefault("roster", {})
    for table in (NAMES, DNAMES):
        for uid, names in table.items():
            row = ro.get(uid, {})
            row["name"] = names[i]
            ro[uid] = row

# era-neutral descriptions (armies from WW2 to modern share them)
U["javelin"]["desc"] = "Anti-tank team. Rocket or guided-missile launcher that punches through armor at range."
U["mine_flail"]["desc"] = "Mine-clearing armor. Flails or rolls through minefields, defusing every mine and trap near it, with a light MG."
U["cruise_sub"]["desc"] = "Missile submarine. Launches long-range missiles at land and sea targets from hiding."
U["riot_trooper"]["desc"] = "Heavily armored shock infantry. Very tough, short-ranged. Soaks damage for the squad."
S_["sniper_nest"]["desc"] = "Hidden sniper post. Kills infantry at long range, useless against armor."
df.save_all(d)
print("themed names added for", len(NAMES) + len(DNAMES), "items x 8 armies")

# tag everything added by this script (the legacy roster self-test exempts v5 items)
for uid in NAMES:
    U[uid]["v5"] = 1
for sid in list(DNAMES) + ["landmine", "ap_mine", "claymore", "napalm_trap", "barbed_wire", "tank_trap", "naval_mine", "decoy_tank"]:
    S_[sid]["v5"] = 1
df.save_all(d)
