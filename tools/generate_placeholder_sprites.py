#!/usr/bin/env python3
"""Generates the placeholder sprites in assets/sprites/ (requires Pillow).

All sprites are drawn top-down, FACING RIGHT, on a 128x128 transparent canvas
in neutral light greys so the in-game team tint (blue / red) shows through.
You don't need to run this - it only exists so the placeholders can be
regenerated or restyled. To use your own art just overwrite the PNGs (or drop
files with the same name into the user://sprites folder).
"""
import os
from PIL import Image, ImageDraw

SS = 4                      # supersampling factor
N = 128
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sprites")

BODY = (216, 220, 208, 255)
MID = (168, 175, 158, 255)
DARK = (84, 90, 78, 255)
EDGE = (38, 42, 34, 255)
ACC = (240, 196, 60, 255)
RED = (214, 70, 60, 255)


class Canvas:
    def __init__(self):
        self.img = Image.new("RGBA", (N * SS, N * SS), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    def _s(self, pts):
        return [(x * SS, y * SS) for x, y in pts]

    def poly(self, pts, fill=BODY, edge=True):
        p = self._s(pts)
        self.d.polygon(p, fill=fill)
        if edge:
            self.d.line(p + [p[0]], fill=EDGE, width=int(1.6 * SS), joint="curve")

    def rect(self, x0, y0, x1, y1, fill=BODY, r=0, edge=True):
        box = [x0 * SS, y0 * SS, x1 * SS, y1 * SS]
        if r:
            self.d.rounded_rectangle(box, radius=r * SS, fill=fill, outline=EDGE if edge else None, width=int(1.6 * SS))
        else:
            self.d.rectangle(box, fill=fill, outline=EDGE if edge else None, width=int(1.6 * SS))

    def ell(self, x0, y0, x1, y1, fill=BODY, edge=True):
        self.d.ellipse([x0 * SS, y0 * SS, x1 * SS, y1 * SS], fill=fill,
                       outline=EDGE if edge else None, width=int(1.6 * SS))

    def circ(self, cx, cy, r, fill=BODY, edge=True):
        self.ell(cx - r, cy - r, cx + r, cy + r, fill, edge)

    def line(self, pts, fill=DARK, w=2):
        self.d.line(self._s(pts), fill=fill, width=int(w * SS))

    def save(self, name):
        out = self.img.resize((N, N), Image.LANCZOS)
        out.save(os.path.join(OUT_DIR, name + ".png"))


# ---------------------------------------------------------------- infantry
def soldier(c, tube=False, band=False):
    c.ell(44, 38, 78, 90, MID)                 # shoulders / pack
    c.circ(62, 64, 13, BODY)                   # helmet
    c.circ(62, 64, 6, MID)
    if tube:
        c.rect(24, 52, 98, 62, DARK, r=3)      # launcher tube over shoulder
        c.rect(92, 50, 104, 64, ACC if band else MID, r=2)
    else:
        c.rect(74, 59, 116, 67, DARK, r=2)     # rifle
    c.ell(70, 52, 82, 62, BODY)                # hands


def rifleman():
    c = Canvas(); soldier(c); c.save("rifleman")


def bazooka():
    c = Canvas(); soldier(c, tube=True); c.save("bazooka")


def manpads():
    c = Canvas(); soldier(c, tube=True, band=True); c.save("manpads")


# ---------------------------------------------------------------- vehicles
def tracks(c, x0, x1, y0, y1, y2, y3):
    for (a, b) in ((y0, y1), (y2, y3)):
        c.rect(x0, a, x1, b, DARK, r=4)
        x = x0 + 6
        while x < x1 - 4:
            c.line([(x, a + 2), (x, b - 2)], MID, 1.2)
            x += 8


def jeep():
    c = Canvas()
    for (x, y) in ((24, 30), (80, 30), (24, 88), (80, 88)):
        c.rect(x, y, x + 24, y + 12, DARK, r=3)
    c.rect(16, 38, 112, 90, BODY, r=8)
    c.rect(70, 46, 86, 82, DARK, r=3)          # windscreen
    c.rect(22, 44, 62, 84, MID, r=4)           # bed
    c.circ(46, 64, 8, DARK)
    c.rect(46, 61, 92, 67, DARK, r=2)          # MG
    c.save("jeep")


def tank_like(name, heavy=False):
    c = Canvas()
    if heavy:
        tracks(c, 8, 118, 18, 42, 86, 110)
        c.rect(14, 38, 114, 90, BODY, r=6)
        c.circ(54, 64, 25, MID)
        c.rect(54, 52, 124, 59, DARK, r=2)
        c.rect(54, 69, 124, 76, DARK, r=2)
        c.circ(54, 64, 10, BODY)
        c.rect(112, 49, 126, 62, MID, r=2)
        c.rect(112, 66, 126, 79, MID, r=2)
    else:
        tracks(c, 14, 108, 26, 44, 84, 102)
        c.rect(18, 42, 104, 86, BODY, r=5)
        c.circ(56, 64, 19, MID)
        c.rect(56, 60, 122, 68, DARK, r=2)
        c.circ(56, 64, 8, BODY)
    c.save(name)


def artillery():
    c = Canvas()
    tracks(c, 14, 92, 30, 46, 82, 98)
    c.rect(18, 44, 90, 84, BODY, r=5)
    c.rect(36, 56, 126, 72, DARK, r=3)         # long barrel
    c.rect(116, 53, 126, 75, MID, r=2)         # muzzle brake
    c.ell(24, 40, 64, 88, MID)
    c.save("artillery")


def mlrs():
    c = Canvas()
    tracks(c, 12, 104, 24, 42, 86, 104)
    c.rect(14, 40, 100, 88, BODY, r=5)
    c.rect(22, 44, 96, 84, MID, r=3)
    for row in range(3):
        for col in range(2):
            y = 50 + col * 18
            x = 28 + row * 22
            c.rect(x, y, x + 18, y + 12, DARK, r=2)
            c.rect(x + 14, y + 1, x + 22, y + 11, ACC, r=2)
    c.rect(100, 50, 118, 78, BODY, r=3)        # cab
    c.save("mlrs")


def aa_truck():
    c = Canvas()
    tracks(c, 12, 104, 26, 42, 86, 102)
    c.rect(14, 40, 104, 88, BODY, r=5)
    c.circ(50, 64, 20, MID)
    c.rect(50, 52, 118, 58, DARK, r=2)         # twin flak guns
    c.rect(50, 70, 118, 76, DARK, r=2)
    c.circ(50, 64, 9, BODY)
    c.rect(84, 48, 96, 80, ACC, r=2)           # radar strip
    c.save("aa_truck")


# ---------------------------------------------------------------- aircraft
def fighter():
    c = Canvas()
    c.poly([(80, 58), (42, 10), (28, 10), (50, 58)], MID)
    c.poly([(80, 70), (42, 118), (28, 118), (50, 70)], MID)
    c.poly([(34, 58), (14, 38), (8, 38), (18, 58)], MID)
    c.poly([(34, 70), (14, 90), (8, 90), (18, 70)], MID)
    c.poly([(126, 64), (100, 55), (26, 55), (10, 64), (26, 73), (100, 73)], BODY)
    c.ell(76, 57, 106, 71, DARK)
    c.rect(18, 60, 40, 68, ACC, r=2)
    c.save("fighter")


def helicopter():
    c = Canvas()
    c.rect(2, 61, 46, 68, MID, r=2)            # tail boom
    c.rect(2, 48, 12, 80, DARK, r=2)           # tail rotor
    c.ell(28, 44, 104, 84, BODY)
    c.ell(78, 52, 108, 76, DARK)               # canopy
    c.rect(52, 30, 82, 40, MID, r=3)           # stub wings w/ rockets
    c.rect(52, 88, 82, 98, MID, r=3)
    c.rect(78, 32, 100, 38, DARK, r=2)
    c.rect(78, 90, 100, 96, DARK, r=2)
    # rotor disc
    c.line([(58, 14), (58, 114)], (60, 66, 56, 255), 4)
    c.line([(10, 64), (106, 64)], (60, 66, 56, 120), 3)
    c.line([(24, 22), (92, 106)], (60, 66, 56, 200), 4)
    c.line([(24, 106), (92, 22)], (60, 66, 56, 200), 4)
    c.circ(58, 64, 7, ACC)
    c.save("helicopter")


def bomber():
    c = Canvas()
    c.poly([(84, 56), (58, 4), (40, 4), (52, 56)], MID)
    c.poly([(84, 72), (58, 124), (40, 124), (52, 72)], MID)
    c.poly([(30, 58), (8, 34), (2, 34), (10, 58)], MID)
    c.poly([(30, 70), (8, 94), (2, 94), (10, 70)], MID)
    c.poly([(126, 64), (108, 53), (24, 53), (4, 64), (24, 75), (108, 75)], BODY)
    for y in (24, 40, 88, 104):
        c.ell(54, y - 6, 78, y + 6, DARK)
    c.ell(96, 57, 116, 71, DARK)
    c.rect(38, 60, 70, 68, ACC, r=2)
    c.save("bomber")


# ---------------------------------------------------------------- structures
def turret_base(c, r=30):
    c.circ(64, 64, r + 6, MID)
    for i in range(12):
        import math
        a = i * math.pi / 6
        c.circ(64 + (r + 4) * math.cos(a), 64 + (r + 4) * math.sin(a), 5, BODY)
    c.circ(64, 64, r - 4, BODY)


def mg_turret():
    c = Canvas(); turret_base(c)
    c.circ(58, 64, 14, MID)
    c.rect(58, 55, 112, 61, DARK, r=2)
    c.rect(58, 67, 112, 73, DARK, r=2)
    c.save("mg_turret")


def cannon_turret():
    c = Canvas()
    c.rect(14, 14, 114, 114, MID, r=14)
    c.rect(24, 24, 104, 104, BODY, r=10)
    c.circ(56, 64, 24, MID)
    c.rect(56, 57, 122, 71, DARK, r=3)
    c.rect(112, 54, 124, 74, DARK, r=2)
    c.circ(56, 64, 10, BODY)
    c.save("cannon_turret")


def sam_site():
    c = Canvas()
    c.rect(16, 16, 112, 112, MID, r=10)
    c.rect(24, 24, 104, 104, BODY, r=6)
    for y in (34, 74):
        c.rect(30, y, 108, y + 22, DARK, r=3)
        c.rect(96, y + 2, 118, y + 20, ACC, r=2)
    c.circ(46, 64, 9, MID)
    c.save("sam_site")


def heavy_battery():
    c = Canvas()
    c.rect(12, 12, 116, 116, MID, r=16)
    c.rect(22, 22, 106, 106, BODY, r=10)
    c.circ(48, 64, 28, MID)
    c.rect(48, 58, 124, 70, DARK, r=3)
    c.rect(112, 52, 124, 76, DARK, r=2)
    c.circ(48, 64, 12, BODY)
    c.save("heavy_battery")


def interceptor_battery():
    c = Canvas()
    c.circ(64, 64, 56, MID)
    c.circ(64, 64, 48, BODY)
    for (x, y) in ((40, 40), (40, 88), (84, 40), (84, 88)):
        c.circ(x, y, 14, DARK)
        c.circ(x, y, 8, ACC)
    c.circ(64, 64, 12, MID)
    c.rect(64, 61, 116, 67, DARK, r=2)         # radar mast pointing at target
    c.save("interceptor_battery")


def hq():
    c = Canvas()
    c.rect(6, 6, 122, 122, MID, r=10)
    c.rect(14, 14, 114, 114, BODY, r=6)
    c.rect(26, 26, 102, 102, MID, r=4)
    c.circ(64, 64, 26, BODY)
    # star
    import math
    pts = []
    for i in range(10):
        r = 20 if i % 2 == 0 else 8
        a = -math.pi / 2 + i * math.pi / 5
        pts.append((64 + r * math.cos(a), 64 + r * math.sin(a)))
    c.poly(pts, ACC)
    for (x, y) in ((14, 14), (114, 14), (14, 114), (114, 114)):
        c.circ(x, y, 9, DARK)
    c.save("hq")


# ---------------------------------------------------------------- missiles
def missile(name, body_h, length_end, fins, nuke=False):
    c = Canvas()
    y0, y1 = 64 - body_h, 64 + body_h
    for dy in (-1, 1):
        c.poly([(14, 64 + dy * body_h), (4, 64 + dy * fins), (30, 64 + dy * body_h)], DARK)
    c.rect(8, y0, length_end, y1, BODY, r=3)
    c.poly([(length_end - 2, y0), (126, 64), (length_end - 2, y1)], MID)
    if nuke:
        for x in range(16, length_end - 10, 22):
            c.poly([(x, y0), (x + 11, y0), (x + 5, y1), (x - 6, y1)], ACC, edge=False)
        c.circ(48, 64, body_h - 6, (30, 30, 30, 255))
        c.circ(48, 64, 4, ACC)
        c.poly([(length_end - 2, y0), (126, 64), (length_end - 2, y1)], RED)
    else:
        c.rect(30, y0 + 2, 40, y1 - 2, ACC, edge=False)
    c.save(name)


# -------------------------------------------------------------- projectiles
def projectiles():
    c = Canvas(); c.rect(30, 56, 100, 72, (255, 226, 122, 255), r=6); c.rect(52, 60, 100, 68, (255, 255, 235, 255), r=4, edge=False); c.save("proj_bullet")
    c = Canvas(); c.circ(64, 64, 26, (70, 64, 56, 255)); c.circ(56, 56, 8, (150, 140, 120, 255), edge=False); c.save("proj_shell")
    c = Canvas()
    c.poly([(30, 58), (2, 64), (30, 70)], (255, 150, 40, 255), edge=False)
    c.rect(26, 54, 98, 74, (235, 235, 230, 255), r=4)
    c.poly([(96, 54), (124, 64), (96, 74)], RED)
    c.save("proj_rocket")
    c = Canvas()
    c.poly([(30, 56), (10, 44), (10, 84), (30, 72)], DARK)
    c.ell(24, 40, 108, 88, (60, 64, 56, 255))
    c.ell(40, 48, 70, 62, (120, 126, 112, 255), edge=False)
    c.save("proj_bomb")
    c = Canvas()
    c.poly([(30, 58), (2, 64), (30, 70)], (120, 220, 255, 255), edge=False)
    c.rect(26, 54, 98, 74, (225, 245, 255, 255), r=4)
    c.poly([(96, 54), (124, 64), (96, 74)], (60, 150, 255, 255))
    c.save("proj_interceptor")


# =====================================================================
# v2 additions: unit variants, national structures, extra missiles/projectiles
# =====================================================================
import math

WHITE = (240, 240, 236, 255)
ORANGE = (255, 150, 40, 255)
YELLOW = (255, 226, 122, 255)
CONC = (150, 154, 144, 255)
ROOF = (188, 190, 180, 255)


def ring_pts(cx, cy, r, n, start=0.0):
    return [(cx + r * math.cos(start + i * 2 * math.pi / n), cy + r * math.sin(start + i * 2 * math.pi / n))
            for i in range(n)]


# ---------------------------------------------------------------- infantry
def trooper(name, weapon):
    c = Canvas()
    if weapon == "smg":
        c.ell(46, 38, 78, 90, MID); c.circ(62, 64, 12, BODY); c.circ(62, 64, 5, MID)
        c.rect(74, 60, 104, 67, DARK, r=2); c.rect(86, 66, 92, 78, DARK, r=1)
        c.ell(70, 52, 82, 62, BODY)
        c.rect(40, 62, 50, 70, ACC, r=2)                       # speed band
    elif weapon == "lmg":
        c.ell(40, 34, 80, 94, MID); c.circ(62, 64, 13, BODY); c.circ(62, 64, 6, MID)
        c.rect(70, 59, 122, 69, DARK, r=2); c.rect(108, 56, 116, 72, MID, r=1)
        c.line([(100, 69), (96, 80)], DARK, 2.2); c.line([(100, 69), (106, 80)], DARK, 2.2)   # bipod
        c.rect(48, 74, 64, 92, ACC, r=2)                       # ammo box
        c.ell(70, 52, 82, 62, BODY)
    elif weapon == "grenade":
        c.ell(44, 36, 78, 92, MID); c.circ(62, 64, 13, BODY); c.circ(62, 64, 6, MID)
        c.rect(66, 55, 112, 73, DARK, r=5); c.rect(104, 52, 118, 76, MID, r=3)
        c.circ(84, 64, 6, ACC)
        for y in (44, 54, 74, 84):
            c.circ(52, y, 3.5, ACC, edge=False)
        c.ell(70, 50, 82, 60, BODY)
    elif weapon == "sniper":
        c.ell(42, 36, 80, 92, MID)
        for (x, y) in ((46, 42), (50, 84), (40, 62), (54, 36), (58, 90)):
            c.circ(x, y, 6, DARK, edge=False)                  # camouflage tufts
        c.circ(62, 64, 12, BODY); c.circ(62, 64, 5, MID)
        c.rect(70, 62, 126, 67, DARK, r=1); c.rect(88, 56, 102, 63, MID, r=2)
        c.rect(120, 60, 128, 69, EDGE, r=1)
    elif weapon == "flame":
        c.ell(40, 36, 80, 92, MID); c.circ(62, 64, 13, BODY); c.circ(62, 64, 6, MID)
        c.rect(20, 42, 46, 58, ACC, r=6); c.rect(20, 70, 46, 86, ACC, r=6)      # fuel tanks
        c.line([(46, 50), (70, 62)], DARK, 2.5); c.line([(46, 78), (70, 66)], DARK, 2.5)
        c.rect(72, 59, 104, 68, DARK, r=2)
        c.poly([(104, 56), (126, 64), (104, 72)], ORANGE, edge=False)
        c.ell(68, 52, 80, 62, BODY)
    elif weapon == "medic":
        c.ell(44, 38, 78, 90, MID); c.circ(62, 64, 13, WHITE); c.circ(62, 64, 6, MID)
        c.rect(24, 46, 50, 82, WHITE, r=4)
        c.rect(34, 52, 40, 76, RED, edge=False); c.rect(28, 61, 46, 67, RED, edge=False)
        c.rect(74, 60, 94, 66, DARK, r=2); c.ell(70, 52, 82, 62, BODY)
    elif weapon == "engineer":
        c.ell(44, 38, 78, 90, MID); c.circ(62, 64, 13, ACC); c.circ(62, 64, 6, MID)
        c.rect(24, 48, 50, 80, DARK, r=3); c.rect(28, 54, 46, 62, ACC, r=1)     # tool box
        c.line([(74, 44), (112, 84)], DARK, 3.5); c.circ(112, 84, 7, MID)        # wrench
        c.circ(74, 44, 5, MID); c.ell(70, 52, 82, 62, BODY)
    elif weapon == "commando":
        c.ell(40, 34, 82, 94, DARK); c.circ(62, 64, 13, MID); c.circ(62, 64, 6, DARK)
        c.rect(66, 53, 74, 75, ACC, r=2)                       # night-vision bar
        c.rect(72, 60, 112, 67, EDGE, r=2); c.rect(108, 58, 126, 69, EDGE, r=2)  # suppressed rifle
        c.rect(50, 28, 62, 40, MID, r=2); c.rect(50, 88, 62, 100, MID, r=2)     # grenade pouches
        c.ell(70, 52, 82, 62, MID)
    c.save(name)


# ---------------------------------------------------------------- vehicles
def armored_car():
    c = Canvas()
    for (x, y) in ((18, 26), (76, 26), (18, 90), (76, 90)):
        c.rect(x, y, x + 30, y + 14, DARK, r=4)
    c.rect(12, 34, 116, 94, BODY, r=10)
    c.rect(18, 40, 60, 88, MID, r=4)
    c.circ(66, 64, 17, MID); c.circ(66, 64, 8, BODY)
    c.rect(66, 60, 112, 68, DARK, r=2); c.rect(106, 58, 118, 70, DARK, r=2)
    c.save("armored_car")


def apc():
    c = Canvas()
    tracks(c, 8, 116, 20, 40, 88, 108)
    c.rect(10, 36, 112, 92, BODY, r=7)
    c.rect(4, 44, 14, 84, DARK, r=2)                           # rear ramp
    c.rect(24, 44, 60, 84, MID, r=3)
    for y in (52, 70):
        c.rect(30, y, 54, y + 10, DARK, r=2)                   # troop hatches
    c.circ(84, 64, 12, MID); c.rect(84, 61, 118, 67, DARK, r=2)
    c.save("apc")


def tank_v(name, scale="light"):
    c = Canvas()
    if scale == "light":
        tracks(c, 18, 106, 30, 46, 82, 98)
        c.rect(22, 44, 98, 84, BODY, r=5)
        c.circ(56, 64, 15, MID); c.rect(56, 60, 112, 68, DARK, r=2); c.circ(56, 64, 6, BODY)
    elif scale == "mammoth":
        tracks(c, 4, 122, 8, 38, 90, 120)
        c.rect(8, 34, 120, 94, BODY, r=7)
        for x in (16, 98):
            c.rect(x, 40, x + 14, 88, MID, r=2)                # engine decks
        c.ell(26, 38, 90, 90, MID)
        c.rect(48, 48, 126, 56, DARK, r=2); c.rect(48, 72, 126, 80, DARK, r=2)
        c.rect(118, 45, 128, 59, MID, r=2); c.rect(118, 69, 128, 83, MID, r=2)
        c.circ(58, 64, 14, BODY); c.circ(100, 44, 6, DARK); c.circ(100, 84, 6, DARK)
    c.save(name)


def tank_destroyer():
    c = Canvas()
    tracks(c, 12, 108, 26, 44, 84, 102)
    c.rect(14, 42, 108, 86, BODY, r=4)
    c.poly([(30, 46), (96, 52), (96, 76), (30, 82)], MID)      # casemate
    c.rect(48, 59, 128, 69, DARK, r=2); c.rect(118, 55, 128, 73, MID, r=2)
    c.circ(44, 64, 7, BODY)
    c.save("tank_destroyer")


def flame_tank():
    c = Canvas()
    tracks(c, 12, 108, 24, 42, 86, 104)
    c.rect(16, 40, 104, 88, BODY, r=5)
    c.ell(20, 46, 52, 60, ACC); c.ell(20, 68, 52, 82, ACC)     # fuel tanks
    c.circ(66, 64, 17, MID)
    c.rect(66, 58, 106, 70, DARK, r=3)
    c.poly([(106, 54), (128, 64), (106, 74)], ORANGE, edge=False)
    c.circ(66, 64, 7, BODY)
    c.save("flame_tank")


def howitzer():
    c = Canvas()
    tracks(c, 8, 90, 28, 46, 82, 100)
    c.rect(12, 42, 88, 86, BODY, r=5)
    c.rect(28, 56, 126, 72, DARK, r=3)
    c.rect(114, 52, 128, 76, MID, r=2)
    c.rect(100, 50, 112, 78, MID, r=2)
    c.ell(16, 40, 62, 88, MID)
    c.line([(10, 28), (26, 44)], DARK, 4); c.line([(10, 100), (26, 84)], DARK, 4)   # spades
    c.rect(36, 66, 50, 78, ACC, r=1)
    c.save("howitzer")


def sam_truck():
    c = Canvas()
    for (x, y) in ((10, 28), (52, 28), (10, 92), (52, 92)):
        c.rect(x, y, x + 28, y + 12, DARK, r=3)
    c.rect(8, 38, 104, 90, BODY, r=5)
    c.rect(86, 44, 112, 84, MID, r=4)                          # cab
    for y in (46, 58, 70):
        c.rect(14, y, 100, y + 10, DARK, r=2)
        c.poly([(92, y), (118, y + 5), (92, y + 10)], ACC, edge=False)
    c.save("sam_truck")


def repair_vehicle():
    c = Canvas()
    tracks(c, 12, 108, 24, 42, 86, 104)
    c.rect(14, 40, 108, 88, BODY, r=5)
    c.rect(84, 46, 106, 82, MID, r=3)
    c.rect(24, 46, 76, 82, WHITE, r=3)
    c.rect(46, 50, 54, 78, RED, edge=False); c.rect(32, 60, 68, 68, RED, edge=False)
    c.line([(30, 44), (96, 24)], ACC, 5); c.circ(96, 24, 5, DARK)      # crane
    c.save("repair_vehicle")


# ---------------------------------------------------------------- aircraft
def mirror(pts):
    return [(x, 128 - y) for (x, y) in pts]


def drone():
    c = Canvas()
    w = [(88, 62), (44, 24), (30, 24), (52, 62)]
    c.poly(w, MID); c.poly(mirror(w), MID)
    c.ell(24, 56, 104, 72, BODY)
    c.poly([(104, 56), (122, 64), (104, 72)], RED, edge=False)
    c.rect(14, 52, 28, 76, DARK, r=2)
    c.save("drone")


def interceptor_jet():
    c = Canvas()
    w = [(84, 58), (38, 6), (24, 6), (46, 58)]
    c.poly(w, MID); c.poly(mirror(w), MID)
    t = [(36, 58), (12, 40), (6, 40), (14, 58)]
    c.poly(t, MID); c.poly(mirror(t), MID)
    c.poly([(126, 64), (100, 56), (20, 56), (4, 64), (20, 72), (100, 72)], BODY)
    c.ell(80, 58, 106, 70, DARK)
    c.rect(6, 58, 30, 70, ACC, r=3)
    c.save("interceptor_jet")


def stealth_fighter():
    c = Canvas()
    top = [(126, 64), (80, 48), (34, 24), (14, 30), (30, 52), (22, 64)]
    pts = top + mirror(top[::-1][:-1])
    c.poly(pts, MID)
    c.poly([(104, 64), (76, 56), (52, 56), (36, 64), (52, 72), (76, 72)], DARK)
    c.ell(84, 59, 100, 69, WHITE, edge=False)
    c.line([(34, 64), (110, 64)], EDGE, 1.2)
    c.save("stealth_fighter")


def strike_jet():
    c = Canvas()
    w = [(86, 56), (74, 6), (50, 6), (56, 56)]
    c.poly(w, MID); c.poly(mirror(w), MID)
    t = [(30, 58), (10, 38), (4, 38), (8, 58)]
    c.poly(t, MID); c.poly(mirror(t), MID)
    c.poly([(126, 64), (104, 56), (22, 54), (4, 64), (22, 74), (104, 72)], BODY)
    for y in (50, 78):
        c.ell(10, y - 7, 52, y + 7, DARK)
    c.ell(80, 58, 104, 70, DARK)
    for y in (24, 104):
        c.rect(58, y - 3, 78, y + 3, ACC, r=1)                  # underwing pods
    c.rect(106, 61, 126, 67, DARK, r=1)
    c.save("strike_jet")


def gunship():
    c = Canvas()
    c.rect(0, 61, 36, 68, MID, r=2); c.rect(0, 46, 12, 82, DARK, r=2)
    c.ell(22, 42, 110, 86, BODY)
    c.ell(84, 50, 114, 78, DARK)
    for y in (26, 94):
        c.rect(46, y, 90, y + 8, MID, r=3)
        c.rect(84, y + 1, 112, y + 7, DARK, r=2)
    c.rect(106, 60, 126, 68, DARK, r=2)
    for a in (0.0, math.pi / 2, math.pi / 4, 3 * math.pi / 4):
        dx, dy = 52 * math.cos(a), 52 * math.sin(a)
        c.line([(60 - dx, 64 - dy), (60 + dx, 64 + dy)], (60, 66, 56, 200), 4)
    c.circ(60, 64, 8, ACC)
    c.save("gunship")


def bomber_like(name, span, engines, long_body=False, big=False):
    c = Canvas()
    w = [(84, 56), (58, 128 - span), (40, 128 - span), (52, 56)]
    c.poly(w, MID); c.poly(mirror(w), MID)
    t = [(30, 58), (8, 34), (2, 34), (10, 58)]
    c.poly(t, MID); c.poly(mirror(t), MID)
    hw = 11 if big else 9
    c.poly([(126, 64), (108, 64 - hw), (24, 64 - hw), (4, 64), (24, 64 + hw), (108, 64 + hw)], BODY)
    for y in engines:
        c.ell(52, y - 6, 80, y + 6, DARK)
    c.ell(96, 64 - hw + 3, 116, 64 + hw - 3, DARK)
    c.rect(36, 60, 72, 68, ACC, r=2)
    c.save(name)


def stealth_bomber():
    c = Canvas()
    top = [(124, 64), (66, 14), (14, 6), (30, 28), (18, 38), (38, 50), (24, 58), (40, 64)]
    pts = top + mirror(top[::-1][1:])
    c.poly(pts, MID)
    c.poly([(104, 64), (84, 56), (70, 56), (60, 64), (70, 72), (84, 72)], DARK)
    c.ell(88, 59, 102, 69, WHITE, edge=False)
    c.line([(40, 64), (112, 64)], EDGE, 1.2)
    c.save("stealth_bomber")


# ---------------------------------------------------------------- defenses
def sandbag_ring(c, cx, cy, r, n=14, size=7):
    for i in range(n):
        a = i * 2 * math.pi / n
        c.ell(cx + r * math.cos(a) - size, cy + r * math.sin(a) - size * 0.7,
              cx + r * math.cos(a) + size, cy + r * math.sin(a) + size * 0.7, CONC)


def pillbox():
    c = Canvas()
    c.rect(14, 14, 114, 114, MID, r=26)
    c.rect(24, 24, 104, 104, CONC, r=20)
    c.rect(66, 54, 112, 74, DARK, r=3)
    c.rect(80, 60, 126, 68, DARK, r=2)
    c.circ(52, 64, 12, MID)
    c.save("pillbox")


def at_gun():
    c = Canvas()
    for y in (30, 98):
        c.rect(34, y - 3, 62, y + 5, DARK, r=3)                   # wheels
    c.rect(26, 56, 126, 72, DARK, r=2)
    c.rect(116, 52, 128, 76, MID, r=2)
    c.poly([(58, 34), (82, 40), (82, 88), (58, 94)], BODY)        # gun shield
    c.rect(20, 52, 40, 76, MID, r=3)
    c.line([(26, 64), (6, 44)], DARK, 4); c.line([(26, 64), (6, 84)], DARK, 4)
    c.save("at_gun")


def mortar_pit():
    c = Canvas()
    c.circ(64, 64, 50, (96, 90, 78, 255), edge=False)
    sandbag_ring(c, 64, 64, 46, 16, 9)
    c.circ(64, 64, 30, DARK)
    c.rect(60, 56, 104, 72, MID, r=3)
    c.rect(96, 54, 108, 74, DARK, r=2)
    c.rect(24, 76, 42, 92, ACC, r=2)
    c.save("mortar_pit")


def flak_battery():
    c = Canvas()
    c.circ(64, 64, 52, MID)
    sandbag_ring(c, 64, 64, 50, 16, 8)
    c.circ(64, 64, 36, BODY)
    for (dy, ln) in ((-16, 56), (-5, 62), (5, 62), (16, 56)):
        c.rect(60, 64 + dy - 3, 60 + ln, 64 + dy + 3, DARK, r=2)
    c.circ(58, 64, 14, MID); c.circ(58, 64, 6, ACC)
    c.save("flak_battery")


def railgun():
    c = Canvas()
    c.rect(8, 22, 122, 106, MID, r=12)
    c.rect(16, 30, 114, 98, CONC, r=8)
    for y in (46, 72):
        c.rect(22, y, 128, y + 10, DARK, r=2)
        for x in range(36, 120, 16):
            c.rect(x, y - 4, x + 5, y + 14, ACC, r=1)
    c.rect(18, 54, 40, 74, DARK, r=3); c.circ(30, 64, 7, ACC)
    c.save("railgun")


def ciws():
    c = Canvas()
    c.circ(64, 64, 52, MID)
    c.circ(64, 64, 42, BODY)
    c.ell(24, 44, 64, 84, WHITE)
    c.circ(44, 64, 7, MID)
    c.circ(66, 64, 20, DARK)
    for dy in (-8, -3, 3, 8):
        c.rect(66, 64 + dy - 2, 118, 64 + dy + 2, MID, r=1)
    c.circ(66, 64, 8, ACC)
    c.save("ciws")


def abm_battery():
    c = Canvas()
    c.circ(64, 64, 60, MID)
    c.circ(64, 64, 52, BODY)
    for p in ring_pts(64, 64, 34, 6):
        c.circ(p[0], p[1], 12, DARK); c.circ(p[0], p[1], 7, ACC)
    c.circ(64, 64, 15, MID)
    c.rect(64, 61, 122, 67, DARK, r=2); c.circ(122, 64, 4, ACC)
    c.save("abm_battery")


def barricade():
    c = Canvas()
    for i, x in enumerate(range(8, 112, 26)):
        c.rect(x, 34 + (i % 2) * 6, x + 24, 94 - (i % 2) * 6, CONC, r=3)
    c.line([(8, 64), (120, 64)], DARK, 2)
    c.save("barricade")


def repair_depot():
    c = Canvas()
    c.rect(12, 12, 116, 116, MID, r=10)
    c.rect(20, 20, 108, 108, BODY, r=6)
    c.rect(26, 26, 102, 54, CONC, r=2)
    c.rect(26, 74, 102, 102, CONC, r=2)
    c.rect(54, 52, 74, 76, ACC, r=1)
    c.line([(38, 64), (92, 64)], DARK, 6); c.line([(64, 40), (64, 88)], DARK, 6)
    c.circ(64, 64, 9, ACC)
    c.save("repair_depot")


# ---------------------------------------------------------------- national structures
def road(c, pts, w=7):
    c.line(pts, (92, 96, 88, 255), w)
    c.line(pts, (190, 190, 170, 255), 1.0)


def metropolis():
    c = Canvas()
    c.rect(2, 2, 126, 126, (140, 146, 134, 255), r=8)
    road(c, [(2, 64), (126, 64)], 9); road(c, [(64, 2), (64, 126)], 9)
    blocks = [(10, 10, 34, 30), (38, 12, 56, 38), (10, 36, 28, 56), (72, 10, 96, 34), (100, 8, 120, 40),
              (74, 38, 94, 56), (100, 44, 120, 56), (10, 72, 36, 92), (40, 74, 58, 100), (10, 98, 34, 120),
              (40, 106, 58, 122), (72, 72, 98, 96), (102, 74, 120, 98), (74, 102, 96, 122), (102, 104, 122, 122)]
    for i, (x0, y0, x1, y1) in enumerate(blocks):
        c.rect(x0, y0, x1, y1, BODY if i % 3 else ROOF, r=2)
        c.rect(x0 + 3, y0 + 3, x1 - 3, y1 - 3, MID if i % 2 else CONC, edge=False)
    c.circ(64, 64, 15, BODY); c.circ(64, 64, 9, ACC)                # central tower
    c.save("metropolis")


def town():
    c = Canvas()
    c.circ(64, 64, 58, (120, 126, 112, 255), edge=False)
    road(c, [(6, 64), (122, 64)], 8); road(c, [(64, 8), (64, 120)], 8)
    houses = [(18, 22, 46, 46), (74, 20, 108, 46), (16, 82, 44, 108), (76, 84, 104, 110), (46, 44, 56, 54)]
    for (x0, y0, x1, y1) in houses:
        c.rect(x0, y0, x1, y1, BODY, r=2)
        c.line([(x0, (y0 + y1) / 2), (x1, (y0 + y1) / 2)], MID, 2)
    c.circ(64, 64, 9, ACC)
    c.save("town")


def oil_refinery():
    c = Canvas()
    c.rect(2, 2, 126, 126, (128, 130, 120, 255), r=8)
    for (x, y) in ((30, 34), (30, 90), (66, 34), (66, 90)):
        c.circ(x, y, 20, BODY); c.circ(x, y, 14, MID); c.circ(x, y, 5, DARK)
    c.line([(30, 54), (30, 70)], DARK, 4); c.line([(66, 54), (66, 70)], DARK, 4)
    c.line([(50, 34), (46, 34)], DARK, 4)
    c.rect(94, 14, 120, 112, MID, r=3)
    for y in (24, 50, 76, 100):
        c.circ(107, y, 8, DARK); c.circ(107, y, 4, BODY)
    c.line([(86, 64), (94, 64)], DARK, 4)
    c.poly([(8, 60), (14, 66), (8, 72), (2, 66)], ORANGE, edge=False)   # flare
    c.save("oil_refinery")


def power_plant():
    c = Canvas()
    c.rect(2, 2, 126, 126, (130, 134, 126, 255), r=8)
    for (x, y) in ((34, 34), (34, 94)):
        c.circ(x, y, 26, BODY); c.circ(x, y, 18, DARK); c.circ(x, y, 12, (200, 204, 210, 255), edge=False)
    c.rect(68, 14, 122, 56, MID, r=3); c.rect(68, 72, 122, 114, MID, r=3)
    for y in (24, 44, 82, 102):
        c.line([(74, y), (116, y)], DARK, 2)
    c.rect(64, 58, 74, 70, DARK, r=1)
    c.poly([(98, 62), (88, 74), (96, 74), (90, 88), (106, 70), (98, 70), (104, 62)], ACC)
    c.save("power_plant")


def barracks():
    c = Canvas()
    c.rect(2, 2, 126, 126, (124, 130, 112, 255), r=8)
    for y in (12, 50, 88):
        c.rect(8, y, 82, y + 28, BODY, r=2)
        c.line([(8, y + 14), (82, y + 14)], MID, 2)
        for x in range(18, 80, 12):
            c.line([(x, y + 2), (x, y + 26)], MID, 1)
    c.rect(92, 12, 122, 116, CONC, r=2)                             # parade ground
    c.line([(98, 20), (98, 112)], ACC, 2)
    c.line([(107, 60), (107, 100)], DARK, 2); c.poly([(107, 60), (122, 66), (107, 72)], RED)
    c.save("barracks")


def factory():
    c = Canvas()
    c.rect(2, 2, 126, 126, (126, 128, 120, 255), r=8)
    c.rect(8, 10, 92, 118, BODY, r=3)
    for x in range(14, 88, 14):
        c.poly([(x, 16), (x + 10, 16), (x + 10, 112), (x, 112)], ROOF)
        c.line([(x, 16), (x, 112)], MID, 1.5)
    c.circ(106, 28, 11, DARK); c.circ(106, 28, 6, MID)
    c.circ(106, 62, 9, DARK); c.circ(106, 62, 5, MID)
    c.rect(98, 82, 122, 118, CONC, r=2)
    c.rect(102, 88, 118, 96, ACC, r=1); c.rect(102, 104, 118, 112, ACC, r=1)
    c.save("factory")


def airbase():
    c = Canvas()
    c.rect(1, 1, 127, 127, (120, 126, 112, 255), r=6)
    c.rect(2, 50, 126, 80, DARK, r=1)
    for x in range(10, 120, 18):
        c.rect(x, 63, x + 9, 67, WHITE, edge=False)
    for y in range(54, 78, 5):
        c.rect(4, y, 10, y + 3, WHITE, edge=False); c.rect(118, y, 124, y + 3, WHITE, edge=False)
    c.rect(2, 90, 126, 98, MID, r=1)                                # taxiway
    for x in (10, 52, 94):
        c.rect(x, 104, x + 28, 124, BODY, r=2); c.line([(x, 114), (x + 28, 114)], MID, 1.5)   # hangars
    c.rect(10, 8, 40, 36, CONC, r=2)
    c.circ(100, 24, 11, BODY); c.circ(100, 24, 5, ACC)             # tower
    c.poly([(60, 12), (82, 20), (60, 28)], MID)                      # parked plane
    c.rect(54, 17, 72, 23, MID, edge=False)
    c.save("airbase")


def radar_station():
    c = Canvas()
    c.circ(64, 64, 58, (126, 130, 120, 255), edge=False)
    c.rect(8, 84, 40, 116, BODY, r=2); c.rect(88, 12, 120, 40, BODY, r=2)
    c.circ(64, 64, 40, MID); c.circ(64, 64, 32, BODY)
    for r in (24, 16, 8):
        c.circ(64, 64, r, MID if r % 16 else BODY)
    c.line([(64, 64), (112, 40)], DARK, 4); c.circ(112, 40, 5, ACC)
    c.poly([(64, 64), (108, 30), (118, 48)], (255, 226, 122, 90), edge=False)
    c.save("radar_station")


def missile_silo():
    c = Canvas()
    c.rect(8, 8, 120, 120, MID, r=14)
    c.rect(14, 14, 114, 114, CONC, r=10)
    c.circ(64, 64, 44, DARK)
    c.circ(64, 64, 38, MID)
    c.poly([(64, 26), (90, 34), (98, 64), (90, 94), (64, 102)], BODY)
    c.poly([(64, 26), (38, 34), (30, 64), (38, 94), (64, 102)], BODY)
    c.line([(64, 26), (64, 102)], DARK, 3)
    for p in ring_pts(64, 64, 44, 16):
        c.circ(p[0], p[1], 3, ACC, edge=False)
    for (x, y) in ((22, 22), (106, 22), (22, 106), (106, 106)):
        c.rect(x - 6, y - 6, x + 6, y + 6, ACC, r=1)
    c.save("missile_silo")


def tech_center():
    c = Canvas()
    c.rect(4, 4, 124, 124, (128, 132, 124, 255), r=8)
    c.rect(14, 18, 88, 110, BODY, r=6)
    c.rect(22, 26, 80, 102, MID, r=3)
    for y in (36, 54, 72, 90):
        c.line([(26, y), (76, y)], BODY, 2)
    c.circ(104, 36, 17, BODY); c.circ(104, 36, 11, MID); c.circ(104, 36, 4, ACC)
    c.line([(104, 36), (118, 24)], DARK, 3)
    for y in (66, 86, 106):
        c.rect(94, y - 5, 122, y + 5, DARK, r=1)
    c.circ(51, 64, 10, ACC)
    c.save("tech_center")


def fortress():
    c = Canvas()
    c.poly([(20, 4), (108, 4), (124, 20), (124, 108), (108, 124), (20, 124), (4, 108), (4, 20)], MID)
    c.poly([(26, 12), (102, 12), (116, 26), (116, 102), (102, 116), (26, 116), (12, 102), (12, 26)], CONC)
    for (x, y) in ((14, 14), (114, 14), (14, 114), (114, 114)):
        c.circ(x, y, 14, DARK); c.circ(x, y, 8, MID)
    c.rect(32, 32, 96, 96, BODY, r=6)
    c.rect(40, 40, 88, 88, MID, r=4)
    c.circ(64, 64, 20, DARK); c.circ(64, 64, 14, BODY)
    for (dx, dy) in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        xa, xb = sorted((64 + dx * 14, 64 + dx * 34))
        ya, yb = sorted((64 + dy * 14, 64 + dy * 34))
        if dx:
            ya, yb = 64 - 6, 64 + 6
        else:
            xa, xb = 64 - 6, 64 + 6
        c.rect(xa, ya, xb, yb, DARK, r=2)
    c.circ(64, 64, 6, ACC)
    c.save("fortress")


# ---------------------------------------------------------------- missiles / projectiles
def missile_ex(name, body_h, length_end, fins, nuke=False, bands=0, nose=None, delta=False):
    c = Canvas()
    y0, y1 = 64 - body_h, 64 + body_h
    for dy in (-1, 1):
        if delta:
            c.poly([(34, 64 + dy * body_h), (6, 64 + dy * fins), (14, 64 + dy * body_h)], DARK)
        else:
            c.poly([(14, 64 + dy * body_h), (4, 64 + dy * fins), (30, 64 + dy * body_h)], DARK)
    c.rect(8, y0, length_end, y1, BODY, r=3)
    c.poly([(length_end - 2, y0), (126, 64), (length_end - 2, y1)], nose or MID)
    for i in range(bands):
        x = 22 + i * 18
        c.rect(x, y0, x + 8, y1, ACC, edge=False)
    if nuke:
        c.circ(48, 64, max(body_h - 6, 4), (30, 30, 30, 255)); c.circ(48, 64, max(body_h // 4, 2), ACC)
        c.poly([(length_end - 2, y0), (126, 64), (length_end - 2, y1)], RED)
    c.save(name)


def projectiles_v2():
    c = Canvas(); c.circ(64, 64, 14, (90, 96, 70, 255)); c.rect(52, 40, 76, 52, DARK, r=1); c.save("proj_grenade")
    c = Canvas(); c.rect(6, 60, 122, 68, (255, 255, 255, 255), r=3); c.rect(80, 61, 122, 67, (255, 240, 180, 255), edge=False); c.save("proj_sniper")
    c = Canvas()
    c.ell(14, 46, 108, 82, (255, 120, 30, 255), edge=False)
    c.ell(34, 52, 112, 76, (255, 190, 60, 255), edge=False)
    c.ell(56, 58, 116, 70, (255, 244, 170, 255), edge=False)
    c.save("proj_flame")
    c = Canvas(); c.ell(30, 48, 94, 80, (84, 80, 70, 255)); c.poly([(30, 56), (10, 46), (10, 82), (30, 72)], DARK); c.save("proj_mortar")
    c = Canvas()
    c.poly([(26, 58), (2, 64), (26, 70)], (255, 190, 80, 255), edge=False)
    c.rect(22, 56, 100, 72, (210, 214, 206, 255), r=3)
    c.poly([(98, 56), (126, 64), (98, 72)], (200, 60, 50, 255))
    c.save("proj_atgm")
    c = Canvas(); c.ell(24, 44, 100, 84, (70, 64, 56, 255)); c.poly([(98, 46), (124, 64), (98, 82)], (150, 140, 120, 255)); c.save("proj_heavy")
    c = Canvas(); c.circ(64, 64, 18, (255, 214, 90, 255)); c.circ(64, 64, 9, (255, 250, 220, 255), edge=False); c.save("proj_flak")
    c = Canvas()
    c.rect(2, 54, 124, 74, (120, 190, 255, 120), r=8, edge=False)
    c.rect(8, 58, 124, 70, (190, 230, 255, 255), r=5, edge=False)
    c.rect(30, 61, 124, 67, (255, 255, 255, 255), r=3, edge=False)
    c.save("proj_rail")
    c = Canvas()
    c.poly([(26, 54), (4, 40), (4, 88), (26, 74)], DARK)
    c.ell(18, 36, 110, 92, (58, 62, 54, 255)); c.ell(40, 46, 80, 62, (120, 126, 112, 255), edge=False)
    c.rect(60, 36, 70, 92, ACC, edge=False)
    c.save("proj_bigbomb")


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    # --- v1 art (kept)
    rifleman(); bazooka(); manpads()
    jeep(); tank_like("tank"); tank_like("heavy_tank", heavy=True)
    artillery(); mlrs(); aa_truck()
    fighter(); helicopter(); bomber()
    mg_turret(); cannon_turret(); sam_site(); heavy_battery(); interceptor_battery(); hq()
    missile("cruise_missile", 8, 98, 26)
    missile("ballistic_missile", 12, 94, 36)
    missile("nuke", 18, 90, 40, nuke=True)
    projectiles()
    # --- v2 art
    for n, w in (("assault", "smg"), ("mg_gunner", "lmg"), ("grenadier", "grenade"), ("sniper", "sniper"),
                 ("flamer", "flame"), ("medic", "medic"), ("engineer", "engineer"), ("commando", "commando")):
        trooper(n, w)
    armored_car(); apc(); tank_v("light_tank", "light"); tank_v("mammoth", "mammoth")
    tank_destroyer(); flame_tank(); howitzer(); sam_truck(); repair_vehicle()
    drone(); interceptor_jet(); stealth_fighter(); strike_jet(); gunship()
    bomber_like("light_bomber", 14, (26, 102))
    bomber_like("heavy_bomber", 2, (14, 34, 94, 114), big=True)
    stealth_bomber()
    pillbox(); at_gun(); mortar_pit(); flak_battery(); railgun(); ciws(); abm_battery(); barricade(); repair_depot()
    metropolis(); town(); oil_refinery(); power_plant(); barracks(); factory(); airbase()
    radar_station(); missile_silo(); tech_center(); fortress()
    missile_ex("tactical_missile", 5, 96, 16)
    missile_ex("cluster_missile", 11, 92, 30, bands=3)
    missile_ex("bunker_buster", 13, 84, 28, nose=ACC)
    missile_ex("hypersonic", 6, 100, 44, delta=True, nose=ACC)
    missile_ex("tactical_nuke", 14, 88, 32, nuke=True)
    missile_ex("mega_nuke", 24, 90, 50, nuke=True, bands=2)
    projectiles_v2()
    print("Wrote sprites to", os.path.abspath(OUT_DIR))


if __name__ == "__main__":
    main()
