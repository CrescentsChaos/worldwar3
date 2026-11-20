#!/usr/bin/env python3
"""Generates data/maps/<id>.json : the four battlefields (terrain, rivers, bridges, roads, sectors, country layout).

Every map shares the same 6400 x 2128 grid (see scripts/water.gd), so only geography changes. Run from the
project root:   python3 tools/gen_maps.py
It also contains a Python copy of the water raster used by the game, and validates each map
(roads on land or bridges only, sectors / buildings on dry land, ports on the coast).
"""
import json, math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import datafiles as df

W = 6400
CELL = 16
Y_MIN, Y_MAX = -560, 1568
COLS, ROWS = W // CELL, (Y_MAX - Y_MIN) // CELL
MID_Y = 504.0
FIELD_TOP, FIELD_BOTTOM = -240.0, 1248.0


# ------------------------------------------------------------------ geometry helpers
def spline(pts, samples=8):
    out = []
    n = len(pts)
    for i in range(n - 1):
        p0 = pts[max(i - 1, 0)]; p1 = pts[i]; p2 = pts[i + 1]; p3 = pts[min(i + 2, n - 1)]
        for s in range(samples):
            t = s / samples; t2 = t * t; t3 = t2 * t
            out.append(tuple(0.5 * ((2 * p1[k]) + (p2[k] - p0[k]) * t + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t2
                                    + (3 * p1[k] - p0[k] - 3 * p2[k] + p3[k]) * t3) for k in (0, 1)))
    out.append(tuple(pts[-1]))
    return out


def rnd(p):
    return [round(p[0], 1), round(p[1], 1)]


def wob(x, coast, bay_depth, bay_sigma, bay_x):
    w = 6.0 * math.sin(x / 71.0) + 4.0 * math.sin(x / 37.0 + 1.3)
    t = (x - bay_x) / bay_sigma
    return coast + w - bay_depth * math.exp(-t * t)


class Raster:
    """Python twin of Water.ensure_built(): 0 land, 1 stream, 2 river / lake, 3 sea; bridge cells."""

    def __init__(self, m):
        c = m["coast"]
        self.kinds = [0] * (COLS * ROWS)
        self.bridge = [0] * (COLS * ROWS)
        for cy in range(ROWS):
            py = Y_MIN + (cy + 0.5) * CELL
            for cx in range(COLS):
                px = (cx + 0.5) * CELL
                if abs(py - MID_Y) > wob(px, c["half"], c["bay_depth"], c["bay_sigma"], c["bay_x"]):
                    self.kinds[cy * COLS + cx] = 3
        for ww in m["waterways"]:
            self.stamp(ww["pts"], ww["w"] * 0.5, ww["kind"])
        for b in m["bridges"]:
            for cy in range(max(0, int((b[1] - Y_MIN) // CELL)), min(ROWS, int((b[1] + b[3] - Y_MIN) // CELL) + 1)):
                for cx in range(max(0, int(b[0] // CELL)), min(COLS, int((b[0] + b[2]) // CELL) + 1)):
                    cxp = (cx + 0.5) * CELL; cyp = Y_MIN + (cy + 0.5) * CELL
                    if b[0] <= cxp <= b[0] + b[2] and b[1] <= cyp <= b[1] + b[3]:
                        self.bridge[cy * COLS + cx] = 1

    def stamp(self, pts, r, kind):
        for i in range(len(pts) - 1):
            a = pts[i]; b = pts[i + 1]
            n = max(1, int(math.dist(a, b) / 6.0))
            for s in range(n + 1):
                px = a[0] + (b[0] - a[0]) * s / n; py = a[1] + (b[1] - a[1]) * s / n
                for cy in range(max(0, int((py - r - Y_MIN) // CELL)), min(ROWS, int((py + r - Y_MIN) // CELL) + 1)):
                    for cx in range(max(0, int((px - r) // CELL)), min(COLS, int((px + r) // CELL) + 1)):
                        if math.hypot((cx + 0.5) * CELL - px, Y_MIN + (cy + 0.5) * CELL - py) > r:
                            continue
                        idx = cy * COLS + cx
                        if self.kinds[idx] != 3 and self.kinds[idx] < kind:
                            self.kinds[idx] = kind

    def kind(self, x, y):
        cx = int(x // CELL); cy = int((y - Y_MIN) // CELL)
        if cx < 0 or cx >= COLS or cy < 0 or cy >= ROWS:
            return 0
        return self.kinds[cy * COLS + cx]

    def is_bridge(self, x, y):
        cx = int(x // CELL); cy = int((y - Y_MIN) // CELL)
        if cx < 0 or cx >= COLS or cy < 0 or cy >= ROWS:
            return False
        return self.bridge[cy * COLS + cx] == 1

    def dry(self, x, y):
        return self.kind(x, y) == 0 or self.is_bridge(x, y)

    def reach_sea(self, x, y, maxd=200):
        for d in range(0, maxd, 8):
            for ang in range(0, 360, 20):
                if self.kind(x + d * math.cos(math.radians(ang)), y + d * math.sin(math.radians(ang))) == 3:
                    return True
        return False


# ------------------------------------------------------------------ shared pieces
def country(coast_half):
    """The default country layout (own half, x from own edge). Ports are placed relative to the coast."""
    base = df._read(os.path.join(df.DATA, "country.json"))
    out = []
    for e in base:
        if e[0] == "naval_port":
            continue
        out.append(list(e))
    py = coast_half - 38
    out.append(["naval_port", 450, round(MID_Y + py)])
    out.append(["naval_port", 450, round(MID_Y - py)])
    return out


def mirror(p):
    return (W - p[0], 2 * MID_Y - p[1])


def dnieper_waterways():
    COAST, BAY_DEPTH = 760.0, 250.0
    RIVER_X, RIVER_W, STREAM_W = 3200.0, 72.0, 40.0
    half = COAST - BAY_DEPTH + 40.0
    out = [{"w": RIVER_W, "kind": 2, "pts": [rnd((RIVER_X, MID_Y - half)), rnd((RIVER_X, MID_Y + half))]}]
    src = [(1228, 44), (1244, 120), (1300, 215), (1390, 285), (1480, 345), (1560, 392), (1600, 410)]
    ctrl = [(RIVER_X + (c[0] - 1600.0) * 2.4, MID_Y + (c[1] - 504.0) * 1.7) for c in src]
    ctrl[-1] = (RIVER_X, ctrl[-1][1])
    base_line = spline(ctrl, 8)
    for cx in (2150.0, 4250.0):
        creek = [(cx + 70.0 * math.sin(k * 1.1 + cx), MID_Y - 700.0 + k * 175.0) for k in range(9)]
        out.append({"w": STREAM_W * 0.8, "kind": 1, "pts": [rnd(p) for p in spline(creek, 6)]})
    for flip_x in (False, True):
        for flip_y in (False, True):
            line = []
            for p in base_line:
                x, y = p
                if flip_x: x = W - x
                if flip_y: y = 2 * MID_Y - y
                line.append(rnd((x, y)))
            out.append({"w": STREAM_W, "kind": 1, "pts": line})
    return out


class RoadBuilder:
    """Roads as a node / edge graph; every edge becomes a polyline cut into <=90 px pieces so the
    game's road graph (scripts/roads.gd) connects them at shared coordinates."""

    def __init__(self):
        self.nodes = {}
        self.edges = []

    def node(self, name, x, y):
        self.nodes[name] = (float(x), float(y))
        return name

    def road(self, names, w, curve=0.0, seed=0, flat=()):
        """`flat` lists (a, b) pairs that must stay perfectly straight (road decks over bridges)."""
        for a, b in zip(names[:-1], names[1:]):
            c = 0.0 if ((a, b) in flat or (b, a) in flat) else curve
            self.edges.append((a, b, w, c, seed + len(self.edges)))

    def build(self):
        out = []
        for a, b, w, curve, seed in self.edges:
            pa = self.nodes[a]; pb = self.nodes[b]
            n = max(1, int(math.dist(pa, pb) / 90.0))
            pts = []
            nx, ny = -(pb[1] - pa[1]), (pb[0] - pa[0])
            ln = math.hypot(nx, ny) or 1.0
            nx /= ln; ny /= ln
            for i in range(n + 1):
                t = i / n
                x = pa[0] + (pb[0] - pa[0]) * t; y = pa[1] + (pb[1] - pa[1]) * t
                off = math.sin(t * math.pi) * curve * math.sin(seed * 1.7 + t * 3.0)
                pts.append(rnd((x + nx * off, y + ny * off)))
            out.append({"w": w, "pts": pts})
        return out


def site_spurs(rb, hub_names, country_list, w=9.0):
    """A dirt spur from every country building to the nearest highway node (both sides)."""
    for side in (0, 1):
        for i, e in enumerate(country_list):
            if e[0] == "naval_port":
                continue
            x, y = float(e[1]), float(e[2])
            if side == 1:
                x, y = mirror((x, y))
            best = min(hub_names, key=lambda h: math.dist(rb.nodes[h], (x, y)))
            nm = "s%d_%d" % (side, i)
            rb.node(nm, x, y)
            rb.road([nm, best], w, curve=14.0, seed=i * 3 + side)


def make_map(mid, name, desc, palette, coast, waterways, bridges, rb_fn, sectors, forests, seed, crater_density=1.0, extra=None):
    half = coast["half"]
    ctry = country(half)
    rb = RoadBuilder()
    hubs = rb_fn(rb, ctry)
    site_spurs(rb, hubs, ctry)
    m = {
        "name": name, "desc": desc, "palette": palette, "seed": seed,
        "coast": coast, "waterways": waterways, "bridges": bridges,
        "roads": rb.build(), "sectors": sectors, "country": ctry,
        "forests": forests, "craters": int(520 * crater_density),
    }
    if extra:
        m.update(extra)
    return m


PALETTES = {
    "temperate": {"ground": [0.18, 0.22, 0.12], "dirt": [0.34, 0.30, 0.16], "shade": [0.04, 0.06, 0.03], "tree": [0.05, 0.105, 0.045], "water_tint": [0.0, 0.0, 0.0]},
    "steppe":    {"ground": [0.30, 0.28, 0.15], "dirt": [0.46, 0.40, 0.21], "shade": [0.09, 0.07, 0.03], "tree": [0.12, 0.15, 0.06], "water_tint": [0.02, 0.01, 0.0]},
    "alpine":    {"ground": [0.15, 0.19, 0.15], "dirt": [0.30, 0.31, 0.27], "shade": [0.03, 0.05, 0.04], "tree": [0.03, 0.08, 0.06], "water_tint": [0.0, 0.01, 0.02]},
    "delta":     {"ground": [0.17, 0.22, 0.14], "dirt": [0.28, 0.30, 0.18], "shade": [0.03, 0.06, 0.04], "tree": [0.05, 0.12, 0.07], "water_tint": [0.0, 0.02, 0.01]},
}


# ------------------------------------------------------------------ the four maps
def map_dnieper():
    ww = dnieper_waterways()
    bys = [30.0, 267.0, 504.0, 741.0, 978.0]
    bridges = [[3146.0, by - 22.0, 108.0, 44.0] for by in bys]

    def roads(rb, ctry):
        xs = [0, 420, 1000, 1500, 2300, 3090, 3310, 4100, 4900, 5400, 6000, 6400]
        hub = []
        for x in xs:
            hub.append(rb.node("h%d" % x, x, MID_Y))
        rb.road(["h%d" % x for x in xs], 22.0, curve=0.0)
        for i, by in enumerate(bys):
            if by == 504.0:
                continue
            a = rb.node("w%d" % i, 1500, by); b = rb.node("wb%d" % i, 3090, by); c = rb.node("eb%d" % i, 3310, by); d = rb.node("e%d" % i, 4900, by)
            rb.road([a, b], 12.0, curve=30.0, seed=i); rb.road([b, c], 12.0); rb.road([c, d], 12.0, curve=30.0, seed=i + 7)
            hub += [a, b, c, d]
        # N-S connectors on the zone edges
        for side, x in (("w", 1500), ("e", 4900)):
            names = []
            for i, by in enumerate(bys):
                nm = ("w%d" % i) if (side == "w" and by != 504.0) else (("e%d" % i) if (side == "e" and by != 504.0) else "h%d" % x)
                names.append(nm)
            rb.road(names, 12.0, curve=18.0, seed=3)
        return hub

    sectors = [
        {"id": "A", "name": "West Crossroads", "x": 2300, "y": 504, "r": 190, "income": 2.0},
        {"id": "B", "name": "Central Bridge", "x": 3200, "y": 504, "r": 210, "income": 3.5},
        {"id": "C", "name": "East Crossroads", "x": 4100, "y": 504, "r": 190, "income": 2.0},
        {"id": "D", "name": "North Bridge", "x": 3200, "y": 267, "r": 170, "income": 2.0},
        {"id": "E", "name": "South Bridge", "x": 3200, "y": 741, "r": 170, "income": 2.0},
        {"id": "F", "name": "Northern Village", "x": 2150, "y": 170, "r": 170, "income": 1.5},
        {"id": "G", "name": "Southern Village", "x": 4250, "y": 838, "r": 170, "income": 1.5},
    ]
    return make_map("dnieper", "Dnieper Crossing",
                    "A wide river valley cut by five bridges. The Central Bridge decides the war; creeks and the northern and southern seas allow flanking by boat and plane.",
                    "temperate", {"half": 760.0, "bay_depth": 250.0, "bay_sigma": 420.0, "bay_x": 3200.0},
                    ww, bridges, roads, sectors, {"count": 420, "min": 4, "max": 8}, 1914)


def map_steppe():
    cr1 = [(2050 + 90 * math.sin(k * 0.9), -120 + k * 150) for k in range(0, 11)]
    cr2 = [(4350 + 90 * math.sin(k * 0.9 + 2), -120 + k * 150) for k in range(0, 11)]
    ww = [
        {"w": 36.0, "kind": 1, "pts": [rnd(p) for p in spline(cr1, 6)]},
        {"w": 36.0, "kind": 1, "pts": [rnd(p) for p in spline(cr2, 6)]},
        {"w": 330.0, "kind": 2, "pts": [[3120.0, 40.0], [3280.0, 40.0]]},     # northern lake
        {"w": 330.0, "kind": 2, "pts": [[3120.0, 968.0], [3280.0, 968.0]]},   # southern lake
        {"w": 34.0, "kind": 1, "pts": [rnd(p) for p in spline([(1000, -60), (1050, 120), (1000, 260), (1090, 330), (1250, 380)], 6)]},
        {"w": 34.0, "kind": 1, "pts": [rnd(mirror(p)) for p in spline([(1000, -60), (1050, 120), (1000, 260), (1090, 330), (1250, 380)], 6)]},
    ]

    def roads(rb, ctry):
        hub = []
        xs = [0, 420, 1000, 1500, 2300, 3200, 4100, 4900, 5400, 6000, 6400]
        for x in xs:
            hub.append(rb.node("h%d" % x, x, MID_Y))
        rb.road(["h%d" % x for x in xs], 22.0)
        # two long diagonal roads that cross the highway in the centre
        for nm, pts in (("nw", [(1500, 130), (2300, 300), (3200, MID_Y), (4100, 700), (4900, 880)]),
                        ("sw", [(1500, 880), (2300, 700), (3200, MID_Y), (4100, 300), (4900, 130)])):
            names = []
            for i, p in enumerate(pts):
                key = "%s%d" % (nm, i)
                if abs(p[0] - 3200) < 1 and abs(p[1] - MID_Y) < 1:
                    names.append("h3200")
                else:
                    rb.node(key, p[0], p[1]); names.append(key); hub.append(key)
            rb.road(names, 13.0, curve=36.0, seed=len(nm))
        # edge connectors
        rb.road(["nw0", "h1500", "sw0"], 12.0, curve=10.0, seed=2)
        rb.road(["sw4", "h4900", "nw4"], 12.0, curve=10.0, seed=5)
        return hub

    sectors = [
        {"id": "A", "name": "Hill 214", "x": 3200, "y": 504, "r": 230, "income": 3.5},
        {"id": "B", "name": "West Junction", "x": 2300, "y": 504, "r": 190, "income": 2.0},
        {"id": "C", "name": "East Junction", "x": 4100, "y": 504, "r": 190, "income": 2.0},
        {"id": "D", "name": "NW Kolkhoz", "x": 2300, "y": 300, "r": 170, "income": 1.5},
        {"id": "E", "name": "SE Kolkhoz", "x": 4100, "y": 700, "r": 170, "income": 1.5},
        {"id": "F", "name": "North Ridge", "x": 4100, "y": 300, "r": 170, "income": 1.5},
        {"id": "G", "name": "South Ridge", "x": 2300, "y": 700, "r": 170, "income": 1.5},
    ]
    return make_map("steppe", "Kursk Steppe",
                    "Open rolling steppe with two creeks and twin lakes. Few places to hide, long sight lines, and a road net made for fast armoured thrusts.",
                    "steppe", {"half": 760.0, "bay_depth": 120.0, "bay_sigma": 500.0, "bay_x": 3200.0},
                    ww, [], roads, sectors, {"count": 170, "min": 3, "max": 6}, 1943, 0.8)


def map_carpathian():
    r1 = [(2300 + 60 * math.sin(k * 0.8), -90 + k * 120) for k in range(0, 11)]
    r2 = [(4100 + 60 * math.sin(k * 0.8 + 1.7), -90 + k * 120) for k in range(0, 11)]
    ww = [
        {"w": 70.0, "kind": 2, "pts": [rnd(p) for p in spline(r1, 6)]},
        {"w": 70.0, "kind": 2, "pts": [rnd(p) for p in spline(r2, 6)]},
        {"w": 34.0, "kind": 1, "pts": [rnd(p) for p in spline([(3200, -60), (3150, 120), (3250, 250), (3200, 340)], 6)]},
        {"w": 34.0, "kind": 1, "pts": [rnd(p) for p in spline([(3200, 1068), (3250, 880), (3150, 760), (3200, 670)], 6)]},
        {"w": 32.0, "kind": 1, "pts": [rnd(p) for p in spline([(1000, 90), (1180, 250), (1130, 380), (1260, 480)], 6)]},
        {"w": 32.0, "kind": 1, "pts": [rnd(mirror(p)) for p in spline([(1000, 90), (1180, 250), (1130, 380), (1260, 480)], 6)]},
    ]

    def river_x(pts, y):
        best = min(pts, key=lambda p: abs(p[1] - y))
        return best[0]

    lines = [spline(r1, 6), spline(r2, 6)]
    bys = [120.0, 504.0, 888.0]
    bridges = []
    bx = {}
    for li, ln in enumerate(lines):
        for by in bys:
            x = river_x(ln, by)
            bridges.append([x - 54.0, by - 22.0, 108.0, 44.0])
            bx[(li, by)] = x

    def roads(rb, ctry):
        hub = []
        xs = [0, 420, 1000, 1500, 2300, 3200, 4100, 4900, 5400, 6000, 6400]
        names = []
        for x in xs:
            if x == 2300:
                x_use = bx[(0, 504.0)]; nm = "h2300"; rb.node("wbL", x_use - 70, MID_Y); rb.node("wbR", x_use + 70, MID_Y)
                names += ["wbL", "wbR"]
            elif x == 4100:
                x_use = bx[(1, 504.0)]; rb.node("ebL", x_use - 70, MID_Y); rb.node("ebR", x_use + 70, MID_Y)
                names += ["ebL", "ebR"]
            else:
                names.append(rb.node("h%d" % x, x, MID_Y)); hub.append("h%d" % x)
        hub += ["wbL", "wbR", "ebL", "ebR"]
        rb.road(names, 22.0, curve=40.0, seed=4, flat=[("wbL", "wbR"), ("ebL", "ebR")])
        # northern and southern passes through the two rivers
        for by in (120.0, 888.0):
            tag = "n" if by < 500 else "s"
            pts = [("%s0" % tag, 1500, by), ("%s1" % tag, bx[(0, by)] - 70, by), ("%s2" % tag, bx[(0, by)] + 70, by),
                   ("%s3" % tag, 3200, by + (60 if by < 500 else -60)), ("%s4" % tag, bx[(1, by)] - 70, by),
                   ("%s5" % tag, bx[(1, by)] + 70, by), ("%s6" % tag, 4900, by)]
            for nm, x, y in pts:
                rb.node(nm, x, y); hub.append(nm)
            rb.road([p[0] for p in pts], 12.0, curve=40.0, seed=9 if by < 500 else 11,
                    flat=[("%s1" % tag, "%s2" % tag), ("%s4" % tag, "%s5" % tag)])
        # edge connectors + mountain pass links to the highway (through the centre valley)
        rb.road(["n0", "h1500", "s0"], 12.0, curve=12.0, seed=1)
        rb.road(["n6", "h4900", "s6"], 12.0, curve=12.0, seed=2)
        rb.node("c1", 3200, 330); rb.node("c2", 3200, 680); rb.node("h3200x", 3200, MID_Y)
        rb.road(["wbR", "h3200x", "ebL"], 22.0, curve=30.0, seed=6)
        rb.road(["n3", "c1", "h3200x", "c2", "s3"], 12.0, curve=20.0, seed=8)
        hub += ["c1", "c2", "h3200x"]
        return hub

    sectors = [
        {"id": "A", "name": "Valley Pass", "x": 3200, "y": 504, "r": 210, "income": 3.0},
        {"id": "B", "name": "West Bridge", "x": round(bx[(0, 504.0)]), "y": 504, "r": 170, "income": 2.5},
        {"id": "C", "name": "East Bridge", "x": round(bx[(1, 504.0)]), "y": 504, "r": 170, "income": 2.5},
        {"id": "D", "name": "North Pass", "x": 3420, "y": 210, "r": 170, "income": 1.5},
        {"id": "E", "name": "South Pass", "x": 2980, "y": 798, "r": 170, "income": 1.5},
        {"id": "F", "name": "NW Gorge", "x": round(bx[(0, 120.0)]), "y": 120, "r": 150, "income": 1.5},
        {"id": "G", "name": "SE Gorge", "x": round(bx[(1, 888.0)]), "y": 888, "r": 150, "income": 1.5},
    ]
    return make_map("carpathian", "Carpathian Gorge",
                    "Two deep rivers and dense pine forest turn the front into a chain of choke-point bridges. Infantry and transports shine; armour is funnelled onto the roads.",
                    "alpine", {"half": 760.0, "bay_depth": 180.0, "bay_sigma": 380.0, "bay_x": 3200.0},
                    ww, bridges, roads, sectors, {"count": 760, "min": 5, "max": 10}, 1968, 0.7)


def map_delta():
    ww = [
        {"w": 440.0, "kind": 2, "pts": [[2980.0, MID_Y], [3420.0, MID_Y]]},                   # central estuary lake
        {"w": 70.0, "kind": 2, "pts": [rnd(p) for p in spline([(3200, -60), (3230, 80), (3190, 200), (3210, 300)], 6)]},
        {"w": 70.0, "kind": 2, "pts": [rnd(p) for p in spline([(3210, 708), (3190, 810), (3230, 930), (3200, 1060)], 6)]},
        {"w": 40.0, "kind": 1, "pts": [rnd(p) for p in spline([(2200, -60), (2150, 200), (2250, 400), (2200, 600), (2260, 800), (2200, 1060)], 6)]},
        {"w": 40.0, "kind": 1, "pts": [rnd(p) for p in spline([(4200, -60), (4250, 200), (4150, 400), (4200, 600), (4140, 800), (4200, 1060)], 6)]},
        {"w": 36.0, "kind": 1, "pts": [rnd(p) for p in spline([(2700, -60), (2760, 120), (2700, 260), (2780, 360)], 6)]},
        {"w": 36.0, "kind": 1, "pts": [rnd(p) for p in spline([(3700, -60), (3640, 120), (3700, 260), (3620, 360)], 6)]},
        {"w": 36.0, "kind": 1, "pts": [rnd(p) for p in spline([(2700, 1068), (2760, 880), (2700, 760), (2780, 650)], 6)]},
        {"w": 36.0, "kind": 1, "pts": [rnd(p) for p in spline([(3700, 1068), (3640, 880), (3700, 760), (3620, 650)], 6)]},
    ]
    bridges = [[3146.0, 230.0 - 22.0, 108.0, 44.0], [3146.0, 780.0 - 22.0, 108.0, 44.0]]
    ww[1]["pts"] = [rnd(p) for p in spline([(3200, -60), (3200, 80), (3200, 230), (3200, 300)], 6)]
    ww[2]["pts"] = [rnd(p) for p in spline([(3200, 708), (3200, 780), (3200, 930), (3200, 1060)], 6)]

    def roads(rb, ctry):
        hub = []
        for x in (0, 420, 1000, 1500, 2000, 2600):
            hub.append(rb.node("a%d" % x, x, MID_Y))
        rb.road(["a%d" % x for x in (0, 420, 1000, 1500, 2000, 2600)], 22.0)
        for x in (3800, 4400, 4900, 5400, 6000, 6400):
            hub.append(rb.node("b%d" % x, x, MID_Y))
        rb.road(["b%d" % x for x in (3800, 4400, 4900, 5400, 6000, 6400)], 22.0)
        # northern and southern causeways around the estuary, over the two river bridges
        rb.node("n1", 2600, 330); rb.node("n2", 3090, 230); rb.node("n3", 3310, 230); rb.node("n4", 3800, 330)
        rb.node("s1", 2600, 680); rb.node("s2", 3090, 780); rb.node("s3", 3310, 780); rb.node("s4", 3800, 680)
        rb.road(["a2600", "n1", "n2", "n3", "n4", "b3800"], 20.0, curve=30.0, seed=3, flat=[("n2", "n3")])
        rb.road(["a2600", "s1", "s2", "s3", "s4", "b3800"], 20.0, curve=30.0, seed=5, flat=[("s2", "s3")])
        rb.node("w1", 1500, 140); rb.node("w2", 1500, 868); rb.node("e1", 4900, 140); rb.node("e2", 4900, 868)
        rb.road(["w1", "a1500", "w2"], 12.0, curve=12.0, seed=2); rb.road(["e1", "b4900", "e2"], 12.0, curve=12.0, seed=4)
        rb.road(["w1", "n1"], 12.0, curve=30.0, seed=6); rb.road(["w2", "s1"], 12.0, curve=30.0, seed=7)
        rb.road(["e1", "n4"], 12.0, curve=30.0, seed=8); rb.road(["e2", "s4"], 12.0, curve=30.0, seed=9)
        hub += ["n1", "n2", "n3", "n4", "s1", "s2", "s3", "s4", "w1", "w2", "e1", "e2"]
        return hub

    sectors = [
        {"id": "A", "name": "North Causeway", "x": 3200, "y": 230, "r": 190, "income": 3.0},
        {"id": "B", "name": "South Causeway", "x": 3200, "y": 780, "r": 190, "income": 3.0},
        {"id": "C", "name": "West Dyke", "x": 2200, "y": 504, "r": 170, "income": 2.0},
        {"id": "D", "name": "East Dyke", "x": 4200, "y": 504, "r": 170, "income": 2.0},
        {"id": "E", "name": "Harbour Quarter", "x": 2650, "y": 200, "r": 160, "income": 2.0},
        {"id": "F", "name": "Lock Gates", "x": 3750, "y": 810, "r": 160, "income": 2.0},
    ]
    return make_map("delta", "Rhine Delta",
                    "Flooded lowlands around a central estuary. Two causeways are the only dry routes through the centre; the wider sea gives navies and air power room to hit the flanks.",
                    "delta", {"half": 690.0, "bay_depth": 200.0, "bay_sigma": 500.0, "bay_x": 3200.0},
                    ww, bridges, roads, sectors, {"count": 300, "min": 4, "max": 8}, 1944, 0.9)


# ------------------------------------------------------------------ validation
def validate(mid, m):
    r = Raster(m)
    problems = []
    for road in m["roads"]:
        pts = road["pts"]
        for i in range(len(pts) - 1):
            a, b = pts[i], pts[i + 1]
            n = max(1, int(math.dist(a, b) / 12))
            for s in range(n + 1):
                x = a[0] + (b[0] - a[0]) * s / n; y = a[1] + (b[1] - a[1]) * s / n
                k = r.kind(x, y)
                if k >= 2 and not r.is_bridge(x, y):
                    problems.append(("road in deep water", [round(x), round(y)], k))
                    break
    for s in m["sectors"]:
        if not r.dry(s["x"], s["y"]):
            problems.append(("sector in water", s["id"], r.kind(s["x"], s["y"])))
    for e in m["country"]:
        for side in (0, 1):
            x, y = float(e[1]), float(e[2])
            if side == 1:
                x, y = mirror((x, y))
            k = r.kind(x, y)
            if e[0] == "naval_port":
                if k != 0 or not r.reach_sea(x, y, 160):
                    problems.append(("port not on coast", e, side, k))
            elif k != 0:
                problems.append(("building in water", e, side, k))
    # bridges must span the water they sit on
    for b in m["bridges"]:
        cx, cy = b[0] + b[2] / 2, b[1] + b[3] / 2
        if r.kind(cx, cy) < 2:
            problems.append(("bridge over no river", b))
    return problems


def main():
    maps = {"dnieper": map_dnieper(), "steppe": map_steppe(), "carpathian": map_carpathian(), "delta": map_delta()}
    bad = False
    for mid, m in maps.items():
        probs = validate(mid, m)
        print("%-11s roads %-3d road-points %-4d sectors %d  problems: %d" % (mid, len(m["roads"]), sum(len(r["pts"]) for r in m["roads"]), len(m["sectors"]), len(probs)))
        for p in probs[:12]:
            print("   ", p)
        bad = bad or bool(probs)
        m["palette_def"] = PALETTES[m["palette"]]
        df._write(os.path.join(df.DATA, "maps", mid + ".json"), m, 0)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
