import sys, os, random, json, hashlib
sys.path.insert(0, os.path.dirname(__file__))
import numpy as np
from PIL import Image
import core, schemes, infantry
D = json.load(open(os.path.join(os.path.dirname(__file__), "..", "..", "data", "units.json")))
facs = ["wehrmacht","red_army","ija","british_army","us_army","french_army","italian_army","russian_gf"]
slots = ["rifleman","assault","bazooka","manpads","mg_gunner","grenadier","sniper","flamer","medic","engineer","commando"]
S = 96
sheet = Image.new("RGB", (S*len(slots), S*len(facs)), (52, 60, 38))
for fi, f in enumerate(facs):
    for si, s in enumerate(slots):
        r = D["factions"][f]["roster"][s]
        seed = int(hashlib.md5((f+s).encode()).hexdigest()[:8], 16)
        rng = np.random.default_rng(seed)
        cv = infantry.draw(f, s, r["name"], rng)
        sc = schemes.pick(f, "inf", rng)
        im = core.finish(cv, sc, 192, rng).resize((S, S), Image.LANCZOS)
        sheet.paste(im, (si*S, fi*S), im)
sheet.save("/tmp/inf.png")
