"""Shared ground for the hero drawings: the canvas, the builds, and the
small helpers every layer uses. See hero.py for how the layers are assembled.

Coordinates are points on a W x H canvas, centred on x = CX, feet at FOOT.
Every layer is drawn relative to a `Geo`, which is a build's proportions, so
a style is written once and fits every body.
"""
import math

from artkit import Sprite

W, H = 64, 80
CX = 32
FOOT = 76

INK = 0x0B0908
VOID = 0x120D0C
LEG = 0x2A2320
BOOT = 0x1A1512
BELT = 0x3A2A1C
LEATHER = 0x3B302B
LEATHER_DARK = 0x2E2521
STEEL = 0x8A9098
STEEL_LIGHT = 0xC9CFD6
STEEL_MID = 0x6E747C
STEEL_DARK = 0x5C626A
BONE = 0xE0D8C0
BONE_SHADE = 0xB5AC92
IVORY = 0xE8E2D4

BUILDS = {
    "lithe": dict(sw=8, hw=12, leg=4.0, hood_w=17, hood_h=18, hem_up=10, torso=25),
    "standard": dict(sw=10, hw=14, leg=4.5, hood_w=19, hood_h=19, hem_up=9, torso=23),
    "broad": dict(sw=13, hw=17, leg=5.5, hood_w=21, hood_h=20, hem_up=9, torso=22),
    "stout": dict(sw=12, hw=16, leg=5.0, hood_w=20, hood_h=18, hem_up=7, torso=19),
    "towering": dict(sw=12, hw=16, leg=5.0, hood_w=20, hood_h=20, hem_up=12, torso=27),
}


def cap(word):
    return word[0].upper() + word[1:]


class Geo:
    def __init__(self, build):
        self.build = build
        for key, value in BUILDS[build].items():
            setattr(self, key, value)
        self.hem = FOOT - self.hem_up
        self.sy = self.hem - self.torso  # the line of the shoulders

    def edge(self, y):
        """Half-width of a straight-sided cloak at height y."""
        t = (y - self.sy) / (self.hem - self.sy)
        return self.sw + (self.hw - self.sw) * t

    @property
    def legs_x(self):
        return (CX - 1.5 - self.leg, CX + 1.5)


def layer(name, doc):
    return Sprite(name, W, H, foot=FOOT, doc=doc)


def rect(s, x, y, w, h, color, outline=None, width=1.0):
    s.poly([(x, y), (x + w, y), (x + w, y + h), (x, y + h)], color, outline=outline, width=width)


def belt(s, g, y):
    rect(s, CX - g.sw + 1, y, 2 * g.sw - 2, 3, BELT)
    rect(s, CX - 1.5, y - 0.5, 3, 4, "trim")


def star(s, x, y, r, color):
    """A four-pointed star."""
    k = r * 0.32
    s.poly([(x, y - r), (x + k, y - k), (x + r, y), (x + k, y + k), (x, y + r), (x - k, y + k), (x - r, y),
            (x - k, y - k)], color)


def leaf(s, x, y, angle, length, width, color, rib=None):
    """A leaf from its base (x, y) pointing along `angle` (radians)."""
    dx, dy = math.cos(angle), math.sin(angle)
    nx, ny = -dy, dx
    mid = (x + dx * length * 0.5, y + dy * length * 0.5)
    tip = (x + dx * length, y + dy * length)
    s.poly([(x, y), (mid[0] + nx * width, mid[1] + ny * width), tip, (mid[0] - nx * width, mid[1] - ny * width)],
           color, outline=INK, width=0.5)
    if rib is not None:
        s.line((x, y), tip, rib, 0.4)


def arc_points(cx, cy, r, start, end, steps=14):
    return [(cx + r * math.cos(start + (end - start) * i / steps),
             cy + r * math.sin(start + (end - start) * i / steps)) for i in range(steps + 1)]
