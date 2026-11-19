"""Aircraft: parameterised fuselage / wing / tail / engines plus rotorcraft and loitering munitions."""
import math
import re
from core import *

CY = 64.0
NOSE = 112.0

PROFILES = {
    "prop":   [(0.0, 0.25), (0.15, 0.55), (0.35, 1.0), (0.6, 1.0), (0.85, 0.7), (0.97, 0.38), (1.0, 0.1)],
    "radial": [(0.0, 0.25), (0.2, 0.6), (0.4, 1.0), (0.75, 1.0), (0.93, 0.95), (1.0, 0.7)],
    "jet":    [(0.0, 0.9), (0.2, 1.0), (0.5, 0.9), (0.8, 0.5), (0.95, 0.2), (1.0, 0.0)],
    "blunt":  [(0.0, 0.5), (0.15, 0.9), (0.5, 1.0), (0.85, 0.9), (0.96, 0.6), (1.0, 0.25)],
    "glass":  [(0.0, 0.3), (0.2, 0.8), (0.5, 1.0), (0.9, 0.85), (0.97, 0.7), (1.0, 0.4)],
    "bomber": [(0.0, 0.2), (0.25, 0.8), (0.5, 1.0), (0.85, 0.9), (0.97, 0.55), (1.0, 0.2)],
    "slab":   [(0.0, 0.8), (0.3, 1.0), (0.75, 1.0), (0.95, 0.6), (1.0, 0.2)],
}


def fuselage(c, L, fw, prof, fill=BODY):
    pts = PROFILES[prof]
    x0 = NOSE - L
    top = [(x0 + t * L, CY - fw * k) for t, k in pts]
    bot = [(x0 + t * L, CY + fw * k) for t, k in reversed(pts)]
    c.poly(top + bot, fill)
    return x0


def wing(c, x_le, fw, span, rc, tc, sweep, dihedral_kink=None, fill=BODY, flaps=True):
    """Both wings. x_le = leading-edge x at the root. sweep = how far (px) the tip LE is BEHIND the root LE."""
    for s in (-1, 1):
        root_le = (x_le, CY + s * fw * 0.6)
        root_te = (x_le - rc, CY + s * fw * 0.6)
        tip_le = (x_le - sweep, CY + s * span)
        tip_te = (x_le - sweep - tc, CY + s * span)
        if dihedral_kink:                         # inverted gull (Stuka)
            ky, kx = dihedral_kink
            mid_le = (x_le - sweep * 0.3, CY + s * (fw * 0.6 + (span - fw * 0.6) * ky))
            mid_te = (x_le - rc * 0.8 - sweep * 0.3, CY + s * (fw * 0.6 + (span - fw * 0.6) * ky))
            c.poly([root_le, mid_le, tip_le, tip_te, mid_te, root_te], fill)
        else:
            c.poly([root_le, tip_le, tip_te, root_te], fill)
        if flaps:
            c.line([(x_le - rc * 0.8, CY + s * (fw * 0.7)), (x_le - sweep - tc * 0.8, CY + s * span * 0.97)], EDGE, 0.8)
    c.mark("auto", x_le - sweep * 0.5 - rc * 0.45, CY - (fw * 0.6 + (span - fw * 0.6) * 0.62), min(7.0, span * 0.17))
    c.mark("auto", x_le - sweep * 0.5 - rc * 0.45, CY + (fw * 0.6 + (span - fw * 0.6) * 0.62), min(7.0, span * 0.17))


def tailplane(c, x_te, span, ch, sweep=3, fill=BODY):
    for s in (-1, 1):
        c.poly([(x_te + ch, CY + s * 2), (x_te + ch - sweep, CY + s * span), (x_te - sweep, CY + s * span), (x_te, CY + s * 2)], fill)


def prop_disc(c, x, y, r):
    c.ell(x - 1.6, y - r, x + 1.6, y + r, MID, edge=False)
    c.line([(x, y - r), (x, y + r)], DARK, 1.4)


def nacelle(c, x, y, L, w, kind="prop"):
    c.rect(x - L, y - w / 2, x, y + w / 2, MID, r=w * 0.4)
    if kind == "prop":
        prop_disc(c, x + 1, y, w * 1.9)
    elif kind == "jet":
        c.rect(x - L - 4, y - w * 0.42, x - L, y + w * 0.42, DARK, r=1)
    elif kind == "radial":
        c.circ(x, y, w * 0.62, DARK); prop_disc(c, x + 2, y, w * 1.9)


def canopy(c, x, w=3.0, L=9.0, fill=DARK):
    c.ell(x - L / 2, CY - w / 2, x + L / 2, CY + w / 2, fill)
    c.ell(x - L * 0.2, CY - w * 0.25, x + L * 0.1, CY - w * 0.05, LIGHT, edge=False)


# preset-driven fixed-wing: dict keys documented in PRESET
def plane(c, p):
    L = p["L"]; fw = p["fw"]
    x0 = fuselage(c, L, fw, p.get("prof", "jet"))
    wx = NOSE - L * p.get("wpos", 0.42)
    # tail first (under the wing)
    if p.get("tail", True):
        tailplane(c, x0 + L * 0.02, p.get("ts", 12), p.get("tc", 7), p.get("tsw", 3))
    if p.get("canard"):
        cs, cc = p["canard"]
        for s in (-1, 1):
            c.poly([(NOSE - L * 0.28, CY + s * fw * 0.5), (NOSE - L * 0.28 - cc, CY + s * cs), (NOSE - L * 0.28 - cc - 3, CY + s * cs), (NOSE - L * 0.28 - cc - 3, CY + s * fw * 0.5)], BODY)
    for e in p.get("eng", []):
        kind, ey, el, ew = e
        ex = wx - p.get("rc", 16) * 0.2 + (0 if kind != "jet" else -p.get("rc", 16) * 0.2)
        nacelle(c, ex + el * 0.3, CY + ey, el, ew, kind)
    wing(c, wx, fw, p["span"], p["rc"], p["tc"], p.get("sweep", 2), p.get("kink"), flaps=True)
    if p.get("twintail"):
        for s in (-1, 1):
            c.rect(x0 - 2, CY + s * p.get("twintail"), x0 + 14, CY + s * p.get("twintail") + 2.6 * s, MID, r=1)
    if p.get("intake"):
        for s in (-1, 1):
            c.rect(wx + 4, CY + s * (fw + 1.2) - 1.8, wx + 14, CY + s * (fw + 1.2) + 1.8, DARK, r=1)
    if p.get("nose_prop") == "prop":
        prop_disc(c, NOSE + 1, CY, p.get("pr", 13))
    elif p.get("nose_prop") == "radial":
        prop_disc(c, NOSE + 1, CY, p.get("pr", 13))
    canopy(c, NOSE - L * p.get("cpos", 0.42), fw * 0.7, L * 0.14)
    if p.get("nose_gun"):
        c.bar(NOSE - 4, CY, NOSE + 8, CY, 2.0, DARK)


P = dict
CAT = [
 # ---- fighters (WW2 piston)
 (r"Bf 109", P(L=70, fw=3.8, prof="prop", span=34, rc=15, tc=8, sweep=1, ts=11, tc_=0, wpos=0.45, nose_prop="prop", cpos=0.5, pr=11, eng=[])),
 (r"Fw 190", P(L=74, fw=5.2, prof="radial", span=36, rc=16, tc=8, sweep=1, ts=12, wpos=0.42, nose_prop="radial", cpos=0.46, pr=13)),
 (r"Ki-43|Ki-84", P(L=72, fw=4.8, prof="radial", span=38, rc=15, tc=7, sweep=0, ts=12, wpos=0.42, nose_prop="radial", cpos=0.46, pr=12)),
 (r"Yak-9", P(L=72, fw=3.8, prof="prop", span=33, rc=15, tc=8, sweep=1, ts=11, wpos=0.45, nose_prop="prop", cpos=0.5)),
 (r"La-7", P(L=70, fw=5.0, prof="radial", span=33, rc=15, tc=8, sweep=1, ts=12, wpos=0.42, nose_prop="radial", cpos=0.5)),
 (r"C.202|C.205", P(L=74, fw=4.0, prof="prop", span=34, rc=15, tc=7, sweep=1, ts=11, wpos=0.44, nose_prop="prop")),
 (r"Re.2005", P(L=72, fw=4.0, prof="prop", span=36, rc=17, tc=8, sweep=2, ts=12, wpos=0.45, nose_prop="prop")),
 # ---- early jets
 (r"Me 262", P(L=76, fw=4.2, prof="jet", span=40, rc=15, tc=8, sweep=10, ts=12, wpos=0.42, eng=[("jet", -9, 20, 6), ("jet", 9, 20, 6)])),
 (r"Yak-15", P(L=66, fw=4.4, prof="jet", span=36, rc=15, tc=8, sweep=2, ts=12, wpos=0.4, eng=[])),
 (r"Shusui", P(L=52, fw=4.0, prof="blunt", span=34, rc=16, tc=7, sweep=16, ts=0, wpos=0.45, tail=False)),
 # ---- modern fighters / strike
 (r"Typhoon", P(L=86, fw=4.6, prof="jet", span=34, rc=34, tc=0, sweep=26, ts=12, wpos=0.4, canard=(14, 8), intake=True)),
 (r"Rafale", P(L=84, fw=4.4, prof="jet", span=34, rc=34, tc=0, sweep=26, ts=12, wpos=0.4, canard=(14, 8), intake=True)),
 (r"F-16", P(L=84, fw=4.4, prof="jet", span=30, rc=28, tc=7, sweep=14, ts=14, wpos=0.34, intake=True)),
 (r"F-15C|F-15E", P(L=92, fw=6.4, prof="jet", span=38, rc=34, tc=10, sweep=22, ts=16, wpos=0.36, twintail=7, eng=[("jet", -6, 14, 6), ("jet", 6, 14, 6)])),
 (r"Mirage 2000", P(L=86, fw=4.6, prof="jet", span=34, rc=46, tc=0, sweep=34, ts=0, wpos=0.34, tail=False)),
 (r"Mirage IV", P(L=96, fw=5.0, prof="jet", span=36, rc=52, tc=0, sweep=38, ts=0, wpos=0.34, tail=False, eng=[("jet", -7, 12, 6), ("jet", 7, 12, 6)])),
 (r"MiG-31", P(L=98, fw=7.0, prof="jet", span=38, rc=36, tc=10, sweep=20, ts=16, wpos=0.36, twintail=8, eng=[("jet", -7, 16, 7), ("jet", 7, 16, 7)])),
 (r"Su-35|Su-34", P(L=96, fw=7.0, prof="slab", span=40, rc=34, tc=8, sweep=18, ts=16, wpos=0.36, twintail=9, eng=[("jet", -8, 16, 7), ("jet", 8, 16, 7)])),
 (r"Su-57", P(L=94, fw=6.0, prof="jet", span=36, rc=40, tc=8, sweep=24, ts=14, wpos=0.36, twintail=8, eng=[("jet", -8, 14, 7), ("jet", 8, 14, 7)])),
 (r"F-22", P(L=92, fw=5.8, prof="jet", span=34, rc=38, tc=6, sweep=26, ts=14, wpos=0.36, eng=[("jet", -6, 12, 6), ("jet", 6, 12, 6)])),
 (r"F-35", P(L=84, fw=5.4, prof="jet", span=34, rc=32, tc=7, sweep=18, ts=15, wpos=0.38)),
 (r"nEUROn", P(L=64, fw=5.0, prof="blunt", span=38, rc=46, tc=6, sweep=40, ts=0, wpos=0.45, tail=False)),
 (r"Tornado", P(L=92, fw=5.0, prof="jet", span=40, rc=30, tc=10, sweep=8, ts=14, wpos=0.38, eng=[])),
 (r"A-10", P(L=78, fw=4.6, prof="blunt", span=54, rc=22, tc=18, sweep=2, ts=16, wpos=0.42, twintail=12, eng=[("jet", -13, 18, 7), ("jet", 13, 18, 7)], nose_gun=True)),
 (r"Su-25", P(L=80, fw=4.2, prof="jet", span=44, rc=24, tc=12, sweep=6, ts=14, wpos=0.42, eng=[("jet", -7, 18, 6), ("jet", 7, 18, 6)])),
 # ---- WW2 attack
 (r"Stuka", P(L=64, fw=4.2, prof="radial", span=46, rc=18, tc=9, sweep=0, ts=12, wpos=0.44, nose_prop="prop", kink=(0.35, 0), cpos=0.4, pr=12)),
 (r"Il-2|Il-10", P(L=68, fw=5.0, prof="radial", span=44, rc=22, tc=11, sweep=2, ts=13, wpos=0.42, nose_prop="prop", pr=12)),
 (r"Ki-51|Ki-102", P(L=66, fw=4.2, prof="radial", span=44, rc=18, tc=9, sweep=1, ts=13, wpos=0.44, nose_prop="prop", pr=12)),
 (r"Ba.65|Ba.88", P(L=70, fw=4.4, prof="radial", span=46, rc=18, tc=9, sweep=1, ts=13, wpos=0.44, nose_prop="prop", pr=12)),
 (r"Hs 129", P(L=62, fw=4.6, prof="blunt", span=44, rc=18, tc=9, sweep=1, ts=12, wpos=0.44, eng=[("radial", -10, 14, 7), ("radial", 10, 14, 7)])),
 # ---- WW2 bombers
 (r"Ju 88|Ki-48|Pe-2", P(L=76, fw=5.2, prof="glass", span=50, rc=22, tc=11, sweep=2, ts=16, wpos=0.44, eng=[("prop", -14, 16, 6.4), ("prop", 14, 16, 6.4)])),
 (r"He 111|Tu-2|Ki-67|SM.79|Z.1007", P(L=80, fw=5.6, prof="glass", span=56, rc=24, tc=12, sweep=2, ts=18, wpos=0.44, eng=[("prop", -15, 16, 6.8), ("prop", 15, 16, 6.8)])),
 (r"He 177|Pe-8|Ki-91|P.108|Tu-4", P(L=92, fw=6.0, prof="bomber", span=66, rc=26, tc=12, sweep=2, ts=20, wpos=0.44, eng=[("prop", -16, 18, 6.6), ("prop", -30, 18, 6.6), ("prop", 16, 18, 6.6), ("prop", 30, 18, 6.6)])),
 (r"Ho 229", P(L=48, fw=5.0, prof="blunt", span=56, rc=42, tc=10, sweep=26, ts=0, wpos=0.46, tail=False)),
 (r"Fugaku", P(L=100, fw=7.0, prof="bomber", span=80, rc=36, tc=16, sweep=2, ts=22, wpos=0.44, eng=[("prop", -14, 20, 6.8), ("prop", -28, 20, 6.8), ("prop", -42, 20, 6.8), ("prop", 14, 20, 6.8), ("prop", 28, 20, 6.8), ("prop", 42, 20, 6.8)])),
 # ---- modern bombers
 (r"B-1B", P(L=100, fw=5.6, prof="jet", span=50, rc=34, tc=14, sweep=24, ts=16, wpos=0.4, eng=[("jet", -9, 16, 7), ("jet", 9, 16, 7)])),
 (r"B-52", P(L=100, fw=5.0, prof="bomber", span=62, rc=26, tc=10, sweep=26, ts=22, wpos=0.42, eng=[("jet", -14, 16, 5.6), ("jet", -26, 16, 5.6), ("jet", -38, 16, 5.6), ("jet", 14, 16, 5.6), ("jet", 26, 16, 5.6), ("jet", 38, 16, 5.6)])),
 (r"Tu-22M", P(L=98, fw=6.0, prof="jet", span=44, rc=36, tc=14, sweep=30, ts=16, wpos=0.4)),
 (r"Tu-160", P(L=104, fw=6.6, prof="jet", span=52, rc=40, tc=16, sweep=36, ts=18, wpos=0.4)),
 (r"B-2|Tempest|SCAF|PAK DA", P(L=60, fw=6.0, prof="blunt", span=62, rc=44, tc=8, sweep=30, ts=0, wpos=0.5, tail=False)),
]


HELI = [
 (r"Mi-1", dict(body="bubble", L=40, w=9, boom=34, bw=3, rotor=40, blades=3, tail="rotor", skids=True)),
 (r"Ka-1", dict(body="autogyro", L=36, w=8, boom=24, rotor=46, blades=2, tail="fin", prop=True)),
 (r"Wildcat", dict(body="slim", L=52, w=9, boom=36, bw=3.4, rotor=42, blades=4, tail="rotor", skids=True, stub=0)),
 (r"Apache", dict(body="tandem", L=54, w=8, boom=42, bw=3, rotor=44, blades=4, tail="rotor", stub=22, pods=2, chin=True, stab=True)),
 (r"Tigre", dict(body="tandem", L=50, w=7, boom=38, bw=2.8, rotor=42, blades=4, tail="fen", stub=20, pods=2, chin=True, stab=True)),
 (r"Ka-52", dict(body="wide", L=46, w=11, boom=22, bw=3, rotor=44, blades=3, coax=True, tail="none", stub=24, pods=2)),
 (r"Mi-28", dict(body="tandem", L=56, w=8.5, boom=40, bw=3, rotor=46, blades=5, tail="x", stub=22, pods=2, chin=True)),
]


def helicopter(c, name, rng):
    if re.search(r"Fl 282", name):          # intermeshing synchropter
        c.ell(30, 58, 82, 70, BODY); c.bar(24, 64, 58, 64, 3.0, DARK)
        c.ell(36, 55, 60, 73, MID, edge=False)
        for off in (-10, 10):
            c.ell(34, 64 + off - 3.2, 88, 64 + off + 3.2, MID)
        c.line([(30, 64), (36, 64)], DARK, 1.5)
        c.mark("auto", 52, 64, 3)
        return
    p = None
    for rx, d in HELI:
        if re.search(rx, name):
            p = dict(d)
            break
    if p is None:
        c.fb = True
        p = dict(body="slim", L=50, w=9, boom=36, bw=3, rotor=42, blades=4, tail="rotor")
    perturb(p, rng, ("L", "w", "boom", "rotor", "stub"), 0.06)
    cx, L, w = 70.0, p["L"], p["w"]
    x_nose, x_tail = cx + L * 0.5, cx - L * 0.5
    b = p["body"]
    # tail boom
    c.bar(x_tail + 4, 64, x_tail - p["boom"], 64, p.get("bw", 3), MID if b != "autogyro" else DARK)
    if p.get("stab"):
        c.rect(x_tail - p["boom"] + 2, 64 - 9, x_tail - p["boom"] + 8, 64 + 9, MID, r=1)
    if p.get("tail") == "fin":
        c.poly([(x_tail - p["boom"], 64 - 8), (x_tail - p["boom"] + 6, 64), (x_tail - p["boom"], 64 + 8)], MID)
    elif p.get("tail") == "fen":
        c.circ(x_tail - p["boom"], 64, 5.5, DARK); c.circ(x_tail - p["boom"], 64, 2.4, MID, edge=False)
    elif p.get("tail") == "x":
        for ang in (0.6, 2.5):
            c.bar(x_tail - p["boom"] - 7 * math.cos(ang), 64 - 7 * math.sin(ang), x_tail - p["boom"] + 7 * math.cos(ang), 64 + 7 * math.sin(ang), 2.0, MID)
    elif p.get("tail") == "rotor":
        c.line([(x_tail - p["boom"], 64 - 8), (x_tail - p["boom"], 64 + 8)], MID, 1.8); c.circ(x_tail - p["boom"], 64, 1.8, DARK)
    # stub wings with weapon pylons
    if p.get("stub"):
        for sgn in (-1, 1):
            c.poly([(cx + 4, 64 + sgn * w * 0.6), (cx + 2, 64 + sgn * p["stub"]), (cx - 10, 64 + sgn * p["stub"]), (cx - 8, 64 + sgn * w * 0.6)], BODY)
            for k in range(int(p.get("pods", 0))):
                yy = 64 + sgn * (p["stub"] * (0.5 + 0.4 * k))
                c.rect(cx - 12, yy - 2.3, cx + 8, yy + 2.3, DARK, r=1.2)
    # fuselage
    if b == "tandem":
        c.poly([(x_tail, 64 - w * 0.5), (cx, 64 - w * 0.8), (x_nose - 8, 64 - w * 0.45), (x_nose, 64), (x_nose - 8, 64 + w * 0.45), (cx, 64 + w * 0.8), (x_tail, 64 + w * 0.5)], BODY)
        c.ell(x_nose - 22, 64 - 2.6, x_nose - 8, 64 + 2.6, DARK); c.ell(x_nose - 40, 64 - 2.6, x_nose - 26, 64 + 2.6, DARK)
    elif b == "wide":
        c.poly([(x_tail, 64 - w * 0.6), (cx, 64 - w), (x_nose - 6, 64 - w * 0.7), (x_nose, 64), (x_nose - 6, 64 + w * 0.7), (cx, 64 + w), (x_tail, 64 + w * 0.6)], BODY)
        c.ell(x_nose - 22, 64 - 6, x_nose - 4, 64 + 6, DARK)
    elif b == "bubble":
        c.ell(x_tail + 2, 64 - w, x_nose, 64 + w, BODY); c.circ(x_nose - 8, 64, w * 0.8, DARK)
    elif b == "autogyro":
        c.ell(x_tail, 64 - w * 0.7, x_nose, 64 + w * 0.7, BODY); c.ell(x_nose - 18, 64 - 3, x_nose - 6, 64 + 3, DARK)
    else:
        c.poly([(x_tail, 64 - w * 0.5), (cx, 64 - w), (x_nose - 8, 64 - w * 0.6), (x_nose, 64), (x_nose - 8, 64 + w * 0.6), (cx, 64 + w), (x_tail, 64 + w * 0.5)], BODY)
        c.ell(x_nose - 18, 64 - 4, x_nose - 4, 64 + 4, DARK)
    if p.get("chin"):
        c.rect(x_nose - 2, 64 - 1.6, x_nose + 10, 64 + 1.6, DARK, r=1)
    if p.get("prop"):
        c.line([(x_nose + 2, 64 - 12), (x_nose + 2, 64 + 12)], DARK, 2.0)
    if p.get("skids"):
        for sgn in (-1, 1):
            c.bar(cx - L * 0.3, 64 + sgn * (w + 1.5), cx + L * 0.3, 64 + sgn * (w + 1.5), 1.6, DARK)
    # rotor disc blades
    r = p["rotor"]
    mx = cx + float(p.get("mast", 0))
    nb = int(p["blades"])
    base = float(rng.uniform(0, math.pi))
    for layer in ((0.0, 1.0), (math.pi / max(nb, 1) * 0.5, 0.82)) if p.get("coax") else ((0.0, 1.0),):
        off, k = layer
        for i in range(nb):
            ang = base + off + i * math.pi * 2 / nb
            c.bar(mx, 64, mx + math.cos(ang) * r * k, 64 + math.sin(ang) * r * k, 2.6, MID, edge=True)
    c.circ(mx, 64, 3.4, DARK)
    c.mark("auto", cx - 4, 64 + w * 0.2, 3.2)


def loitering(c, name, rng):
    if re.search(r"Mistel", name):
        c.poly([(18, 64), (40, 60), (100, 60), (116, 64), (100, 68), (40, 68)], BODY)
        for s in (-1, 1):
            c.poly([(66, 64 + s * 4), (50, 64 + s * 44), (36, 64 + s * 44), (44, 64 + s * 4)], BODY)
        c.poly([(40, 64), (30, 64 - 14), (24, 64 - 14), (30, 64)], BODY); c.poly([(40, 64), (30, 64 + 14), (24, 64 + 14), (30, 64)], BODY)
        c.ell(58, 59, 98, 69, MID); c.poly([(88, 64), (110, 64 - 4), (110, 64 + 4)], DARK)
        for s in (-1, 1):
            c.poly([(76, 64 + s * 2), (68, 64 + s * 22), (62, 64 + s * 22), (66, 64 + s * 2)], LIGHT)
        c.mark("auto", 46, 64 - 30, 5); c.mark("auto", 46, 64 + 30, 5)
    elif re.search(r"TB-3", name):
        c.poly([(14, 64), (30, 58), (98, 58), (116, 64), (98, 70), (30, 70)], BODY)
        c.poly([(80, 62), (40, 8), (18, 8), (30, 62)], BODY); c.poly([(80, 66), (40, 120), (18, 120), (30, 66)], BODY)
        for yy in (22, 40): c.rect(52, yy, 70, yy + 7, MID, r=2); c.rect(52, 128 - yy - 7, 70, 128 - yy, MID, r=2)
        c.mark("auto", 36, 34, 6); c.mark("auto", 36, 94, 6)
    elif re.search(r"Ohka|MXY", name):
        c.poly([(34, 64), (50, 61), (96, 60), (112, 64), (96, 68), (50, 67)], BODY)
        for s in (-1, 1):
            c.poly([(70, 64 + s * 3), (62, 64 + s * 18), (50, 64 + s * 18), (56, 64 + s * 3)], BODY)
        c.rect(30, 62, 36, 66, DARK, r=1); c.mark("auto", 58, 64 - 12, 3)
    elif re.search(r"Lancet", name):
        c.poly([(24, 64), (40, 62), (98, 61), (112, 64), (98, 67), (40, 66)], BODY)
        for yy in (-1, 1):
            c.poly([(34, 64 + yy * 2), (24, 64 + yy * 26), (14, 64 + yy * 26), (22, 64 + yy * 2)], BODY)
            c.poly([(84, 64 + yy * 2), (74, 64 + yy * 18), (66, 64 + yy * 18), (72, 64 + yy * 2)], BODY)
        c.mark("auto", 52, 64, 3)
    elif re.search(r"Switchblade", name):
        c.poly([(30, 64), (44, 62), (98, 61), (112, 64), (98, 67), (44, 66)], BODY)
        for s in (-1, 1):
            c.poly([(70, 64 + s * 2), (60, 64 + s * 24), (50, 64 + s * 24), (56, 64 + s * 2)], MID)
        c.rect(26, 62, 32, 66, DARK, r=1)
    elif re.search(r"Hero", name):
        c.poly([(26, 64), (40, 61), (98, 60), (112, 64), (98, 68), (40, 67)], BODY)
        for s in (-1, 1):
            c.poly([(64, 64 + s * 3), (52, 64 + s * 30), (36, 64 + s * 30), (48, 64 + s * 3)], BODY)
        c.rect(22, 62, 28, 66, DARK, r=1)
    else:                                  # Larinae and generic
        c.poly([(24, 64), (38, 61), (96, 60), (112, 64), (96, 68), (38, 67)], BODY)
        for s in (-1, 1):
            c.poly([(70, 64 + s * 3), (58, 64 + s * 28), (46, 64 + s * 28), (54, 64 + s * 3)], BODY)
            c.poly([(34, 64 + s * 2), (26, 64 + s * 14), (20, 64 + s * 14), (26, 64 + s * 2)], BODY)
        c.mark("auto", 56, 64, 3)


def special(c, name, slot, rng):
    if re.search(r"MQ-9", name):
        c.poly([(24, 64), (40, 61), (98, 60), (112, 64), (98, 68), (40, 67)], BODY)
        for s in (-1, 1):
            c.poly([(70, 64 + s * 3), (62, 64 + s * 58), (52, 64 + s * 58), (58, 64 + s * 3)], BODY)
            c.poly([(30, 64 + s * 2), (20, 64 + s * 12), (14, 64 + s * 12), (24, 64 + s * 2)], BODY)
        c.circ(100, 64, 4, DARK); c.rect(22, 61, 27, 67, DARK, r=1)
        c.mark("auto", 56, 64 - 36, 5); c.mark("auto", 56, 64 + 36, 5)
        return True
    if re.search(r"AC-130", name):
        c.poly([(8, 64), (30, 58), (100, 58), (118, 64), (100, 70), (30, 70)], BODY)
        for s in (-1, 1):
            c.poly([(76, 64 + s * 4), (66, 64 + s * 52), (46, 64 + s * 52), (52, 64 + s * 4)], BODY)
            for k in (16, 36):
                c.rect(54, 64 + s * k - 3, 78, 64 + s * k + 3, MID, r=2); prop_disc(c, 79, 64 + s * k, 8)
            c.poly([(20, 64 + s * 2), (10, 64 + s * 20), (2, 64 + s * 20), (10, 64 + s * 2)], BODY)
        c.bar(60, 58, 72, 52, 2.4, DARK)
        c.mark("auto", 60, 64 - 44, 5); c.mark("auto", 60, 64 + 44, 5)
        return True
    return False


def draw(faction, slot, name, rng):
    c = Canvas()
    if slot == "drone":
        loitering(c, name, rng)
        return c
    if slot in ("helicopter", "gunship") and re.search(r"Apache|Tigre|Mi-28|Ka-52|Mi-1|Ka-1|Wildcat|Fl 282", name):
        helicopter(c, name, rng)
        return c
    if special(c, name, slot, rng):
        return c
    spec = None
    for rx, p in CAT:
        if re.search(rx, name):
            spec = dict(p)
            break
    if spec is None:
        c.fb = True
        spec = dict(L=76, fw=4.4, prof="jet", span=34, rc=24, tc=8, sweep=8, ts=12, wpos=0.4)
    perturb(spec, rng, ("L", "fw", "span", "rc", "tc", "sweep", "ts", "pr"), 0.08, ("wpos", "cpos"), 0.03)
    spec.setdefault("tc", 8)
    if "tc_" in spec:
        spec.pop("tc_")
    plane(c, spec)
    return c
