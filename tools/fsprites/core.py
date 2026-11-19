"""Shared drawing + styling core for the per-army sprite generator.

All drawing happens on a 128x128 logical grid, FACING RIGHT (east), in neutral greys:
LIGHT / BODY / MID / DARK / EDGE.  `finish()` then recolours those greys with the army's paint scheme,
adds camouflage, lighting, wear and an outline, and paints national insignia.
"""
import math
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

N = 128
SS = 6
LIGHT = (240, 242, 234, 255)
BODY = (216, 220, 208, 255)
MID = (168, 175, 158, 255)
DARK = (84, 90, 78, 255)
EDGE = (38, 42, 34, 255)
ACC = (240, 196, 60, 255)
RED = (214, 70, 60, 255)
WHITE = (255, 255, 255, 255)


class Canvas:
    def __init__(self, n=N):
        self.n = n
        self.img = Image.new("RGBA", (n * SS, n * SS), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)
        self.marks = []          # insignia anchors: (kind, x, y, size, angle)
        self.crop = (0.0, 0.0, float(n))
        self.fb = False          # True when the unit fell back to a generic template (no specific design)

    def _s(self, pts):
        return [(x * SS, y * SS) for x, y in pts]

    def poly(self, pts, fill=BODY, edge=True, w=1.5):
        p = self._s(pts)
        self.d.polygon(p, fill=fill)
        if edge:
            self.d.line(p + [p[0]], fill=EDGE, width=max(1, int(w * SS)), joint="curve")

    def rect(self, x0, y0, x1, y1, fill=BODY, r=0, edge=True, w=1.5):
        box = [min(x0, x1) * SS, min(y0, y1) * SS, max(x0, x1) * SS, max(y0, y1) * SS]
        ow = max(1, int(w * SS))
        if r:
            self.d.rounded_rectangle(box, radius=r * SS, fill=fill, outline=EDGE if edge else None, width=ow)
        else:
            self.d.rectangle(box, fill=fill, outline=EDGE if edge else None, width=ow)

    def ell(self, x0, y0, x1, y1, fill=BODY, edge=True, w=1.5):
        self.d.ellipse([x0 * SS, y0 * SS, x1 * SS, y1 * SS], fill=fill,
                       outline=EDGE if edge else None, width=max(1, int(w * SS)))

    def circ(self, cx, cy, r, fill=BODY, edge=True, w=1.5):
        self.ell(cx - r, cy - r, cx + r, cy + r, fill, edge, w)

    def line(self, pts, fill=DARK, w=2.0):
        self.d.line(self._s(pts), fill=fill, width=max(1, int(w * SS)), joint="curve")

    def bar(self, x0, y0, x1, y1, w, fill=DARK, edge=True):
        """Thick line drawn as a polygon, optionally outlined (guns, barrels, tubes)."""
        dx, dy = x1 - x0, y1 - y0
        L = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / L * w / 2, dx / L * w / 2
        self.poly([(x0 + nx, y0 + ny), (x1 + nx, y1 + ny), (x1 - nx, y1 - ny), (x0 - nx, y0 - ny)], fill, edge, 1.0)

    def rrect(self, cx, cy, w, h, ang, fill=BODY, edge=True):
        c, s = math.cos(ang), math.sin(ang)
        pts = [(cx + x * c - y * s, cy + x * s + y * c) for x, y in
               ((-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2))]
        self.poly(pts, fill, edge, 1.2)

    def mark(self, kind, x, y, size, ang=0.0):
        self.marks.append((kind, x, y, size, ang))

    def render(self, out, pad=0.06):
        """Auto-fit: crop to the drawing's bounding box (square, centred) so every unit fills its sprite."""
        bb = self.img.getbbox() or (0, 0, self.n * SS, self.n * SS)
        cx, cy = (bb[0] + bb[2]) / 2.0, (bb[1] + bb[3]) / 2.0
        side = max(bb[2] - bb[0], bb[3] - bb[1]) * (1.0 + pad * 2.0)
        x0, y0 = cx - side / 2.0, cy - side / 2.0
        self.crop = (x0 / SS, y0 / SS, side / SS)
        im = self.img.crop((int(round(x0)), int(round(y0)), int(round(x0 + side)), int(round(y0 + side))))
        return im.resize((out, out), Image.LANCZOS)


# ------------------------------------------------------------------ paint schemes
class Scheme:
    """base: colour of the main painted surface (what BODY maps to). camo: extra colours. style: pattern name."""

    def __init__(self, base, camo=(), style="none", strength=0.85, insignia=None, accent=None):
        self.base = np.array(base, dtype=np.float32)
        self.camo = [np.array(c, dtype=np.float32) for c in camo]
        self.style = style
        self.strength = strength
        self.insignia = insignia
        self.accent = np.array(accent if accent is not None else (0.62, 0.45, 0.12), dtype=np.float32)


MULT = [0.10, 0.42, 0.78, 1.0, 1.2]
XP = [0.10, 0.33, 0.66, 0.85, 0.95]


def _ramp(lum, base):
    out = np.zeros(lum.shape + (3,), dtype=np.float32)
    for c in range(3):
        out[..., c] = np.interp(lum, XP, [min(1.0, base[c] * m) for m in MULT])
    return out


def _blob(rng, n, sigma):
    z = ndi.gaussian_filter(rng.standard_normal((n, n)), sigma, mode="wrap")
    return (z - z.mean()) / (z.std() + 1e-6)


def _camo_layers(rng, n, scheme, ncol):
    """Returns a list of (mask[n,n] float 0..1, colour) in paint order."""
    layers = []
    st = scheme.style
    for i in range(ncol):
        col = scheme.camo[i]
        if st == "blotch":
            z = _blob(rng, n, n / rng.uniform(7, 12))
            m = np.clip((z - rng.uniform(0.2, 0.6)) * 3.0, 0, 1)
        elif st == "splinter":
            pts = rng.uniform(0, n, size=(18, 2))
            idx = np.argmin(((np.stack(np.mgrid[0:n, 0:n], -1)[:, :, None, :] - pts[None, None]) ** 2).sum(-1), axis=-1)
            pick = rng.random(18) < (0.35 / max(ncol, 1) + 0.1)
            m = pick[idx].astype(np.float32)
        elif st == "stripe":
            yy, xx = np.mgrid[0:n, 0:n]
            wob = ndi.gaussian_filter(rng.standard_normal((n, n)), n / 8.0) * 6.0
            ph = rng.uniform(0, 6.28)
            m = (np.sin((xx * 0.18 + yy * 0.05) + wob + ph + i * 2.1) > 0.45).astype(np.float32)
        elif st == "mottle":
            z = _blob(rng, n, 1.6)
            m = np.clip((z - 0.7) * 3.0, 0, 1)
        elif st == "patch":      # whitewash / field patches
            z = _blob(rng, n, n / 5.0)
            m = np.clip((z - 0.5) * 3.0, 0, 1)
        else:
            m = np.zeros((n, n), dtype=np.float32)
        layers.append((m.astype(np.float32), col))
    return layers


def finish(cv, scheme, out, rng, wear=1.0, outline=3):
    """Recolour the neutral-grey drawing, add camo, light, wear, outline and insignia. Returns a PIL RGBA image."""
    im = cv.render(out)
    a = np.asarray(im).astype(np.float32) / 255.0
    rgb, alpha = a[..., :3], a[..., 3]
    n = out
    lum = rgb @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    amber_m = ndi.gaussian_filter(((rgb[..., 0] > 0.8) & (rgb[..., 1] > 0.65) & (rgb[..., 2] < 0.45)).astype(np.float32), 0.7)
    red_m = ndi.gaussian_filter(((rgb[..., 0] > 0.65) & (rgb[..., 1] < 0.42) & (rgb[..., 2] < 0.4)).astype(np.float32), 0.7)

    col = _ramp(lum, scheme.base)
    if scheme.camo and scheme.style != "none":
        body = np.clip((lum - 0.5) / 0.2, 0.0, 1.0)[..., None]
        shade = (lum[..., None] / 0.85)
        for m, ccol in _camo_layers(rng, n, scheme, len(scheme.camo)):
            w = (body * m[..., None]) * scheme.strength
            col = col * (1 - w) + (ccol * shade) * w
    col = col * (1 - amber_m[..., None]) + scheme.accent * (0.45 + 0.5 * lum[..., None]) * amber_m[..., None]
    col = col * (1 - red_m[..., None]) + np.array([0.5, 0.12, 0.09]) * (0.5 + 0.5 * lum[..., None]) * red_m[..., None]

    # lighting from the top-left + ambient occlusion
    sig = n / 18.0
    h = ndi.gaussian_filter(alpha, sig) + ndi.gaussian_filter(lum * alpha, n / 128.0 * 2.0) * 0.35
    gy, gx = np.gradient(h)
    light = 0.7 * gx + 0.7 * gy
    col = col * (1.0 + np.clip(-light * 55.0 * (128.0 / n), -0.35, 0.35))[..., None]
    ao = ndi.gaussian_filter(alpha, n / 32.0)
    col = col * (0.62 + 0.38 * np.clip(ao * 1.15, 0, 1))[..., None]

    # grain, streaks, scuffs, soot
    k = n / 128.0
    grain = ndi.gaussian_filter(rng.standard_normal((n, n)), 0.7 * k)
    col = col * (1 + 0.10 * wear * grain)[..., None]
    streak = ndi.gaussian_filter(rng.standard_normal((n, n)), (1.2 * k, 14.0 * k))
    col = col * (1 - 0.07 * wear * np.clip(streak / (streak.std() + 1e-6), 0, 3))[..., None]
    scuff = ndi.gaussian_filter(rng.standard_normal((n, n)), 1.1 * k)
    scuff = np.clip(scuff / (scuff.std() + 1e-6) - 2.2, 0, 1)
    col = col + (0.12 * wear * scuff * (lum > 0.4))[..., None]
    soot = _blob(rng, n, n / 7.0)
    col = col * (1 - 0.22 * wear * np.clip(soot - 0.8, 0, 1))[..., None]
    col = np.clip(col, 0, 1)

    solid = alpha > 0.35
    ring = ndi.binary_dilation(solid, iterations=max(1, int(outline * n / 256.0 + 0.5))) & ~solid
    ring_a = ndi.gaussian_filter(ring.astype(np.float32), 0.7 * k)
    outc = np.array([0.025, 0.03, 0.025])
    out_rgb = col * alpha[..., None] + outc * (1 - alpha[..., None])
    out_alpha = np.clip(np.maximum(alpha, ring_a * 0.95), 0, 1)
    img = Image.fromarray((np.dstack([np.clip(out_rgb, 0, 1), out_alpha]) * 255).astype(np.uint8), "RGBA")
    _paint_marks(img, cv.marks, scheme, n, cv.crop)
    return img


# --------------------------------------------------------------------- insignia
def _insignia(d, kind, cx, cy, r, ang, ss):
    """Draw one national marking onto `d` (an ImageDraw on a supersampled layer)."""
    def C(x, y, rr, fill):
        d.ellipse([(x - rr) * ss, (y - rr) * ss, (x + rr) * ss, (y + rr) * ss], fill=fill)
    if kind == "cross":          # German Balkenkreuz: black cross, white edge
        for col, t, L in (((245, 245, 240, 255), 0.42, 1.0), ((18, 18, 18, 255), 0.28, 0.9)):
            w = r * t
            d.rectangle([(cx - r * L) * ss, (cy - w) * ss, (cx + r * L) * ss, (cy + w) * ss], fill=col)
            d.rectangle([(cx - w) * ss, (cy - r * L) * ss, (cx + w) * ss, (cy + r * L) * ss], fill=col)
    elif kind == "star":         # Soviet / Russian red star
        for rr, col in ((r * 1.08, (240, 240, 235, 255)), (r * 0.95, (170, 30, 30, 255))):
            pts = []
            for i in range(10):
                a = ang - math.pi / 2 + i * math.pi / 5
                q = rr if i % 2 == 0 else rr * 0.42
                pts.append(((cx + math.cos(a) * q) * ss, (cy + math.sin(a) * q) * ss))
            d.polygon(pts, fill=col)
    elif kind == "usstar":       # US white star on blue disc with bars
        C(cx, cy, r, (35, 55, 110, 255))
        pts = []
        for i in range(10):
            a = ang - math.pi / 2 + i * math.pi / 5
            q = r * 0.78 if i % 2 == 0 else r * 0.32
            pts.append(((cx + math.cos(a) * q) * ss, (cy + math.sin(a) * q) * ss))
        d.polygon(pts, fill=(235, 235, 235, 255))
    elif kind == "disk":         # Japanese hinomaru
        C(cx, cy, r * 1.0, (240, 240, 235, 255))
        C(cx, cy, r * 0.74, (180, 30, 35, 255))
    elif kind in ("roundel_uk", "roundel_fr", "roundel_it"):
        cols = {"roundel_uk": ((35, 55, 130), (235, 235, 235), (180, 30, 40)),
                "roundel_fr": ((35, 55, 130), (235, 235, 235), (180, 30, 40)),
                "roundel_it": ((40, 130, 60), (235, 235, 235), (180, 35, 40))}[kind]
        if kind == "roundel_uk":
            C(cx, cy, r, cols[0] + (255,)); C(cx, cy, r * 0.62, cols[1] + (255,)); C(cx, cy, r * 0.3, cols[2] + (255,))
        else:                    # French / Italian: outer ring first colour, middle white, centre third
            C(cx, cy, r, cols[0] + (255,)); C(cx, cy, r * 0.66, cols[1] + (255,)); C(cx, cy, r * 0.33, cols[2] + (255,))
    elif kind == "flash":        # small tricolour bar (ground vehicles)
        for i, col in enumerate(((35, 55, 130), (235, 235, 235), (180, 30, 40))):
            d.rectangle([(cx - r + i * r * 2 / 3) * ss, (cy - r * 0.5) * ss, (cx - r + (i + 1) * r * 2 / 3) * ss, (cy + r * 0.5) * ss], fill=col + (255,))
    elif kind == "flash_it":
        for i, col in enumerate(((40, 130, 60), (235, 235, 235), (180, 35, 40))):
            d.rectangle([(cx - r + i * r * 2 / 3) * ss, (cy - r * 0.5) * ss, (cx - r + (i + 1) * r * 2 / 3) * ss, (cy + r * 0.5) * ss], fill=col + (255,))
    elif kind == "whitebar":     # plain white identification bar
        d.rectangle([(cx - r) * ss, (cy - r * 0.25) * ss, (cx + r) * ss, (cy + r * 0.25) * ss], fill=(235, 235, 228, 255))


def _paint_marks(img, marks, scheme, out, crop):
    if not marks:
        return
    ss = 4
    layer = Image.new("RGBA", (out * ss, out * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    k = out / crop[2]
    for kind, x, y, size, ang in marks:
        kind = scheme.insignia if kind == "auto" else kind
        if kind:
            _insignia(d, kind, (x - crop[0]) * k, (y - crop[1]) * k, size * k, ang, ss)
    layer = layer.resize((out, out), Image.LANCZOS)
    # weather the markings a little so they sit in the paint
    la = np.asarray(layer).astype(np.float32)
    base = np.asarray(img).astype(np.float32)
    a = la[..., 3:4] / 255.0 * 0.88
    base[..., :3] = base[..., :3] * (1 - a) + la[..., :3] * a * 0.92
    base[..., 3] = np.maximum(base[..., 3], la[..., 3] * 0.9)
    img.paste(Image.fromarray(np.clip(base, 0, 255).astype(np.uint8), "RGBA"))


def perturb(p, rng, keys, amt=0.08, shift_keys=(), shift=0.03):
    """Per-unit proportion variation: scales numeric params and nudges fractional positions."""
    for k in keys:
        if k in p and isinstance(p[k], (int, float)) and not isinstance(p[k], bool):
            p[k] = p[k] * float(rng.uniform(1 - amt, 1 + amt))
    for k in shift_keys:
        if k in p and isinstance(p[k], (int, float)):
            p[k] = p[k] + float(rng.uniform(-shift, shift))
    return p
