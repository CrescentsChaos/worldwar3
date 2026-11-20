#!/usr/bin/env python3
"""Builds factions.<id>.roster in data/factions/<id>.json from tools/rosters/<id>.py.

Every roster entry is a complete, army-specific definition of one slot of the shared roster:
its own name, class, description, real-world spec line and stats. Anything not given is
inherited from the slot. Cost is derived from the final stats (so a better unit costs more)
unless `cost=` is given. Run from the project root:  python3 tools/build_rosters.py
"""
import json, math, importlib, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import datafiles as df
D = df.load_all()
GROUPS = {"unit": D["units"], "structure": D["structures"], "strategic": D["strategic"]}
SLOT = {}
for kind, g in GROUPS.items():
    for k, v in g.items():
        SLOT[k] = (kind, v)
# Manual cost corrections where the stat formula over/under-prices (rapid-fire AA guns, kamikazes).
COST = {("red_army","manpads"):130,("wehrmacht","manpads"):130,("italian_army","manpads"):115,("ija","manpads"):115,
 ("wehrmacht","drone"):170,("red_army","drone"):150,("ija","drone"):110,("ija","sam_truck"):430,("red_army","sam_truck"):400,
 ("wehrmacht","aa_truck"):330,("russian_gf","aa_truck"):340,("french_army","light_tank"):270,("british_army","light_tank"):250,
 ("red_army","howitzer"):900,("british_army","strike_jet"):380,("italian_army","heavy_tank"):330,("italian_army","gunship"):480}
ALIAS = {"ar": "armor", "sp": "speed", "rg": "range", "dm": "damage", "cd": "cooldown"}


def U(id, name, cls, desc, specs, **kw):
    e = {"name": name, "class": cls, "desc": desc, "specs": specs}
    for k, v in kw.items():
        e[ALIAS.get(k, k)] = v
    return id, e


def power(d, strategic=False):
    if strategic:
        return float(d["damage"]) * (1 + float(d.get("splash", 0)) / 260.0) * (max(float(d.get("speed", 300)), 50) / 300.0) ** 0.15
    dur = float(d["hp"]) * (1 + 0.045 * float(d.get("armor", 0)))
    dmg = float(d.get("damage", 0)); cd = max(float(d.get("cooldown", 1)), 0.05)
    dps = dmg / cd
    if d.get("kamikaze"):
        dps = dmg / 2.5
    fp = dps * (1 + float(d.get("splash", 0)) / 160.0) * (1 + float(d.get("pierce", 0)) / 80.0)
    if dmg == 0:
        h = d.get("heal", {}).get("rate", 0)
        fp = max(h * 6.0, 1.0)
    rf = (max(float(d.get("range", 40)), 40) / 200.0) ** 0.28
    sp = float(d.get("speed", 0))
    sf = (max(sp, 10) / 70.0) ** 0.10 if sp > 0 else 1.0
    return math.sqrt(dur) * math.sqrt(max(fp, 1.0)) * rf * sf


def rnd(c):
    if c < 100: return int(round(c / 5.0) * 5)
    if c < 1000: return int(round(c / 10.0) * 10)
    return int(round(c / 50.0) * 50)


def build(fid):
    mod = importlib.import_module("rosters." + fid)
    f = D["factions"][fid]
    roster = {}
    for id, e in mod.ROSTER:
        assert id in SLOT, (fid, id)
        kind, base = SLOT[id]
        d = json.loads(json.dumps(base)); d.update({k: v for k, v in e.items() if k not in ("name", "class", "desc", "specs")})
        strat = kind == "strategic"
        if (fid, id) in COST:
            e["cost"] = COST[(fid, id)]
        if "cost" not in e:
            ratio = power(d, strat) / power(base, strat)
            ratio = min(max(ratio, 0.35), 3.0)
            e["cost"] = rnd(float(base["cost"]) * ratio ** 0.9)
        e["sprite"] = "%s_%s" % (fid, id)      # unique per-army art: tools/fsprites/build_all.py
        roster[id] = e
    meta = getattr(mod, "META", {})
    for k, v in meta.items():
        f[k] = v
    f["roster"] = roster
    f["names"] = {k: v["name"] for k, v in roster.items()}
    banned = set(f.get("ban", []))
    missing = [k for k in SLOT if k not in roster and k not in banned]
    assert not missing, (fid, "missing", missing)
    for sid, s in f["strategies"].items():
        for en in s["setup"]:
            assert en[1] not in banned, (fid, sid, en[1])
    return len(roster)


if __name__ == "__main__":
    ids = sys.argv[1:] or list(D["factions"].keys())
    for fid in ids:
        try:
            n = build(fid); print(fid, n, "ok")
        except ModuleNotFoundError:
            print(fid, "no roster module yet")
    df.save_all(D)
