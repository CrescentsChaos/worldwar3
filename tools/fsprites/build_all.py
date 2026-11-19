#!/usr/bin/env python3
"""Generates one unique sprite per unit per army: assets/sprites/<faction>_<slot>.png (+ prints fallbacks).

Run from the project root:   python3 tools/fsprites/build_all.py
Then `python3 tools/build_rosters.py` links every roster entry to its sprite (sprite = <faction>_<slot>).
"""
import sys, os, json, hashlib, time
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import numpy as np
from PIL import Image
import core, schemes, infantry, vehicles, air, navy, defenses, missiles

ROOT = os.path.join(HERE, "..", "..")
D = json.load(open(os.path.join(ROOT, "data", "units.json")))
OUT = os.path.join(ROOT, "assets", "sprites")

INF = {"rifleman", "assault", "bazooka", "manpads", "mg_gunner", "grenadier", "sniper", "flamer", "medic", "engineer", "commando", "diver"}
VEH = {"jeep", "armored_car", "apc", "light_tank", "tank", "heavy_tank", "mammoth", "tank_destroyer", "flame_tank", "artillery", "howitzer",
       "mlrs", "aa_truck", "sam_truck", "repair_vehicle"}
AIR = {"drone", "fighter", "interceptor_jet", "stealth_fighter", "strike_jet", "helicopter", "gunship", "light_bomber", "bomber", "heavy_bomber", "stealth_bomber"}
NAV = {"patrol_boat", "gunboat", "missile_boat", "destroyer", "cruiser", "battleship", "submarine", "aircraft_carrier"}
STR = {"tactical_missile", "cruise_missile", "cluster_missile", "bunker_buster", "ballistic_missile", "hypersonic", "tactical_nuke", "nuke", "mega_nuke"}
SIZE = {"inf": 176, "veh": 256, "air": 256, "nav": 384, "def": 224, "mis": 256}


def family(slot):
    if slot in INF: return "inf"
    if slot in VEH: return "veh"
    if slot in AIR: return "air"
    if slot in NAV: return "nav"
    if slot in STR: return "mis"
    return "def"


def build_one(fid, slot, name):
    fam = family(slot)
    seed = int(hashlib.md5((fid + ":" + slot + ":" + name).encode()).hexdigest()[:8], 16)
    rng = np.random.default_rng(seed)
    mod = {"inf": infantry, "veh": vehicles, "air": air, "nav": navy, "def": defenses, "mis": missiles}[fam]
    cv = mod.draw(fid, slot, name, rng) if fam != "inf" else mod.draw(fid, slot, name, rng)
    cat = {"inf": "inf", "veh": "ground", "air": "air", "nav": "ship", "def": "struct", "mis": "missile"}[fam]
    sc = schemes.pick(fid, cat, rng)
    if slot == "diver":
        sc = core.Scheme(base=(0.16, 0.2, 0.24), camo=[], style="none")
    im = core.finish(cv, sc, SIZE[fam], rng)
    return im, cv.fb


def main():
    os.makedirs(OUT, exist_ok=True)
    t0 = time.time()
    n = 0
    fallbacks = []
    for fid, f in D["factions"].items():
        for slot, r in f["roster"].items():
            im, fb = build_one(fid, slot, r["name"])
            im.save(os.path.join(OUT, "%s_%s.png" % (fid, slot)), optimize=True)
            n += 1
            if fb:
                fallbacks.append((fid, slot, r["name"]))
    print("wrote", n, "sprites in %.0fs" % (time.time() - t0))
    print("generic fallbacks:", len(fallbacks))
    for fb in fallbacks:
        print("  ", fb)


if __name__ == "__main__":
    main()
