"""Strategic weapons drawn horizontally (facing right): rockets, cruise missiles, bombs, balloon bombs, ICBMs."""
import re
from core import *

CY = 64.0


RNG = None


def body(c, x0, x1, r, nose=0.18, fill=BODY, tail=0.0, cy=CY):
    if RNG is not None:
        x0 = x0 + float(RNG.uniform(-4, 6)); x1 = x1 + float(RNG.uniform(-5, 3)); r = r * float(RNG.uniform(0.85, 1.18))
        nose = nose * float(RNG.uniform(0.8, 1.25))
    L = x1 - x0
    pts_t = [(x0, cy - r * (1 - tail)), (x1 - L * nose, cy - r), (x1, cy)]
    pts_b = [(x1 - L * nose, cy + r), (x0, cy + r * (1 - tail))]
    c.poly(pts_t + pts_b, fill)


def fins(c, x, span, ch, sweep=6, n=2):
    for s in (-1, 1):
        c.poly([(x + ch, CY + s * 3), (x + ch - sweep, CY + s * span), (x - sweep, CY + s * span), (x, CY + s * 3)], MID)


def band(c, x, w, r, col=ACC):
    c.rect(x, CY - r + 0.6, x + w, CY + r - 0.6, col, edge=False)


TIER = {"tactical_nuke": 0, "nuke": 1, "mega_nuke": 2}


def nuke_draw(c, slot, n, rng):
    """Nuclear weapons: each named design is distinct; the tier (tactical / strategic / mega) scales and marks it."""
    t = TIER[slot]
    k = (0.9, 1.15, 1.5)[t]
    if re.search(r"Trident|M51|Minuteman|Yars|Sarmat|Uran-Rakete|Wunderwaffe|723 Nuclear", n):
        count = 3 if re.search(r"full salvo|MIRV Salvo", n) else 1
        big = bool(re.search(r"Sarmat|Wunderwaffe", n))
        for i in range(count):
            cy = CY + (i - (count - 1) / 2) * (22 if count > 1 else 0)
            r = (6.2 if count > 1 else 9) * k * (1.2 if big else 1.0) * (0.8 if re.search(r"Yars|Trident", n) else 1.0)
            body(c, 10 + i * 4, 112 - i * 2, r, 0.22 if not re.search(r"Minuteman", n) else 0.3, cy=cy)
            for xx in (34, 64, 88) if not re.search(r"M51", n) else (40, 80):
                c.line([(xx + i * 3, cy - r), (xx + i * 3, cy + r)], EDGE, 1.4)
            for s_ in (-1, 1):
                c.poly([(10 + i * 4 + 14, cy + s_ * r * 0.9), (10 + i * 4 + 2, cy + s_ * r * 2.0), (10 + i * 4 - 3, cy + s_ * r * 2.0), (10 + i * 4 + 2, cy + s_ * r * 0.9)], MID)
            band(c, 94 - i * 2, 5, r, RED) if t else band(c, 94, 4, r, ACC)
        if re.search(r"723 Nuclear", n):
            c.rect(52, CY - 3, 70, CY + 3, DARK, r=1)
    elif re.search(r"ASMPA|TN 81", n):
        body(c, 12, 112, 6 * k, 0.26)
        c.rect(30, CY - 9 * k, 52, CY - 5 * k, DARK, r=1)
        for s_ in (-1, 1):
            c.poly([(70, CY + s_ * 5), (60, CY + s_ * 20), (50, CY + s_ * 20), (56, CY + s_ * 5)], MID)
        band(c, 90, 4, 6 * k, ACC)
    elif re.search(r"B61", n):
        body(c, 14, 106, 6.4 * k, 0.3)
        fins(c, 14, 6.4 * k + 9, 14, 3)
        c.rect(30, CY - 5, 44, CY + 5, DARK, r=1)
        band(c, 70, 3, 6.4 * k, ACC); band(c, 78, 3, 6.4 * k, WHITE)
    elif re.search(r"Tsar|RDS-220", n):
        body(c, 8, 112, 17, 0.2)
        c.poly([(16, CY - 17), (8, CY - 28), (24, CY - 28), (34, CY - 17)], MID); c.poly([(16, CY + 17), (8, CY + 28), (24, CY + 28), (34, CY + 17)], MID)
        c.rect(68, CY - 20, 82, CY - 17, DARK); c.rect(68, CY + 17, 82, CY + 20, DARK)
        band(c, 94, 6, 17, RED); band(c, 84, 3, 17, WHITE)
    elif re.search(r"B41|Mk-41", n):
        body(c, 12, 112, 12 * k / 1.5, 0.3)
        fins(c, 12, 22, 14, 4)
        c.ell(60, CY - 6, 80, CY + 6, MID, edge=False)
        band(c, 90, 5, 12 * k / 1.5, ACC)
    elif re.search(r"RDS-37|Joe-1|RDS-1", n):
        body(c, 20, 104, 11 * k, 0.1)
        fins(c, 20, 11 * k + 12, 14, 2)
        c.circ(62, CY, 6, MID, edge=True)
        band(c, 76, 4, 11 * k, RED)
    elif re.search(r"Fat|Uranbombe|Fisica|Atomica|Finale|F-Go|Ni-Go|Bomba|Fission", n):
        body(c, 22, 100, 13 * k / 1.2, 0.12 + 0.04 * t)
        for s_ in (-1, 1):
            c.line([(34, CY + s_ * 12), (26, CY + s_ * 20)], DARK, 1.8)
        fins(c, 22, 13 * k + 12, 12, 2)
        band(c, 64, 4, 13 * k / 1.2, ACC)
        if t == 2:
            band(c, 74, 4, 13 * k / 1.2, RED)
    else:
        body(c, 14, 110, 9 * k, 0.24); fins(c, 14, 9 * k + 10, 12, 3); band(c, 86, 5, 9 * k, RED)
    c.mark("auto", 60, CY, 0)
    return c


def draw(faction, slot, name, rng):
    global RNG
    RNG = rng
    c = Canvas()
    n = name
    if slot in TIER:
        return nuke_draw(c, slot, n, rng)
    if re.search(r"V-1|Fi 103|Flying Bomb|10Kh", n):
        body(c, 14, 106, 5, 0.14); fins(c, 44, 28, 14, 4)
        c.rect(6, CY - 4, 40, CY + 4, DARK, r=2); c.rect(20, CY - 9, 86, CY - 5, MID, r=1)       # pulsejet on top
        band(c, 90, 6, 5, RED)
    elif re.search(r"Fu-Go", n):
        c.circ(64, CY, 44, BODY); c.circ(64, CY, 30, MID, edge=False)
        for a in range(8):
            c.line([(64, CY), (64 + 44 * __import__('math').cos(a * 0.785), CY + 44 * __import__('math').sin(a * 0.785))], EDGE, 1.0)
        c.rect(58, CY - 6, 72, CY + 6, DARK, r=2)
    elif re.search(r"A4|V-2|R-1|R-2|Rheinbote|Razzo|V-2 Derived", n):
        body(c, 8, 114, 8, 0.3); fins(c, 12, 20, 16, 8)
        band(c, 40, 10, 8, DARK); band(c, 56, 10, 8, WHITE) if False else None
        c.rect(30, CY - 8, 62, CY + 8, MID, edge=False)
    elif re.search(r"Amerika|Kikka|Campini|Hypersonic|Dark Eagle|Kinzhal|HCSW|ASN4G", n):
        body(c, 10, 114, 6, 0.34); fins(c, 18, 24, 18, 12)
        c.poly([(70, CY - 5), (88, CY - 18), (96, CY - 18), (90, CY - 5)], MID); c.poly([(70, CY + 5), (88, CY + 18), (96, CY + 18), (90, CY + 5)], MID)
        band(c, 40, 6, 6, RED)
    elif re.search(r"Nebelwerfer|Rocket Salvo|M-13|M-30|Barrage|Salvo|Smerch Cluster|GMLRS|Cluster|ATACMS", n):
        for k in range(5):
            yy = CY - 24 + k * 12
            body(c, 22 + (k % 2) * 8, 100 + (k % 2) * 8, 4.4, 0.22, cy=yy)
            c.rect(20 + (k % 2) * 8, yy - 1.4, 30 + (k % 2) * 8, yy + 1.4, DARK, edge=False)
            c.rect(86 + (k % 2) * 8, yy - 4.4, 90 + (k % 2) * 8, yy + 4.4, RED, edge=False)
        c.rect(12, CY - 32, 19, CY + 32, MID, r=1)
    elif re.search(r"Fritz|FAB|KAB|Storm Shadow|BROACH|MOP|Hammer|Bomba Perforante|AP Bomb|Bomb", n) and slot == "bunker_buster":
        big = bool(re.search(r"MOP|FAB-5000|Fritz", n))
        r = 9 if big else 7
        body(c, 14, 108, r, 0.32)
        for s in (-1, 1):
            c.rect(14, CY + s * (r + 1) - 1, 34, CY + s * (r + 1) + 1, MID, edge=False)
        fins(c, 14, r + 12, 12, 2)
        c.poly([(40, CY - r), (46, CY - r - 8), (52, CY - r - 8), (50, CY - r)], MID) if re.search(r"Fritz", n) else None
        band(c, 70, 4, r, ACC)
    elif re.search(r"Tomahawk|SCALP|Kalibr|Aerosilurante|Hades|Tochka|Iskander|PrSM|Pershing|Plateau|Storm", n):
        torp = "Aerosilurante" in n
        body(c, 10, 114, 5.5 if not torp else 6, 0.22)
        for s in (-1, 1):
            c.poly([(74, CY + s * 4), (58, CY + s * 24), (48, CY + s * 24), (56, CY + s * 4)], MID)
            c.poly([(20, CY + s * 4), (14, CY + s * 14), (8, CY + s * 14), (12, CY + s * 4)], MID)
        c.rect(64, CY - 8, 80, CY - 4, DARK, r=1) if not torp else None
        band(c, 96, 5, 5.5, RED) if re.search(r"Hades|Tochka|Iskander|PrSM|Pershing", n) else None
    elif re.search(r"Trident|Minuteman|M51|Yars|Sarmat|ICBM|Plateau|Uran|A10", n):
        body(c, 6, 116, 9, 0.2)
        for xx in (30, 62, 86):
            c.line([(xx, CY - 9), (xx, CY + 9)], EDGE, 1.4)
        fins(c, 8, 16, 12, 6)
        band(c, 96, 6, 9, RED)
    elif re.search(r"Tsar|RDS-220|B41|Mk-41|Super Bomb|Wunderwaffe|Finale", n):
        body(c, 14, 108, 15, 0.24)
        for s in (-1, 1):
            c.rect(14, CY + s * 12 - 2, 40, CY + s * 12 + 2, MID, edge=False)
        fins(c, 14, 26, 14, 2)
        c.poly([(70, CY - 15), (74, CY - 24), (84, CY - 24), (88, CY - 15)], MID)
        band(c, 90, 6, 15, RED)
    elif re.search(r"Joe-1|RDS|Fission|Fat|Uranbombe|Fisica|Atomica|Fugaku|F-Go|Ni-Go|B61|TN 81|ASMPA|Warhead|Holbrooke|Trident", n):
        body(c, 20, 104, 12, 0.14)
        for s in (-1, 1):
            c.line([(34, CY + s * 12), (28, CY + s * 18)], DARK, 1.6)
        fins(c, 20, 20, 12, 2)
        band(c, 70, 5, 12, ACC); band(c, 80, 5, 12, RED)
    else:
        c.fb = True
        body(c, 12, 112, 7, 0.25); fins(c, 14, 20, 12, 4); band(c, 80, 6, 7, ACC)
    # individual details so equal-class weapons of different armies never look identical
    import math
    k = int(rng.integers(0, 4))
    xs = int(rng.integers(24, 90))
    if rng.random() < 0.5:
        for s_ in (-1, 1):
            xf = int(rng.integers(70, 96)); sp = float(rng.uniform(6, 11))
            c.poly([(xf, CY + s_ * 4), (xf - 8, CY + s_ * (4 + sp)), (xf - 13, CY + s_ * (4 + sp)), (xf - 10, CY + s_ * 4)], MID)
    c.rect(xs, CY - 1.2, xs + 3, CY + 1.2, EDGE, edge=False)
    if k == 1:
        band(c, int(rng.integers(30, 80)), 3, 4, WHITE)
    elif k == 2:
        c.rect(int(rng.integers(30, 70)), CY - 2, int(rng.integers(74, 96)), CY + 2, MID, edge=False)
    c.mark("auto", 60, CY, 0)
    return c
