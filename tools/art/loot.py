"""FateLost's spoils: what an enemy leaves behind that is not experience.

Run from the repo root:

    python tools/art/loot.py            # writes the Swift and a preview
    python tools/art/loot.py --preview  # preview sheet only

The Swift lands in FateLost/Rendering/PlaceholderArt+Loot.swift; the preview
in tools/art/loot-preview.png (gitignored).

Everything here stands on the ground, so each is anchored at its base. The
three chests differ in silhouette and not only in colour: a cache is a small
strongbox you would walk past, a chest is banded iron, and a hoard is the
kind of thing that has its own light.
"""
import os
import sys

from artkit import Sprite, preview_sheet

INK = 0x0E0C08

WOOD = 0x5A3E26
WOOD_LIGHT = 0x7E5C36
WOOD_DARK = 0x33220F
IRON = 0x5E5A54
IRON_LIGHT = 0x9A968C
IRON_DARK = 0x3A3833
RUST = 0x7A5A40
GOLD = 0xC9A24A
GOLD_LIGHT = 0xF0D58A
GOLD_DARK = 0x8A6A26
RED = 0xB8323A
RED_DEEP = 0x6E1E24
GLASS = 0xD8E8F0
GEM = 0x6AD0F0
GEM_HOT = 0xE4FAFF
MAGNET_RED = 0xC23A34
MAGNET_BLUE = 0x3A5AC2
STEEL = 0xC4CAD2


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


def standing(name, width, height, doc):
    return Sprite(name, width, height, foot=height - 2, doc=doc)


def dropVial():
    s = standing("dropVial", 18, 24, "A red draught in a stoppered flask. It is what it looks like.")
    ground = 22
    s.ellipse(3, ground - 3, 12, 4.5, _shade(WOOD_DARK, 0.3))
    s.glow(9, ground - 9, 9, RED, 0.35)
    # Neck and cork.
    s.poly([(7, ground - 17), (11, ground - 17), (11, ground - 12), (7, ground - 12)], GLASS, outline=INK, width=0.7)
    s.poly([(6.4, ground - 20.4), (11.6, ground - 20.4), (11.2, ground - 17), (6.8, ground - 17)], WOOD_LIGHT,
           outline=INK, width=0.7)
    s.line((7.6, ground - 19.2), (10.4, ground - 19.2), WOOD_DARK, 0.5)
    # Body: a round flask, liquid to the shoulder.
    s.blob([(9, ground - 13), (14, ground - 9), (15, ground - 5.5), (12.6, ground - 2), (5.4, ground - 2),
            (3, ground - 5.5), (4, ground - 9)], GLASS, outline=INK, width=0.9)
    s.blob([(9, ground - 10.4), (13.2, ground - 8), (14, ground - 5.4), (12, ground - 2.6), (6, ground - 2.6),
            (4.2, ground - 5.4), (4.8, ground - 8)], RED)
    s.blob([(5, ground - 5.4), (13, ground - 5.4), (12, ground - 2.8), (6, ground - 2.8)], RED_DEEP)
    s.ellipse(5.6, ground - 9, 2.6, 3.4, _light(GLASS, 0.6))
    s.dot(11.6, ground - 7, 0.7, _light(RED, 0.6))
    return s


def dropMagnet():
    s = standing("dropMagnet", 22, 22, "A horseshoe of lodestone. Everything loose wants to be near it.")
    ground = 20
    s.ellipse(3, ground - 3.4, 16, 5, _shade(WOOD_DARK, 0.3))
    s.glow(11, ground - 9, 11, GOLD, 0.3)
    # The horseshoe, two arms and a bend.
    s.poly([(3, ground - 1), (8, ground - 1), (8.4, ground - 9), (10, ground - 12.4), (12, ground - 12.4),
            (13.6, ground - 9), (14, ground - 1), (19, ground - 1), (19, ground - 10), (15.4, ground - 16.6),
            (11, ground - 18.4), (6.6, ground - 16.6), (3, ground - 10)], STEEL, outline=INK, width=0.9)
    s.poly([(11, ground - 18.4), (15.4, ground - 16.6), (19, ground - 10), (19, ground - 1), (14, ground - 1),
            (13.6, ground - 9), (12, ground - 12.4), (11, ground - 12.4)], _shade(STEEL, 0.25))
    # Painted poles.
    s.poly([(3, ground - 1), (8, ground - 1), (8.1, ground - 5.6), (3, ground - 5.6)], MAGNET_RED, outline=INK,
           width=0.7)
    s.poly([(14, ground - 1), (19, ground - 1), (19, ground - 5.6), (13.9, ground - 5.6)], MAGNET_BLUE,
           outline=INK, width=0.7)
    s.curve([(5, ground - 10), (7.6, ground - 15.4), (11, ground - 17)], _light(STEEL, 0.5), 0.8)
    for x, y in ((11, ground - 22), (6, ground - 20), (16, ground - 20)):
        s.dot(x, max(1, y), 0.7, GOLD_LIGHT)
    return s


def _strap(s, x, top, bottom, color=IRON, width=2.4):
    s.poly([(x, top), (x + width, top), (x + width, bottom), (x, bottom)], color, outline=INK, width=0.6)


def dropChestCache():
    s = standing("dropChestCache", 30, 24, "A strongbox with a hasp. Somebody meant to come back for it.")
    ground = 22
    s.ellipse(2, ground - 4, 26, 6, _shade(WOOD_DARK, 0.3))
    # Body and lid.
    s.poly([(4, ground - 1), (26, ground - 1), (26, ground - 11), (4, ground - 11)], WOOD, outline=INK, width=0.9)
    s.poly([(4, ground - 11), (26, ground - 11), (24.5, ground - 17.5), (5.5, ground - 17.5)], WOOD_LIGHT,
           outline=INK, width=0.9)
    for y in (ground - 4.5, ground - 8):
        s.line((4.6, y), (25.4, y), WOOD_DARK, 0.5)
    s.line((6.6, ground - 15), (23.4, ground - 15), WOOD_DARK, 0.5)
    for x in (7, 20.6):
        _strap(s, x, ground - 17.4, ground - 1.4)
    # Hasp and a splash of rust.
    s.poly([(13, ground - 13), (17, ground - 13), (17, ground - 8), (13, ground - 8)], IRON_LIGHT, outline=INK,
           width=0.7)
    s.dot(15, ground - 10.4, 0.9, INK)
    s.poly([(4, ground - 1), (9, ground - 1), (4, ground - 5)], RUST)
    return s


def dropChestChest():
    s = standing("dropChestChest", 34, 28, "A banded iron chest. It was locked, and then someone made an argument.")
    ground = 26
    s.ellipse(2, ground - 4.4, 30, 6.4, _shade(WOOD_DARK, 0.3))
    s.glow(17, ground - 12, 16, GEM, 0.18)
    # Body.
    s.poly([(4, ground - 1), (30, ground - 1), (30, ground - 12), (4, ground - 12)], _shade(WOOD, 0.1), outline=INK,
           width=1.0)
    # Domed lid.
    s.blob([(4, ground - 12), (5.4, ground - 18.6), (11, ground - 22.6), (17, ground - 23.6), (23, ground - 22.6),
            (28.6, ground - 18.6), (30, ground - 12)], WOOD_LIGHT, outline=INK, width=1.0)
    s.curve([(7, ground - 19), (17, ground - 22), (27, ground - 19)], _light(WOOD_LIGHT, 0.3), 0.7)
    for x in (5.6, 15.2, 25.2):
        _strap(s, x, ground - 21, ground - 1.4, color=IRON, width=3.4)
        s.line((x + 0.6, ground - 20), (x + 0.6, ground - 2), IRON_LIGHT, 0.5)
        for y in (ground - 17, ground - 9, ground - 4):
            s.dot(x + 1.7, y, 0.6, IRON_LIGHT)
    # The lock.
    s.poly([(14.4, ground - 15), (19.6, ground - 15), (19.6, ground - 8), (14.4, ground - 8)], GOLD, outline=INK,
           width=0.8)
    s.ellipse(16, ground - 12.6, 2, 2, INK)
    s.poly([(16.4, ground - 11.2), (17.6, ground - 11.2), (17.8, ground - 9), (16.2, ground - 9)], INK)
    s.curve([(14.8, ground - 15), (14.8, ground - 17.6), (19.2, ground - 17.6), (19.2, ground - 15)], IRON_LIGHT,
            0.9)
    return s


def dropChestHoard():
    s = standing("dropChestHoard", 38, 40, "Gold heaped past the lid. It gives off a light of its own.")
    ground = 38
    s.ellipse(1, ground - 4.6, 36, 7, _shade(WOOD_DARK, 0.3))
    s.glow(19, ground - 17, 18, GOLD, 0.5)
    s.glow(19, ground - 20, 11, GOLD_LIGHT, 0.35)
    # Body, gilded.
    s.poly([(4, ground - 1), (34, ground - 1), (34, ground - 13), (4, ground - 13)], _shade(WOOD, 0.05),
           outline=INK, width=1.0)
    for x in (5, 16.4, 28.6):
        s.poly([(x, ground - 13), (x + 3.4, ground - 13), (x + 3.4, ground - 1.4), (x, ground - 1.4)], GOLD,
               outline=INK, width=0.7)
        s.line((x + 0.8, ground - 12.4), (x + 0.8, ground - 2), GOLD_LIGHT, 0.5)
    s.line((4.6, ground - 13), (33.4, ground - 13), GOLD_DARK, 1.0)
    # The lid, thrown back, and the pile it holds up.
    s.poly([(3.4, ground - 13), (34.6, ground - 13), (32, ground - 19), (6, ground - 19)], _shade(WOOD, 0.2),
           outline=INK, width=0.9)
    s.blob([(6, ground - 18.6), (11, ground - 24), (19, ground - 27), (27, ground - 24), (32, ground - 18.6)],
           GOLD, outline=INK, width=0.9)
    s.blob([(10, ground - 19), (14, ground - 23), (19, ground - 25), (24, ground - 23), (28, ground - 19)],
           GOLD_LIGHT)
    for x, y in ((12, ground - 21), (17, ground - 23.4), (23, ground - 22.4), (27, ground - 20.4)):
        s.dot(x, y, 0.8, GOLD_DARK)
    # Coins that fell out and stayed where they landed.
    for x, y, r in ((9, ground - 2.6, 2.6), (30, ground - 2.2, 2.8), (2.6, ground - 1.6, 2.2)):
        s.ellipse(x - r, y - r * 0.6, r * 2, r * 1.3, GOLD, outline=INK, width=0.5)
        s.line((x - r * 0.5, y - r * 0.15), (x + r * 0.4, y - r * 0.15), GOLD_LIGHT, 0.5)
    # A gem on top, catching the light.
    s.poly([(19, ground - 34), (22.6, ground - 29.4), (19, ground - 25.4), (15.4, ground - 29.4)], GEM,
           outline=INK, width=0.7)
    s.poly([(19, ground - 34), (22.6, ground - 29.4), (19, ground - 29.4)], _light(GEM, 0.45))
    s.dot(17.6, ground - 30.4, 0.9, GEM_HOT)
    return s


def all_sprites():
    return [dropVial(), dropMagnet(), dropChestCache(), dropChestChest(), dropChestHoard()]


HEADER = '''import UIKit

// Generated by tools/art/loot.py. Edit the Python and rerun it; do not edit
// this file by hand.

/// What the horde leaves behind: draughts, a lodestone, and three grades of
/// chest. They stand on the ground and are anchored at their base. The
/// drawing primitives these call live in PlaceholderArt+Drawing.swift.
extension PlaceholderArt {
'''


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    sprites = all_sprites()
    preview_sheet(sprites, os.path.join(here, "loot-preview.png"), columns=5)
    if "--preview" in sys.argv:
        return
    root = os.path.dirname(os.path.dirname(here))
    out = os.path.join(root, "FateLost", "Rendering", "PlaceholderArt+Loot.swift")
    body = "\n\n".join("    // MARK: - " + s.name + "\n\n" + s.swift_source() for s in sprites)
    with open(out, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(HEADER + "\n" + body + "\n}\n")
    print(f"wrote {len(sprites)} sprites")


if __name__ == "__main__":
    main()
