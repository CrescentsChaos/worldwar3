#!/usr/bin/env python3
"""Generates simple top-down sprites (facing RIGHT) for the v6 scouting drones into assets/sprites/.
Replace them with your own art any time (same file names, or use the in-game Asset Manager)."""
import os
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites")
S = 4          # supersampling
W = 128
BODY = (214, 218, 208, 255)
DARK = (52, 58, 54, 255)
MID = (120, 128, 120, 255)
ACC = (230, 170, 60, 255)


def canvas():
    return Image.new("RGBA", (W * S, W * S), (0, 0, 0, 0))


def fin(img, name):
    img = img.resize((W, W), Image.LANCZOS)
    os.makedirs(OUT, exist_ok=True)
    img.save(os.path.join(OUT, name + ".png"))


def P(pts):
    return [(x * S, y * S) for x, y in pts]


def recon_quad():
    im = canvas(); d = ImageDraw.Draw(im)
    for cx, cy in [(34, 34), (34, 94), (94, 34), (94, 94)]:
        d.line(P([(64, 64), (cx, cy)]), fill=DARK, width=5 * S)
        d.ellipse([(cx - 17) * S, (cy - 17) * S, (cx + 17) * S, (cy + 17) * S], fill=(90, 96, 92, 150), outline=DARK, width=2 * S)
        d.ellipse([(cx - 3) * S, (cy - 3) * S, (cx + 3) * S, (cy + 3) * S], fill=DARK)
    d.rounded_rectangle([44 * S, 52 * S, 86 * S, 76 * S], radius=6 * S, fill=BODY, outline=DARK, width=2 * S)
    d.ellipse([78 * S, 58 * S, 90 * S, 70 * S], fill=ACC, outline=DARK, width=S)
    fin(im, "recon_quad")


def scout_uav():
    im = canvas(); d = ImageDraw.Draw(im)
    d.polygon(P([(30, 64), (62, 14), (74, 14), (60, 64), (74, 114), (62, 114)]), fill=BODY, outline=DARK)
    d.polygon(P([(10, 58), (28, 58), (28, 70), (10, 70)]), fill=MID, outline=DARK)
    d.polygon(P([(14, 40), (28, 56), (28, 72), (14, 88)]), fill=MID, outline=DARK)
    d.ellipse([20 * S, 56 * S, 118 * S, 72 * S], fill=BODY, outline=DARK, width=2 * S)
    d.ellipse([92 * S, 58 * S, 108 * S, 70 * S], fill=DARK)
    d.line(P([(14, 64), (6, 64)]), fill=DARK, width=4 * S)
    fin(im, "scout_uav")


def hale_uav():
    im = canvas(); d = ImageDraw.Draw(im)
    d.polygon(P([(44, 64), (58, 4), (72, 4), (66, 64), (72, 124), (58, 124)]), fill=BODY, outline=DARK)
    d.polygon(P([(10, 60), (26, 60), (26, 68), (10, 68)]), fill=MID, outline=DARK)
    d.ellipse([8 * S, 54 * S, 118 * S, 74 * S], fill=BODY, outline=DARK, width=2 * S)
    d.ellipse([86 * S, 48 * S, 108 * S, 80 * S], fill=MID, outline=DARK, width=2 * S)
    d.ellipse([100 * S, 58 * S, 116 * S, 70 * S], fill=DARK)
    d.line(P([(14, 56), (6, 48)]), fill=DARK, width=3 * S)
    d.line(P([(14, 72), (6, 80)]), fill=DARK, width=3 * S)
    fin(im, "hale_uav")


def naval_scout():
    im = canvas(); d = ImageDraw.Draw(im)
    d.ellipse([6 * S, 60 * S, 40 * S, 68 * S], fill=MID, outline=DARK)
    d.line(P([(24, 64), (4, 64)]), fill=DARK, width=3 * S)
    d.ellipse([24 * S, 48 * S, 100 * S, 80 * S], fill=BODY, outline=DARK, width=2 * S)
    d.line(P([(60, 64), (28, 20)]), fill=(80, 86, 82, 200), width=6 * S)
    d.line(P([(60, 64), (28, 108)]), fill=(80, 86, 82, 200), width=6 * S)
    d.line(P([(60, 64), (96, 22)]), fill=(80, 86, 82, 200), width=6 * S)
    d.line(P([(60, 64), (96, 106)]), fill=(80, 86, 82, 200), width=6 * S)
    d.ellipse([82 * S, 54 * S, 104 * S, 74 * S], fill=ACC, outline=DARK, width=S)
    fin(im, "naval_scout")


def scout_ugv():
    im = canvas(); d = ImageDraw.Draw(im)
    d.rounded_rectangle([22 * S, 34 * S, 106 * S, 52 * S], radius=5 * S, fill=DARK)
    d.rounded_rectangle([22 * S, 76 * S, 106 * S, 94 * S], radius=5 * S, fill=DARK)
    d.rounded_rectangle([30 * S, 46 * S, 98 * S, 82 * S], radius=6 * S, fill=BODY, outline=DARK, width=2 * S)
    d.ellipse([52 * S, 52 * S, 76 * S, 76 * S], fill=MID, outline=DARK, width=2 * S)
    d.rectangle([68 * S, 62 * S, 104 * S, 68 * S], fill=DARK)
    d.ellipse([96 * S, 60 * S, 108 * S, 70 * S], fill=ACC, outline=DARK, width=S)
    fin(im, "scout_ugv")


for fn in (recon_quad, scout_uav, hale_uav, naval_scout, scout_ugv):
    fn()
print("sprites written to", os.path.abspath(OUT))
