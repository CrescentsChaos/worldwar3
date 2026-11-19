"""Ground vehicles: tracked / wheeled / half-track chassis + payload modules, parameterised per real-world design."""
import math
import re
from core import *

CY = 64.0


# ------------------------------------------------------------------ chassis pieces
def tracks(c, cx, L, W, tw, wheels=7, skirt=False, bogie=False):
    x0, x1 = cx - L / 2, cx + L / 2
    for side in (-1, 1):
        yc = CY + side * (W / 2 - tw / 2)
        c.rect(x0, yc - tw / 2, x1, yc + tw / 2, DARK, r=tw * 0.35)
        n = wheels
        for i in range(n):
            wx = x0 + tw * 0.6 + (L - tw * 1.2) * i / max(n - 1, 1)
            r = tw * (0.46 if i in (0, n - 1) else 0.4)
            c.circ(wx, yc, r, MID, w=1.0)
        if bogie:
            for i in range(0, n - 1, 2):
                wx = x0 + tw * 0.6 + (L - tw * 1.2) * (i + 0.5) / max(n - 1, 1)
                c.line([(wx, yc - tw * 0.3), (wx, yc + tw * 0.3)], EDGE, 1.0)
        if skirt:
            y_in = CY + side * (W / 2 - tw * 0.95)
            y_out = CY + side * (W / 2 + 0.2)
            c.rect(x0 + L * 0.1, min(y_in, y_out), x1 - L * 0.06, max(y_in, y_out), BODY, w=1.2)
            for i in range(1, 7):
                sx = x0 + L * 0.1 + (L * 0.84) * i / 7
                c.line([(sx, min(y_in, y_out)), (sx, max(y_in, y_out))], EDGE, 0.8)


def hull(c, cx, L, W, tw, bev_f=8.0, bev_r=4.0, inset=0.75, fill=BODY, glacis=True, deck=True):
    x0, x1 = cx - L / 2, cx + L / 2
    h = W / 2 - tw * inset
    pts = [(x0 + bev_r, CY - h), (x1 - bev_f, CY - h), (x1, CY - h + bev_f * 0.7), (x1, CY + h - bev_f * 0.7),
           (x1 - bev_f, CY + h), (x0 + bev_r, CY + h), (x0, CY + h - bev_r * 0.8), (x0, CY - h + bev_r * 0.8)]
    c.poly(pts, fill)
    if glacis and bev_f > 2:
        c.poly([(x1 - bev_f * 1.6, CY - h + 1), (x1 - bev_f * 0.2, CY - h + bev_f * 0.7 + 1), (x1 - bev_f * 0.2, CY + h - bev_f * 0.7 - 1), (x1 - bev_f * 1.6, CY + h - 1)], MID, edge=False)
    if deck:
        for i in range(5):
            gx = x0 + L * 0.06 + i * 3.2
            c.line([(gx, CY - h * 0.65), (gx, CY + h * 0.65)], DARK, 1.0)
    return h


def turret(c, shape, tx, ty, r, ry=None):
    ry = ry or r
    if shape == "round":
        c.ell(tx - r, ty - ry, tx + r, ty + ry, BODY)
        c.ell(tx - r * 0.6, ty - ry * 0.6, tx + r * 0.6, ty + ry * 0.6, MID, edge=False)
    elif shape == "box":
        c.poly([(tx - r, ty - ry * 0.85), (tx + r * 0.8, ty - ry), (tx + r, ty - ry * 0.5), (tx + r, ty + ry * 0.5), (tx + r * 0.8, ty + ry), (tx - r, ty + ry * 0.85)], BODY)
        c.rect(tx - r * 0.4, ty - ry * 0.5, tx + r * 0.3, ty + ry * 0.5, MID, edge=False)
    elif shape == "wedge":      # Abrams / Challenger style angular
        c.poly([(tx - r, ty - ry * 0.8), (tx + r * 0.5, ty - ry * 0.55), (tx + r, ty - ry * 0.3), (tx + r, ty + ry * 0.3), (tx + r * 0.5, ty + ry * 0.55), (tx - r, ty + ry * 0.8)], BODY)
        c.poly([(tx + r * 0.1, ty - ry * 0.5), (tx + r, ty - ry * 0.28), (tx + r, ty + ry * 0.28), (tx + r * 0.1, ty + ry * 0.5)], MID, edge=False)
    elif shape == "flat":       # low and wide (T-14, Leclerc, T-72)
        c.ell(tx - r * 1.05, ty - ry * 0.85, tx + r * 1.05, ty + ry * 0.85, BODY)
        c.ell(tx - r * 0.55, ty - ry * 0.45, tx + r * 0.65, ty + ry * 0.45, MID, edge=False)
    elif shape == "oct":
        pts = [(tx + r * math.cos(a), ty + ry * math.sin(a)) for a in [i * math.pi / 4 + math.pi / 8 for i in range(8)]]
        c.poly(pts, BODY)
    elif shape == "open":
        c.rect(tx - r, ty - ry, tx + r, ty + ry, MID, r=2)
        c.rect(tx - r * 0.7, ty - ry * 0.7, tx + r * 0.7, ty + ry * 0.7, DARK, r=1, edge=False)
    else:
        c.circ(tx, ty, r, BODY)


def gun(c, x, y, length, w=3.0, brake=None, sleeve=False, coax=False):
    c.bar(x, y, x + length, y, w, DARK)
    if sleeve:
        c.rect(x + length * 0.25, y - w * 0.95, x + length * 0.7, y + w * 0.95, MID, r=1)
    if brake == "ball":
        c.rect(x + length - 1.5, y - w * 1.2, x + length + 3.5, y + w * 1.2, DARK, r=1)
    elif brake == "double":
        for dx in (0.0, 3.2):
            c.rect(x + length - 3 + dx, y - w * 1.35, x + length - 1 + dx, y + w * 1.35, DARK, r=0.6)
    elif brake == "slot":
        c.rect(x + length - 5, y - w * 1.15, x + length + 1, y + w * 1.15, DARK, r=1)
    elif brake == "evac":
        c.rect(x + length * 0.55, y - w * 1.15, x + length * 0.72, y + w * 1.15, MID, r=1)
    if coax:
        c.bar(x + 2, y + w * 1.6, x + 14, y + w * 1.6, 1.4, DARK)


def hatches(c, tx, ty, r, n=2, cupola=True):
    if cupola:
        c.circ(tx - r * 0.25, ty - r * 0.35, r * 0.2, MID); c.circ(tx - r * 0.25, ty - r * 0.35, r * 0.1, DARK, edge=False)
    if n >= 2:
        c.circ(tx - r * 0.3, ty + r * 0.38, r * 0.18, MID)


def era_plates(c, tx, ty, r):
    for i in range(4):
        yy = ty - r * 0.6 + i * r * 0.4
        c.rect(tx + r * 0.55, yy, tx + r * 0.95, yy + r * 0.3, MID, w=0.8)


# ------------------------------------------------------------------ wheeled pieces
def wheels(c, cx, L, W, n, r=5.0, spread=None):
    x0 = cx - L * 0.4
    x1 = cx + L * 0.4
    for i in range(n):
        wx = x0 + (x1 - x0) * i / max(n - 1, 1)
        for side in (-1, 1):
            c.rect(wx - r, CY + side * (W / 2) - 3.2 + (3.2 if side > 0 else 0) - (0 if side > 0 else 0), wx + r, CY + side * (W / 2) + (3.2 if side > 0 else 0) - (3.2 if side < 0 else 0), DARK, r=1.6, w=1.0)


def wheel_row(c, cx, L, W, n, r=5.0):
    x0 = cx - L * 0.42
    x1 = cx + L * 0.42
    for i in range(n):
        wx = x0 + (x1 - x0) * i / max(n - 1, 1)
        for side in (-1, 1):
            yc = CY + side * (W / 2 + 1.0)
            c.rect(wx - r, yc - 3.4, wx + r, yc + 3.4, DARK, r=1.6, w=1.0)


# ------------------------------------------------------------------ complete vehicles
def tracked(c, p):
    L, W = p.get("L", 74), p.get("W", 42)
    tw = p.get("tw", 9)
    cx = p.get("cx", 60)
    tracks(c, cx, L, W, tw, p.get("wheels", 7), p.get("skirt", False), p.get("bogie", False))
    h = hull(c, cx, L, W, tw, p.get("bev_f", 9), p.get("bev_r", 5), p.get("inset", 0.75), glacis=p.get("glacis", True))
    mod = p.get("mod", "turret")
    tx = cx + p.get("tx", 0.0) * L
    if p.get("rear_deck"):
        c.rect(cx - L * 0.5 + 3, CY - h * 0.7, cx - L * 0.2, CY + h * 0.7, MID, edge=True)
    if mod == "turret":
        tr = p.get("tr", 14)
        tyo = p.get("ty", 0)
        gl = p.get("gun", 38)
        turret(c, p.get("shape", "round"), tx, CY + tyo, tr, p.get("try", tr * p.get("tratio", 1.0)))
        gun(c, tx + tr * 0.55, CY + tyo, gl, p.get("gw", 3.2), p.get("brake"), p.get("sleeve", False), p.get("coax", False))
        if p.get("twin"):
            gun(c, tx + tr * 0.5, CY + tyo + 5, gl * 0.8, 2.0, None)
        if p.get("era"):
            era_plates(c, tx, CY + tyo, tr)
        hatches(c, tx, CY + tyo, tr, 2, True)
        if p.get("mg"):
            c.bar(tx - tr * 0.3, CY + tyo - tr * 0.5, tx + tr * 0.3, CY + tyo - tr * 0.55, 1.4, DARK)
        if p.get("aps"):
            c.rect(tx - tr * 0.1, CY + tyo - tr * 1.25, tx + tr * 0.5, CY + tyo - tr * 0.9, DARK, r=1)
            c.rect(tx - tr * 0.1, CY + tyo + tr * 0.9, tx + tr * 0.5, CY + tyo + tr * 1.25, DARK, r=1)
        if p.get("smoke"):
            for sgn in (-1, 1):
                for i in range(3):
                    c.rect(tx + tr * 0.1 + i * 2.2, CY + tyo + sgn * tr * 0.95 - 1, tx + tr * 0.1 + i * 2.2 + 1.6, CY + tyo + sgn * tr * 0.95 + 1, DARK, w=0.6)
        c.mark("auto", tx - tr * 0.1, CY + tyo, tr * 0.42)
    elif mod == "casemate":
        cl = p.get("cl", 0.5)
        cxm = cx - L * 0.5 + L * (0.12 + cl / 2)
        cw = h * p.get("cw", 1.7) * 0.5
        c.poly([(cxm - L * cl / 2, CY - cw), (cxm + L * cl / 2 - 2, CY - cw * 0.85), (cxm + L * cl / 2, CY - cw * 0.5), (cxm + L * cl / 2, CY + cw * 0.5),
                (cxm + L * cl / 2 - 2, CY + cw * 0.85), (cxm - L * cl / 2, CY + cw)], BODY)
        c.rect(cxm - L * cl * 0.25, CY - cw * 0.5, cxm + L * cl * 0.1, CY + cw * 0.5, MID, edge=False)
        gy = CY + p.get("gy", 0)
        gun(c, cxm + L * cl / 2 - 3, gy, p.get("gun", 36), p.get("gw", 3.6), p.get("brake"))
        c.rect(cxm + L * cl / 2 - 6, gy - 5, cxm + L * cl / 2 + 1, gy + 5, DARK, r=1.5)
        hatches(c, cxm, CY, cw * 0.7, 2, True)
        c.mark("auto", cxm - 4, CY - 2, 6)
    elif mod == "open_gun":
        cl = p.get("cl", 0.5)
        cxm = cx - L * 0.5 + L * (0.14 + cl / 2)
        cw = h * 0.92
        c.rect(cxm - L * cl / 2, CY - cw, cxm + L * cl / 2, CY + cw, MID, r=1.5)
        c.rect(cxm - L * cl / 2 + 2, CY - cw + 2, cxm + L * cl / 2 - 2, CY + cw - 2, DARK, r=1, edge=False)
        c.ell(cxm + L * cl * 0.1 - 6, CY - 6, cxm + L * cl * 0.1 + 6, CY + 6, BODY)
        gun(c, cxm + L * cl * 0.1, CY, p.get("gun", 44), p.get("gw", 4.0), p.get("brake"), p.get("sleeve", False))
        c.rect(cxm + L * cl * 0.1 - 9, CY - 6, cxm + L * cl * 0.1 - 2, CY + 6, MID, r=1)
        c.mark("auto", cxm - 6, CY - cw * 0.6, 5)


def wheeled(c, p):
    L, W = p.get("L", 70), p.get("W", 38)
    cx = 60
    wheel_row(c, cx, L, W, p.get("n", 4), p.get("wr", 5.4))
    x0, x1 = cx - L / 2, cx + L / 2
    h = W / 2 - 3.0
    if p.get("open"):
        pts = [(x0, CY - h), (x1 - 12, CY - h), (x1, CY - h * 0.6), (x1, CY + h * 0.6), (x1 - 12, CY + h), (x0, CY + h)]
        c.poly(pts, BODY)
        c.rect(x0 + L * 0.18, CY - h + 3, x1 - L * 0.38, CY + h - 3, DARK, r=1.5, edge=True)
        for ry in (-h * 0.45, h * 0.45):
            c.bar(x0 + L * 0.2, CY + ry, x1 - L * 0.4, CY + ry, 1.6, MID)
    else:
        bf = p.get("bf", 10)
        pts = [(x0, CY - h), (x1 - bf, CY - h), (x1, CY - h + bf * 0.6), (x1, CY + h - bf * 0.6), (x1 - bf, CY + h), (x0, CY + h)]
        c.poly(pts, BODY)
        c.poly([(x1 - bf * 1.8, CY - h + 1), (x1 - 1, CY - h + bf * 0.6 + 1), (x1 - 1, CY + h - bf * 0.6 - 1), (x1 - bf * 1.8, CY + h - 1)], MID, edge=False)
        for i in range(4):
            c.line([(x0 + 3 + i * 3, CY - h * 0.6), (x0 + 3 + i * 3, CY + h * 0.6)], DARK, 1.0)
    mod = p.get("mod", "turret")
    if mod == "turret":
        tx = cx + p.get("tx", 0.0) * L
        tr = p.get("tr", 11)
        turret(c, p.get("shape", "round"), tx, CY, tr)
        gun(c, tx + tr * 0.5, CY, p.get("gun", 28), p.get("gw", 2.8), p.get("brake"), p.get("sleeve", False))
        if p.get("twin"):
            gun(c, tx + tr * 0.5, CY + 4.5, p.get("gun", 28) * 0.7, 1.8)
        hatches(c, tx, CY, tr, 2, True)
        c.mark("auto", tx - tr * 0.1, CY, tr * 0.4)
    elif mod == "mg":
        mx = cx + p.get("tx", 0.0) * L
        c.circ(mx, CY, 6, MID)
        c.bar(mx, CY, mx + 18, CY, 2.0, DARK)
        c.mark("auto", cx - L * 0.2, CY, 5)
    elif mod == "rack":
        rx = cx - L * 0.1
        c.rect(rx - L * 0.3, CY - h * 0.9, rx + L * 0.3, CY + h * 0.9, MID, r=1)
        c.mark("auto", cx + L * 0.25, CY, 5)
    else:
        c.mark("auto", cx + L * 0.2, CY, 5)


def halftrack(c, p):
    L, W = p.get("L", 78), p.get("W", 36)
    cx = 60
    x0, x1 = cx - L / 2, cx + L / 2
    # rear tracks
    for side in (-1, 1):
        yc = CY + side * (W / 2 - 4)
        c.rect(cx - L * 0.05, yc - 4.2, x1 - L * 0.42 + L * 0.0 - 4 + L * 0.0 + 4 - L * 0.0 - (L * 0.0), yc + 4.2, DARK, r=3) if False else None
        c.rect(x0 + 2, yc - 4.2, cx + L * 0.12, yc + 4.2, DARK, r=3)
        for i in range(4):
            c.circ(x0 + 7 + i * (L * 0.62 / 4), yc, 3.4, MID, w=0.9)
        fx = x1 - L * 0.12
        c.rect(fx - 4.4, yc - 3.4 + side * 0.9, fx + 4.4, yc + 3.4 + side * 0.9, DARK, r=1.6, w=1.0)
    h = W / 2 - 3.5
    pts = [(x0, CY - h), (x1 - 14, CY - h), (x1 - 3, CY - h + 5), (x1 - 3, CY + h - 5), (x1 - 14, CY + h), (x0, CY + h)]
    c.poly(pts, BODY)
    c.rect(x0 + 3, CY - h + 3, cx + L * 0.12, CY + h - 3, DARK, r=1.5, edge=True)
    c.poly([(x1 - 22, CY - h + 1), (x1 - 4, CY - h + 6), (x1 - 4, CY + h - 6), (x1 - 22, CY + h - 1)], MID, edge=False)
    mod = p.get("mod", "mg")
    if mod == "mg":
        c.circ(cx + L * 0.12, CY, 4, MID); c.bar(cx + L * 0.12, CY, cx + L * 0.12 + 17, CY, 2.0, DARK)
        c.bar(x0 + 5, CY - 4, x0 + 14, CY - 4, 1.6, DARK)
    elif mod == "gun88":
        c.ell(cx - 6, CY - 9, cx + 12, CY + 9, MID)
        c.rect(cx - 2, CY - 7, cx + 10, CY + 7, BODY, r=2)
        gun(c, cx + 8, CY, 38, 3.6, "ball")
    elif mod == "quad":
        c.circ(cx + 2, CY, 9, MID)
        for dy in (-4.5, -1.5, 1.5, 4.5):
            c.bar(cx + 4, CY + dy, cx + 30, CY + dy, 1.6, DARK)
    elif mod == "rack":
        c.rect(cx - 12, CY - h * 0.85, cx + 12, CY + h * 0.85, MID, r=1)
        for i in range(2):
            for j in range(5):
                c.circ(cx - 8 + i * 12, CY - h * 0.7 + j * h * 0.35, 2.6, DARK, w=0.8)
    elif mod == "turret":
        turret(c, "box", cx + 6, CY, 9)
        gun(c, cx + 12, CY, p.get("gun", 24), 2.4)
    c.mark("auto", cx - L * 0.2, CY, 5)


# ------------------------------------------------------------------ payload modules for any chassis
def rocket_pack(c, cx, w, h, rows, cols, ang=0.0, tube=2.6):
    c.rect(cx - w / 2, CY - h / 2, cx + w / 2, CY + h / 2, MID, r=1.5)
    for i in range(rows):
        for j in range(cols):
            tx = cx - w / 2 + 3 + (w - 6) * (i + 0.5) / rows
            ty = CY - h / 2 + 3 + (h - 6) * (j + 0.5) / cols
            c.circ(tx, ty, tube, DARK, w=0.8)


def rails(c, cx, L, n=8, h=36):
    for i in range(n):
        yy = CY - h / 2 + h * (i + 0.5) / n
        c.bar(cx - L / 2, yy, cx + L / 2, yy, 2.0, DARK)
    c.line([(cx - L / 2, CY - h / 2), (cx - L / 2, CY + h / 2)], MID, 2.0)
    c.line([(cx + L / 2, CY - h / 2), (cx + L / 2, CY + h / 2)], MID, 2.0)


def canisters(c, cx, n=4, L=34, r=4.6, ang=0.3, rows=1):
    for i in range(n):
        yy = CY - (n - 1) * r * 1.1 + i * r * 2.2
        c.rrect(cx, yy, L, r * 1.9, 0.0, MID)
        c.circ(cx + L / 2, yy, r * 0.8, DARK, w=0.9)


def radar_dish(c, x, y, r=9, ang=0.0):
    c.circ(x, y, r, MID); c.circ(x, y, r * 0.55, BODY, edge=False); c.circ(x, y, r * 0.18, DARK, edge=False)


def phased_array(c, x, y, w=16, h=14):
    c.rect(x - w / 2, y - h / 2, x + w / 2, y + h / 2, DARK, r=1)
    for i in range(1, 4):
        c.line([(x - w / 2, y - h / 2 + i * h / 4), (x + w / 2, y - h / 2 + i * h / 4)], MID, 1.0)


def crane(c, x, y, L=40, ang=0.0):
    c.circ(x, y, 7, MID)
    c.bar(x, y, x + L, y + math.tan(ang) * L, 4.0, DARK)
    c.rect(x + L - 2, y + math.tan(ang) * L - 4, x + L + 5, y + math.tan(ang) * L + 4, MID, r=1)


def dozer(c, x, W, depth=4):
    c.rect(x, CY - W / 2 - 2, x + depth, CY + W / 2 + 2, DARK, r=1)
    c.bar(x - 8, CY - W * 0.3, x, CY - W / 2, 2.0, MID); c.bar(x - 8, CY + W * 0.3, x, CY + W / 2, 2.0, MID)


# ------------------------------------------------------------------ catalogue (name regex -> builder)
T = "tracked"; Wh = "wheeled"; H = "half"
CAT = [
 # --- light tanks
 (r"Panzer III", T, dict(L=66, W=40, tw=8, shape="box", tr=12, gun=30, brake=None, skirt=True, wheels=6, tx=0.04)),
 (r"T-70", T, dict(L=58, W=34, tw=8, shape="round", tr=9, ty=-5, gun=24, wheels=5, bev_f=8)),
 (r"Ha-Go", T, dict(L=52, W=36, tw=8, shape="round", tr=9, gun=18, wheels=5, bev_f=5, mg=True)),
 (r"Scimitar", T, dict(L=64, W=34, tw=8, shape="box", tr=9, gun=24, gw=2.2, wheels=5, bev_f=10)),
 (r"Booker", T, dict(L=74, W=42, tw=9, shape="wedge", tr=14, gun=42, gw=3.8, wheels=7, era=True, aps=True)),
 (r"Jaguar", Wh, dict(L=78, W=38, n=3, shape="wedge", tr=13, gun=34, gw=3.2, tx=0.0)),
 (r"L6/40", T, dict(L=50, W=32, tw=7, shape="round", tr=8, gun=17, gw=2.0, wheels=5, bev_f=4)),
 (r"Sprut", T, dict(L=76, W=40, tw=9, shape="flat", tr=13, gun=44, gw=3.8, wheels=6, bev_f=12, tx=-0.02)),
 # --- medium / main battle tanks
 (r"Panzer IV", T, dict(L=72, W=42, tw=9, shape="box", tr=13, gun=42, gw=3.0, brake="ball", skirt=True, wheels=8, tx=0.0)),
 (r"T-34", T, dict(L=74, W=40, tw=9, shape="round", tr=14, gun=44, gw=3.2, brake="ball", wheels=5, bev_f=14, bev_r=6, tx=0.05)),
 (r"Chi-Ha", T, dict(L=60, W=38, tw=8, shape="round", tr=11, ty=-1, gun=22, gw=2.4, wheels=6, bev_f=5, mg=True)),
 (r"Challenger 2", T, dict(L=84, W=50, tw=11, shape="wedge", tr=16, gun=50, gw=3.8, sleeve=True, brake="evac", wheels=7, bev_f=12, era=True, smoke=True)),
 (r"M1A2 SEP|M1A2C|M1E3", T, dict(L=86, W=48, tw=10, shape="wedge", tr=16, gun=52, gw=4.0, wheels=7, bev_f=12, era=True, smoke=True, aps=True, tx=0.02)),
 (r"Leclerc", T, dict(L=82, W=44, tw=10, shape="flat", tr=14, gun=48, gw=3.8, sleeve=True, wheels=7, bev_f=14, era=True, smoke=True)),
 (r"M13/40", T, dict(L=58, W=38, tw=8, shape="box", tr=10, gun=24, gw=2.4, wheels=6, bev_f=3, tx=-0.02, mg=True)),
 (r"T-72|T-90", T, dict(L=76, W=42, tw=9, shape="flat", tr=13, gun=48, gw=3.6, wheels=6, bev_f=13, era=True, smoke=True, tx=-0.02)),
 # --- heavies
 (r"Tiger II", T, dict(L=88, W=52, tw=12, shape="box", tr=17, gun=62, gw=4.0, brake="double", skirt=True, wheels=9, bev_f=10, tx=-0.06)),
 (r"IS-2", T, dict(L=80, W=44, tw=10, shape="round", tr=15, gun=56, gw=4.0, brake="double", wheels=6, bev_f=12, tx=0.06)),
 (r"Chi-To", T, dict(L=72, W=44, tw=9, shape="round", tr=14, gun=38, gw=3.4, brake="ball", wheels=7, bev_f=6, tx=0.0, mg=True)),
 (r"Challenger 3", T, dict(L=86, W=50, tw=11, shape="wedge", tr=16, gun=52, gw=4.0, sleeve=True, wheels=7, bev_f=12, era=True, aps=True)),
 (r"P26/40", T, dict(L=68, W=42, tw=9, shape="box", tr=13, gun=40, gw=3.2, brake="ball", wheels=7, bev_f=6)),
 # --- super heavies
 (r"Maus", T, dict(L=100, W=60, tw=14, shape="box", tr=20, gun=66, gw=5.2, brake="slot", coax=True, skirt=True, wheels=10, bev_f=8, tx=-0.1)),
 (r"IS-7", T, dict(L=96, W=50, tw=11, shape="round", tr=17, gun=62, gw=4.6, brake="double", wheels=7, bev_f=16, tx=0.06, twin=True)),
 (r"O-I", T, dict(L=104, W=58, tw=12, shape="box", tr=18, gun=48, gw=4.4, brake="ball", wheels=10, bev_f=7, tx=0.08, twin=True)),
 (r"Armata", T, dict(L=92, W=52, tw=11, shape="flat", tr=13, gun=50, gw=3.2, wheels=7, bev_f=16, era=True, aps=True, tx=-0.02)),
 # --- tank destroyers / ATGM carriers
 (r"Jagdpanther", T, dict(L=82, W=44, tw=9, mod="casemate", cl=0.55, cw=1.9, gun=54, gw=4.0, brake="ball", skirt=True, wheels=8, bev_f=14)),
 (r"SU-100", T, dict(L=74, W=40, tw=9, mod="casemate", cl=0.5, cw=1.8, gun=48, gw=3.4, brake="ball", wheels=5, bev_f=12, gy=3)),
 (r"Ho-Ni", T, dict(L=64, W=36, tw=8, mod="open_gun", cl=0.55, gun=38, gw=3.2, brake="ball", wheels=6, bev_f=5)),
 (r"Semovente 90", T, dict(L=66, W=38, tw=8, mod="open_gun", cl=0.55, gun=52, gw=3.6, brake="ball", wheels=6, bev_f=5)),
 (r"Exactor", Wh, dict(L=84, W=40, n=4, mod="launcher")),
 (r"Stryker ATGM", Wh, dict(L=76, W=40, n=4, mod="launcher")),
 (r"AMX-10 RC with MMP", Wh, dict(L=78, W=38, n=3, shape="wedge", tr=12, gun=30, gw=3.0, mod="turret", twin=True)),
 (r"Shturm", T, dict(L=66, W=36, tw=7, mod="launcher", wheels=5, bev_f=12)),
 # --- flame
 (r"Flammpanzer", T, dict(L=66, W=40, tw=8, shape="box", tr=12, gun=24, gw=2.8, wheels=6, skirt=True, flame=True)),
 (r"OT-34", T, dict(L=72, W=40, tw=9, shape="round", tr=13, gun=18, gw=3.0, wheels=5, bev_f=14, flame=True)),
 (r"Flamethrower Tank", T, dict(L=60, W=38, tw=8, shape="round", tr=10, gun=18, gw=2.8, wheels=6, bev_f=5, flame=True)),
 (r"Trojan", T, dict(L=84, W=50, tw=11, shape="box", tr=14, gun=26, gw=5.0, wheels=7, bev_f=8, dozer=True)),
 (r"Breacher", T, dict(L=84, W=48, tw=10, shape="oct", tr=11, gun=12, gw=3.0, wheels=7, bev_f=10, dozer=True, mod="turret")),
 (r"L3 Flame", T, dict(L=40, W=26, tw=6, shape="round", tr=6, gun=14, gw=2.0, wheels=4, bev_f=3, flame=True, trailer=True)),
 (r"TOS-1A", T, dict(L=80, W=44, tw=9, mod="rocketpack", wheels=6, bev_f=13)),
 # --- artillery
 (r"Wespe", T, dict(L=58, W=36, tw=7, mod="open_gun", cl=0.52, gun=30, gw=3.0, brake="ball", wheels=5, bev_f=5)),
 (r"SU-122", T, dict(L=72, W=40, tw=9, mod="casemate", cl=0.5, cw=1.8, gun=34, gw=4.0, wheels=5, bev_f=12)),
 (r"Ho-Ro", T, dict(L=66, W=38, tw=8, mod="open_gun", cl=0.5, gun=36, gw=4.2, wheels=6, bev_f=5)),
 (r"AS-90|Paladin|AuF1|Msta|Koalitsiya", T, dict(L=84, W=44, tw=9, shape="box", tr=18, tratio=0.78, gun=66, gw=3.8, brake="evac", wheels=7, bev_f=8, tx=-0.1)),
 (r"Semovente 75/18", T, dict(L=58, W=34, tw=7, mod="casemate", cl=0.5, cw=1.7, gun=26, gw=3.2, wheels=5, bev_f=5)),
 (r"ERCA", T, dict(L=84, W=44, tw=9, shape="box", tr=18, tratio=0.78, gun=80, gw=3.8, brake="slot", wheels=7, bev_f=8, tx=-0.1)),
 (r"Hummel", T, dict(L=72, W=40, tw=8, mod="open_gun", cl=0.55, gun=48, gw=4.8, brake="slot", wheels=7, bev_f=6)),
 (r"ISU-152", T, dict(L=76, W=42, tw=9, mod="casemate", cl=0.52, cw=1.9, gun=44, gw=5.4, brake="slot", wheels=6, bev_f=12)),
 (r"24 cm", T, dict(L=92, W=50, tw=11, mod="open_gun", cl=0.6, gun=64, gw=6.4, brake="slot", wheels=8, bev_f=6)),
 (r"RCH 155", Wh, dict(L=90, W=40, n=4, shape="box", tr=15, gun=68, gw=3.8, brake="evac", tx=-0.1)),
 (r"CAESAR", Wh, dict(L=92, W=36, n=3, mod="rear_gun")),
 (r"Cannone 149", T, dict(L=80, W=42, tw=9, mod="open_gun", cl=0.55, gun=66, gw=4.4, brake="slot", wheels=7, bev_f=5)),
 # --- rockets
 (r"Panzerwerfer", H, dict(L=80, mod="rack")),
 (r"Katyusha", Wh, dict(L=84, W=36, n=3, mod="rails")),
 (r"20 cm Rocket", Wh, dict(L=84, W=36, n=3, mod="rocketpack")),
 (r"M270|LRU", T, dict(L=84, W=44, tw=9, mod="rocketpack2", wheels=6, bev_f=12)),
 (r"HIMARS", Wh, dict(L=84, W=36, n=3, mod="rocketpack1")),
 (r"Smerch", Wh, dict(L=96, W=40, n=4, mod="rocketpack")),
 # --- AA / SAM trucks
 (r"Wirbelwind", T, dict(L=72, W=42, tw=9, shape="oct", tr=13, gun=26, wheels=8, skirt=True, quad=True, tx=-0.02)),
 (r"SU-37", T, dict(L=72, W=40, tw=9, shape="round", tr=12, gun=30, wheels=5, bev_f=14, twin=True)),
 (r"Type 98 20", Wh, dict(L=76, W=34, n=3, mod="mg", aa=True)),
 (r"Stormer", T, dict(L=72, W=38, tw=8, mod="canisters", wheels=6, bev_f=8)),
 (r"M-SHORAD", Wh, dict(L=82, W=40, n=4, mod="canisters")),
 (r"VAB Mistral", Wh, dict(L=74, W=38, n=3, mod="canisters")),
 (r"Breda 20/65", Wh, dict(L=76, W=34, n=3, mod="mg", aa=True)),
 (r"Pantsir", Wh, dict(L=100, W=42, n=4, mod="pantsir")),
 (r"Sd.Kfz. 7", H, dict(L=82, mod="gun88")),
 (r"M17 MGMC", H, dict(L=80, mod="quad")),
 (r"Ta-Se", T, dict(L=68, W=40, tw=8, shape="box", tr=11, gun=36, wheels=6, bev_f=5, brake="ball")),
 (r"Sky Sabre|VL MICA", Wh, dict(L=92, W=38, n=3, mod="vls")),
 (r"Patriot", Wh, dict(L=100, W=42, n=4, mod="patriot")),
 (r"Autocannone 90", Wh, dict(L=84, W=38, n=3, mod="rear_gun")),
 (r"S-400", Wh, dict(L=104, W=42, n=4, mod="patriot")),
 # --- recovery
 (r"Bergepanther|T-34T|So-Ki|CRARRV|M88|DNG|BREM", T, dict(L=80, W=44, tw=9, mod="crane", wheels=7, bev_f=10)),
 (r"Recovery Tractor", Wh, dict(L=70, W=36, n=3, mod="crane")),
 # --- light vehicles
 (r"Kuebelwagen|Fiat 508|Kurogane", Wh, dict(L=54, W=30, n=2, open=True, mod="none", wr=4.6)),
 (r"GAZ-67B", Wh, dict(L=56, W=30, n=2, open=True, mod="mg")),
 (r"Wolf|JLTV|VBL|Tigr", Wh, dict(L=62, W=34, n=2, mod="mg", bf=12)),
 (r"Puma", Wh, dict(L=84, W=36, n=4, shape="box", tr=10, gun=30, gw=2.8, tx=0.0)),
 (r"BA-64", Wh, dict(L=56, W=30, n=2, shape="round", tr=7, gun=12, gw=1.8, tx=0.0)),
 (r"Sumida", Wh, dict(L=66, W=34, n=2, shape="round", tr=9, gun=14, gw=2.0, tx=-0.02)),
 (r"Jackal", Wh, dict(L=68, W=34, n=2, open=True, mod="mg")),
 (r"Guardian ASV", Wh, dict(L=74, W=38, n=4, shape="box", tr=9, gun=16, gw=2.2)),
 (r"AMX-10 RC", Wh, dict(L=82, W=38, n=3, shape="wedge", tr=13, gun=36, gw=3.4)),
 (r"AB 41", Wh, dict(L=70, W=32, n=2, shape="round", tr=8, gun=16, gw=2.0)),
 (r"BRDM|BTR-82", Wh, dict(L=84, W=36, n=4, shape="round", tr=9, gun=22, gw=2.4, twin=True)),
 (r"Hanomag|M3 Half|Ho-Ha|Sahariana", H, dict(L=82, mod="mg")),
 (r"Warrior", T, dict(L=74, W=40, tw=8, shape="round", tr=11, gun=34, gw=2.8, wheels=6, bev_f=10)),
 (r"Bradley", T, dict(L=74, W=40, tw=8, shape="wedge", tr=11, gun=32, gw=2.6, wheels=6, bev_f=8, aps=True)),
 (r"VBCI", Wh, dict(L=88, W=40, n=4, shape="round", tr=10, gun=28, gw=2.6)),
]


def draw(faction, slot, name, rng):
    c = Canvas()
    spec = None
    for rx, kind, p in CAT:
        if re.search(rx, name):
            spec = (kind, dict(p))
            break
    if spec is None:
        c.fb = True
        spec = ("tracked", dict(L=72, W=40, shape="round", tr=13, gun=36, wheels=7))
    kind, p = spec
    # per-unit proportion variation so even shared designs differ between armies
    perturb(p, rng, ("L", "W", "tw", "tr", "gun", "gw", "cl", "cw", "wr"), 0.09, ("tx", "cl"), 0.025)
    if "wheels" in p:
        p["wheels"] = int(p["wheels"] + rng.integers(-1, 2))
    if "n" in p and kind == "wheeled":
        p["n"] = int(max(2, p["n"] + (rng.integers(-1, 2) if rng.random() < 0.3 else 0)))
    mod = p.get("mod", "turret")
    if kind == "tracked":
        if mod in ("canisters", "launcher", "rocketpack", "rocketpack2", "crane", "vls", "patriot", "pantsir", "rear_gun"):
            tracked(c, dict(p, mod="none"))
            _payload(c, p, mod, rng, tracked=True)
        else:
            tracked(c, p)
            if p.get("flame"):
                c.bar(60 + p["L"] * 0.0 + p.get("tr", 12) * 0.5, CY - 4, 60 + p.get("tr", 12) * 0.5 + 30, CY - 4, 2.4, DARK)
                c.poly([(60 + p.get("tr", 12) * 0.5 + 30, CY - 6), (60 + p.get("tr", 12) * 0.5 + 38, CY - 9), (60 + p.get("tr", 12) * 0.5 + 38, CY + 1), (60 + p.get("tr", 12) * 0.5 + 30, CY - 2)], ACC, edge=False)
            if p.get("dozer"):
                dozer(c, 60 + p["L"] / 2 + 1, p["W"])
            if p.get("quad"):
                for dy in (-4.5, -1.5, 1.5, 4.5):
                    c.bar(60 + 6, CY + dy, 60 + 32, CY + dy, 1.6, DARK)
            if p.get("trailer"):
                c.rect(60 - p["L"] / 2 - 14, CY - 8, 60 - p["L"] / 2 - 1, CY + 8, MID, r=2)
    elif kind == "wheeled":
        if mod in ("rails", "rocketpack", "rocketpack1", "canisters", "launcher", "pantsir", "vls", "patriot", "rear_gun", "crane"):
            wheeled(c, dict(p, mod="none"))
            _payload(c, p, mod, rng, tracked=False)
        else:
            wheeled(c, p)
            if p.get("aa"):
                c.bar(60 + 2, CY, 60 + 22, CY, 3.0, DARK); c.bar(60 + 2, CY + 3.5, 60 + 22, CY + 3.5, 3.0, DARK)
    else:
        halftrack(c, p)
    return c


def _payload(c, p, mod, rng, tracked):
    L = p.get("L", 80)
    cx = 60
    if mod == "rails":
        rails(c, cx, L * 0.6, 8, 32)
    elif mod == "rocketpack":
        rocket_pack(c, cx + 2, L * 0.55, 32, 4, 6)
    elif mod == "rocketpack1":
        rocket_pack(c, cx, L * 0.5, 24, 3, 2)
    elif mod == "rocketpack2":
        rocket_pack(c, cx - 8, L * 0.34, 30, 3, 3); rocket_pack(c, cx + 18, L * 0.3, 30, 3, 3)
    elif mod == "canisters":
        canisters(c, cx, 4, L * 0.45, 4.4)
    elif mod == "launcher":
        c.rect(cx - L * 0.28, CY - 14, cx + L * 0.12, CY + 14, MID, r=2)
        for i in range(2):
            c.rrect(cx - L * 0.1, CY - 7 + i * 14, L * 0.36, 7, 0.0, DARK)
        c.circ(cx + L * 0.25, CY, 6, BODY)
    elif mod == "pantsir":
        c.rect(cx - L * 0.35, CY - 15, cx + L * 0.2, CY + 15, MID, r=2)
        for i in range(2):
            for j in range(3):
                c.circ(cx - L * 0.28 + i * 12, CY - 11 + j * 11, 3.6, DARK, w=0.8)
        for dy in (-6, 6):
            c.bar(cx + 6, CY + dy, cx + 38, CY + dy, 2.4, DARK)
        phased_array(c, cx + L * 0.3, CY, 12, 12)
    elif mod == "vls":
        c.rect(cx - L * 0.3, CY - 15, cx + L * 0.25, CY + 15, MID, r=2)
        for i in range(4):
            for j in range(4):
                c.circ(cx - L * 0.25 + i * 8, CY - 10.5 + j * 7, 2.8, DARK, w=0.8)
        phased_array(c, cx + L * 0.36, CY, 10, 14)
    elif mod == "patriot":
        for i in range(4):
            yy = CY - 15 + i * 10
            c.rrect(cx - L * 0.05, yy, L * 0.48, 8.4, 0.0, MID)
            c.circ(cx + L * 0.19, yy, 3.4, DARK, w=0.8)
        c.rect(cx + L * 0.34, CY - 10, cx + L * 0.44, CY + 10, DARK, r=1)
    elif mod == "rear_gun":
        c.rect(cx - L * 0.45, CY - 12, cx - L * 0.15, CY + 12, MID, r=2)
        c.bar(cx - L * 0.3, CY, cx + L * 0.3, CY, 4.2, DARK)
        c.rect(cx + L * 0.28, CY - 4, cx + L * 0.35, CY + 4, DARK)
        c.rect(cx + L * 0.12, CY - 13, cx + L * 0.38, CY + 13, BODY, r=2)
    elif mod == "crane":
        c.rect(cx - L * 0.2, CY - 16, cx + L * 0.15, CY + 16, MID, r=2)
        crane(c, cx - L * 0.05, CY, L * 0.62, 0.0)
        c.rect(cx - L * 0.5, CY - 14, cx - L * 0.38, CY + 14, DARK, r=1)
    c.mark("auto", cx - L * 0.3, CY - 12, 4)
