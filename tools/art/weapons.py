"""FateLost's armoury: the weapons a run can be started with.

Run from the repo root:

    python tools/art/weapons.py            # writes the Swift and a preview
    python tools/art/weapons.py --preview  # preview sheet only

The Swift lands in FateLost/Rendering/PlaceholderArt+Weapons.swift; the
preview in tools/art/weapons-preview.png (gitignored).

Weapons are drawn pointing up, tip at the top, with the grip near the
bottom: the anchor is the hand. A thrown weapon and the bolts the wands
throw are anchored at their middle instead, because they spin about it.
"""
import os
import sys

from artkit import Sprite, preview_sheet

INK = 0x0E0C08

STEEL = 0xC4CAD2
STEEL_LIGHT = 0xE6EAEE
STEEL_DARK = 0x767C86
IRON = 0x5E5A54
IRON_DARK = 0x3A3833
RUST = 0x7A5A40
GOLD = 0xC9A24A
BRASS = 0x9A7A3A

WOOD = 0x5A3E26
WOOD_LIGHT = 0x7E5C36
WOOD_DARK = 0x33220F
WRAP = 0x3A2A2A
WRAP_LIGHT = 0x5E4040
CORD = 0xB8A88C

FIRE = 0xE2601A
FIRE_HOT = 0xFFC24A
ICE = 0x8CD0E8
ICE_DEEP = 0x3E7E9E
STORM = 0xC9A6FF
STORM_HOT = 0xF2E4FF


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


def held(name, width, height, doc, grip=0.2):
    """A weapon held in the hand, anchored on the grip."""
    return Sprite(name, width, height, anchor=(0.5, grip), doc=doc)


def spun(name, width, height, doc):
    """Something that turns about its own middle."""
    return Sprite(name, width, height, anchor=(0.5, 0.5), doc=doc)


def _wrapped_grip(s, x, top, bottom, width=3.0, color=WRAP):
    """The bound grip every melee weapon here shares."""
    s.taper([(x, top), (x, bottom)], color, width, width, outline=INK, width=0.6)
    y = top + 1.4
    while y < bottom - 0.6:
        s.line((x - width / 2 + 0.2, y), (x + width / 2 - 0.2, y + 0.9), _light(color, 0.25), 0.5)
        y += 2.2


# ---------------------------------------------------------------------------
# Blades
# ---------------------------------------------------------------------------

def sai():
    s = held("sai", 16, 36, "A sai: one prong to stab with, two to take a blade out of a hand.")
    s.taper([(8, 30), (8, 15), (8, 2)], STEEL, 2.6, 1.0, outline=INK, width=0.6)
    s.line((8, 5), (8, 26), STEEL_LIGHT, 0.5)
    # The two side prongs curl up and out of the guard.
    for side in (-1, 1):
        s.curve([(8 + side * 1.6, 25), (8 + side * 5.2, 20), (8 + side * 4.4, 12)], STEEL_DARK, 1.6)
        s.taper([(8 + side * 4.6, 14), (8 + side * 4.2, 10.5)], STEEL, 1.6, 0.4, outline=INK, width=0.5)
    s.ellipse(5.2, 24.4, 5.6, 3.2, IRON, outline=INK, width=0.6)
    _wrapped_grip(s, 8, 26, 33.5, width=3.2)
    s.ellipse(6.2, 33, 3.6, 2.6, BRASS, outline=INK, width=0.6)
    return s


def claymore():
    s = held("claymore", 22, 66, "A claymore: a two-handed greatsword with a blade as long as a child is tall.", grip=0.16)
    # Blade: broad and straight, tapering only near the point.
    blade = [(7.6, 43), (7.7, 12), (8.4, 7.4), (11, 1.6), (13.6, 7.4), (14.3, 12), (14.4, 43)]
    s.poly(blade, STEEL, outline=INK, width=0.8)
    s.poly([(11, 43), (11, 8), (11, 2.6), (14.3, 12), (14.4, 43)], _shade(STEEL, 0.14))
    # A long fuller down the middle, and the two edge bevels catching light.
    s.line((11, 41), (11, 10), _shade(STEEL, 0.34), 1.4)
    s.line((9.9, 41), (9.9, 10), STEEL_LIGHT, 0.5)
    s.line((12.1, 41), (12.1, 10), STEEL_DARK, 0.5)
    s.line((8.5, 42), (8.5, 12), STEEL_LIGHT, 0.5)
    # Old runes worn into the ricasso.
    for y in (36.6, 33.8, 31):
        s.line((10, y), (12, y), _mix(GOLD, IRON_DARK, 0.45), 0.5)
    # Crossguard: wide, dark, with the quillons turned toward the point.
    s.taper([(2.2, 45.4), (11, 44.2), (19.8, 45.4)], IRON, 3.0, 3.0, outline=INK, width=0.7)
    s.poly([(1.2, 43.4), (3.4, 42.2), (3.8, 46.6), (1.6, 47.2)], IRON_DARK, outline=INK, width=0.6)
    s.poly([(20.8, 43.4), (18.6, 42.2), (18.2, 46.6), (20.4, 47.2)], IRON_DARK, outline=INK, width=0.6)
    s.line((3.6, 44.4), (18.4, 44.4), _light(IRON, 0.25), 0.5)
    s.ellipse(9.5, 43.6, 3, 3, BRASS, outline=INK, width=0.6)
    # A grip long enough for two hands, and a heavy pommel with a red stone.
    _wrapped_grip(s, 11, 47, 59, width=3.4)
    s.ellipse(7.8, 58.4, 6.4, 5.6, BRASS, outline=INK, width=0.7)
    s.ellipse(9.4, 60, 3.2, 2.6, 0xA2261E, outline=INK, width=0.4)
    s.dot(10.5, 60.5, 0.55, 0xF2A29A)
    return s


def katana():
    s = held("katana", 14, 48, "A katana, single-edged and barely curved.")
    # Blade: a long taper with the curve carried by the spine.
    s.taper([(6.4, 33), (7.4, 18), (9.4, 2.5)], STEEL, 4.0, 1.2, outline=INK, width=0.7)
    s.curve([(7.2, 31), (8.1, 17), (9.4, 4)], STEEL_LIGHT, 0.6)
    s.curve([(5.6, 31.5), (6.6, 17.5), (8.6, 4.5)], _shade(STEEL, 0.25), 0.5)
    # Tsuba: a small square guard turned on the diagonal.
    s.poly([(6.3, 30), (10.2, 33), (6.3, 36), (2.6, 33)], IRON, outline=INK, width=0.7)
    s.ellipse(5.1, 32.1, 2.4, 2, IRON_DARK)
    _wrapped_grip(s, 6, 34.5, 45.5, width=3.4)
    s.poly([(4.3, 45), (7.7, 45), (7.4, 47.2), (4.6, 47.2)], IRON, outline=INK, width=0.6)
    return s


def dualDaggers():
    s = Sprite("dualDaggers", 24, 34, anchor=(0.5, 0.3),
               doc="Two daggers, crossed: nothing here is meant to be parried.")
    for side, lean in ((0, 1), (1, -1)):
        x = 8 if side == 0 else 16
        tip = (x + lean * 5.5, 3)
        s.taper([(x, 24), (x + lean * 2.6, 14), tip], STEEL, 2.8, 0.7, outline=INK, width=0.6)
        s.curve([(x + lean * 0.4, 22), (x + lean * 3, 12), (x + lean * 5, 4.5)], STEEL_LIGHT, 0.5)
        s.taper([(x - 2.4, 24.6), (x + 2.4, 23.4)], IRON, 2.0, 2.0, outline=INK, width=0.6)
        _wrapped_grip(s, x - lean * 0.6, 25, 31, width=2.8)
        s.ellipse(x - lean * 0.6 - 1.5, 30.6, 3, 2.2, BRASS, outline=INK, width=0.5)
    return s


# ---------------------------------------------------------------------------
# Hafted things
# ---------------------------------------------------------------------------

def warHammer():
    s = held("warHammer", 24, 48, "A war hammer: one flat face, one beak, and no subtlety.")
    s.taper([(11.5, 44), (11.5, 26), (11.5, 12)], WOOD, 3.4, 2.8, outline=INK, width=0.7)
    s.curve([(10.6, 42), (10.6, 14)], WOOD_DARK, 0.5)
    # Head: a squat block with a beak on the far side.
    s.poly([(4.5, 9), (14.5, 7.5), (15.5, 17.5), (5.5, 19)], IRON, outline=INK, width=0.9)
    s.poly([(10, 8.2), (14.5, 7.5), (15.5, 17.5), (11, 18.3)], _light(IRON, 0.18))
    s.poly([(4.5, 9), (5.5, 19), (3.2, 18.2), (2.4, 9.8)], IRON_DARK, outline=INK, width=0.6)
    for ry in (11, 16):
        s.dot(6.5, ry, 0.7, RUST)
    s.poly([(15, 9.5), (22, 11.5), (15.6, 16)], IRON, outline=INK, width=0.8)
    s.poly([(15, 9.5), (22, 11.5), (18.5, 12.4)], _light(IRON, 0.25))
    s.taper([(11.5, 6.5), (11.5, 10)], IRON, 2.4, 2.4, outline=INK, width=0.6)
    _wrapped_grip(s, 11.5, 34, 45, width=3.6)
    return s


def boStaff():
    s = spun("boStaff", 10, 60, "A bo staff, iron-shod at both ends and worn smooth in the middle.")
    s.taper([(5, 57), (5, 30), (5, 3)], WOOD_LIGHT, 3.4, 3.4, outline=INK, width=0.7)
    s.curve([(4, 54), (4, 6)], WOOD_DARK, 0.5)
    for y in (3, 51):
        s.poly([(3.1, y), (6.9, y), (6.9, y + 6), (3.1, y + 6)], IRON, outline=INK, width=0.7)
        s.line((3.4, y + 2), (6.6, y + 2), _light(IRON, 0.3), 0.5)
    _wrapped_grip(s, 5, 24, 36, width=3.8, color=WRAP)
    for y in (20, 40):
        s.taper([(3.2, y), (6.8, y)], CORD, 1.6, 1.6, outline=INK, width=0.4)
    return s


def flail():
    s = held("flail", 20, 46, "A flail. Blocking it is not the same as being safe from it.")
    s.taper([(7, 43), (7, 34), (7, 24)], WOOD, 3.2, 2.6, outline=INK, width=0.7)
    _wrapped_grip(s, 7, 32, 44, width=3.4)
    s.poly([(5.4, 22.5), (8.6, 22.5), (8.6, 25.5), (5.4, 25.5)], IRON, outline=INK, width=0.6)
    # Chain, hanging out to the side under its own weight.
    for cx, cy in ((7.6, 20), (9, 16.8), (11, 14.2), (13.4, 12.4)):
        s.ellipse(cx - 1.5, cy - 1.9, 3, 3.8, IRON, outline=INK, width=0.6)
        s.ellipse(cx - 0.8, cy - 1.1, 1.6, 2.2, IRON_DARK)
    # The head.
    for angle in ((0, -6.4), (6.2, -1.6), (4.4, 4.8), (-4.4, 4.8), (-6.2, -1.6)):
        s.taper([(15, 9), (15 + angle[0], 9 + angle[1])], IRON, 2.6, 0.4, outline=INK, width=0.5)
    s.ellipse(10.6, 4.6, 8.8, 8.8, _shade(IRON, 0.1), outline=INK, width=0.9)
    s.ellipse(12, 6, 4.4, 4, _light(IRON, 0.22))
    s.dot(13.4, 7.2, 1.0, _light(IRON, 0.5))
    return s


def boomerang():
    s = spun("boomerang", 30, 30, "A boomerang, carved from one bent piece and burnt with marks.")
    elbow = (25, 15)
    tips = ((7.5, 3.5), (7.5, 26.5))
    s.ellipse(elbow[0] - 3.4, elbow[1] - 3.4, 6.8, 6.8, WOOD_LIGHT, outline=INK, width=0.9)
    for tip in tips:
        s.taper([elbow, ((elbow[0] + tip[0]) / 2, (elbow[1] + tip[1]) / 2), tip],
                WOOD_LIGHT, 6.4, 4.0, outline=INK, width=0.9)
    s.curve([(9, 5.4), (17, 10.4), (23.4, 14)], WOOD_DARK, 0.8)
    s.curve([(9, 24.6), (17, 19.6), (23.4, 16)], WOOD_DARK, 0.8)
    for px, py in ((11.5, 7), (17, 11), (17, 19), (11.5, 23)):
        s.line((px - 1.2, py - 0.8), (px + 1.2, py + 0.8), _shade(WOOD, 0.1), 0.6)
    s.poly([(5.4, 1.8), (10, 4.4), (6.4, 6.2)], _shade(WOOD, 0.2), outline=INK, width=0.5)
    s.poly([(5.4, 28.2), (10, 25.6), (6.4, 23.8)], _shade(WOOD, 0.2), outline=INK, width=0.5)
    return s


# ---------------------------------------------------------------------------
# Wands
# ---------------------------------------------------------------------------

def _wand(name, doc, rod, core, halo, facets):
    s = held(name, 16, 34, doc)
    s.taper([(8, 31), (8, 22), (8, 15)], rod, 2.8, 2.2, outline=INK, width=0.6)
    s.curve([(7.2, 30), (7.2, 16)], _shade(rod, 0.4), 0.5)
    s.taper([(6.6, 15.4), (9.4, 15.4)], BRASS, 2.4, 2.4, outline=INK, width=0.5)
    for cx, cy in ((6.4, 14), (9.6, 14)):
        s.taper([(cx, 14.6), (cx + (8 - cx) * 0.25, 8)], BRASS, 1.6, 0.8, outline=INK, width=0.4)
    s.glow(8, 8, 9, halo, 0.7)
    s.poly(facets, core, outline=INK, width=0.6)
    s.dot(7.2, 7, 1.0, _light(core, 0.55))
    _wrapped_grip(s, 8, 22, 32, width=3.0)
    return s


def emberWand():
    return _wand("emberWand", "A wand with a coal in it that has never gone out.",
                 rod=0x4A2A18, core=FIRE, halo=FIRE_HOT,
                 facets=[(8, 2.5), (12, 7), (9.6, 13), (6.4, 13), (4, 7)])


def rimeWand():
    return _wand("rimeWand", "A wand ending in a splinter of ice that will not melt.",
                 rod=0x2A3A46, core=ICE, halo=ICE_DEEP,
                 facets=[(8, 1.5), (11.4, 8.5), (8, 13.4), (4.6, 8.5)])


def stormWand():
    return _wand("stormWand", "A wand holding a charge that keeps trying to leave.",
                 rod=0x2E2838, core=STORM, halo=STORM_HOT,
                 facets=[(8.6, 2), (11.8, 6.8), (9, 8.4), (11, 13.4), (5, 8.6), (7.8, 7.2), (5.4, 4)])


# ---------------------------------------------------------------------------
# What they throw
# ---------------------------------------------------------------------------

def projectileBoomerang():
    s = spun("projectileBoomerang", 22, 22, "The boomerang, mid-flight.")
    s.glow(11, 11, 11, CORD, 0.25)
    elbow = (18, 11)
    s.ellipse(elbow[0] - 2.6, elbow[1] - 2.6, 5.2, 5.2, WOOD_LIGHT, outline=INK, width=0.8)
    for tip in ((5, 3.5), (5, 18.5)):
        s.taper([elbow, tip], WOOD_LIGHT, 5.0, 3.0, outline=INK, width=0.8)
    return s


def _bolt(name, doc, core, halo):
    s = spun(name, 18, 12, doc)
    s.glow(9, 6, 9, halo, 0.75)
    s.taper([(1.5, 6), (8, 6), (16.5, 6)], core, 1.6, 5.2, outline=INK, width=0.5)
    s.ellipse(9.5, 3.2, 5.6, 5.6, _light(core, 0.45))
    s.dot(11.5, 5.4, 1.2, 0xFFFFFF)
    return s


def emberBolt():
    return _bolt("projectileEmberBolt", "A gout of fire from the ember wand.", FIRE, FIRE_HOT)


def frostBolt():
    return _bolt("projectileFrostBolt", "A shard of ice from the rime wand.", ICE, ICE_DEEP)


def stormBolt():
    return _bolt("projectileStormBolt", "A charge thrown from the storm wand.", STORM, STORM_HOT)


def all_sprites():
    return [
        sai(), katana(), claymore(), dualDaggers(),
        warHammer(), boStaff(), flail(), boomerang(),
        emberWand(), rimeWand(), stormWand(),
        projectileBoomerang(), emberBolt(), frostBolt(), stormBolt(),
    ]


HEADER = '''import UIKit

// Generated by tools/art/weapons.py. Edit the Python and rerun it; do not
// edit this file by hand.

/// The weapons a run can be started with, and what they throw.
///
/// A held weapon is anchored on its grip and drawn pointing up; a thrown one
/// is anchored at its middle. The drawing primitives these call live in
/// PlaceholderArt+Drawing.swift.
extension PlaceholderArt {
'''


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    sprites = all_sprites()
    preview_sheet(sprites, os.path.join(here, "weapons-preview.png"), columns=5)
    if "--preview" in sys.argv:
        return
    root = os.path.dirname(os.path.dirname(here))
    out = os.path.join(root, "FateLost", "Rendering", "PlaceholderArt+Weapons.swift")
    body = "\n\n".join("    // MARK: - " + s.name + "\n\n" + s.swift_source() for s in sprites)
    with open(out, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(HEADER + "\n" + body + "\n}\n")
    print(f"wrote {len(sprites)} sprites")


if __name__ == "__main__":
    main()
