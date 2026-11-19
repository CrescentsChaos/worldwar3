"""Ships and submarines: hull outline, superstructure, funnels, turrets / VLS / flight deck per real class."""
import math
import re
from core import *

CY = 64.0


def hull_poly(x0, x1, w, bow=0.22, stern=0.06, sq=False):
    """Pointed bow, rounded or square stern. Returns outline points (top side then bottom side)."""
    L = x1 - x0
    pts_t = [(x0, CY - w * (0.7 if sq else 0.45)), (x0 + L * 0.08, CY - w), (x1 - L * bow, CY - w), (x1 - L * bow * 0.3, CY - w * 0.55), (x1, CY)]
    pts_b = [(x1 - L * bow * 0.3, CY + w * 0.55), (x1 - L * bow, CY + w), (x0 + L * 0.08, CY + w), (x0, CY + w * (0.7 if sq else 0.45))]
    return pts_t + pts_b


def turret_gun(c, x, y, r, barrels=2, L=14, w=1.9, dirn=1):
    c.circ(x, y, r, MID)
    for i in range(barrels):
        off = (i - (barrels - 1) / 2) * (r * 0.8)
        c.bar(x, y + off, x + dirn * L, y + off, w, DARK)
    c.circ(x, y, r * 0.5, BODY, edge=False)


def vls_block(c, x0, x1, w, rows=2):
    c.rect(x0, CY - w, x1, CY + w, MID, edge=True, w=1.0)
    n = int((x1 - x0) / 3.2)
    for i in range(n):
        for j in range(rows):
            yy = CY - w + (j + 0.5) * (2 * w / rows)
            c.rect(x0 + 1 + i * 3.2, yy - 1.1, x0 + 1 + i * 3.2 + 2.2, yy + 1.1, DARK, edge=False)


def funnel(c, x, w, L=9):
    c.rect(x - L / 2, CY - w, x + L / 2, CY + w, MID, r=2)
    c.ell(x - L / 2 + 1, CY - w + 1, x + L / 2 - 1, CY + w - 1, DARK, edge=False)


def mast_radar(c, x, kind="dome"):
    if kind == "dome":
        c.circ(x, CY, 3.0, LIGHT)
    elif kind == "array":
        c.rect(x - 2, CY - 5, x + 2, CY + 5, DARK, r=1)


def classic(c, p):
    """Gun ship: destroyers, cruisers, battleships, torpedo boats."""
    L, w = p["L"], p["w"]
    x0 = 64 - L / 2
    x1 = 64 + L / 2
    c.poly(hull_poly(x0, x1, w, p.get("bow", 0.22), 0.06, p.get("sq", False)), BODY)
    c.line([(x0 + 4, CY), (x1 - 6, CY)], EDGE, 0.8)
    # fore turrets, aft turrets
    for tx, b in p.get("fore", []):
        turret_gun(c, x0 + L * tx, CY, p.get("tr", 5), b, p.get("gl", 14), p.get("gw", 2.0), 1)
    for tx, b in p.get("aft", []):
        turret_gun(c, x0 + L * tx, CY, p.get("tr", 5), b, p.get("gl", 14), p.get("gw", 2.0), -1)
    # superstructure
    sx = x0 + L * p.get("sup", 0.5)
    sl = L * p.get("supl", 0.16)
    c.rect(sx - sl / 2, CY - w * 0.55, sx + sl / 2, CY + w * 0.55, LIGHT, r=2)
    c.rect(sx - sl / 4, CY - w * 0.3, sx + sl / 4, CY + w * 0.3, MID, r=1, edge=False)
    for fx in p.get("funnels", []):
        funnel(c, x0 + L * fx, w * 0.38)
    if p.get("vls"):
        a, b = p["vls"]
        vls_block(c, x0 + L * a, x0 + L * b, w * 0.5)
    if p.get("helo"):
        c.rect(x0 + L * 0.06, CY - w * 0.6, x0 + L * 0.22, CY + w * 0.6, MID, r=1); c.circ(x0 + L * 0.14, CY, w * 0.4, DARK, edge=False); c.line([(x0 + L * 0.1, CY), (x0 + L * 0.18, CY)], ACC, 1.2)
    if p.get("catapult"):
        c.line([(x0 + L * 0.3, CY - w * 0.9), (x0 + L * 0.3, CY + w * 0.9)], DARK, 1.4)
    mast_radar(c, sx + sl * 0.2, p.get("radar", "dome"))
    if p.get("torp"):
        for s in (-1, 1):
            c.rect(x0 + L * 0.46, CY + s * w * 0.88 - 1.5, x0 + L * 0.62, CY + s * w * 0.88 + 1.5, DARK, r=1)
    c.mark("auto", x0 + L * 0.34, CY, 0)


def small_boat(c, p):
    """Patrol boats, gunboats and corvettes. Flags: cat (twin hull), tri (trimaran), cabin, guns, torp, rib, ramp, helo, vls, flat ..."""
    L, w = p["L"], p["w"]
    x0, x1 = 64 - L / 2, 64 + L / 2
    st = p.get("style", "hull")
    if st == "cat":
        for s in (-1, 1):
            c.poly(hull_poly(x0, x1, w * 0.38, 0.28, 0.04, True) if False else [(x0, CY + s * w * 0.75 - w * 0.35), (x1 - L * 0.18, CY + s * w * 0.75 - w * 0.35), (x1, CY + s * w * 0.75), (x1 - L * 0.18, CY + s * w * 0.75 + w * 0.35), (x0, CY + s * w * 0.75 + w * 0.35)], BODY)
        c.rect(x0 + L * 0.1, CY - w * 0.9, x1 - L * 0.12, CY + w * 0.9, MID, r=1.5)
    elif st == "tri":
        c.poly(hull_poly(x0, x1, w * 0.62, 0.26, 0.04, True), BODY)
        for s in (-1, 1):
            c.poly([(x0 + L * 0.05, CY + s * w * 0.9 - 2.2), (x1 - L * 0.3, CY + s * w * 0.9 - 2.2), (x1 - L * 0.22, CY + s * w * 0.9), (x1 - L * 0.3, CY + s * w * 0.9 + 2.2), (x0 + L * 0.05, CY + s * w * 0.9 + 2.2)], MID)
            c.line([(x0 + L * 0.4, CY + s * w * 0.3), (x0 + L * 0.4, CY + s * w * 0.9)], DARK, 1.6)
    elif st == "rib":
        c.poly([(x0, CY - w * 0.9), (x1 - L * 0.25, CY - w), (x1, CY), (x1 - L * 0.25, CY + w), (x0, CY + w * 0.9)], DARK)
        c.poly([(x0 + 2, CY - w * 0.55), (x1 - L * 0.3, CY - w * 0.6), (x1 - 5, CY), (x1 - L * 0.3, CY + w * 0.6), (x0 + 2, CY + w * 0.55)], BODY)
    elif st == "wood":
        c.poly(hull_poly(x0, x1, w, 0.34, 0.04, False), BODY)
        for i in range(1, 7):
            c.line([(x0 + L * i / 8, CY - w * 0.9), (x0 + L * i / 8, CY + w * 0.9)], EDGE, 0.8)
    else:
        c.poly(hull_poly(x0, x1, w, p.get("bow", 0.3), 0.04, p.get("sq", True)), BODY)
    cb = p.get("cabin", (0.4, 0.68, 0.6))
    if cb:
        c.rect(x0 + L * cb[0], CY - w * cb[2], x0 + L * cb[1], CY + w * cb[2], LIGHT, r=2)
        c.rect(x0 + L * (cb[0] + 0.03), CY - w * cb[2] * 0.6, x0 + L * (cb[1] - 0.03), CY + w * cb[2] * 0.6, DARK, r=1, edge=False)
    for tx, b in p.get("guns", []):
        turret_gun(c, x0 + L * tx, CY, p.get("tr", 4), b, p.get("gl", 10), 1.6, 1)
    if p.get("turret_t34"):
        c.ell(x0 + L * 0.34 - 8, CY - 7, x0 + L * 0.34 + 8, CY + 7, BODY); c.bar(x0 + L * 0.34, CY, x0 + L * 0.34 + 22, CY, 3.0, DARK)
    if p.get("torp"):
        for s in (-1, 1):
            c.rect(x0 + L * 0.2, CY + s * w * 0.72 - 1.4, x0 + L * 0.52, CY + s * w * 0.72 + 1.4, DARK, r=1)
    if p.get("chutes"):
        for s in (-1, 1):
            c.rect(x0 + L * 0.0, CY + s * w * 0.4 - 1.6, x0 + L * 0.28, CY + s * w * 0.4 + 1.6, DARK, r=1)
    if p.get("outboard"):
        for k in range(int(p["outboard"])):
            yy = CY + (k - (p["outboard"] - 1) / 2) * w * 0.7
            c.rect(x0 - 5, yy - 2.2, x0 + 3, yy + 2.2, DARK, r=1)
    if p.get("explosive"):
        c.rect(x1 - L * 0.34, CY - w * 0.55, x1 - L * 0.1, CY + w * 0.55, RED, r=1.5, edge=True)
    if p.get("helo"):
        c.rect(x0 + L * 0.02, CY - w * 0.6, x0 + L * 0.26, CY + w * 0.6, MID, r=1.5); c.circ(x0 + L * 0.14, CY, w * 0.42, DARK, edge=False)
    if p.get("ramp"):
        c.rect(x0 - 3, CY - w * 0.5, x0 + 4, CY + w * 0.5, MID, r=1)
    if p.get("vls"):
        a, b = p["vls"]
        vls_block(c, x0 + L * a, x0 + L * b, w * 0.4, 2)
    if p.get("missiles"):
        for i in range(p["missiles"]):
            c.rect(x0 + L * 0.58 + (i % 2) * L * 0.12, CY - w * 0.7 + (i // 2) * w * 0.9 - 1, x0 + L * 0.66 + (i % 2) * L * 0.12, CY - w * 0.7 + (i // 2) * w * 0.9 + 1.4, DARK, r=0.6)
    if p.get("fun"):
        funnel(c, x0 + L * p["fun"], w * 0.3, 6)
    if p.get("mast"):
        c.circ(x0 + L * p["mast"], CY, 2.4, DARK)
    c.mark("auto", x0 + L * 0.3, CY, 0)


def carrier(c, p):
    L, w = p["L"], p["w"]
    x0, x1 = 64 - L / 2, 64 + L / 2
    ang = p.get("angled", True)
    c.poly(hull_poly(x0, x1, w, 0.14, 0.04, True), BODY)
    # flight deck overhang
    c.poly([(x0 + 2, CY - w * 1.04), (x1 - L * 0.06, CY - w * 1.04), (x1, CY - w * 0.5), (x1, CY + w * 0.4), (x1 - L * 0.1, CY + w * 1.04 + (4 if ang else 0)), (x0 + 2, CY + w * 1.04 + (4 if ang else 0))], MID)
    c.line([(x0 + 6, CY - w * 0.15), (x1 - 8, CY - w * 0.15)], LIGHT, 1.4)
    if ang:
        c.bar(x0 + L * 0.25, CY - w * 0.75, x1 - L * 0.22, CY + w * 0.85, 2.4, LIGHT, edge=False)
    for k in range(3):
        c.line([(x0 + L * (0.22 + k * 0.05), CY - w * 0.9), (x0 + L * (0.22 + k * 0.05), CY + w * 0.1)], LIGHT, 1.0) if False else None
    ix = x0 + L * p.get("island", 0.58)
    iw = p.get("isl_w", 0.5)
    c.rect(ix - L * 0.05, CY - w * 1.05, ix + L * 0.05, CY - w * (1.05 - iw), LIGHT, r=1.5)
    c.rect(ix - L * 0.02, CY - w * 1.0, ix + L * 0.02, CY - w * 0.65, DARK, r=1, edge=False)
    if p.get("twin"):
        ix2 = x0 + L * 0.7
        c.rect(ix2 - L * 0.035, CY - w * 1.05, ix2 + L * 0.035, CY - w * 0.6, LIGHT, r=1.5)
    if p.get("funnel"):
        c.rect(ix - L * 0.03, CY - w * 1.2, ix + L * 0.03, CY - w * 1.04, DARK, r=2)
    if p.get("deck_launchers"):
        for k in range(6):
            c.rect(x1 - L * 0.2 - k * 4.4, CY + w * 0.05, x1 - L * 0.2 - k * 4.4 + 3, CY + w * 0.4, DARK, r=0.6)
    if p.get("narrow"):
        c.rect(x0 + L * 0.1, CY - w * 1.05, x1 - L * 0.1, CY - w * 0.95, MID, edge=False)
    for k in range(p.get("lifts", 2)):
        c.rect(x0 + L * (0.36 + k * 0.2), CY + w * 0.6, x0 + L * (0.36 + k * 0.2) + 7, CY + w * 0.95, DARK, r=1)
    if p.get("ski"):
        c.poly([(x1 - 2, CY - w * 0.5), (x1 - L * 0.12, CY - w * 0.4), (x1 - L * 0.12, CY + w * 0.4), (x1 - 2, CY + w * 0.4)], BODY)
    for k in range(5):
        c.rect(x0 + L * 0.1 + k * L * 0.04, CY + w * 0.2, x0 + L * 0.1 + k * L * 0.04 + 6, CY + w * 0.2 + 3, LIGHT, r=0.5, edge=False) if False else None
    c.mark("auto", x0 + L * 0.3, CY, 0)


def submarine(c, p):
    L, w = p["L"], p["w"]
    x0, x1 = 64 - L / 2, 64 + L / 2
    tp = p.get("taper", 0.2)
    pts = [(x0, CY - w * (0.1 + tp * 0.4)), (x0 + L * 0.12, CY - w * 0.8), (x0 + L * 0.5, CY - w), (x1 - L * 0.18, CY - w * 0.9), (x1 - 3, CY - w * 0.4), (x1, CY),
           (x1 - 3, CY + w * 0.4), (x1 - L * 0.18, CY + w * 0.9), (x0 + L * 0.5, CY + w), (x0 + L * 0.12, CY + w * 0.8), (x0, CY + w * (0.1 + tp * 0.4))]
    c.poly(pts, BODY)
    c.line([(x0 + 6, CY), (x1 - 8, CY)], EDGE, 0.8)
    sx = x0 + L * p.get("sail", 0.55)
    sl, sw = L * p.get("sl", 0.14), w * p.get("sw", 0.35) * 2
    if p.get("hump"):
        c.rect(x0 + L * 0.74, CY - w * 0.55, x0 + L * 0.9, CY + w * 0.55, MID, r=3)
        c.rect(x0 + L * 0.76, CY - w * 0.4, x0 + L * 0.88, CY - w * 0.1, DARK, r=1, edge=False)
    if p.get("vls"):
        c.rect(x0 + L * 0.58, CY - w * 0.5, x0 + L * 0.72, CY + w * 0.5, DARK, r=1)
        for i in range(2):
            for j in range(4):
                c.circ(x0 + L * 0.62 + i * 6, CY - w * 0.36 + j * w * 0.24, 1.3, MID, edge=False)
    c.rect(sx - sl / 2, CY - sw / 2, sx + sl / 2, CY + sw / 2, MID, r=2)
    c.rect(sx - sl * 0.2, CY - 1.3, sx + sl * 0.4, CY + 1.3, DARK, edge=False)
    pl = p.get("planes", "sail")
    for s in (-1, 1):
        if pl == "sail":
            c.poly([(sx + sl * 0.45, CY + s * sw * 0.5), (sx + sl * 0.6, CY + s * w * 1.1), (sx - sl * 0.1, CY + s * w * 1.1), (sx - sl * 0.2, CY + s * sw * 0.5)], MID)
        else:
            c.poly([(x1 - L * 0.2, CY + s * w * 0.5), (x1 - L * 0.17, CY + s * w * 1.15), (x1 - L * 0.26, CY + s * w * 1.15), (x1 - L * 0.28, CY + s * w * 0.5)], MID)
        c.poly([(x0 + 2, CY + s * 2), (x0 - 4, CY + s * w * 1.25), (x0 + 8, CY + s * w * 1.25), (x0 + 12, CY + s * 2)], MID)
    if p.get("pump"):
        c.circ(x0 + 2, CY, w * 0.45, DARK, edge=True)
    if p.get("deck_gun"):
        c.circ(x0 + L * 0.3, CY, 3.4, DARK); c.bar(x0 + L * 0.3, CY, x0 + L * 0.3 + 9, CY, 1.6, DARK)
    c.mark("auto", x0 + L * 0.3, CY, 0)


# (regex, builder, params)
CAT = [
 # ---- patrol boats
 (r"S-100", "small", dict(L=84, w=7.5, style="wood", guns=[(0.84, 1)], torp=True, cabin=(0.4, 0.58, 0.5), outboard=0, tr=3, bow=0.3)),
 (r"G-5", "small", dict(L=60, w=6, style="wood", chutes=True, cabin=(0.46, 0.62, 0.45), guns=[(0.76, 1)], tr=2.6)),
 (r"Shinyo", "small", dict(L=58, w=6.4, style="wood", explosive=True, cabin=None, outboard=1)),
 (r"P2000", "small", dict(L=54, w=6.6, style="hull", cabin=(0.5, 0.74, 0.55), outboard=2, guns=[(0.2, 1)], tr=2.6)),
 (r"Mk VI", "small", dict(L=84, w=9, style="hull", cabin=(0.44, 0.66, 0.6), guns=[(0.8, 1), (0.1, 1)], outboard=2, bow=0.26, tr=3.6)),
 (r"Vedette", "small", dict(L=66, w=7.4, style="hull", cabin=(0.3, 0.6, 0.62), guns=[(0.82, 1)], fun=0.5, mast=0.45, tr=3)),
 (r"MAS", "small", dict(L=78, w=7.6, style="wood", chutes=True, cabin=(0.46, 0.62, 0.5), guns=[(0.8, 1), (0.14, 1)], tr=3)),
 (r"Raptor", "small", dict(L=66, w=8, style="rib", cabin=(0.5, 0.68, 0.4), guns=[(0.28, 1)], outboard=2, tr=2.8)),
 # ---- gunboats / OPV
 (r"Siebel", "small", dict(L=96, w=14, style="cat", guns=[(0.82, 1), (0.14, 2)], cabin=None, tr=4.6, gl=16)),
 (r"BK-1124", "small", dict(L=90, w=10, style="hull", turret_t34=True, cabin=(0.55, 0.76, 0.6), guns=[(0.12, 1)], tr=3.4, bow=0.22, sq=False)),
 (r"Hashidate", "small", dict(L=82, w=8.6, style="hull", guns=[(0.8, 1), (0.24, 1)], cabin=(0.42, 0.62, 0.55), fun=0.52, tr=3.8, bow=0.28)),
 (r"River-class", "small", dict(L=112, w=12, style="hull", guns=[(0.84, 1)], cabin=(0.36, 0.64, 0.66), helo=True, ramp=True, tr=3.6, bow=0.22, mast=0.5)),
 (r"Cyclone", "small", dict(L=104, w=10.4, style="hull", guns=[(0.84, 1), (0.64, 1)], cabin=(0.38, 0.6, 0.6), ramp=True, tr=3.6, bow=0.24)),
 (r"Gowind", "small", dict(L=110, w=11.4, style="hull", guns=[(0.84, 1)], cabin=(0.4, 0.62, 0.62), helo=True, vls=(0.6, 0.72), tr=4, bow=0.2, mast=0.52)),
 (r"Cannoniera", "small", dict(L=82, w=8.4, style="wood", guns=[(0.82, 1), (0.18, 1)], cabin=(0.42, 0.6, 0.55), fun=0.5, tr=3.6)),
 (r"Grachonok", "small", dict(L=76, w=8, style="hull", guns=[(0.8, 1)], cabin=(0.46, 0.72, 0.55), ramp=True, tr=2.8, outboard=0, mast=0.5)),
 # ---- torpedo / missile boats, corvettes, frigates
 (r"T-24", "small", dict(L=100, w=9, style="hull", guns=[(0.82, 1), (0.18, 1)], torp=True, cabin=(0.42, 0.58, 0.5), fun=0.46, tr=3.6, bow=0.28)),
 (r"Komsomolets", "small", dict(L=88, w=8.4, style="wood", guns=[(0.8, 1), (0.24, 1)], chutes=True, cabin=(0.46, 0.62, 0.5), tr=3)),
 (r"Otori", "small", dict(L=86, w=8.2, style="hull", guns=[(0.82, 1)], torp=True, cabin=(0.4, 0.58, 0.52), fun=0.5, tr=3.2, bow=0.3)),
 (r"Type 31", "classic", dict(L=114, w=11.6, fore=[(0.84, 1)], aft=[(0.24, 1)], sup=0.44, supl=0.24, vls=(0.62, 0.76), helo=True, bow=0.19, radar="array", funnels=[0.36], tr=4)),
 (r"Independence", "small", dict(L=118, w=14, style="tri", guns=[(0.84, 1)], cabin=(0.34, 0.62, 0.5), helo=True, vls=(0.62, 0.72), tr=4, mast=0.5)),
 (r"La Fayette", "small", dict(L=116, w=11.2, style="hull", guns=[(0.84, 1)], cabin=(0.36, 0.6, 0.66), helo=True, vls=(0.62, 0.74), missiles=4, tr=3.6, bow=0.22, mast=0.5)),
 (r"MTM", "small", dict(L=60, w=6.8, style="wood", explosive=True, cabin=(0.4, 0.54, 0.4), outboard=1)),
 (r"Buyan", "small", dict(L=100, w=10.6, style="hull", guns=[(0.86, 1)], cabin=(0.4, 0.62, 0.62), vls=(0.58, 0.72), fun=0.36, helo=False, tr=3.8, bow=0.24, mast=0.46)),
 (r"Gnevny|Fubuki", "classic", dict(L=100, w=9, fore=[(0.8, 2), (0.7, 2)], aft=[(0.12, 2), (0.24, 2)], sup=0.5, supl=0.12, funnels=[0.4, 0.58], torp=True, tr=4)),
 (r"Z-31", "classic", dict(L=104, w=10, fore=[(0.82, 2), (0.72, 2)], aft=[(0.12, 1), (0.22, 1)], sup=0.5, supl=0.14, funnels=[0.46], torp=True, tr=4.4, gl=15)),
 (r"Soldati", "classic", dict(L=104, w=9.5, fore=[(0.82, 2), (0.72, 2)], aft=[(0.12, 2)], sup=0.5, supl=0.13, funnels=[0.42, 0.58], torp=True, tr=4)),
 (r"Type 45", "classic", dict(L=114, w=11.5, fore=[(0.84, 1)], sup=0.42, supl=0.24, vls=(0.66, 0.8), helo=True, bow=0.17, radar="array", funnels=[0.3], tr=4.4)),
 (r"Arleigh", "classic", dict(L=112, w=10.5, fore=[(0.82, 1)], sup=0.5, supl=0.18, vls=(0.62, 0.74), helo=True, bow=0.2, radar="array", funnels=[0.38, 0.56], tr=4.2)),
 (r"FREMM|Aquitaine", "classic", dict(L=108, w=10.5, fore=[(0.8, 1)], sup=0.55, supl=0.2, vls=(0.4, 0.52), helo=True, bow=0.2, radar="dome", funnels=[0.34])),
 (r"Gorshkov", "classic", dict(L=110, w=10.5, fore=[(0.82, 1)], sup=0.46, supl=0.22, vls=(0.62, 0.76), helo=True, bow=0.19, radar="array", funnels=[0.3, 0.38], tr=4.4)),
 (r"Admiral Hipper", "classic", dict(L=124, w=13, fore=[(0.82, 2), (0.72, 2)], aft=[(0.18, 2), (0.28, 2)], sup=0.52, supl=0.14, funnels=[0.44], tr=5.4, gl=16, gw=2.2, catapult=True)),
 (r"Kirov-class Cruiser|Takao|Zara|Slava", "classic", dict(L=124, w=13, fore=[(0.82, 3), (0.72, 3)], aft=[(0.16, 3)], sup=0.5, supl=0.16, funnels=[0.44, 0.58], tr=5.4, gl=16, helo=True)),
 (r"City-class", "classic", dict(L=122, w=12, fore=[(0.84, 1)], sup=0.46, supl=0.22, vls=(0.66, 0.8), helo=True, bow=0.17, radar="array", funnels=[0.34])),
 (r"Ticonderoga", "classic", dict(L=124, w=12.5, fore=[(0.86, 1)], aft=[(0.1, 1)], sup=0.5, supl=0.2, vls=(0.62, 0.76), helo=True, bow=0.19, radar="array", funnels=[0.4, 0.54], tr=4.6)),
 (r"Horizon|Forbin", "classic", dict(L=118, w=12, fore=[(0.82, 1)], sup=0.5, supl=0.2, vls=(0.44, 0.58), helo=True, bow=0.18, radar="dome", funnels=[0.32])),
 (r"Bismarck|Littorio|Sovetsky", "classic", dict(L=132, w=15.5, fore=[(0.82, 2), (0.7, 2)], aft=[(0.2, 2), (0.3, 2)], sup=0.52, supl=0.14, funnels=[0.46], tr=6.4, gl=19, gw=2.6, catapult=True)),
 (r"Yamato", "classic", dict(L=134, w=16.5, fore=[(0.82, 3), (0.7, 3)], aft=[(0.22, 3)], sup=0.5, supl=0.14, funnels=[0.44], tr=7, gl=20, gw=2.8)),
 (r"Kirov-class Battlecruiser", "classic", dict(L=134, w=14.5, fore=[(0.82, 3), (0.72, 3)], aft=[(0.14, 3)], sup=0.5, supl=0.16, vls=(0.58, 0.7), funnels=[0.44], tr=6.4, gl=18, gw=2.4)),
 (r"Zumwalt", "classic", dict(L=124, w=11.5, fore=[(0.82, 1), (0.72, 1)], sup=0.38, supl=0.28, vls=(0.46, 0.7), helo=True, bow=0.3, radar="array")),
 # ---- submarines
 (r"Type XXI", "sub", dict(L=108, w=7, sail=0.5, sl=0.1, sw=0.3, deck_gun=False, planes="sail", taper=0.2)),
 (r"Shchuka", "sub", dict(L=104, w=6.8, sail=0.5, sl=0.12, sw=0.34, deck_gun=True, planes="bow", taper=0.12)),
 (r"I-400", "sub", dict(L=122, w=8.4, sail=0.62, sl=0.1, sw=0.4, deck_gun=True, hump=True, planes="bow", taper=0.12)),
 (r"Astute", "sub", dict(L=116, w=8.6, sail=0.45, sl=0.16, sw=0.36, planes="sail", taper=0.3, pump=True)),
 (r"Virginia", "sub", dict(L=114, w=8.4, sail=0.38, sl=0.15, sw=0.34, vls=True, planes="bow", taper=0.3)),
 (r"Barracuda|Suffren", "sub", dict(L=106, w=8.2, sail=0.44, sl=0.13, sw=0.34, planes="sail", taper=0.34, pump=True)),
 (r"Marcello", "sub", dict(L=100, w=7, sail=0.5, sl=0.1, sw=0.32, deck_gun=True, planes="bow", taper=0.14)),
 (r"Yasen", "sub", dict(L=122, w=9.4, sail=0.42, sl=0.18, sw=0.4, vls=True, hump=True, planes="sail", taper=0.28)),
 # ---- carriers
 (r"Graf Zeppelin", "carrier", dict(L=124, w=13, island=0.6, lifts=2, angled=False, isl_w=0.3)),
 (r"Shokaku", "carrier", dict(L=126, w=14, island=0.5, lifts=2, angled=False, isl_w=0.28, funnel=True)),
 (r"Queen Elizabeth", "carrier", dict(L=128, w=15, island=0.46, lifts=2, ski=True, twin=True, angled=False)),
 (r"Kuznetsov", "carrier", dict(L=126, w=15, island=0.54, lifts=2, ski=True, deck_launchers=True)),
 (r"Gerald R. Ford", "carrier", dict(L=130, w=16.5, island=0.74, lifts=3)),
 (r"Charles de Gaulle", "carrier", dict(L=122, w=15, island=0.58, lifts=2)),
 (r"Aquila", "carrier", dict(L=118, w=12, island=0.5, lifts=1, angled=False, narrow=True)),
]


def draw(faction, slot, name, rng):
    c = Canvas()
    for rx, kind, p in CAT:
        if re.search(rx, name):
            p = dict(p)
            perturb(p, rng, ("L", "w", "tr", "gl"), 0.05, ("sup", "supl", "bow", "island"), 0.025)
            for key in ("fore", "aft"):
                if key in p:
                    p[key] = [(t + float(rng.uniform(-0.025, 0.025)), b) for t, b in p[key]]
            if "funnels" in p:
                p["funnels"] = [f + float(rng.uniform(-0.03, 0.03)) for f in p["funnels"]]
            if isinstance(p.get("vls"), tuple):
                a, b = p["vls"]; d = float(rng.uniform(-0.03, 0.03)); p["vls"] = (a + d, b + d)
            {"small": small_boat, "classic": classic, "carrier": carrier, "sub": submarine}[kind](c, p)
            return c
    c.fb = True
    classic(c, dict(L=100, w=10, fore=[(0.8, 2)], aft=[(0.14, 1)], sup=0.5, supl=0.14, funnels=[0.45]))
    return c
