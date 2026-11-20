#!/usr/bin/env python3
"""v7 data pass: lifelike sizes, road / off-road mobility, finite ammo, seats + supply, flight models,
new logistics units (Supply Truck, Troop Truck, Transport Helicopter) and data/logistics.json.

Idempotent (guarded by settings.model == "v7"). Run once from the project root:  python3 tools/tune_data.py
"""
import copy, json, math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import datafiles as df

D = df.load_all()
S = D["settings"]
if S.get("model") == "v7":
    print("already tuned (settings.model == v7)")
    sys.exit(0)

# ----------------------------------------------------------------------------- sizes
# px per metre: ground + air 5.0, ships 1.6 (a 1:1 carrier would not fit the sea).  Infantry and tiny drones are
# drawn at a readable minimum.  Buildings keep their old on-screen size (old sprite_scale 1.4 is baked in).
SIZE_PX = {
    # infantry (about 1 m of soldier + kit, shown at 12-15 px so they stay visible)
    "rifleman": 12, "assault": 12, "bazooka": 13, "manpads": 13, "mg_gunner": 13, "grenadier": 12, "sniper": 12,
    "flamer": 14, "medic": 12, "engineer": 13, "commando": 13, "shotgunner": 12, "marksman": 12, "mortar_team": 15,
    "javelin": 13, "riot_trooper": 13, "sapper": 13, "officer": 12, "k9": 10, "diver": 12,
    # vehicles (length x 5)
    "jeep": 23, "armored_car": 28, "apc": 33, "light_tank": 34, "tank": 49, "heavy_tank": 55, "mammoth": 66,
    "tank_destroyer": 43, "flame_tank": 40, "artillery": 46, "howitzer": 58, "mlrs": 38, "aa_truck": 26,
    "sam_truck": 50, "repair_vehicle": 42, "mine_flail": 40, "scout_ugv": 14,
    # air
    "drone": 14, "fighter": 75, "interceptor_jet": 97, "stealth_fighter": 95, "strike_jet": 100, "helicopter": 88,
    "gunship": 150, "light_bomber": 117, "bomber": 222, "heavy_bomber": 243, "stealth_bomber": 170,
    "recon_quad": 12, "scout_uav": 16, "hale_uav": 72, "naval_scout": 38,
    # navy (length x 1.6)
    "patrol_boat": 40, "gunboat": 64, "missile_boat": 82, "destroyer": 248, "cruiser": 277, "battleship": 432,
    "submarine": 184, "aircraft_carrier": 533, "torpedo_boat": 51, "frigate": 216, "minelayer": 112,
    "midget_sub": 40, "cruise_sub": 272,
}
NEW_UNITS = {
    "supply_truck": 40, "troop_truck": 40, "transport_heli": 77,
}
SIZE_PX.update(NEW_UNITS)
BUILDING_SCALE = 1.4

old_slot_size = {}
for k, v in D["units"].items():
    old_slot_size[k] = float(v.get("size", 32))
    if k in SIZE_PX:
        v["size"] = SIZE_PX[k]
    else:
        print("no real size for", k)
for group in ("structures", "national"):
    for k, v in D[group].items():
        v["size"] = round(float(v.get("size", 32)) * BUILDING_SCALE)
D["base"]["size"] = round(float(D["base"]["size"]) * BUILDING_SCALE)
S["sprite_scale"] = 1.0
# roster rows that carry their own size
slot_kind = {}
for k in D["units"]: slot_kind[k] = "unit"
for k in D["structures"]: slot_kind[k] = "structure"
for k in D["national"]: slot_kind[k] = "national"
for fid, f in D["factions"].items():
    for k, row in f["roster"].items():
        if "size" not in row:
            continue
        if slot_kind.get(k) == "unit":
            ratio = float(row["size"]) / old_slot_size[k]
            row["size"] = round(SIZE_PX[k] * min(max(ratio, 0.8), 1.35))
        else:
            row["size"] = round(float(row["size"]) * BUILDING_SCALE)

# radius_k: long hulls / airframes collide on a smaller core than their length
for k, v in D["units"].items():
    sz = float(v["size"])
    if v.get("tab") == "navy" and sz >= 200:
        v["radius_k"] = 0.2
    elif v.get("tab") == "navy" and sz >= 100:
        v["radius_k"] = 0.24
    elif v.get("tab") == "air":
        v["radius_k"] = 0.2 if sz >= 140 else (0.25 if sz >= 90 else 0.32)

# ----------------------------------------------------------------------------- mobility (drive)
DRIVE = {
    "jeep": "wheeled", "armored_car": "wheeled", "apc": "tracked", "light_tank": "tracked", "tank": "tracked",
    "heavy_tank": "heavy", "mammoth": "heavy", "tank_destroyer": "wheeled", "flame_tank": "tracked",
    "artillery": "tracked", "howitzer": "heavy", "mlrs": "wheeled", "aa_truck": "wheeled", "sam_truck": "truck",
    "repair_vehicle": "heavy", "mine_flail": "heavy", "scout_ugv": "tracked",
    "supply_truck": "truck", "troop_truck": "truck",
}
for k, v in D["units"].items():
    if v.get("tab") == "infantry":
        v["drive"] = "foot"
    elif k in DRIVE:
        v["drive"] = DRIVE[k]

# ----------------------------------------------------------------------------- ammo, seats, supply
AMMO = {
    "rifleman": 120, "assault": 200, "bazooka": 6, "manpads": 4, "mg_gunner": 300, "grenadier": 22, "sniper": 18,
    "flamer": 150, "commando": 160, "shotgunner": 50, "marksman": 40, "mortar_team": 16, "javelin": 4,
    "riot_trooper": 90, "sapper": 40, "officer": 90, "k9": 1, "diver": 30,
    "jeep": 240, "armored_car": 260, "apc": 520, "light_tank": 45, "tank": 40, "heavy_tank": 36, "mammoth": 48,
    "tank_destroyer": 20, "flame_tank": 220, "artillery": 28, "howitzer": 22, "mlrs": 24, "aa_truck": 420,
    "sam_truck": 12, "mine_flail": 80,
    "drone": 1, "fighter": 70, "interceptor_jet": 30, "stealth_fighter": 60, "strike_jet": 40, "helicopter": 40,
    "gunship": 140, "light_bomber": 10, "bomber": 16, "heavy_bomber": 28, "stealth_bomber": 18,
    "patrol_boat": 400, "gunboat": 150, "missile_boat": 14, "destroyer": 120, "cruiser": 90, "battleship": 40,
    "submarine": 12, "aircraft_carrier": 200, "torpedo_boat": 6, "frigate": 100, "midget_sub": 4, "cruise_sub": 12,
}
for k, a in AMMO.items():
    if k in D["units"]:
        D["units"][k]["ammo"] = a

SEATS = {"jeep": 4, "armored_car": 3, "apc": 8}
for k, n in SEATS.items():
    D["units"][k]["seats"] = n
D["units"]["apc"]["desc"] = D["units"]["apc"]["desc"].replace("Unloads troops when destroyed.", "Carries 8 infantry: order troops to board (RMB on it), drive them forward and dismount (U).")

# ----------------------------------------------------------------------------- flight
FLIGHT = {
    "drone": ("drone", 90), "fighter": ("fighter", 170), "interceptor_jet": ("fighter", 150),
    "stealth_fighter": ("fighter", 160), "strike_jet": ("strike", 190), "helicopter": ("heli", 0),
    "gunship": ("orbit", 330), "light_bomber": ("bomber", 360), "bomber": ("bomber", 520),
    "heavy_bomber": ("bomber", 720), "stealth_bomber": ("bomber", 480), "recon_quad": ("heli", 0),
    "scout_uav": ("uav", 140), "hale_uav": ("uav", 260), "naval_scout": ("heli", 0),
}
for k, (fl, tr) in FLIGHT.items():
    u = D["units"][k]
    u["flight"] = fl
    if tr:
        u["turn_radius"] = tr
    if fl in ("fighter", "strike", "drone"):
        u["sight_bonus"] = 520
    if fl == "orbit":
        u["sight_bonus"] = 300
D["units"]["scout_uav"]["ammo"] = -1

# ----------------------------------------------------------------------------- new units
def tmpl(**kw):
    base = {"layer": "ground", "armor": 0, "range": 0, "damage": 0, "cooldown": 1.0, "proj": "bullet", "targets": [],
            "deploy_cd": 2.0, "ai_tier": 0.3}
    base.update(kw)
    return base


D["units"]["supply_truck"] = tmpl(
    name="Supply Truck", tab="vehicles", role="logistics", shape="vehicle", cost=150, hp=260, armor=1, speed=82, size=40,
    drive="truck", seats=6, supply_cap=1200, supply_rate=45,
    desc="Logistics. Carries 1200 crates of ammunition and shells. Reloads friendly units around it, refills at a depot, factory or HQ. "
         "Keep one near every battle group.", ai_tier=0.35)
D["units"]["troop_truck"] = tmpl(
    name="Troop Truck", tab="vehicles", role="transport", shape="vehicle", cost=120, hp=240, armor=1, speed=88, size=40,
    drive="truck", seats=16, supply_cap=120, supply_rate=30,
    desc="Soft-skinned transport. Seats 16 infantry and is the fastest way to move them along roads. Order troops to board (RMB on it) "
         "and press U to dismount. Dies quickly under fire - keep it behind the front.", ai_tier=0.3)
D["units"]["transport_heli"] = tmpl(
    name="UH-60 Transport Helicopter", tab="air", role="transport", shape="air", cost=520, hp=380, armor=3, speed=165, size=77,
    flight="heli", seats=12, supply_cap=300, supply_rate=60, requires="airbase", radius_k=0.3, deploy_cd=4.0,
    desc="Air mobility. Lifts 12 infantry over rivers and fronts and drops them anywhere. Fragile: avoid enemy air defence.",
    ai_tier=0.8)

# new units need a sensible `ban` wherever the army has no helicopters
for fid, f in D["factions"].items():
    ban = f.get("ban", [])
    if "helicopter" in ban and "transport_heli" not in ban:
        ban.append("transport_heli")
    f["ban"] = ban

# ----------------------------------------------------------------------------- supply sources
SUPPLY = {
    "barracks": {"radius": 250, "rate": 0.07}, "factory": {"radius": 270, "rate": 0.07},
    "airbase": {"radius": 330, "rate": 0.09, "rearm": True}, "naval_port": {"radius": 320, "rate": 0.07},
    "supply_depot": {"radius": 360, "rate": 0.10}, "forward_base": {"radius": 300, "rate": 0.07},
}
for k, sp in SUPPLY.items():
    D["national"][k]["supply"] = sp
D["national"]["supply_depot"]["desc"] = "Stockpiles materiel: +3 income per second. Reloads every unit near it and refills supply trucks."
D["national"]["forward_base"]["desc"] += " Reloads friendly units nearby."
D["base"]["supply"] = {"radius": 340, "rate": 0.09, "rearm": True}
D["units"]["aircraft_carrier"]["supply"] = {"radius": 300, "rate": 0.08, "rearm": True}
D["units"]["aircraft_carrier"]["provides"] = D["units"]["aircraft_carrier"].get("provides", ["airbase"])
D["structures"]["repair_depot"]["supply"] = {"radius": 160, "rate": 0.04}

# ----------------------------------------------------------------------------- settings + logistics.json
S["model"] = "v7"
S["default_zoom"] = 1.25
S["zoom_max"] = 3.0
S["unit_cap"] = 170
S.setdefault("sector_income_mult", 1.0)
S["map"] = "dnieper"

LOGI = {
    "mobility": {
        "foot":      {"road": 1.20, "off": 1.00, "name": "On foot"},
        "wheeled":   {"road": 2.10, "off": 0.70, "name": "Wheeled"},
        "truck":     {"road": 2.20, "off": 0.55, "name": "Truck"},
        "tracked":   {"road": 1.50, "off": 0.95, "name": "Tracked"},
        "heavy":     {"road": 1.35, "off": 0.85, "name": "Heavy tracked"},
        "air":       {"road": 1.00, "off": 1.00, "name": "Air"},
        "ship":      {"road": 1.00, "off": 1.00, "name": "Naval"},
    },
    "ammo": {
        "low_fraction": 0.25,          # below this a unit asks for resupply (auto units head for a supply point)
        "empty_fraction": 0.0,
        "reload_rate": 0.07,           # fraction of a magazine restored per second inside a supply radius
        "supply_cost": {"infantry": 1.5, "vehicle": 5.0, "armor": 8.0, "artillery": 10.0, "air": 14.0, "ship": 25.0},
        "truck_search_radius": 1900,
        "truck_refill_below": 0.2,
    },
    "transport": {
        "board_range": 26,
        "dismount_range": 330,         # auto transports unload this close to the objective or to contact
        "wait_for_load": 18.0,         # seconds an empty auto transport waits at the factory for riders
        "survive_chance": 0.55,        # chance each rider survives when a ground transport is destroyed
        "heli_survive_chance": 0.12,
        "auto_board_radius": 520,
    },
    "flight": {
        "default_rearm_time": 10.0,
        "bingo_hp": 0.35,
        "takeoff_time": 1.4,
        "min_speed_factor": 0.72,
        "gun_cone_deg": {"fighter": 13, "strike": 16, "drone": 30, "orbit": 40, "bomber": 360},
    },
    "sectors": {
        "capture_rate": 5.0,           # meter points per second per unit of capture power in the zone
        "max_rate": 20.0,
        "own_at": 100.0,
        "power": {"infantry": 1.0, "vehicle": 1.4, "armor": 1.6, "ship": 0.0, "air": 0.0},
        "decay": 3.0,
    },
}
D["logistics"] = LOGI
df.save_all(D)
print("tuned. units:", len(D["units"]))
