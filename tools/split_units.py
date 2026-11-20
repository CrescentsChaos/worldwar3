#!/usr/bin/env python3
"""One-shot: split the legacy data/units.json into the data/ folder layout (see tools/datafiles.py).
Usage:  python3 tools/split_units.py [path/to/units.json]
The legacy file is moved to data/legacy/units.json.bak so nothing is lost."""
import json, os, shutil, sys
sys.path.insert(0, os.path.dirname(__file__))
import datafiles as df

src = sys.argv[1] if len(sys.argv) > 1 else os.path.join(df.DATA, "units.json")
old = json.load(open(src, encoding="utf-8"))
D = dict(old)
D["maps"] = {}
country = D.pop("country", [])
D["_country"] = country
save = {k: v for k, v in D.items() if not k.startswith("_")}
df.save_all(save)
df._write(os.path.join(df.DATA, "country.json"), country)
os.makedirs(os.path.join(df.DATA, "legacy"), exist_ok=True)
shutil.move(src, os.path.join(df.DATA, "legacy", "units.json.bak"))
back = df.load_all()
back["country"] = df._read(os.path.join(df.DATA, "country.json"))
for k, v in old.items():
    if back.get(k) != v:
        print("MISMATCH in", k)
        sys.exit(1)
print("split OK:", sorted(os.listdir(df.DATA)))
