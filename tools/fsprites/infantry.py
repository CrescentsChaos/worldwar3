"""Top-down infantry: helmet + kit are army specific, weapon comes from the unit's real-world identity."""
import math
import re
from core import *

HELMET = {"wehrmacht": "stahl", "red_army": "ssh40", "ija": "type90", "british_army": "mk7",
          "us_army": "ach", "french_army": "f2", "italian_army": "m33", "russian_gf": "6b47"}
PACK = {"wehrmacht": "ystrap", "red_army": "bedroll", "ija": "bigpack", "british_army": "bergen",
        "us_army": "molle", "french_army": "bag", "italian_army": "zaino", "russian_gf": "ratnik"}

# (regex on name, weapon kind, options). First match wins; falls back to the slot default.
SPEC = [
    (r"Kar98k ZF39|Mosin PU|Type 97 Sniper|Carcano Cecchino", "sniper", dict(length=58, scope=True)),
    (r"M107|Hecate", "sniper", dict(length=66, scope=True, brake=True, heavy=True)),
    (r"L115|SV-98", "sniper", dict(length=62, scope=True, bipod=True)),
    (r"Kar98k|Mosin|Carcano|Type 99", "rifle", dict(length=54)),
    (r"StG 44", "assault", dict(mag="curve", length=38)),
    (r"PPSh", "smg", dict(drum=True, length=30)),
    (r"Type 100|MAB 38", "smg", dict(drum=False, length=30)),
    (r"L22A2|Mk18|AKS-74U", "assault", dict(mag="short", length=30)),
    (r"FELIN Grenadier", "ugl", dict()),
    (r"FAMAS|FELIN", "bullpup", dict(length=32, optic=True)),
    (r"L85|HK416|M4A1|AK-12", "assault", dict(mag="straight", length=38, optic=True)),
    (r"Panzerschreck", "tube", dict(length=70, shield=True)),
    (r"PTRD|Solothurn", "sniper", dict(length=74, heavy=True, bipod=True, brake=True, scope=False)),
    (r"Type 4 70", "tube", dict(length=44, bulb=True)),
    (r"NLAW", "tube", dict(length=56, sight=True)),
    (r"Javelin", "atgm", dict()),
    (r"Eryx|MMP", "tube", dict(length=52, tripod=True)),
    (r"RPG-7", "tube", dict(length=50, bulb=True)),
    (r"MG 34 AA|DShK|Maxim|Type 92 AA|Breda 20", "aa_mg", dict()),
    (r"Starstreak", "tube", dict(length=56, sight=True, head=True)),
    (r"Stinger|Igla|Mistral", "tube", dict(length=58, head=True)),
    (r"MG 42|MG 34", "gpmg", dict(belt=True)),
    (r"DP-27", "lmg", dict(pan=True)),
    (r"Type 96 LMG", "lmg", dict(hopper=True)),
    (r"Breda 30", "lmg", dict(strip=True)),
    (r"L7A2|M240|PKM|MAG 58", "gpmg", dict(belt=True)),
    (r"Minimi", "lmg", dict(box=True)),
    (r"Sturmpionier", "satchel", dict()),
    (r"RGD-33|SRCM", "grenades", dict()),
    (r"Knee Mortar", "kneemortar", dict()),
    (r"UGL|M320|GP-34", "ugl", dict()),
    (r"FELIN Grenadier", "ugl", dict()),
    (r"Flammenwerfer|ROKS|Type 93 Flame|Lanciafiamme", "flame", dict()),
    (r"Carl Gustaf|SMAW|LRAC|Shmel", "tube", dict(length=60, bulb=True, heavy=True)),
    (r"Medic|Sanitar|Sanitaeter|Sanitari", "medic", dict()),
    (r"Engineer|Sapper|Pionier|Genie|Genio", "engineer", dict()),
    (r"FG 42", "assault", dict(mag="side", length=44)),
    (r"Razvedchik|Giretsu|Spetsnaz|Raider", "smg", dict(drum=False, length=28, suppressor=True)),
    (r"SAS|CAG|Delta|Hubert|Legion|Folgore|SBS|SEAL", "assault", dict(mag="short", length=32, optic=True, suppressor=True)),
]
SLOT_DEFAULT = {"rifleman": ("rifle", {}), "assault": ("assault", {}), "bazooka": ("tube", {}), "manpads": ("tube", dict(head=True)),
                "mg_gunner": ("gpmg", {}), "grenadier": ("ugl", {}), "sniper": ("sniper", {}), "flamer": ("flame", {}),
                "medic": ("medic", {}), "engineer": ("engineer", {}), "commando": ("assault", {}), "diver": ("diver", {})}


def weapon(c, kind, o, rng):
    x0, y = 66, 62
    L = o.get("length", 40)
    if kind in ("rifle", "sniper"):
        if o.get("heavy"):
            c.rect(x0 + 2, y - 2.6, x0 + 18, y + 2.6, DARK, edge=True)
        c.rect(x0, y - 2.5, x0 + 16, y + 2.5, MID, edge=True)                 # stock
        c.bar(x0 + 14, y, x0 + L, y, 2.2 if not o.get("heavy") else 3.0, DARK)  # barrel
        if kind == "sniper" and o.get("scope", True):
            c.rect(x0 + 18, y - 5.2, x0 + 34, y - 2.2, DARK, r=1)             # scope
            c.rect(x0 + 18, y - 4.6, x0 + 20, y - 2.8, LIGHT, edge=False)
        if o.get("bipod"):
            c.line([(x0 + L * 0.7, y), (x0 + L * 0.8, y - 7)], DARK, 1.2); c.line([(x0 + L * 0.7, y), (x0 + L * 0.8, y + 7)], DARK, 1.2)
        if o.get("brake"):
            c.rect(x0 + L - 2, y - 3, x0 + L + 4, y + 3, DARK, r=1)
        if kind == "rifle" and L > 50 and not o.get("heavy"):
            c.bar(x0 + L, y, x0 + L + 9, y, 1.3, LIGHT)                       # bayonet
    elif kind == "assault":
        mag = o.get("mag", "straight")
        c.rect(x0, y - 2.8, x0 + 14, y + 2.8, MID)
        c.bar(x0 + 12, y, x0 + L, y, 2.6, DARK)
        c.rect(x0 + 12, y - 3.4, x0 + 24, y + 3.4, DARK, r=1)                  # receiver
        if mag == "curve":
            c.poly([(x0 + 18, y + 3), (x0 + 24, y + 3), (x0 + 28, y + 11), (x0 + 23, y + 11)], DARK)
        elif mag == "side":
            c.rect(x0 + 14, y - 11, x0 + 21, y - 3, DARK)
        elif mag == "short":
            c.rect(x0 + 18, y + 3, x0 + 23, y + 8, DARK)
        else:
            c.rect(x0 + 19, y + 3, x0 + 24, y + 10, DARK)
        if o.get("optic"):
            c.rect(x0 + 14, y - 5.4, x0 + 24, y - 2.6, DARK, r=1)
        if o.get("suppressor"):
            c.rect(x0 + L, y - 2.6, x0 + L + 10, y + 2.6, DARK, r=1)
    elif kind == "bullpup":
        c.rect(x0 - 4, y - 3.5, x0 + 26, y + 3.5, MID, r=1.5)
        c.bar(x0 + 24, y, x0 + L + 8, y, 2.4, DARK)
        c.rect(x0 + 8, y - 5.4, x0 + 18, y - 3, DARK, r=1)
        c.rect(x0 + 8, y + 3.5, x0 + 13, y + 9, DARK)
    elif kind == "smg":
        c.rect(x0, y - 2.6, x0 + 10, y + 2.6, MID)
        c.rect(x0 + 8, y - 3.2, x0 + 22, y + 3.2, DARK, r=1)
        c.bar(x0 + 22, y, x0 + L, y, 2.4, DARK)
        if o.get("drum"):
            c.circ(x0 + 16, y + 6.5, 5.6, MID)
            c.circ(x0 + 16, y + 6.5, 2.2, DARK)
        else:
            c.rect(x0 + 14, y + 3, x0 + 18, y + 12, DARK)
        if o.get("suppressor"):
            c.rect(x0 + L, y - 2.8, x0 + L + 9, y + 2.8, DARK, r=1)
    elif kind in ("gpmg", "lmg"):
        c.rect(x0 - 2, y - 3, x0 + 14, y + 3, MID)
        c.rect(x0 + 10, y - 4, x0 + 26, y + 4, DARK, r=1)
        c.bar(x0 + 24, y, x0 + 52, y, 3.2, DARK)
        c.rect(x0 + 40, y - 5, x0 + 52, y + 5, MID, r=1.5, edge=True)              # barrel shroud
        c.line([(x0 + 40, y), (x0 + 48, y - 9)], DARK, 1.4); c.line([(x0 + 40, y), (x0 + 48, y + 9)], DARK, 1.4)  # bipod
        if o.get("belt"):
            c.rect(x0 + 12, y + 4, x0 + 22, y + 12, MID, r=1)
            c.line([(x0 + 14, y + 4), (x0 + 12, y + 1)], ACC, 1.4)
        if o.get("pan"):
            c.circ(x0 + 17, y, 7.5, MID); c.circ(x0 + 17, y, 3, DARK)
        if o.get("hopper"):
            c.rect(x0 + 12, y - 9, x0 + 22, y - 3, DARK, r=1)
        if o.get("strip"):
            c.rect(x0 + 12, y + 3, x0 + 26, y + 6, MID)
        if o.get("box"):
            c.rect(x0 + 12, y + 3, x0 + 24, y + 12, MID, r=1.5)
    elif kind == "tube":
        tx0 = x0 - 28
        c.bar(tx0, y - 1, tx0 + L, y - 1, 6.2 if o.get("heavy") else 5.2, MID)
        c.rect(tx0 - 3, y - 5.4, tx0 + 3, y + 3.4, DARK, r=1)                  # rear flare
        c.circ(tx0 + L, y - 1, 3.2, DARK)
        if o.get("bulb"):
            c.ell(tx0 + L - 2, y - 7.5, tx0 + L + 12, y + 5.5, DARK)
        if o.get("head"):
            c.poly([(tx0 + L, y - 3.6), (tx0 + L + 8, y - 1), (tx0 + L, y + 1.6)], DARK)
        if o.get("sight"):
            c.rect(tx0 + L * 0.35, y - 7.8, tx0 + L * 0.55, y - 4, DARK, r=1)
        if o.get("shield"):
            c.rect(tx0 + L - 8, y - 9, tx0 + L - 5, y + 7, DARK)
        if o.get("tripod"):
            for dy in (-9, 9):
                c.line([(tx0 + L * 0.5, y - 1), (tx0 + L * 0.5 + 6, y - 1 + dy)], DARK, 1.4)
        c.rect(x0 - 6, y - 4, x0 + 2, y, DARK)
    elif kind == "atgm":
        c.rect(x0 - 8, y - 7, x0 + 12, y + 4, DARK, r=2)                       # command launch unit
        c.rect(x0 - 5, y - 5, x0 + 4, y - 1, LIGHT, edge=False)
        c.bar(x0 - 16, y - 1, x0 + 34, y - 1, 6.4, MID)
        c.circ(x0 + 34, y - 1, 3.4, DARK)
        c.rect(x0 - 20, y - 6, x0 - 14, y + 4, DARK, r=1)
    elif kind == "aa_mg":
        for ang in (0.0, 2.3, -2.3):
            c.line([(x0 + 12, y), (x0 + 12 + 14 * math.cos(ang), y + 14 * math.sin(ang))], DARK, 1.6)
        c.bar(x0 + 4, y, x0 + 44, y, 3.6, DARK)
        c.rect(x0 + 2, y - 4, x0 + 16, y + 4, MID, r=1)
        c.rect(x0 + 14, y + 4, x0 + 22, y + 10, MID)
    elif kind == "ugl":
        c.rect(x0, y - 2.8, x0 + 14, y + 2.8, MID)
        c.bar(x0 + 12, y, x0 + 40, y, 2.6, DARK)
        c.rect(x0 + 16, y - 3.6, x0 + 30, y + 5.5, DARK, r=1.5)
        c.rect(x0 + 30, y + 0.5, x0 + 44, y + 5, MID, r=1)
        c.circ(x0 + 44, y + 2.8, 2.6, DARK)
    elif kind == "kneemortar":
        c.bar(x0 - 4, y, x0 + 18, y + 4, 5, DARK)
        c.circ(x0 - 6, y - 1, 6.5, MID)
        c.rect(x0 + 6, y - 7, x0 + 16, y - 3, MID)                              # grenade
    elif kind == "grenades":
        c.rect(x0, y - 2.6, x0 + 16, y + 2.6, MID)
        c.bar(x0 + 14, y, x0 + 38, y, 2.2, DARK)
        for i, off in enumerate((-8, -2)):
            c.rect(x0 + 8 + i * 7, y + 5 + off * 0, x0 + 12 + i * 7, y + 13, DARK, r=1)
            c.circ(x0 + 10 + i * 7, y + 5, 2.6, MID)
    elif kind == "satchel":
        c.bar(x0, y, x0 + 26, y, 2.4, DARK)
        c.rect(x0 + 8, y + 6, x0 + 26, y + 22, MID, r=1.5)
        c.rect(x0 + 12, y + 9, x0 + 22, y + 13, DARK)
        c.bar(x0 + 28, y - 3, x0 + 42, y - 8, 2.4, DARK); c.circ(x0 + 44, y - 8.5, 2.6, MID)
    elif kind == "flame":
        c.bar(x0 - 6, y + 2, x0 + 34, y, 3.0, DARK)
        c.rect(x0 + 32, y - 3.6, x0 + 42, y + 3.6, DARK, r=1)
        c.poly([(x0 + 42, y - 4), (x0 + 50, y - 7), (x0 + 50, y + 7), (x0 + 42, y + 4)], ACC, edge=False)
        c.line([(x0 - 14, y - 4), (x0 - 2, y + 2)], DARK, 1.6)
    elif kind == "medic":
        c.rect(x0 - 2, y - 3, x0 + 10, y + 3, MID)                              # sidearm
        c.bar(x0 + 8, y, x0 + 18, y, 2.2, DARK)
        c.rect(x0 + 2, y + 8, x0 + 16, y + 20, LIGHT, r=1.5)
        c.rect(x0 + 8, y + 10, x0 + 10, y + 18, RED, edge=False); c.rect(x0 + 5, y + 13, x0 + 13, y + 15, RED, edge=False)
    elif kind == "engineer":
        c.bar(x0 - 2, y, x0 + 26, y, 2.4, DARK)
        c.bar(x0 + 8, y + 5, x0 + 34, y + 22, 2.0, DARK); c.rect(x0 + 32, y + 18, x0 + 40, y + 26, MID, r=1)   # shovel
        c.rect(x0 + 4, y - 14, x0 + 18, y - 6, MID, r=1.5)                      # demolition charge
    elif kind == "diver":
        c.bar(x0 - 4, y, x0 + 24, y, 2.4, DARK)
        c.bar(x0 + 20, y - 2, x0 + 36, y - 2, 2.0, DARK)
        c.rect(x0 - 2, y + 5, x0 + 12, y + 12, MID, r=1.5)


def helmet(c, kind, cx, cy, rng):
    if kind == "stahl":
        c.poly([(cx - 14, cy - 8), (cx - 17, cy), (cx - 14, cy + 8)], MID)
        c.ell(cx - 12.5, cy - 11.5, cx + 12.5, cy + 11.5, BODY)
        c.ell(cx - 8, cy - 8, cx + 7, cy + 8, MID, edge=False)
    elif kind == "ssh40":
        c.circ(cx, cy, 11.5, BODY); c.circ(cx, cy, 7.5, MID, edge=False)
    elif kind == "type90":
        c.rect(cx - 19, cy - 10, cx - 8, cy + 10, MID, r=2)
        c.circ(cx, cy, 11, BODY); c.circ(cx + 7, cy, 2.2, ACC, edge=False)
    elif kind == "mk7":
        c.circ(cx, cy, 12.5, BODY); c.circ(cx, cy, 8, MID, edge=False)
    elif kind == "ach":
        c.rect(cx - 12, cy - 11.5, cx + 12, cy + 11.5, BODY, r=7)
        c.rect(cx + 8, cy - 3, cx + 13, cy + 3, DARK)
        c.rect(cx - 8, cy - 8, cx + 6, cy + 8, MID, r=4, edge=False)
    elif kind == "f2":
        c.circ(cx, cy, 11.5, BODY); c.poly([(cx + 9, cy - 4), (cx + 14, cy), (cx + 9, cy + 4)], MID)
        c.line([(cx - 10, cy), (cx + 8, cy)], MID, 1.5)
    elif kind == "m33":
        c.ell(cx - 13.5, cy - 12, cx + 13.5, cy + 12, BODY); c.ell(cx - 9, cy - 8, cx + 8, cy + 8, MID, edge=False)
    else:  # 6b47
        c.circ(cx, cy, 11, BODY); c.rect(cx + 2, cy - 12.5, cx + 8, cy - 8, DARK); c.rect(cx + 2, cy + 8, cx + 8, cy + 12.5, DARK)
        c.circ(cx, cy, 6.5, MID, edge=False)


def pack(c, kind, rng):
    if kind == "ystrap":
        c.rect(38, 55, 49, 73, MID, r=2); c.circ(44, 80, 3.5, DARK); c.bar(40, 50, 50, 56, 1.8, DARK)
    elif kind == "bedroll":
        c.line([(64, 45), (50, 46), (42, 64), (50, 82), (64, 83)], MID, 4.5)
        c.rect(38, 56, 46, 72, DARK, r=1.5)
    elif kind == "bigpack":
        c.rect(32, 52, 36, 76, MID, r=1.5); c.rect(36, 54, 51, 74, DARK, r=2); c.circ(44, 64, 3.4, MID, edge=False)
    elif kind == "bergen":
        c.rect(33, 48, 52, 80, DARK, r=3); c.rect(35, 50, 40, 78, MID, r=1.5, edge=False); c.rect(46, 52, 52, 60, MID, r=1); c.rect(46, 68, 52, 76, MID, r=1)
    elif kind == "molle":
        c.rect(34, 50, 52, 78, MID, r=3); c.rect(36, 55, 44, 73, DARK, r=1.5, edge=False); c.rect(46, 50, 53, 58, DARK, r=1); c.rect(46, 70, 53, 78, DARK, r=1)
    elif kind == "bag":
        c.rect(36, 54, 51, 74, DARK, r=3); c.rect(33, 56, 37, 72, MID, r=2)
    elif kind == "zaino":
        c.rect(37, 53, 50, 75, MID, r=3); c.rect(34, 56, 38, 72, DARK, r=1.5); c.circ(44, 80, 3.4, DARK)
    else:
        c.rect(36, 52, 51, 76, MID, r=2); c.rect(44, 48, 52, 54, DARK, r=1); c.rect(44, 74, 52, 80, DARK, r=1)


def draw(faction, slot, name, rng):
    kind, opts = SLOT_DEFAULT.get(slot, ("rifle", {}))
    if slot not in ("diver", "medic", "engineer"):
        for rx, k, o in SPEC:
            if re.search(rx, name):
                kind, opts = k, dict(o)
                break
    opts = dict(opts)
    if kind in ("rifle", "assault", "smg", "gpmg", "lmg", "sniper"):
        opts["length"] = opts.get("length", 40) + float(rng.uniform(-3, 3))
    c = Canvas()
    jit = rng.uniform(-1.0, 1.0)
    if kind == "diver":
        for sgn in (-1, 1):                                          # long fins trailing behind
            c.poly([(40, 64 + sgn * 4), (6, 64 + sgn * 13), (4, 64 + sgn * 8), (30, 64 + sgn * 1.5)], DARK)
        c.rect(34, 56, 58, 62, MID, r=2.5); c.rect(34, 66, 58, 72, MID, r=2.5)       # twin air cylinders
        c.ell(46, 48, 74, 80, MID)
        c.bar(62, 54, 92, 58, 3.4, MID); c.bar(62, 74, 90, 70, 3.4, MID)              # arms reaching forward
        c.circ(66, 64 + jit * 0.5, 9.5, DARK); c.rect(68, 58, 76, 70, LIGHT, r=3, edge=True)   # hood + mask
        pick = int(rng.integers(0, 3))
        if pick == 0:
            c.circ(98, 64, 7, MID); c.circ(98, 64, 2.6, DARK)                               # limpet mine
        elif pick == 1:
            c.bar(90, 64, 112, 64, 3.0, DARK); c.circ(112, 64, 3.2, RED)                    # pole charge
        else:
            c.bar(92, 62, 108, 62, 2.4, DARK); c.rect(100, 58, 106, 66, DARK, r=1)            # underwater weapon
    else:
        pk = PACK[faction]
        if slot == "medic":
            c.rect(33, 50, 52, 78, LIGHT, r=3)
            c.rect(41, 56, 44, 72, RED, edge=False); c.rect(36, 62, 49, 66, RED, edge=False)
        else:
            pack(c, pk, rng)
        c.bar(60, 50, 80, 58, 4.4, MID, True)
        c.bar(60, 78, 74, 68, 4.4, MID, True)
        c.ell(47, 43, 71, 85, MID)
        if slot == "sniper":
            for _ in range(9):
                x, y, r = rng.uniform(36, 66), rng.uniform(44, 84), rng.uniform(3, 6)
                c.ell(x - r, y - r, x + r, y + r, MID, edge=False)
        helmet(c, HELMET[faction], 61, 64 + jit * 0.5, rng)
        if slot == "commando":
            c.rect(70, 59, 74, 69, DARK, r=1)            # NVG / goggles
    weapon(c, kind, opts, rng)
    return c
