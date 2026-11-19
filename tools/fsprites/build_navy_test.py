import sys, os, json, hashlib
sys.path.insert(0, os.path.dirname(__file__))
import numpy as np
from PIL import Image
import core, schemes, navy
D = json.load(open(os.path.join(os.path.dirname(__file__), "..", "..", "data", "units.json")))
facs = ["wehrmacht","red_army","ija","british_army","us_army","french_army","italian_army","russian_gf"]
slots = sys.argv[1].split(",")
W, H = 200, 70
sheet = Image.new("RGB", (W*len(slots), H*len(facs)), (30, 52, 70))
for fi, f in enumerate(facs):
    for si, s in enumerate(slots):
        r = D["factions"][f]["roster"].get(s)
        if not r: continue
        seed = int(hashlib.md5((f+s).encode()).hexdigest()[:8], 16)
        rng = np.random.default_rng(seed)
        cv = navy.draw(f, s, r["name"], rng)
        sc = schemes.pick(f, "ship", rng)
        im = core.finish(cv, sc, 400, rng)
        bb = im.getbbox(); im = im.crop(bb); im.thumbnail((W-6, H-6), Image.LANCZOS)
        sheet.paste(im, (si*W+3, fi*H+3), im)
sheet.save(sys.argv[2])
