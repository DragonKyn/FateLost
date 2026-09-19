"""FateLost's set dressing: the props that tell you which realm you are in.

Run from the repo root:

    python tools/art/props.py            # writes the Swift and a preview
    python tools/art/props.py --preview  # preview sheet only

The Swift lands in FateLost/Rendering/PlaceholderArt+Props.swift; the preview
in tools/art/props-preview.png (gitignored).

A realm reads as itself long before its enemies arrive, so each one gets
props nothing else uses: reeds and standing water in the Fen, living pines
and stumps in the Forest, ice spires in the Wastes, gibbets and banners in
the Kingdom, vents and obsidian in the Depths, rifts and floating stone in
the Shattered Realm, statues and barricades in the Citadel, skull piles and
black obelisks at the Gate and in the Abyss.

Standing props are drawn with their base at the bottom of the canvas; ground
decals are drawn flat and anchored at their centre.
"""
import os
import sys

from artkit import Sprite, preview_sheet

INK = 0x0E0C08

BONE = 0xD8CDB0
BONE_SHADE = 0xA89C80
BONE_DARK = 0x6E6450
HOLLOW = 0x16110E

WOOD = 0x4A3A28
WOOD_LIGHT = 0x6A5438
WOOD_DARK = 0x2E2418
LEAF = 0x2E4428
LEAF_LIGHT = 0x456A38

STONE = 0x6A6660
STONE_LIGHT = 0x8A8680
STONE_DARK = 0x46433E

IRON = 0x5E5A54
IRON_LIGHT = 0x8E8A80
RUST = 0x7A5A40
GOLD = 0xC9A24A
CLOTH_RED = 0x6E2320

WATER = 0x24363A
WATER_LIGHT = 0x3E5A5E
ROT = 0x5A6A32

ICE = 0xA8D4E4
ICE_DEEP = 0x5A8EA8
ICE_PALE = 0xDCF0F8

LAVA = 0xE2601A
LAVA_HOT = 0xFFC24A
OBSIDIAN = 0x1E1A24

VOID = 0x5A3F8C
VOID_HOT = 0xC79BFF


def _mix(a, b, t):
    out = 0
    for shift in (16, 8, 0):
        ca = (a >> shift) & 0xFF
        cb = (b >> shift) & 0xFF
        out |= int(ca + (cb - ca) * t) << shift
    return out


def _shade(color, t=0.35):
    return _mix(color, 0x000000, t)


def _light(color, t=0.3):
    return _mix(color, 0xFFFFFF, t)


def decal(name, width, height, doc):
    """A flat prop lying on the ground, anchored at its middle."""
    return Sprite(name, width, height, anchor=(0.5, 0.5), doc=doc)


def standing(name, width, height, doc, foot=None):
    return Sprite(name, width, height, foot=foot if foot is not None else height - 2, doc=doc)


# ---------------------------------------------------------------------------
# The Drowned Fen
# ---------------------------------------------------------------------------

def reeds():
    s = standing("reeds", 34, 38, "A stand of dead reeds, bent where something came through.")
    ground = 36
    for index, (x, lean, tall) in enumerate(((7, -2, 22), (11, 1, 30), (15, -1, 26), (19, 2, 33),
                                             (23, 0, 24), (26, 3, 18))):
        color = ROT if index % 2 else _shade(ROT, 0.28)
        s.taper([(x, ground), (x + lean, ground - tall * 0.6), (x + lean * 2.2, ground - tall)], color, 1.8, 0.2)
        if tall > 24:
            # A seed head, gone to fluff.
            s.ellipse(x + lean * 2.2 - 1.3, ground - tall - 2, 2.6, 5, _shade(ROT, 0.45),
                      outline=INK, width=0.4)
    s.ellipse(6, ground - 3, 22, 5, _shade(ROT, 0.55))
    return s


def standingWater():
    s = decal("standingWater", 46, 30, "A pool of black water with something under it.")
    s.blob([(4, 15), (12, 5), (26, 3), (40, 9), (42, 19), (30, 26), (13, 25)], WATER, outline=INK, width=0.9)
    s.blob([(9, 14), (18, 8), (30, 8), (36, 14), (28, 20), (15, 20)], _shade(WATER, 0.3))
    # Sky caught on the surface.
    s.curve([(12, 18), (20, 15), (30, 17)], WATER_LIGHT, 1.2)
    s.curve([(18, 11), (27, 10)], WATER_LIGHT, 0.9)
    s.curve([(24, 21), (33, 20)], WATER_LIGHT, 0.7)
    # Something breaking the surface.
    s.taper([(30, 17), (33, 12)], BONE_SHADE, 1.6, 0.3, outline=INK, width=0.4)
    s.taper([(33, 18), (35.5, 14.5)], BONE_SHADE, 1.2, 0.2)
    return s


def bogStump():
    s = standing("bogStump", 30, 26, "A rotted stump sunk to its knees in the mire.")
    ground = 24
    s.ellipse(3, ground - 5, 24, 8, _shade(WATER, 0.2))
    s.blob([(7, ground - 2), (6, ground - 13), (11, ground - 17), (20, ground - 16), (23, ground - 10),
            (22, ground - 1)], WOOD, outline=INK, width=1.0)
    s.blob([(8, ground - 4), (7.5, ground - 12), (11, ground - 15), (13, ground - 3)], WOOD_DARK)
    # A broken-off top, rotted hollow.
    s.ellipse(8, ground - 19, 14, 6, _light(WOOD, 0.2), outline=INK, width=0.7)
    s.ellipse(10, ground - 18, 10, 4.2, _shade(WOOD, 0.4))
    s.ellipse(11.5, ground - 17.4, 7, 2.8, WOOD_DARK)
    s.poly([(20, ground - 17), (23, ground - 22), (22.5, ground - 14)], WOOD_LIGHT, outline=INK, width=0.6)
    # Shelf fungus climbing one side.
    for fx, fy, fw in ((6.6, ground - 9, 5.2), (7.4, ground - 6, 4.2), (6.2, ground - 12, 3.6)):
        s.ellipse(fx - fw / 2, fy - 1.3, fw, 2.6, _light(ROT, 0.35), outline=INK, width=0.4)
        s.ellipse(fx - fw / 2 + 0.5, fy - 1.1, fw * 0.5, 1.2, _light(ROT, 0.6))
    return s


# ---------------------------------------------------------------------------
# The Hollow Forest
# ---------------------------------------------------------------------------

def pineTree():
    s = standing("pineTree", 40, 72, "A black pine, still alive, and not glad about it.")
    ground = 70
    s.ellipse(12, ground - 4, 16, 6, _shade(WOOD, 0.6))
    s.taper([(20, ground - 1), (19, ground - 28), (20, ground - 44)], WOOD, 6.5, 3.2, outline=INK, width=0.8)
    s.taper([(18.5, ground - 3), (17.5, ground - 30)], WOOD_DARK, 2.2, 1.4)
    # Three tiers of boughs, widest at the bottom.
    for index, (y, spread, drop) in enumerate(((ground - 24, 17, 9), (ground - 38, 13, 8),
                                               (ground - 50, 9, 7))):
        color = LEAF if index % 2 else _shade(LEAF, 0.25)
        s.blob([(20 - spread, y), (20 - spread * 0.4, y - drop), (20, y - drop * 1.5),
                (20 + spread * 0.4, y - drop), (20 + spread, y),
                (20 + spread * 0.5, y + drop * 0.5), (20, y + drop * 0.7),
                (20 - spread * 0.5, y + drop * 0.5)], color, outline=INK, width=0.9)
        s.blob([(20 - spread * 0.8, y), (20 - spread * 0.3, y - drop * 0.7), (20 - 1, y + drop * 0.4)],
               _shade(color, 0.3))
        for nx in range(-2, 3):
            s.taper([(20 + nx * spread * 0.3, y - drop * 0.3), (20 + nx * spread * 0.45, y + drop * 0.55)],
                    _light(color, 0.18), 1.4, 0.3)
    s.poly([(20, ground - 50), (22, ground - 60), (18.5, ground - 58)], _shade(LEAF, 0.2),
           outline=INK, width=0.6)
    return s


def forestStump():
    s = standing("forestStump", 28, 22, "A stump cut clean, a long time ago.")
    ground = 20
    s.ellipse(3, ground - 4, 22, 7, _shade(WOOD, 0.6))
    s.blob([(6, ground - 1), (6, ground - 11), (21, ground - 11), (21, ground - 1)], WOOD,
           outline=INK, width=0.9)
    s.blob([(6.5, ground - 2), (6.5, ground - 10), (11, ground - 10), (11, ground - 2)], WOOD_DARK)
    s.ellipse(5, ground - 15, 18, 8, _light(WOOD, 0.25), outline=INK, width=0.8)
    for ring in (0.75, 0.5, 0.28):
        s.ellipse(5 + 9 * (1 - ring), ground - 15 + 4 * (1 - ring), 18 * ring, 8 * ring,
                  _shade(WOOD, 0.18 * (1 - ring) + 0.05))
    s.curve([(9, ground - 13), (14, ground - 11.5), (19, ground - 13)], WOOD_DARK, 0.6)
    for rx, ry in ((4.5, ground - 3), (22, ground - 4)):
        s.taper([(rx, ry), (rx - 3 if rx < 14 else rx + 3, ry + 3)], WOOD_DARK, 2.4, 1.0)
    return s


def mushrooms():
    s = standing("mushrooms", 30, 24, "A cluster of pale caps, faintly lit from underneath.")
    ground = 22
    s.glow(15, ground - 8, 12, 0x9FE0B0, 0.35)
    for x, y, r, tilt in ((9, ground - 1, 4.2, -1), (16, ground - 2, 5.6, 0.5), (22, ground - 1, 3.4, 1.2),
                          (13, ground, 2.6, -0.4)):
        s.taper([(x, y), (x + tilt, y - r * 1.5)], 0xE4DCC4, r * 0.55, r * 0.4, outline=INK, width=0.5)
        s.blob([(x + tilt - r, y - r * 1.4), (x + tilt - r * 0.5, y - r * 2.2), (x + tilt + r * 0.5, y - r * 2.2),
                (x + tilt + r, y - r * 1.4), (x + tilt, y - r * 1.1)], 0xC8D8BC, outline=INK, width=0.7)
        s.blob([(x + tilt - r * 0.8, y - r * 1.5), (x + tilt - r * 0.3, y - r * 2.0),
                (x + tilt + r * 0.1, y - r * 1.5)], _light(0xC8D8BC, 0.4))
        s.dot(x + tilt + r * 0.3, y - r * 1.75, r * 0.16, 0x8AA87A)
    s.ellipse(5, ground - 2, 22, 5, _shade(LEAF, 0.5))
    return s


# ---------------------------------------------------------------------------
# The Frozen Wastes
# ---------------------------------------------------------------------------

def iceSpire():
    s = standing("iceSpire", 34, 56, "A spire of river ice, blue at the root.")
    ground = 54
    s.glow(17, ground - 20, 20, ICE, 0.25)
    s.ellipse(5, ground - 5, 24, 8, _shade(ICE_DEEP, 0.35))
    s.poly([(11, ground - 1), (14, ground - 34), (18, ground - 48), (21, ground - 30), (23, ground - 1)],
           ICE, outline=INK, width=0.9)
    s.poly([(14, ground - 34), (18, ground - 48), (19.5, ground - 30), (16, ground - 6)], ICE_PALE)
    s.poly([(11, ground - 1), (14, ground - 34), (15.5, ground - 20), (14, ground - 1)], ICE_DEEP)
    s.line((16, ground - 40), (17, ground - 12), _light(ICE_PALE, 0.5), 0.8)
    # Lesser shards leaning off the base.
    s.poly([(6, ground - 1), (8, ground - 18), (11, ground - 1)], ICE, outline=INK, width=0.7)
    s.poly([(23, ground - 1), (26, ground - 14), (28, ground - 1)], ICE, outline=INK, width=0.7)
    s.poly([(8, ground - 18), (9.5, ground - 8), (8.5, ground - 2)], ICE_PALE)
    return s


def frozenCorpse():
    s = decal("frozenCorpse", 40, 28, "Someone who sat down out of the wind and stayed.")
    # The drift that took them.
    s.blob([(4, 17), (12, 10), (26, 9), (36, 15), (33, 23), (15, 24)], _shade(ICE_DEEP, 0.18),
           outline=INK, width=0.7)
    s.blob([(9, 17), (18, 13), (29, 14), (31, 19), (18, 21)], _light(ICE_DEEP, 0.12))
    # A helm, tipped on its side, half under.
    s.blob([(9, 16), (11, 11), (16, 10), (19, 13), (18, 17)], 0x4E4E52, outline=INK, width=0.7)
    s.poly([(10, 14), (18, 13), (18.4, 15.2), (10.2, 16.2)], HOLLOW)
    s.curve([(11, 11.4), (15, 10.4)], 0x7A7A7E, 0.7)
    # An arm still reaching, fingers open.
    s.taper([(22, 18), (28, 15), (31, 10)], 0x4E4E52, 3.4, 2.2, outline=INK, width=0.5)
    s.ellipse(29, 7.5, 4.6, 4.4, BONE_SHADE, outline=INK, width=0.5)
    for fx, fy in ((29.4, 6.6), (31.2, 6.2), (32.6, 7.4)):
        s.taper([(fx, fy + 1), (fx + 0.6, fy - 3)], BONE, 1.1, 0.14)
    s.curve([(8, 20), (18, 22), (31, 20)], _light(ICE_PALE, 0.35), 1.0)
    return s


# ---------------------------------------------------------------------------
# The Blighted Kingdom
# ---------------------------------------------------------------------------

def gibbet():
    s = standing("gibbet", 36, 64, "A gibbet, still occupied.")
    ground = 62
    s.ellipse(6, ground - 4, 16, 6, _shade(WOOD, 0.6))
    s.taper([(12, ground - 1), (11, ground - 30), (11, ground - 56)], WOOD, 4.2, 3.0, outline=INK, width=0.8)
    s.taper([(11, ground - 55), (20, ground - 57), (29, ground - 56)], WOOD, 3.2, 2.6, outline=INK, width=0.7)
    s.poly([(12, ground - 52), (12, ground - 48), (18, ground - 54), (18, ground - 57)], WOOD_LIGHT,
           outline=INK, width=0.5)
    s.line((28, ground - 55), (28, ground - 46), IRON, 0.9)
    # The cage, and what is left in it.
    s.blob([(22, ground - 46), (34, ground - 46), (33, ground - 28), (23, ground - 28)], _shade(IRON, 0.2),
           outline=INK, width=0.8)
    for bx in (24.5, 28, 31.5):
        s.line((bx, ground - 45), (bx, ground - 29), IRON_LIGHT, 0.8)
    for by in (ground - 42, ground - 36, ground - 31):
        s.line((23, by), (33.2, by), IRON_LIGHT, 0.7)
    s.ellipse(25.5, ground - 43, 7, 6.5, BONE_SHADE, outline=INK, width=0.6)
    s.ellipse(27.5, ground - 41, 2, 2.2, HOLLOW)
    s.blob([(25, ground - 37), (32, ground - 37), (31, ground - 30), (26, ground - 30)], 0x3A3230)
    for ry in (ground - 35, ground - 32):
        s.curve([(25.5, ry), (31, ry + 0.8)], BONE_DARK, 0.7)
    return s


def warBanner():
    s = standing("warBanner", 30, 58, "A banner nobody came back for.")
    ground = 56
    s.ellipse(9, ground - 4, 12, 5, STONE_DARK)
    s.taper([(14, ground - 1), (14, ground - 28), (13, ground - 52)], WOOD, 2.6, 2.0, outline=INK, width=0.7)
    s.poly([(13, ground - 52), (11, ground - 57), (16, ground - 56)], IRON, outline=INK, width=0.5)
    # Cloth, torn along the bottom.
    s.blob([(14, ground - 50), (26, ground - 48), (25, ground - 26), (14, ground - 28)], CLOTH_RED,
           outline=INK, width=0.8)
    s.blob([(14, ground - 48), (18, ground - 47), (17.5, ground - 28), (14, ground - 29)],
           _shade(CLOTH_RED, 0.3))
    s.curve([(20, ground - 47), (21, ground - 38), (20.5, ground - 28)], _light(CLOTH_RED, 0.22), 1.1)
    for tx in (15.5, 19, 22.5):
        s.taper([(tx, ground - 28), (tx + 0.8, ground - 21)], CLOTH_RED, 2.6, 0.4)
    s.poly([(18, ground - 42), (22, ground - 38), (18, ground - 34), (14.8, ground - 38)], GOLD,
           outline=INK, width=0.5)
    return s


# ---------------------------------------------------------------------------
# The Burning Depths
# ---------------------------------------------------------------------------

def lavaVent():
    s = decal("lavaVent", 42, 30, "A split in the rock with the Depths showing through.")
    s.blob([(4, 15), (13, 6), (28, 5), (38, 12), (35, 23), (18, 25)], OBSIDIAN, outline=INK, width=0.9)
    s.glow(21, 15, 18, LAVA, 0.75)
    s.blob([(10, 15), (17, 10), (28, 10), (33, 15), (26, 20), (15, 20)], LAVA)
    s.blob([(15, 15), (20, 12), (27, 13), (28, 16), (22, 18), (17, 17)], LAVA_HOT)
    # Cracks running off from the mouth.
    for a, b, c in (((10, 15), (5, 11), (2, 12)), ((33, 15), (38, 18), (41, 17)),
                    ((22, 20), (24, 25), (22, 28)), ((18, 10), (16, 5), (18, 2))):
        s.curve([a, b, c], LAVA, 1.3)
        s.curve([a, b], LAVA_HOT, 0.6)
    return s


def obsidianShard():
    s = standing("obsidianShard", 32, 46, "A blade of cooled glass, still warm to stand near.")
    ground = 44
    s.ellipse(6, ground - 4, 20, 7, _shade(OBSIDIAN, 0.3))
    s.poly([(10, ground - 1), (14, ground - 26), (19, ground - 40), (21, ground - 22), (23, ground - 1)],
           OBSIDIAN, outline=INK, width=0.9)
    s.poly([(14, ground - 26), (19, ground - 40), (20, ground - 22), (16, ground - 4)],
           _light(OBSIDIAN, 0.22))
    s.line((17, ground - 34), (18, ground - 10), _light(OBSIDIAN, 0.5), 0.8)
    s.glow(17, ground - 6, 11, LAVA, 0.4)
    s.curve([(12, ground - 8), (16, ground - 11), (21, ground - 7)], LAVA, 1.1)
    s.poly([(5, ground - 1), (8, ground - 15), (11, ground - 1)], OBSIDIAN, outline=INK, width=0.7)
    return s


# ---------------------------------------------------------------------------
# The Shattered Realm
# ---------------------------------------------------------------------------

def voidRift():
    s = decal("voidRift", 44, 34, "A tear in the ground with nothing behind it.")
    s.glow(22, 17, 22, VOID, 0.55)
    s.blob([(6, 17), (14, 8), (26, 6), (38, 14), (33, 26), (18, 28)], _shade(VOID, 0.6),
           outline=INK, width=0.9)
    s.blob([(11, 17), (18, 11), (28, 11), (33, 17), (26, 23), (16, 23)], 0x0A0710)
    s.taper([(13, 17), (22, 14), (32, 18)], VOID_HOT, 3.4, 0.6)
    s.taper([(17, 22), (25, 21)], VOID_HOT, 1.8, 0.3)
    for ax, ay, bx, by in ((11, 17, 3, 14), (33, 17, 41, 21), (22, 11, 20, 3), (24, 24, 27, 32)):
        s.curve([(ax, ay), ((ax + bx) / 2, (ay + by) / 2), (bx, by)], VOID, 1.2)
    s.dot(22, 17, 1.6, 0xFFFFFF)
    return s


def floatingStone():
    s = standing("floatingStone", 36, 44, "A slab that forgot to fall, turning where it stopped.", foot=42)
    s.glow(18, 26, 14, VOID, 0.3)
    # The larger slab, hanging.
    s.poly([(8, 20), (20, 14), (30, 19), (26, 27), (13, 28)], STONE, outline=INK, width=1.0)
    s.poly([(8, 20), (20, 14), (26, 18), (13, 23)], STONE_LIGHT)
    s.poly([(13, 23), (26, 18), (26, 27), (13, 28)], STONE_DARK)
    for cx in (16, 21):
        s.line((cx, 23), (cx + 1, 27), _shade(STONE, 0.5), 0.6)
    # Smaller pieces orbiting it.
    s.poly([(4, 33), (10, 30), (12, 35), (6, 37)], STONE, outline=INK, width=0.7)
    s.poly([(27, 33), (33, 31), (33, 36), (28, 37)], STONE, outline=INK, width=0.7)
    s.poly([(17, 8), (23, 6), (24, 11), (18, 12)], STONE, outline=INK, width=0.7)
    # Dust falling from the underside and stopping.
    for dx, dy in ((15, 31), (20, 33), (24, 30), (18, 36)):
        s.dot(dx, dy, 0.8, VOID_HOT)
    return s


# ---------------------------------------------------------------------------
# The Fallen Citadel
# ---------------------------------------------------------------------------

def brokenStatue():
    s = standing("brokenStatue", 34, 58, "A knight with the head struck off, still at attention.")
    ground = 56
    s.poly([(5, ground - 1), (29, ground - 1), (27, ground - 9), (7, ground - 9)], STONE_DARK,
           outline=INK, width=0.9)
    s.poly([(7, ground - 9), (27, ground - 9), (26, ground - 12), (8, ground - 12)], STONE,
           outline=INK, width=0.7)
    # Legs and a long surcoat.
    s.blob([(11, ground - 12), (23, ground - 12), (22, ground - 30), (12, ground - 30)], STONE,
           outline=INK, width=0.9)
    s.blob([(11.5, ground - 13), (15, ground - 13), (15, ground - 29), (12, ground - 29)], STONE_DARK)
    s.line((17, ground - 29), (17, ground - 13), STONE_DARK, 0.8)
    # Chest and shoulders.
    s.blob([(9, ground - 30), (25, ground - 30), (24, ground - 44), (10, ground - 44)], STONE,
           outline=INK, width=1.0)
    s.poly([(10, ground - 44), (24, ground - 44), (22, ground - 47), (12, ground - 47)], STONE_LIGHT,
           outline=INK, width=0.7)
    s.curve([(12, ground - 38), (17, ground - 36), (22, ground - 38)], STONE_DARK, 1.0)
    # Neck stump, chipped.
    s.poly([(14, ground - 47), (20, ground - 47), (19, ground - 50), (17, ground - 48), (15, ground - 50)],
           STONE_LIGHT, outline=INK, width=0.6)
    # A sword point-down in its hands.
    s.taper([(17, ground - 36), (17, ground - 14)], STONE_LIGHT, 3.0, 1.6, outline=INK, width=0.6)
    s.line((10, ground - 36), (24, ground - 36), STONE_LIGHT, 1.6)
    # Rubble at the foot.
    s.poly([(2, ground - 1), (6, ground - 5), (9, ground - 1)], STONE, outline=INK, width=0.6)
    s.poly([(27, ground - 1), (31, ground - 4), (33, ground - 1)], STONE, outline=INK, width=0.6)
    return s


def barricade():
    s = standing("barricade", 44, 34, "Stakes and a cart's ribs, dragged across the street.")
    ground = 32
    s.ellipse(4, ground - 3, 36, 6, STONE_DARK)
    for x, lean, tall in ((8, 4, 20), (16, -3, 26), (26, 3, 23), (35, -4, 18)):
        s.taper([(x, ground - 1), (x + lean * 0.5, ground - tall * 0.6), (x + lean, ground - tall)],
                WOOD, 3.4, 1.6, outline=INK, width=0.7)
        s.poly([(x + lean - 1.6, ground - tall), (x + lean + 1.6, ground - tall + 1),
                (x + lean + 0.4, ground - tall - 3)], WOOD_LIGHT, outline=INK, width=0.5)
    for y, a, b in ((ground - 11, 6, 40), (ground - 19, 9, 36)):
        s.taper([(a, y + 1.5), (22, y - 1), (b, y + 1)], WOOD_LIGHT, 3.0, 2.4, outline=INK, width=0.6)
        for nx in (12, 20, 30):
            s.dot(nx, y - 0.2, 0.6, IRON_LIGHT)
    s.poly([(30, ground - 8), (40, ground - 12), (41, ground - 4), (31, ground - 1)], RUST,
           outline=INK, width=0.7)
    s.ellipse(33, ground - 9, 9, 9, _shade(WOOD, 0.2), outline=INK, width=0.8)
    for spoke in ((37.5, ground - 8.5),):
        s.line((33.5, ground - 4.5), (41.5, ground - 4.5), WOOD_DARK, 0.7)
        s.line(spoke, (37.5, ground - 0.5), WOOD_DARK, 0.7)
    return s


# ---------------------------------------------------------------------------
# The Gate of Ruin and the Abyss
# ---------------------------------------------------------------------------

def skullPile():
    s = standing("skullPile", 40, 28, "A heap of skulls, stacked on purpose.")
    ground = 26
    s.ellipse(3, ground - 4, 34, 7, _shade(BONE_DARK, 0.5))
    for x, y, r, turn in ((9, ground - 5, 5.5, -1), (19, ground - 4, 6, 0.4), (29, ground - 5, 5, 1),
                          (14, ground - 12, 5.2, 0.6), (24, ground - 12, 4.8, -0.5),
                          (19, ground - 19, 5, 0.2)):
        s.blob([(x - r, y - r * 0.2), (x - r * 0.7, y - r), (x, y - r * 1.25), (x + r * 0.7, y - r),
                (x + r, y - r * 0.2), (x + r * 0.55, y + r * 0.5), (x - r * 0.55, y + r * 0.5)],
               BONE if (r > 5) else BONE_SHADE, outline=INK, width=0.7)
        s.ellipse(x - r * 0.75 + turn, y - r * 0.55, r * 0.55, r * 0.5, HOLLOW)
        s.ellipse(x + r * 0.2 + turn, y - r * 0.55, r * 0.55, r * 0.5, HOLLOW)
        s.poly([(x + turn, y - r * 0.05), (x + r * 0.28 + turn, y + r * 0.25), (x - r * 0.2 + turn, y + r * 0.25)],
               HOLLOW)
        s.poly([(x - r * 0.55, y + r * 0.4), (x + r * 0.55, y + r * 0.4), (x + r * 0.4, y + r * 0.85),
                (x - r * 0.4, y + r * 0.85)], BONE_SHADE, outline=INK, width=0.5)
        for tx in (-0.3, 0.05, 0.4):
            s.line((x + r * tx, y + r * 0.45), (x + r * tx, y + r * 0.78), HOLLOW, 0.35)
    return s


def blackObelisk():
    s = standing("blackObelisk", 32, 66, "A stone with writing on it that will not stay still.")
    ground = 64
    s.ellipse(5, ground - 5, 22, 8, _shade(OBSIDIAN, 0.2))
    s.glow(16, ground - 30, 20, VOID, 0.3)
    s.poly([(10, ground - 1), (12, ground - 52), (16, ground - 60), (20, ground - 52), (22, ground - 1)],
           OBSIDIAN, outline=INK, width=1.0)
    s.poly([(16, ground - 60), (20, ground - 52), (22, ground - 1), (16.5, ground - 1)],
           _light(OBSIDIAN, 0.18))
    s.poly([(10, ground - 1), (12, ground - 52), (16, ground - 60), (15.5, ground - 1)],
           _shade(OBSIDIAN, 0.45))
    # Glyphs cut down the face.
    for index, y in enumerate(range(int(ground - 48), int(ground - 6), 7)):
        width = 3.5 - (index % 3) * 0.8
        s.line((16 - width / 2, y), (16 + width / 2, y), VOID_HOT, 0.9)
        if index % 2 == 0:
            s.line((16, y - 2), (16, y + 2), VOID_HOT, 0.7)
        else:
            s.dot(16 + width / 2 + 1, y, 0.5, VOID_HOT)
    s.poly([(4, ground - 1), (7, ground - 9), (10, ground - 1)], OBSIDIAN, outline=INK, width=0.6)
    s.poly([(22, ground - 1), (25, ground - 7), (27, ground - 1)], OBSIDIAN, outline=INK, width=0.6)
    return s


def all_sprites():
    return [
        reeds(), standingWater(), bogStump(),
        pineTree(), forestStump(), mushrooms(),
        iceSpire(), frozenCorpse(),
        gibbet(), warBanner(),
        lavaVent(), obsidianShard(),
        voidRift(), floatingStone(),
        brokenStatue(), barricade(),
        skullPile(), blackObelisk(),
    ]


HEADER = '''import UIKit

// Generated by tools/art/props.py. Edit the Python and rerun it; do not edit
// this file by hand.

/// Set dressing that belongs to one realm and nowhere else: the props that
/// tell you where you are before anything attacks you.
///
/// Standing props stand on their base; decals lie flat and are anchored at
/// their centre. The drawing primitives these call live in
/// PlaceholderArt+Drawing.swift.
extension PlaceholderArt {
'''


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    sprites = all_sprites()
    preview_sheet(sprites, os.path.join(here, "props-preview.png"), columns=6)
    if "--preview" in sys.argv:
        return
    root = os.path.dirname(os.path.dirname(here))
    out = os.path.join(root, "FateLost", "Rendering", "PlaceholderArt+Props.swift")
    body = "\n\n".join("    // MARK: - " + s.name + "\n\n" + s.swift_source() for s in sprites)
    with open(out, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(HEADER + "\n" + body + "\n}\n")
    print(f"wrote {len(sprites)} sprites")


if __name__ == "__main__":
    main()
