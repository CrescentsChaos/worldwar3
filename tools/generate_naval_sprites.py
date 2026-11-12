#!/usr/bin/env python3
"""Generates ONLY the naval sprites (ships, subs, diver, port, coastal battery, torpedo, depth charge).
Reuses the helpers of generate_placeholder_sprites.py. Safe to run: it never touches the other sprites.
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from generate_placeholder_sprites import Canvas, BODY, MID, DARK, EDGE, ACC, RED, OUT_DIR, sandbag_ring


def hull(c, x0, x1, half, fill=BODY):
    L = x1 - x0
    pts = [(x1, 64), (x1 - L * .22, 64 - half * .78), (x1 - L * .40, 64 - half), (x0 + 4, 64 - half),
           (x0, 64 - half * .7), (x0, 64 + half * .7), (x0 + 4, 64 + half), (x1 - L * .40, 64 + half),
           (x1 - L * .22, 64 + half * .78)]
    c.poly(pts, fill)
    c.poly([(x1 - 5, 64), (x1 - L * .24, 64 - half * .55), (x0 + 8, 64 - half * .62), (x0 + 8, 64 + half * .62),
            (x1 - L * .24, 64 + half * .55)], MID, edge=False)


def turret(c, cx, cy, r, barrel, n=1):
    for i in range(n):
        off = (i - (n - 1) / 2) * (r * .7)
        c.rect(cx, cy + off - 1.6, cx + barrel, cy + off + 1.6, DARK, edge=False)
    c.circ(cx, cy, r, BODY)
    c.circ(cx, cy, r * .5, MID, edge=False)


def patrol_boat():
    c = Canvas(); hull(c, 22, 116, 11)
    c.rect(52, 56, 72, 72, BODY, r=2); c.rect(56, 59, 68, 69, DARK, edge=False)
    turret(c, 92, 64, 4.5, 12); c.save("patrol_boat")


def gunboat():
    c = Canvas(); hull(c, 14, 118, 14)
    c.rect(46, 54, 70, 74, BODY, r=2); c.rect(50, 58, 66, 70, DARK, edge=False)
    turret(c, 88, 64, 7, 18); turret(c, 28, 64, 5, 10); c.save("gunboat")


def missile_boat():
    c = Canvas(); hull(c, 14, 118, 13)
    for y in (50, 70):
        c.rect(62, y, 92, y + 8, DARK, r=1); c.rect(86, y + 1.5, 96, y + 6.5, ACC, edge=False)
    c.rect(36, 56, 54, 72, BODY, r=2); c.circ(45, 64, 4, DARK); c.line([(45, 64), (45, 46)], DARK, 2)
    c.save("missile_boat")


def destroyer():
    c = Canvas(); hull(c, 6, 122, 15)
    turret(c, 100, 64, 7.5, 18); turret(c, 80, 64, 6, 14)
    c.rect(56, 54, 78, 74, BODY, r=3); c.rect(60, 58, 74, 70, DARK, edge=False)
    c.ell(40, 57, 54, 71, DARK); c.circ(24, 64, 8, MID); c.circ(24, 64, 5, BODY, edge=False)
    c.save("destroyer")


def cruiser():
    c = Canvas(); hull(c, 4, 124, 17)
    turret(c, 104, 64, 8, 22, 2); turret(c, 84, 64, 7, 18, 2)
    c.rect(54, 52, 78, 76, BODY, r=3); c.rect(58, 56, 74, 72, DARK, edge=False)
    c.ell(36, 57, 50, 71, DARK); c.ell(22, 58, 34, 70, DARK); turret(c, 12, 64, 6, 10)
    c.save("cruiser")


def battleship():
    c = Canvas(); hull(c, 2, 126, 20)
    turret(c, 106, 64, 9, 24, 3); turret(c, 86, 64, 8.5, 22, 3)
    c.rect(54, 50, 76, 78, BODY, r=3); c.rect(58, 54, 72, 74, DARK, edge=False)
    c.circ(65, 64, 5, ACC)
    turret(c, 32, 64, 8.5, 22, 3); c.ell(40, 57, 50, 71, DARK)
    c.save("battleship")


def submarine():
    c = Canvas()
    c.ell(8, 52, 122, 76, BODY); c.ell(14, 56, 116, 72, MID, edge=False)
    c.rect(50, 55, 74, 73, BODY, r=3); c.rect(56, 58, 68, 70, DARK, edge=False)
    c.rect(66, 40, 70, 56, DARK, edge=False); c.rect(66, 72, 70, 88, DARK, edge=False)
    c.poly([(14, 64), (4, 54), (4, 74)], DARK)
    c.save("submarine")


def aircraft_carrier():
    c = Canvas()
    deck = [(126, 52), (112, 38), (10, 38), (2, 46), (2, 82), (10, 90), (112, 90), (126, 76)]
    c.poly(deck, BODY)
    c.poly([(118, 54), (108, 44), (14, 44), (8, 50), (8, 78), (14, 84), (108, 84), (118, 74)], MID, edge=False)
    c.line([(14, 64), (112, 64)], BODY, 2.4)
    for x in range(20, 106, 14):
        c.line([(x, 64), (x + 6, 64)], DARK, 2)
    c.line([(34, 50), (96, 78)], ACC, 1.6)
    c.rect(66, 24, 92, 40, BODY, r=2); c.rect(70, 28, 88, 37, DARK, edge=False)
    c.line([(79, 24), (79, 14)], DARK, 2)
    for x in (28, 50):
        c.rect(x, 80, x + 12, 88, DARK, edge=False)
    c.save("aircraft_carrier")


def diver():
    c = Canvas()
    c.poly([(30, 50), (6, 40), (8, 52), (30, 58)], DARK); c.poly([(30, 78), (6, 88), (8, 76), (30, 70)], DARK)
    c.rect(26, 54, 56, 74, DARK, r=4)
    c.ell(36, 48, 88, 80, BODY); c.circ(84, 64, 10, MID); c.ell(84, 58, 96, 70, ACC)
    c.line([(70, 52), (104, 54)], BODY, 4); c.line([(70, 76), (104, 74)], BODY, 4)
    c.circ(106, 55, 3, MID); c.circ(106, 73, 3, MID)
    c.save("diver")


def naval_port():
    c = Canvas()
    c.rect(8, 10, 120, 70, MID, r=6); c.rect(14, 16, 114, 64, BODY, r=4)
    for x in (22, 46, 70):
        c.rect(x, 22, x + 20, 38, DARK, r=2)
    for i, x in enumerate((22, 40, 58, 76)):
        c.rect(x, 44, x + 14, 56, ACC if i % 2 == 0 else RED, edge=True)
    c.rect(18, 70, 34, 118, MID, r=2); c.rect(62, 70, 78, 118, MID, r=2); c.rect(100, 70, 114, 118, MID, r=2)
    c.line([(96, 34), (96, 66)], DARK, 3); c.line([(96, 34), (116, 34)], DARK, 3); c.circ(96, 34, 4, ACC)
    c.poly([(48, 112), (42, 104), (42, 78), (52, 74), (58, 78), (58, 104)], BODY)
    c.save("naval_port")


def coastal_battery():
    c = Canvas()
    c.rect(12, 12, 116, 116, MID, r=16); c.rect(22, 22, 106, 106, BODY, r=10)
    sandbag_ring(c, 52, 64, 40, 16, 6)
    c.circ(52, 64, 26, MID)
    c.rect(52, 53, 124, 61, DARK, r=3); c.rect(52, 67, 124, 75, DARK, r=3)
    c.rect(114, 50, 126, 78, DARK, r=2)
    c.circ(52, 64, 11, BODY)
    c.save("coastal_battery")


def projectiles():
    c = Canvas()
    c.rect(12, 56, 112, 72, BODY, r=7); c.poly([(112, 56), (124, 64), (112, 72)], MID)
    c.rect(12, 50, 26, 78, DARK, r=2); c.line([(40, 64), (92, 64)], DARK, 2)
    c.save("proj_torpedo")
    c = Canvas()
    c.circ(64, 64, 26, DARK); c.rect(54, 34, 74, 44, MID, r=2); c.line([(40, 64), (88, 64)], MID, 3)
    c.save("proj_depth")


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    for fn in (patrol_boat, gunboat, missile_boat, destroyer, cruiser, battleship, submarine,
               aircraft_carrier, diver, naval_port, coastal_battery, projectiles):
        fn()
    print("naval sprites written to", os.path.normpath(OUT_DIR))
