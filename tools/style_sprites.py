#!/usr/bin/env python3
"""Turns the flat placeholder sprites into gritty, shaded, weathered military art.

Run AFTER the generators:
    python3 tools/generate_placeholder_sprites.py
    python3 tools/generate_naval_sprites.py
    python3 tools/style_sprites.py

What it does to every unit / building / missile sprite (projectiles are left bright so tracers stay readable):
  * upsamples 128 -> 256 px so the added detail survives scaling
  * re-colours the neutral greys with a category palette (olive drab / gunmetal / haze grey / concrete ...)
  * camouflage blotches on infantry and vehicles, panel wear, soot streaks, fine grain
  * directional lighting (light from the top-left) + ambient occlusion near edges
  * hard dark outline so units separate from the terrain
Needs Pillow, numpy and scipy. Idempotent only on fresh generator output (do not run twice).
"""
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SPR = os.path.join(ROOT, "assets", "sprites")
OUT_N = 256

# ramps: luminance of the neutral source art -> colour. xp = source luminance stops
XP = [0.10, 0.33, 0.66, 0.85, 1.00]
RAMPS = {
    "infantry": [(0.045, 0.055, 0.04), (0.15, 0.17, 0.11), (0.30, 0.34, 0.21), (0.44, 0.46, 0.32), (0.55, 0.56, 0.42)],
    "vehicle":  [(0.04, 0.05, 0.04), (0.13, 0.15, 0.10), (0.27, 0.31, 0.19), (0.41, 0.43, 0.29), (0.52, 0.53, 0.38)],
    "air":      [(0.04, 0.045, 0.055), (0.12, 0.135, 0.16), (0.26, 0.29, 0.33), (0.40, 0.44, 0.48), (0.56, 0.60, 0.63)],
    "ship":     [(0.04, 0.05, 0.06), (0.13, 0.16, 0.19), (0.27, 0.32, 0.35), (0.41, 0.46, 0.48), (0.56, 0.60, 0.61)],
    "structure": [(0.05, 0.05, 0.045), (0.15, 0.15, 0.135), (0.30, 0.30, 0.27), (0.45, 0.44, 0.40), (0.58, 0.57, 0.52)],
    "missile":  [(0.05, 0.05, 0.045), (0.17, 0.18, 0.16), (0.40, 0.42, 0.38), (0.62, 0.64, 0.59), (0.78, 0.79, 0.74)],
}
CAMO = {
    "infantry": [(0.40, 0.36, 0.22), (0.16, 0.22, 0.12)],
    "vehicle":  [(0.44, 0.38, 0.23), (0.15, 0.21, 0.12)],
    "air":      [(0.33, 0.37, 0.41), (0.20, 0.23, 0.27)],
    "ship":     [(0.46, 0.51, 0.53), (0.30, 0.35, 0.38)],
    "structure": [(0.40, 0.39, 0.34), (0.22, 0.22, 0.20)],
}
CAMO_STRENGTH = {"infantry": 0.55, "vehicle": 0.60, "air": 0.35, "ship": 0.18, "structure": 0.22}

AMBER = np.array([0.64, 0.47, 0.13])
RED = np.array([0.50, 0.12, 0.09])
OUTLINE = np.array([0.025, 0.03, 0.025])


def categories():
    d = json.load(open(os.path.join(ROOT, "data", "units.json")))
    cat = {}
    for key, v in d["units"].items():
        shape = v.get("shape", "box")
        if v.get("tab") == "navy" and shape == "infantry":
            cat[v.get("sprite", key)] = "infantry"   # diver
        else:
            cat[v.get("sprite", key)] = {"ship": "ship"}.get(shape, shape)
    for key, v in d["structures"].items():
        cat[v.get("sprite", key)] = "structure"
    for key, v in d["national"].items():
        cat[v.get("sprite", key)] = "structure"
    for key, v in d["strategic"].items():
        cat[v.get("sprite", key)] = "missile"
    return cat


def ramp(lum, name):
    cols = np.array(RAMPS[name])
    out = np.stack([np.interp(lum, XP, cols[:, c]) for c in range(3)], axis=-1)
    return out


def blob_noise(rng, n, sigma, seed_shift=0):
    z = rng.standard_normal((n, n))
    z = ndi.gaussian_filter(z, sigma, mode="wrap")
    z = (z - z.mean()) / (z.std() + 1e-6)
    return z


def stylize(img, cat, rng):
    n = OUT_N
    im = img.resize((n, n), Image.LANCZOS)
    a = np.asarray(im).astype(np.float32) / 255.0
    rgb, alpha = a[..., :3], a[..., 3]
    lum = rgb @ np.array([0.299, 0.587, 0.114], dtype=np.float32)

    # accent masks from the source colours
    amber_m = ((rgb[..., 0] > 0.8) & (rgb[..., 1] > 0.65) & (rgb[..., 2] < 0.45)).astype(np.float32)
    red_m = ((rgb[..., 0] > 0.65) & (rgb[..., 1] < 0.42) & (rgb[..., 2] < 0.4)).astype(np.float32)
    amber_m = ndi.gaussian_filter(amber_m, 0.7)
    red_m = ndi.gaussian_filter(red_m, 0.7)

    col = ramp(lum, cat)

    # camouflage: only on the light/mid body panels (not on dark detail or outlines)
    if cat in CAMO:
        z1 = blob_noise(rng, n, n / 9.0)
        z2 = blob_noise(rng, n, n / 14.0)
        body = np.clip((lum - 0.45) / 0.2, 0.0, 1.0)[..., None]
        s = CAMO_STRENGTH[cat]
        tan, grn = np.array(CAMO[cat][0]), np.array(CAMO[cat][1])
        m_tan = np.clip((z1 - 0.35) * 2.2, 0, 1)[..., None]
        m_grn = np.clip((z2 - 0.45) * 2.2, 0, 1)[..., None]
        shade = lum[..., None] / 0.85
        col = col * (1 - body * m_tan * s) + tan * shade * body * m_tan * s
        col = col * (1 - body * m_grn * s) + grn * shade * body * m_grn * s

    # accents
    col = col * (1 - amber_m[..., None]) + AMBER * (0.45 + 0.5 * lum[..., None]) * amber_m[..., None]
    col = col * (1 - red_m[..., None]) + RED * (0.5 + 0.5 * lum[..., None]) * red_m[..., None]

    # lighting: height-field from the blurred alpha, light from the top-left
    h = ndi.gaussian_filter(alpha, 7.0) * 1.0 + ndi.gaussian_filter(lum * alpha, 2.0) * 0.35
    gy, gx = np.gradient(h)
    light = -(gx * -0.7 + gy * -0.7)  # positive when the surface faces the light
    lit = 1.0 + np.clip(light * 55.0, -0.35, 0.35)
    col = col * lit[..., None]

    # ambient occlusion: darker toward the silhouette edge
    ao = ndi.gaussian_filter(alpha, 4.0)
    col = col * (0.62 + 0.38 * np.clip(ao * 1.15, 0, 1))[..., None]

    # fine grain + weathering streaks (run along the facing axis) + scuffs
    grain = rng.standard_normal((n, n)).astype(np.float32)
    grain = ndi.gaussian_filter(grain, 0.8)
    col = col * (1 + 0.10 * grain)[..., None]
    streak = ndi.gaussian_filter(rng.standard_normal((n, n)), (1.2, 14.0))
    streak = streak / (streak.std() + 1e-6)
    col = col * (1 - 0.07 * np.clip(streak, 0, 3))[..., None]
    scuff = ndi.gaussian_filter(rng.standard_normal((n, n)), 1.1)
    scuff = np.clip((scuff / (scuff.std() + 1e-6)) - 2.2, 0, 1)
    col = col + (0.12 * scuff * (lum > 0.4))[..., None]

    # soot / oil darkening on a few random patches
    soot = blob_noise(rng, n, n / 7.0)
    col = col * (1 - 0.22 * np.clip(soot - 0.8, 0, 1))[..., None]

    col = np.clip(col, 0, 1)

    # hard outline: dilate the silhouette a few px and paint it near-black
    solid = (alpha > 0.35)
    ring = ndi.binary_dilation(solid, iterations=3) & ~solid
    ring_a = ndi.gaussian_filter(ring.astype(np.float32), 0.7)
    out_rgb = col * alpha[..., None] + OUTLINE * (1 - alpha[..., None])
    out_alpha = np.clip(np.maximum(alpha, ring_a * 0.95), 0, 1)
    out_rgb = np.where((ring_a > 0)[..., None] & (alpha[..., None] < 0.5), OUTLINE * (1 - alpha[..., None]) + col * alpha[..., None], out_rgb)

    res = np.dstack([out_rgb, out_alpha])
    return Image.fromarray((np.clip(res, 0, 1) * 255).astype(np.uint8), "RGBA")


def main():
    cat = categories()
    rng = np.random.default_rng(1944)
    done = 0
    for fn in sorted(os.listdir(SPR)):
        if not fn.endswith(".png"):
            continue
        sid = fn[:-4]
        if sid.startswith("proj_") or sid not in cat:
            continue
        p = os.path.join(SPR, fn)
        img = Image.open(p).convert("RGBA")
        if img.size[0] != 128:
            print("skip (already styled?)", fn, img.size)
            continue
        stylize(img, cat[sid], rng).save(p)
        done += 1
    print("styled", done, "sprites")


if __name__ == "__main__":
    sys.exit(main())
