"""Paint schemes per army and category. `pick()` returns a Scheme (chosen per unit with the unit's own rng)."""
from core import Scheme

def c(r, g, b):
    return (r / 255.0, g / 255.0, b / 255.0)

# (weight, Scheme-args)  - the unit's rng chooses one, so units of one army still differ.
G = {
 "wehrmacht": {
  "ground": [(3, dict(base=c(128, 112, 68), camo=[c(70, 82, 44), c(96, 54, 34)], style="splinter", strength=0.9, insignia="cross")),
             (2, dict(base=c(84, 86, 80), camo=[], style="none", insignia="cross")),
             (1, dict(base=c(122, 108, 66), camo=[c(66, 78, 42)], style="stripe", strength=0.8, insignia="cross"))],
  "air": [(3, dict(base=c(96, 104, 108), camo=[c(70, 80, 86), c(112, 120, 122)], style="mottle", strength=0.9, insignia="cross")),
          (1, dict(base=c(104, 112, 98), camo=[c(72, 90, 64)], style="splinter", strength=0.8, insignia="cross"))],
  "ship": [(1, dict(base=c(102, 108, 112), camo=[c(78, 86, 92)], style="stripe", strength=0.5, insignia=None))],
  "inf": [(1, dict(base=c(88, 96, 82), camo=[c(60, 78, 56)], style="splinter", strength=0.5))],
  "struct": [(1, dict(base=c(104, 102, 92), camo=[c(78, 84, 64)], style="blotch", strength=0.6))],
  "missile": [(1, dict(base=c(150, 152, 144), camo=[c(80, 88, 76)], style="blotch", strength=0.6, insignia="cross"))],
 },
 "red_army": {
  "ground": [(4, dict(base=c(82, 94, 56), camo=[], style="none", insignia="star")),
             (1, dict(base=c(82, 94, 56), camo=[c(215, 218, 212)], style="patch", strength=0.9, insignia="star"))],
  "air": [(3, dict(base=c(88, 104, 70), camo=[c(126, 110, 78), c(60, 72, 50)], style="blotch", strength=0.75, insignia="star")),
          (1, dict(base=c(110, 128, 140), camo=[c(78, 92, 66)], style="blotch", strength=0.6, insignia="star"))],
  "ship": [(1, dict(base=c(104, 110, 112), camo=[c(80, 90, 94)], style="stripe", strength=0.5, insignia=None))],
  "inf": [(1, dict(base=c(104, 98, 60), camo=[c(78, 80, 48)], style="blotch", strength=0.4))],
  "struct": [(1, dict(base=c(98, 100, 84), camo=[c(70, 84, 56)], style="blotch", strength=0.6))],
  "missile": [(1, dict(base=c(150, 150, 140), camo=[c(86, 100, 66)], style="blotch", strength=0.5, insignia="star"))],
 },
 "ija": {
  "ground": [(3, dict(base=c(126, 108, 66), camo=[c(66, 84, 52), c(96, 66, 40)], style="stripe", strength=0.85, insignia="whitebar")),
             (1, dict(base=c(112, 100, 64), camo=[c(74, 88, 56)], style="blotch", strength=0.7, insignia="whitebar"))],
  "air": [(3, dict(base=c(70, 92, 66), camo=[c(54, 74, 52)], style="blotch", strength=0.5, insignia="disk")),
          (2, dict(base=c(150, 154, 150), camo=[c(120, 128, 122)], style="mottle", strength=0.5, insignia="disk"))],
  "ship": [(1, dict(base=c(100, 104, 100), camo=[c(78, 84, 80)], style="stripe", strength=0.5, insignia=None))],
  "inf": [(1, dict(base=c(118, 106, 66), camo=[c(90, 90, 54)], style="blotch", strength=0.4))],
  "struct": [(1, dict(base=c(104, 98, 76), camo=[c(74, 84, 54)], style="blotch", strength=0.6))],
  "missile": [(1, dict(base=c(146, 148, 140), camo=[c(86, 96, 70)], style="blotch", strength=0.5, insignia="disk"))],
 },
 "british_army": {
  "ground": [(3, dict(base=c(70, 84, 54), camo=[c(24, 28, 22), c(104, 80, 48)], style="blotch", strength=0.85, insignia="flash")),
             (1, dict(base=c(142, 124, 88), camo=[c(108, 90, 60)], style="blotch", strength=0.6, insignia="flash"))],
  "air": [(1, dict(base=c(112, 118, 122), camo=[c(88, 94, 100)], style="blotch", strength=0.6, insignia="roundel_uk"))],
  "ship": [(1, dict(base=c(120, 128, 134), camo=[c(96, 104, 112)], style="stripe", strength=0.35, insignia=None))],
  "inf": [(1, dict(base=c(104, 96, 66), camo=[c(70, 80, 52), c(130, 110, 78)], style="blotch", strength=0.7))],
  "struct": [(1, dict(base=c(112, 108, 94), camo=[c(80, 88, 66)], style="blotch", strength=0.6))],
  "missile": [(1, dict(base=c(160, 162, 156), camo=[c(96, 104, 88)], style="blotch", strength=0.4, insignia="roundel_uk"))],
 },
 "us_army": {
  "ground": [(2, dict(base=c(72, 80, 54), camo=[c(30, 34, 26)], style="blotch", strength=0.6, insignia=None)),
             (3, dict(base=c(146, 124, 88), camo=[c(112, 94, 64)], style="blotch", strength=0.55, insignia=None))],
  "air": [(1, dict(base=c(118, 122, 128), camo=[c(94, 98, 106)], style="blotch", strength=0.6, insignia="usstar"))],
  "ship": [(1, dict(base=c(130, 138, 142), camo=[c(104, 112, 118)], style="stripe", strength=0.35, insignia=None))],
  "inf": [(1, dict(base=c(110, 102, 74), camo=[c(78, 80, 56), c(136, 116, 82)], style="blotch", strength=0.7))],
  "struct": [(1, dict(base=c(116, 112, 98), camo=[c(84, 92, 70)], style="blotch", strength=0.55))],
  "missile": [(1, dict(base=c(168, 170, 164), camo=[c(104, 110, 96)], style="blotch", strength=0.35, insignia="usstar"))],
 },
 "french_army": {
  "ground": [(3, dict(base=c(66, 80, 50), camo=[c(24, 26, 22), c(142, 124, 86)], style="blotch", strength=0.85, insignia="flash")),
             (1, dict(base=c(144, 126, 90), camo=[c(70, 84, 54)], style="blotch", strength=0.6, insignia="flash"))],
  "air": [(1, dict(base=c(116, 122, 130), camo=[c(92, 98, 108)], style="blotch", strength=0.55, insignia="roundel_fr"))],
  "ship": [(1, dict(base=c(122, 130, 138), camo=[c(96, 106, 116)], style="stripe", strength=0.35, insignia=None))],
  "inf": [(1, dict(base=c(104, 98, 70), camo=[c(72, 82, 54), c(132, 114, 80)], style="blotch", strength=0.7))],
  "struct": [(1, dict(base=c(112, 110, 98), camo=[c(82, 92, 68)], style="blotch", strength=0.55))],
  "missile": [(1, dict(base=c(164, 166, 160), camo=[c(98, 108, 92)], style="blotch", strength=0.4, insignia="roundel_fr"))],
 },
 "italian_army": {
  "ground": [(3, dict(base=c(148, 126, 82), camo=[c(80, 82, 48), c(96, 62, 38)], style="blotch", strength=0.8, insignia="flash_it")),
             (1, dict(base=c(132, 116, 78), camo=[c(78, 86, 56)], style="stripe", strength=0.7, insignia="flash_it"))],
  "air": [(2, dict(base=c(140, 120, 80), camo=[c(76, 92, 60), c(100, 70, 44)], style="blotch", strength=0.8, insignia="roundel_it")),
          (1, dict(base=c(92, 106, 78), camo=[c(130, 112, 74)], style="blotch", strength=0.7, insignia="roundel_it"))],
  "ship": [(1, dict(base=c(124, 130, 134), camo=[c(96, 106, 112)], style="stripe", strength=0.45, insignia=None))],
  "inf": [(1, dict(base=c(92, 98, 80), camo=[c(70, 80, 60)], style="blotch", strength=0.35))],
  "struct": [(1, dict(base=c(122, 112, 88), camo=[c(88, 90, 62)], style="blotch", strength=0.6))],
  "missile": [(1, dict(base=c(150, 150, 142), camo=[c(96, 104, 80)], style="blotch", strength=0.5, insignia="roundel_it"))],
 },
 "russian_gf": {
  "ground": [(3, dict(base=c(60, 76, 46), camo=[c(132, 112, 76), c(22, 26, 20)], style="blotch", strength=0.85, insignia=None)),
             (1, dict(base=c(70, 82, 54), camo=[c(30, 34, 28)], style="blotch", strength=0.6, insignia=None))],
  "air": [(1, dict(base=c(112, 118, 126), camo=[c(86, 94, 104)], style="blotch", strength=0.55, insignia="star"))],
  "ship": [(1, dict(base=c(114, 122, 128), camo=[c(90, 98, 106)], style="stripe", strength=0.4, insignia=None))],
  "inf": [(1, dict(base=c(88, 94, 64), camo=[c(60, 70, 44), c(120, 108, 72)], style="blotch", strength=0.7))],
  "struct": [(1, dict(base=c(110, 108, 94), camo=[c(76, 86, 62)], style="blotch", strength=0.6))],
  "missile": [(1, dict(base=c(160, 162, 154), camo=[c(92, 100, 84)], style="blotch", strength=0.4, insignia="star"))],
 },
}


def pick(faction, cat, rng):
    opts = G[faction][cat]
    tot = sum(w for w, _ in opts)
    r = rng.random() * tot
    for w, kw in opts:
        r -= w
        if r <= 0:
            return Scheme(**kw)
    return Scheme(**opts[-1][1])
