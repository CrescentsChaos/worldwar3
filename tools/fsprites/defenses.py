"""Static defences, top-down: sandbags, concrete, guns and launchers keyed to the real emplacement."""
import math
import re
from core import *

CY = 64.0
CX = 64.0


RNG = None


def pad(c, r=44, sides=8, fill=MID):
    if RNG is not None:
        r = r * float(RNG.uniform(0.92, 1.06))
        sides = int(RNG.choice([6, 8, 8, 10]))
    pts = [(CX + r * math.cos(i * 2 * math.pi / sides + math.pi / sides), CY + r * math.sin(i * 2 * math.pi / sides + math.pi / sides)) for i in range(sides)]
    c.poly(pts, fill)


def sandbags(c, r, a0=0.0, a1=2 * math.pi, n=18, bag=7.5):
    if RNG is not None:
        n = max(6, int(n + RNG.integers(-2, 3))); bag = bag * float(RNG.uniform(0.85, 1.15))
    for i in range(n):
        a = a0 + (a1 - a0) * (i + 0.5) / n
        x, y = CX + r * math.cos(a), CY + r * math.sin(a)
        c.rrect(x, y, bag, bag * 0.62, a + math.pi / 2, BODY if i % 2 else MID)


def wall_box(c, w, h, t=6, fill=BODY):
    c.rect(CX - w, CY - h, CX + w, CY + h, fill, r=2)
    c.rect(CX - w + t, CY - h + t, CX + w - t, CY + h - t, DARK, r=1, edge=False)


def hesco(c, w, h):
    for side in (-1, 1):
        for i in range(8):
            x = CX - w + (2 * w) * i / 8
            c.rect(x, CY + side * h - 3.5 + (0 if side > 0 else -0.0), x + 2 * w / 8, CY + side * h + 3.5, MID if i % 2 else BODY, w=1.0)
    for side in (-1, 1):
        for i in range(8):
            y = CY - h + (2 * h) * i / 8
            c.rect(CX + side * w - 3.5, y, CX + side * w + 3.5, y + 2 * h / 8, MID if i % 2 else BODY, w=1.0)


def gun_mount(c, x, y, L, w=3.0, shield=False, brake=False, base=6):
    c.circ(x, y, base, MID)
    c.bar(x, y, x + L, y, w, DARK)
    if brake:
        c.rect(x + L - 3, y - w, x + L + 2, y + w, DARK, r=1)
    if shield:
        c.rect(x + 4, y - base * 1.6, x + 8, y + base * 1.6, BODY, r=1)


def trail_legs(c, x, y, L=34):
    c.bar(x, y, x - L, y - 14, 2.6, DARK); c.bar(x, y, x - L, y + 14, 2.6, DARK)
    c.rect(x - L - 3, y - 17, x - L + 2, y - 11, MID, r=1); c.rect(x - L - 3, y + 11, x - L + 2, y + 17, MID, r=1)


def tripod_post(c, x, y, tube=40, tw=5.5):
    for a in (0, 2.4, -2.4):
        c.line([(x, y), (x - 12 * math.cos(a + math.pi), y + 12 * math.sin(a + math.pi) * 1.0)], DARK, 1.8) if False else None
    for dy in (-14, 14):
        c.line([(x - 6, y), (x - 14, y + dy)], DARK, 2.0)
    c.bar(x - 8, y, x + tube, y, tw, MID)
    c.circ(x + tube, y, tw * 0.55, DARK)
    c.rect(x - 4, y - 7, x + 8, y + 5, DARK, r=1.5)


def cruciform(c, r=36):
    c.rect(CX - r, CY - 5, CX + r, CY + 5, MID, r=2)
    c.rect(CX - 5, CY - r, CX + 5, CY + r, MID, r=2)
    for dx, dy in ((-r, 0), (r, 0), (0, -r), (0, r)):
        c.circ(CX + dx, CY + dy, 5, DARK)
    c.circ(CX, CY, 12, BODY)


def multi_barrel(c, x, y, n, L, spread, w=2.2):
    for i in range(n):
        off = (i - (n - 1) / 2) * spread
        c.bar(x, y + off, x + L, y + off, w, DARK)


def canister_bank(c, x0, y0, cols, rows, cw=26, ch=8, gap=2):
    for j in range(rows):
        for i in range(cols):
            c.rrect(x0 + i * (cw + gap) + cw / 2, y0 + j * (ch + gap), cw, ch, 0.0, MID)
            c.circ(x0 + i * (cw + gap) + cw, y0 + j * (ch + gap), ch * 0.4, DARK, w=0.8)


def radar_mast(c, x, y, kind="dish"):
    if kind == "dish":
        c.circ(x, y, 9, MID); c.circ(x, y, 5, BODY, edge=False); c.circ(x, y, 1.8, DARK, edge=False)
    else:
        c.rect(x - 5, y - 10, x + 5, y + 10, DARK, r=1)
        for i in range(1, 4):
            c.line([(x - 5, y - 10 + i * 5), (x + 5, y - 10 + i * 5)], MID, 1.0)


def dome(c, x, y, r=13):
    c.circ(x, y, r, LIGHT); c.circ(x - r * 0.3, y - r * 0.3, r * 0.35, WHITE, edge=False)


def turret_on_pad(c, shape, gl, gw=3.6, r=15, brake=None):
    pad(c, 42, 8, MID)
    sandbags(c, 40, n=22, bag=6)
    if shape == "box":
        c.poly([(CX - r, CY - r * 0.85), (CX + r * 0.8, CY - r), (CX + r, CY - r * 0.5), (CX + r, CY + r * 0.5), (CX + r * 0.8, CY + r), (CX - r, CY + r * 0.85)], BODY)
    elif shape == "flat":
        c.ell(CX - r * 1.1, CY - r * 0.85, CX + r * 1.1, CY + r * 0.85, BODY)
    else:
        c.circ(CX, CY, r, BODY)
    c.circ(CX - 3, CY - 5, 3, MID); c.circ(CX - 3, CY + 5, 2.6, MID)
    c.bar(CX + r * 0.6, CY, CX + r * 0.6 + gl, CY, gw, DARK)
    if brake:
        c.rect(CX + r * 0.6 + gl - 4, CY - gw * 1.2, CX + r * 0.6 + gl + 1, CY + gw * 1.2, DARK, r=1)


def draw(faction, slot, name, rng):
    global RNG
    RNG = rng
    c = Canvas()
    n = name
    j = lambda a, b: float(rng.uniform(a, b))
    if slot == "mg_turret":
        if re.search(r"Sangar", n):
            hesco(c, 30, 26); c.rect(CX - 22, CY - 18, CX + 22, CY + 18, DARK, r=2, edge=False); gun_mount(c, CX + 6, CY, 26, 2.6)
        elif re.search(r"Maxim", n):
            sandbags(c, 34, -2.3, 2.3, 12); c.circ(CX - 8, CY + 14, 6, DARK); c.circ(CX - 8, CY - 14, 6, DARK)
            c.rect(CX - 14, CY - 9, CX + 4, CY + 9, BODY, r=2); c.rect(CX + 2, CY - 8, CX + 6, CY + 8, DARK); c.bar(CX + 6, CY, CX + 36, CY, 3.0, DARK)
        elif re.search(r"M2HB|Kord", n):
            sandbags(c, 32, n=16); c.circ(CX, CY, 10, DARK, edge=False); tripod_post(c, CX - 4, CY, 30, 3.4)
        else:
            sandbags(c, 34, -2.4, 2.4, 13); c.rect(CX - 20, CY - 14, CX - 4, CY + 14, MID, r=2)
            c.bar(CX - 10, CY, CX + 34, CY, 3.0, DARK); c.rect(CX - 4, CY - 6, CX + 8, CY + 8, MID, r=1)
            for dy in (-9, 9):
                c.line([(CX + 4, CY), (CX + 16, CY + dy)], DARK, 1.6)
        c.mark("auto", CX - 26, CY - 22, 4)
    elif slot == "pillbox":
        if re.search(r"Cave", n):
            pts = [(CX + 40 * math.cos(a) * (0.8 + 0.25 * math.sin(a * 5 + j(0, 1))), CY + 40 * math.sin(a) * (0.8 + 0.2 * math.cos(a * 3))) for a in [i * math.pi / 8 for i in range(16)]]
            c.poly(pts, MID); c.rect(CX + 18, CY - 4, CX + 40, CY + 4, DARK, r=1)
        elif re.search(r"Maginot", n):
            c.circ(CX, CY, 38, BODY); c.circ(CX, CY, 24, MID); c.circ(CX, CY, 8, DARK)
            for a in (-0.5, 0.5):
                c.rect(CX + 30 * math.cos(a) - 5, CY + 30 * math.sin(a) - 2, CX + 30 * math.cos(a) + 5, CY + 30 * math.sin(a) + 2, DARK)
        elif re.search(r"Hesco", n):
            hesco(c, 34, 30); c.rect(CX - 24, CY - 22, CX + 24, CY + 22, DARK, r=2, edge=False); c.rect(CX + 6, CY - 4, CX + 36, CY + 4, MID, r=1)
        elif re.search(r"Sangar", n):
            wall_box(c, 36, 30, 7, MID); c.rect(CX + 28, CY - 4, CX + 38, CY + 4, DARK)
        else:
            pts = [(CX - 38, CY - 22), (CX + 24, CY - 34), (CX + 40, CY - 14), (CX + 40, CY + 14), (CX + 24, CY + 34), (CX - 38, CY + 22)]
            c.poly(pts, BODY); c.poly([(CX - 30, CY - 16), (CX + 18, CY - 24), (CX + 30, CY - 8), (CX + 30, CY + 8), (CX + 18, CY + 24), (CX - 30, CY + 16)], MID, edge=False)
            for dy in (-12, 0, 12):
                c.rect(CX + 34, CY + dy - 2, CX + 41, CY + dy + 2, DARK)
        c.mark("auto", CX - 18, CY, 5)
    elif slot == "at_gun":
        if re.search(r"MILAN|MMP|Fagot|TOW", n):
            sandbags(c, 34, -2.5, 2.5, 13); tripod_post(c, CX - 2, CY, 36 if "TOW" not in n else 44, 6 if "TOW" in n else 5)
        else:
            trail_legs(c, CX, CY, 38 if re.search(r"PaK|ZiS", n) else 30)
            c.circ(CX - 6, CY - 16, 7, DARK); c.circ(CX - 6, CY + 16, 7, DARK)
            gun_mount(c, CX, CY, 46 if "PaK" in n else 38, 2.8, shield=True, brake=True, base=7)
            c.rect(CX + 4, CY - 13, CX + 8, CY + 13, BODY, r=1)
        c.mark("auto", CX - 22, CY - 24, 4)
    elif slot == "cannon_turret":
        if re.search(r"Casemate|Bunker", n) and not re.search(r"L7", n):
            wall_box(c, 38, 30, 8, BODY); c.bar(CX + 8, CY, CX + 52, CY, 4.0, DARK); c.rect(CX + 28, CY - 8, CX + 40, CY + 8, MID, r=2)
        elif re.search(r"Panther", n):
            turret_on_pad(c, "box", 42, 4.0, 15, "ball")
        elif re.search(r"T-72|T-34", n):
            turret_on_pad(c, "flat" if "T-72" in n else "round", 44, 3.8, 14, None)
        elif re.search(r"M60|L7", n):
            turret_on_pad(c, "box", 46, 3.6, 15, None)
        else:
            turret_on_pad(c, "round", 38, 3.2, 13, "ball")
        c.mark("auto", CX - 26, CY - 24, 4)
    elif slot == "mortar_pit":
        c.circ(CX, CY, 38, MID); sandbags(c, 36, n=20, bag=7); c.circ(CX, CY, 28, DARK, edge=False)
        c.circ(CX - 3, CY + 3, 9, MID); c.bar(CX - 3, CY + 3, CX + 22, CY - 10, 5.0, DARK)
        for i in range(3):
            c.rect(CX - 24 + i * 9, CY - 22, CX - 17 + i * 9, CY - 13, BODY, r=1)
        c.mark("auto", CX - 30, CY - 24, 4)
    elif slot in ("flak_battery", "sam_site"):
        if re.search(r"Rapier|Crotale", n):
            sandbags(c, 40, n=22); c.rect(CX - 20, CY - 18, CX + 6, CY + 18, MID, r=2)
            for dy in (-12, -4, 4, 12):
                c.bar(CX - 14, CY + dy, CX + 10, CY + dy, 3.0, DARK)
            radar_mast(c, CX + 24, CY - 18, "dish"); radar_mast(c, CX + 28, CY + 16, "array")
        elif re.search(r"NASAMS|Tor-M2|M-LIDS", n):
            pad(c, 42, 8); canister_bank(c, CX - 30, CY - 20, 1, 4, 44, 9, 3); radar_mast(c, CX + 28, CY, "array")
        elif re.search(r"ZU-23|Bofors|Tarasque|Breda|61-K|Type 96", n):
            cruciform(c, 32); c.circ(CX, CY, 10, MID)
            nb = 3 if "Type 96" in n else 2
            multi_barrel(c, CX + 2, CY, nb, 38, 4.4, 2.4)
        else:
            cruciform(c, 38); gun_mount(c, CX, CY, 48 if slot == "sam_site" else 36, 3.8 if slot == "sam_site" else 3.0, False, True, 9)
        c.mark("auto", CX - 30, CY - 30, 4)
    elif slot == "heavy_battery":
        if re.search(r"Todt|Coastal|Giatsint|152", n):
            pad(c, 44, 8); c.circ(CX, CY, 28, BODY); c.circ(CX, CY, 20, MID)
            for dy in ((-5, 5) if re.search(r"Todt", n) else (0,)):
                c.bar(CX, CY + dy, CX + 58, CY + dy, 6.0 if "Todt" in n else 4.6, DARK)
            c.rect(CX + 40, CY - 8, CX + 52, CY + 8, MID, r=2)
        else:
            trail_legs(c, CX, CY, 40); c.circ(CX - 6, CY - 18, 8, DARK); c.circ(CX - 6, CY + 18, 8, DARK)
            gun_mount(c, CX, CY, 60, 4.4, False, True, 8); c.rect(CX + 4, CY - 12, CX + 9, CY + 12, MID, r=1)
        c.mark("auto", CX - 30, CY - 30, 4)
    elif slot == "railgun":
        if re.search(r"DragonFire|Peresvet", n):
            pad(c, 42, 8); c.circ(CX, CY, 26, BODY)
            if "Peresvet" in n: c.circ(CX, CY, 20, DARK); radar_mast(c, CX, CY, "dish")
            else:
                c.rect(CX - 14, CY - 14, CX + 14, CY + 14, MID, r=3); c.rect(CX + 8, CY - 5, CX + 40, CY + 5, DARK, r=2); c.circ(CX + 40, CY, 6, LIGHT)
        elif re.search(r"Railgun", n):
            pad(c, 42, 8); c.rect(CX - 20, CY - 14, CX + 8, CY + 14, BODY, r=2)
            for dy in (-3.5, 3.5): c.bar(CX, CY + dy, CX + 60, CY + dy, 2.6, DARK)
        else:
            for dy in (-22, 22):
                c.rect(CX - 56, CY + dy - 1.6, CX + 56, CY + dy + 1.6, DARK, edge=False)
            for i in range(14):
                c.rect(CX - 54 + i * 8, CY - 26, CX - 52 + i * 8, CY + 26, MID, edge=False)
            c.rect(CX - 40, CY - 18, CX + 8, CY + 18, BODY, r=2)
            c.bar(CX - 6, CY, CX + 60, CY, 8.0 if re.search(r"Gustav|80", n) else 6.0, DARK)
            c.rect(CX - 34, CY - 12, CX - 8, CY + 12, MID, r=2)
        c.mark("auto", CX - 34, CY - 20, 4)
    elif slot == "ciws":
        pad(c, 36, 8)
        if re.search(r"Phalanx|Simbad|Pantsir", n):
            c.circ(CX, CY, 15, BODY); dome(c, CX - 2, CY - 2, 10); c.bar(CX + 6, CY, CX + 26, CY, 6.0, DARK)
        elif re.search(r"Flakvierling|Maxim", n):
            c.circ(CX, CY, 11, MID); multi_barrel(c, CX, CY, 4, 32, 3.8, 2.0)
        else:
            c.circ(CX, CY, 11, MID); multi_barrel(c, CX, CY, 3, 30, 4.4, 2.2)
        c.mark("auto", CX - 24, CY - 24, 4)
    elif slot in ("interceptor_battery", "abm_battery"):
        pad(c, 44, 8)
        if re.search(r"Iron Dome|Sky Sabre", n):
            canister_bank(c, CX - 28, CY - 22, 1, 5, 40, 7, 2); radar_mast(c, CX + 30, CY - 14, "array")
        elif re.search(r"SAMP|S-400|S-500|THAAD|Aster", n):
            canister_bank(c, CX - 34, CY - 22, 1, 4, 52, 9, 3); radar_mast(c, CX + 30, CY, "array")
            c.rect(CX - 38, CY - 28, CX - 34, CY + 28, DARK)
        elif re.search(r"Wasserfall|Enzian", n):
            c.rect(CX - 20, CY - 16, CX + 14, CY + 16, MID, r=2); c.bar(CX - 14, CY, CX + 42, CY, 7.0, BODY); c.poly([(CX + 42, CY - 3.5), (CX + 52, CY), (CX + 42, CY + 3.5)], DARK)
        else:
            cruciform(c, 38); gun_mount(c, CX, CY, 54, 4.2, False, True, 9)
        c.mark("auto", CX - 32, CY - 32, 4)
    elif slot == "barricade":
        if re.search(r"Hedgehog|Tschech", n):
            for (x, y) in [(float(rng.uniform(-34, 34)), float(rng.uniform(-26, 26))) for _ in range(int(rng.integers(4, 7)))]:
                for a in (0.0, math.pi / 3, 2 * math.pi / 3):
                    c.bar(CX + x - 12 * math.cos(a), CY + y - 12 * math.sin(a), CX + x + 12 * math.cos(a), CY + y + 12 * math.sin(a), 3.4, MID)
        elif re.search(r"Dragon", n):
            for row in range(int(rng.integers(2, 4))):
                for i in range(int(rng.integers(5, 8))):
                    x = CX - 38 + i * 12.5 + (6 if row % 2 else 0)
                    c.poly([(x, CY - 18 + row * 18 - 6), (x + 9, CY - 18 + row * 18), (x, CY - 18 + row * 18 + 6), (x - 4, CY - 18 + row * 18)], BODY)
        elif re.search(r"Log", n):
            for i in range(int(rng.integers(4, 7))):
                c.bar(CX - 36 + float(rng.uniform(-4, 4)), CY - 24 + i * 9, CX + 36 + float(rng.uniform(-4, 4)), CY - 24 + i * 9 + float(rng.uniform(-3, 3)), float(rng.uniform(5, 7)), MID)
        elif re.search(r"Hesco", n):
            hesco(c, 40, 14)
        else:
            for i in range(int(rng.integers(3, 6))):
                c.rect(CX - 44 + i * 18, CY - 10 + float(rng.uniform(-3, 3)), CX - 28 + i * 18, CY + 10 + float(rng.uniform(-3, 3)), BODY, w=1.6)
        c.mark("auto", CX - 36, CY - 30, 3)
    elif slot == "repair_depot":
        wall_box(c, 40, 32, 5, MID)
        c.poly([(CX - 36, CY - 28), (CX, CY - 12), (CX + 36, CY - 28), (CX + 36, CY - 4), (CX, CY + 12), (CX - 36, CY - 4)], BODY, edge=True) if False else None
        c.rect(CX - 30, CY - 22, CX + 30, CY + 22, BODY, r=2); c.line([(CX - 30, CY), (CX + 30, CY)], EDGE, 1.4)
        c.rect(CX + 8, CY - 18, CX + 26, CY - 4, MID, r=1); c.circ(CX - 16, CY + 12, 7, DARK)
        c.rect(CX - 4, CY + 8, CX + 4, CY + 16, RED, edge=False); c.rect(CX - 8, CY + 11, CX + 8, CY + 13, RED, edge=False)
        c.mark("auto", CX + 18, CY + 14, 4)
    elif slot == "coastal_battery":
        pad(c, 44, 8)
        if re.search(r"NMESIS|Exocet|Bastion", n):
            for k in range(4):
                c.rrect(CX - 2, CY - 21 + k * 14, 50, 9, 0.0, MID); c.circ(CX + 22, CY - 21 + k * 14, 3.6, DARK)
            c.rect(CX - 34, CY - 26, CX - 24, CY + 26, DARK, r=1)
        else:
            c.circ(CX - 8, CY, 24, BODY); c.circ(CX - 8, CY, 15, MID)
            c.bar(CX - 8, CY, CX + 52, CY, 5.6, DARK); c.rect(CX + 30, CY - 8, CX + 40, CY + 8, MID, r=2)
        c.mark("auto", CX - 34, CY - 30, 4)
    else:
        c.fb = True
        pad(c, 40, 8); gun_mount(c, CX, CY, 40, 3.4, False, True, 10)
    decor(c, rng, slot)
    return c


def decor(c, rng, slot):
    """Seeded site clutter (crates, wire, mast, flag) so every emplacement of every army is individual."""
    if slot in ("barricade",):
        return
    r0 = 47 if slot not in ("pillbox", "repair_depot", "railgun") else 50
    for _ in range(int(rng.integers(2, 5))):
        a = float(rng.uniform(0, 2 * math.pi)); rr = r0 + float(rng.uniform(-2, 5))
        x, y = CX + rr * math.cos(a), CY + rr * math.sin(a)
        w, h = float(rng.uniform(4, 8)), float(rng.uniform(3, 6))
        c.rrect(x, y, w, h, a + float(rng.uniform(-0.4, 0.4)), MID)
    if rng.random() < 0.55:
        a = float(rng.uniform(0, 2 * math.pi))
        x, y = CX + (r0 + 4) * math.cos(a), CY + (r0 + 4) * math.sin(a)
        c.line([(x, y), (x + 9 * math.cos(a + 0.4), y + 9 * math.sin(a + 0.4))], DARK, 1.2)
        c.circ(x + 9 * math.cos(a + 0.4), y + 9 * math.sin(a + 0.4), 1.6, ACC, edge=False)
    if rng.random() < 0.5:
        a0 = float(rng.uniform(0, 2 * math.pi))
        pts = []
        for i in range(10):
            a = a0 + i * 0.09
            rr = r0 + 6 + (2.5 if i % 2 else -2.5)
            pts.append((CX + rr * math.cos(a), CY + rr * math.sin(a)))
        c.line(pts, DARK, 0.9)
