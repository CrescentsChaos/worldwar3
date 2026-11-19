import sys, os, json, hashlib
sys.path.insert(0, os.path.dirname(__file__))
import numpy as np
from PIL import Image
import core, schemes, air
D = json.load(open(os.path.join(os.path.dirname(__file__), "..", "..", "data", "units.json")))
facs = ["wehrmacht","red_army","ija","british_army","us_army","french_army","italian_army","russian_gf"]
slots = sys.argv[1].split(",")
S = 110
sheet = Image.new("RGB", (S*len(slots), S*len(facs)), (52, 60, 38))
for fi, f in enumerate(facs):
    for si, s in enumerate(slots):
        r = D["factions"][f]["roster"].get(s)
        if not r: continue
        seed = int(hashlib.md5((f+s).encode()).hexdigest()[:8], 16)
        rng = np.random.default_rng(seed)
        cv = air.draw(f, s, r["name"], rng)
        sc = schemes.pick(f, "air", rng)
        im = core.finish(cv, sc, 256, rng).resize((S, S), Image.LANCZOS)
        sheet.paste(im, (si*S, fi*S), im)
sheet.save(sys.argv[2])
