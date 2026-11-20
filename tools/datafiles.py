"""Shared loader / writer for the split game data (data/*.json).

The game used to keep everything in one 350 KB data/units.json. It is now split so each file is
small enough to edit by hand:

  data/settings.json            settings, tabs, capabilities, base (capital)
  data/logistics.json           road / off-road mobility, ammo, supply, transport, flight, sector tuning
  data/projectiles.json         projectile types
  data/national.json            country buildings
  data/strategic.json           missiles / nukes
  data/units/<tab>.json         infantry.json, vehicles.json, air.json, navy.json (one file per card tab)
  data/structures/<tab>.json    defenses.json, traps.json
  data/factions/<army>.json     one file per army (roster, strategies, perks)
  data/maps/<map>.json          one file per battlefield (terrain, roads, sectors, country layout)

load_all() returns one merged dict with the same shape the old units.json had (plus "maps" and
"logistics"), save_all() writes it back into the split files. GameData (scripts/autoload/game_data.gd)
merges the folders the same way at run time, so both always agree.
"""
import json
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DATA = os.path.join(ROOT, "data")

PLAIN = {"projectiles": "projectiles.json", "national": "national.json", "strategic": "strategic.json"}
GROUP_DIRS = {"units": "units", "structures": "structures"}
SETTINGS_KEYS = ["settings", "tabs", "capabilities", "base"]


def _read(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def _write(path, obj, indent=1):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(obj, f, indent=indent, ensure_ascii=False)
        f.write("\n")


def _read_dir(sub):
    out = {}
    folder = os.path.join(DATA, sub)
    if not os.path.isdir(folder):
        return out
    for name in sorted(os.listdir(folder)):
        if name.endswith(".json"):
            out[name[:-5]] = _read(os.path.join(folder, name))
    return out


def load_all():
    D = {}
    D.update(_read(os.path.join(DATA, "settings.json")))
    if os.path.exists(os.path.join(DATA, "logistics.json")):
        D["logistics"] = _read(os.path.join(DATA, "logistics.json"))
    for key, fn in PLAIN.items():
        D[key] = _read(os.path.join(DATA, fn))
    for key, sub in GROUP_DIRS.items():
        merged = {}
        for _stem, part in _read_dir(sub).items():
            merged.update(part)
        D[key] = merged
    D["factions"] = _read_dir("factions")
    D["maps"] = _read_dir("maps")
    return D


def save_all(D):
    _write(os.path.join(DATA, "settings.json"), {k: D[k] for k in SETTINGS_KEYS if k in D})
    if "logistics" in D:
        _write(os.path.join(DATA, "logistics.json"), D["logistics"], 1)
    for key, fn in PLAIN.items():
        _write(os.path.join(DATA, fn), D[key])
    for key, sub in GROUP_DIRS.items():
        by_tab = {}
        for k, v in D[key].items():
            by_tab.setdefault(v.get("tab", "misc"), {})[k] = v
        folder = os.path.join(DATA, sub)
        for stem, part in by_tab.items():
            _write(os.path.join(folder, stem + ".json"), part)
        # drop files of tabs that no longer exist
        for name in os.listdir(folder):
            if name.endswith(".json") and name[:-5] not in by_tab:
                os.remove(os.path.join(folder, name))
    for fid, f in D["factions"].items():
        _write(os.path.join(DATA, "factions", fid + ".json"), f)
    for mid, m in D.get("maps", {}).items():
        _write(os.path.join(DATA, "maps", mid + ".json"), m)
