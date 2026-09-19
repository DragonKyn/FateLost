"""FateLost's summons and shapeshift forms.

Run from the repo root:

    python tools/art/creatures.py            # writes the Swift and a preview
    python tools/art/creatures.py --preview  # preview sheet only

The Swift lands in FateLost/Rendering/PlaceholderArt+Allies.swift; the preview
in tools/art/allies-preview.png (gitignored).
"""
import os
import sys

from artkit import Sprite, preview_sheet

INK = 0x0E0C08

# Grave-fire: the cold light that animates the dead.
SOUL = 0x8CF2D2
SOUL_HOT = 0xE6FFF6

BONE = 0xD8CDB0
BONE_SHADE = 0xA89C80
BONE_DARK = 0x6E6450
HOLLOW = 0x16110E

RUST = 0x7A5A40
IRON = 0x5E5A54
IRON_LIGHT = 0x8E8A80
STEEL = 0x9C9A92


# ---------------------------------------------------------------------------
# The risen dead
# ---------------------------------------------------------------------------

def bone(s, a, b, width=2.2, color=BONE, knob=True):
    """A limb bone with knobbed ends."""
    s.taper([a, ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2), b], color, width, width * 0.8, outline=INK, width=0.6)
    if knob:
        s.ellipse(b[0] - width * 0.75, b[1] - width * 0.75, width * 1.5, width * 1.5, color, outline=INK, width=0.5)


def skull(s, x, y, scale=1.0, jaw_open=0.0, helm=None):
    """A skull facing +x with its top-left near (x, y)."""
    s.push(x, y, scale)
    cranium = [(0, 5), (2.5, 0.8), (8, -0.4), (11.5, 2.5), (12.2, 6.5), (11, 9.2), (6, 9.6), (1, 8.5)]
    s.blob(cranium, BONE, outline=INK, width=0.9)
    # Shading on the back of the skull, and a crack.
    s.blob([(0.6, 5), (2.5, 1.8), (4.5, 3.5), (4, 8), (1.5, 8.2)], BONE_SHADE)
    s.curve([(5.5, 0.3), (6.2, 2.4), (5.2, 3.6), (6, 5)], BONE_DARK, 0.5)
    # Cheekbone and jaw.
    jaw = [(6.5, 8.6), (12.2, 8), (13, 10.5 + jaw_open), (9.5, 12.4 + jaw_open), (6.8, 11.4 + jaw_open * 0.6)]
    s.poly(jaw, BONE_SHADE, outline=INK, width=0.7)
    for tx in (8.6, 10, 11.4):
        s.line((tx, 8.8), (tx, 10.2), HOLLOW, 0.45)
    s.line((8, 9.8), (12.4, 9.4), HOLLOW, 0.5)
    # Sockets: deep hollows with grave-fire burning in them.
    s.ellipse(7.2, 3.6, 3.6, 3.4, HOLLOW)
    s.ellipse(3.4, 4.0, 2.2, 3.0, HOLLOW)
    s.glow(9.2, 5.3, 3.2, SOUL, 0.85)
    s.dot(9.2, 5.3, 0.75, SOUL_HOT)
    s.dot(4.5, 5.5, 0.5, SOUL)
    s.poly([(11.6, 6.4), (12.8, 7.6), (11.3, 7.9)], HOLLOW)
    if helm == "sallet":
        rim = [(-0.8, 5.8), (-0.2, 1.4), (3.5, -1.8), (9, -2.2), (12.6, 0.6), (13.4, 3.4), (8, 3.2), (3, 3.6)]
        s.poly(rim, IRON, outline=INK, width=0.8)
        s.line((1.5, 0.6), (8.5, -1.2), IRON_LIGHT, 0.6)
        for rx, ry in ((2.2, 2.6), (6.5, 2.2), (10.5, 2.4)):
            s.dot(rx, ry, 0.45, IRON_LIGHT)
        s.blob([(3.5, -1.2), (6, -2.2), (8, -1), (6, 0.2)], RUST)
    elif helm == "horned":
        dome = [(-0.6, 5.5), (0.5, 0.8), (6, -2.4), (11.5, 0), (12.8, 3.8), (6.5, 3.4), (1.2, 4.4)]
        s.poly(dome, IRON, outline=INK, width=0.8)
        s.taper([(2.2, 0.8), (-1.5, -3.5), (-0.5, -7.5)], BONE_SHADE, 2.4, 0.2, outline=INK, width=0.5)
        s.taper([(9, -1.4), (11.5, -5.5), (15, -7)], BONE, 2.4, 0.2, outline=INK, width=0.5)
        s.line((7, -2), (7, 3.2), IRON_LIGHT, 0.7)
    elif helm == "hood":
        hood = [(-1.6, 10), (-1.2, 2.5), (3, -1.8), (9, -2.4), (13.4, 1), (12, 3), (7, 1.4), (2, 3.4), (1.2, 10.5)]
        s.poly(hood, 0x2A2420, outline=INK, width=0.8)
        s.poly([(-1.6, 10), (-3.4, 14), (-0.4, 12.2), (1.2, 14.5), (1.2, 10.5)], 0x2A2420)
    s.pop()


def ribcage(s, x, y, scale=1.0, core=False):
    """Spine, ribs and sternum; `(x, y)` is the base of the neck."""
    s.push(x, y, scale)
    s.blob([(-4.5, 1.5), (0, 0), (5.5, 1.2), (6.5, 6), (4.5, 10.5), (0, 11.5), (-4.5, 9.5), (-5.5, 5)],
           (HOLLOW, 0.55))
    if core:
        s.glow(0.8, 6, 6.5, SOUL, 0.7)
        s.dot(0.8, 6, 1.4, SOUL_HOT)
    s.curve([(-0.5, -1), (-1, 4), (-0.6, 9), (0.2, 13)], BONE_SHADE, 1.9)
    for index, ry in enumerate((1.6, 3.8, 6.0, 8.2)):
        length = 1 - index * 0.08
        s.curve([(-0.8, ry), (-4.2 * length, ry + 0.2), (-4.8 * length, ry + 2)], BONE_SHADE, 1.05)
        s.curve([(-0.6, ry), (4.4 * length, ry - 0.3), (5.6 * length, ry + 1.6), (4.6 * length, ry + 2.6)], BONE, 1.2)
    s.line((3.2, 1.2), (3.6, 7.6), BONE, 1.1)
    for vy in (0.5, 3, 5.5, 8, 10.5, 12.5):
        s.dot(-0.6, vy, 0.55, BONE_DARK)
    # Collarbones.
    s.curve([(-5, 0.8), (0, -0.6), (5.5, 0.4)], BONE, 1.3)
    s.pop()


def pelvis(s, x, y, rags=0x3A2622):
    s.blob([(x - 5, y - 1.5), (x, y - 2.5), (x + 5, y - 1.5), (x + 5.5, y + 1.5), (x + 1, y + 3), (x - 1, y + 3),
            (x - 5.5, y + 1.5)], BONE_SHADE, outline=INK, width=0.7)
    if rags is not None:
        s.poly([(x - 6.5, y - 0.5), (x + 6.5, y - 0.5), (x + 7, y + 6), (x + 4.8, y + 4), (x + 3, y + 8.5),
                (x + 1, y + 4.5), (x - 1.5, y + 7.5), (x - 3.5, y + 4.2), (x - 6.5, y + 6.5)], rags, outline=INK, width=0.6)
        s.line((x - 6, y + 0.8), (x + 6.5, y + 0.8), 0x241814, 0.9)


def leg(s, hip, knee, ankle, far=False):
    color = BONE_SHADE if far else BONE
    bone(s, hip, knee, 2.3, color)
    bone(s, knee, ankle, 2.0, color, knob=False)
    s.poly([(ankle[0] - 1.6, ankle[1] - 0.6), (ankle[0] + 3.4, ankle[1] + 0.2), (ankle[0] + 3.6, ankle[1] + 1.6),
            (ankle[0] - 1.8, ankle[1] + 1.6)], color, outline=INK, width=0.6)


def skeleton_warrior():
    s = Sprite("skeleton", 40, 54, foot=51, doc="A risen swordsman behind a split round shield.")
    leg(s, (16, 34), (13.6, 42), (14.5, 50), far=True)
    # Back arm and the shield strapped to it.
    bone(s, (13.5, 18), (10.5, 24), 1.8, BONE_SHADE)
    s.ellipse(2.5, 21.5, 14, 15, 0x4A3424, outline=INK, width=0.9)
    s.ellipse(3.6, 22.6, 11.8, 12.8, None or 0x5A4030)
    for plank in (6.5, 9.5, 12.5):
        s.line((plank, 23.2), (plank, 35), 0x3A281C, 0.6)
    s.ellipse(2.5, 21.5, 14, 15, (0, 0.0), outline=IRON, width=1.4)
    s.poly([(12.5, 22.4), (10.2, 28.5), (12.4, 29.4), (10.8, 36)], HOLLOW)
    s.ellipse(7.3, 26.8, 4.2, 4.2, IRON, outline=INK, width=0.6)
    s.dot(8.6, 28.2, 0.7, IRON_LIGHT)
    pelvis(s, 19, 33)
    leg(s, (21.5, 34), (24, 42), (22.5, 50))
    ribcage(s, 19, 17)
    # A rusted pauldron on the sword shoulder.
    s.blob([(20, 15.5), (24.5, 14), (28, 16.5), (27, 20.5), (23, 19.5)], IRON, outline=INK, width=0.7)
    s.curve([(21.5, 16), (25, 15.3), (27, 17.4)], IRON_LIGHT, 0.6)
    s.blob([(25, 18), (27, 17.5), (26.6, 20)], RUST)
    # Sword arm, blade raised.
    bone(s, (25, 18.5), (28.5, 24.5), 1.9)
    bone(s, (28.5, 24.5), (31.5, 21), 1.7, knob=False)
    s.taper([(31.8, 20.5), (34.5, 11), (36.8, 2)], STEEL, 3.2, 0.4, outline=INK, width=0.6)
    s.line((32.6, 18.5), (35.6, 6.5), 0xC8C6BE, 0.5)
    for nx, ny in ((34.8, 13.8), (35.6, 9.4)):
        s.poly([(nx + 0.9, ny), (nx - 0.4, ny + 0.6), (nx + 1.2, ny + 1.4)], (0x2E2A26, 0.9))
    s.blob([(33.5, 15.5), (35, 15.8), (34.2, 17.8)], (RUST, 0.8))
    s.line((29.2, 20.2), (34.6, 21.8), IRON, 1.5)
    s.line((31.2, 21), (30.6, 23.4), 0x3A281C, 1.4)
    s.ellipse(30.2, 19.8, 2.6, 2.6, BONE, outline=INK, width=0.5)
    skull(s, 13.6, 4.4, scale=0.9)
    return s


def skeleton_archer():
    s = Sprite("skeletonArcher", 40, 54, foot=51, doc="A hooded bone archer with a quiver of black-fletched arrows.")
    # Quiver on the back.
    s.poly([(8, 13), (12, 12), (15.5, 30), (11.5, 31)], 0x3A281C, outline=INK, width=0.7)
    for fx in (8.5, 10, 11.5):
        s.taper([(fx + 1, 14), (fx - 0.5, 8.5)], 0x1A1614, 1.8, 0.3)
    leg(s, (16, 34), (14.5, 42), (13.5, 50), far=True)
    pelvis(s, 19, 33, rags=0x2A2420)
    leg(s, (21.5, 34), (25, 41.5), (24.5, 50))
    ribcage(s, 19, 17)
    # Tattered hood mantle over the shoulders.
    s.poly([(12, 15), (20, 13), (26, 15.5), (24, 20), (22, 18), (19.5, 21.5), (17.5, 18.5), (14.5, 21),
            (12.5, 18.5)], 0x2A2420, outline=INK, width=0.7)
    # Bow drawn and aimed forward; string pulled to the jaw.
    s.curve([(31, 7), (35.5, 13), (36.5, 20), (35.5, 27), (31, 33)], 0x4A3020, 1.8)
    s.curve([(31.2, 7.4), (35, 12.5), (36, 20), (35, 27.5), (31.2, 32.6)], 0x6A4A30, 0.7)
    s.line((31, 7.2), (22, 20), 0xC8C0A8, 0.5)
    s.line((22, 20), (31, 32.8), 0xC8C0A8, 0.5)
    s.line((22, 20), (39, 20), 0x3A3028, 0.9)
    s.poly([(39.5, 20), (37, 18.8), (37, 21.2)], STEEL, outline=INK, width=0.4)
    s.poly([(22, 20), (24.5, 18.6), (25.5, 20), (24.5, 21.4)], 0x1A1614)
    bone(s, (25, 18.5), (29.5, 20), 1.8)
    bone(s, (29.5, 20), (35.4, 20), 1.6, knob=False)
    bone(s, (14.5, 18), (18, 22.5), 1.7, BONE_SHADE)
    bone(s, (18, 22.5), (22.3, 20.2), 1.5, BONE_SHADE, knob=False)
    skull(s, 13.6, 4.4, scale=0.9, helm="hood")
    return s


def skeleton_brute():
    s = Sprite("skeletonBrute", 46, 56, foot=53, doc="A horned, hulking bone warrior with a notched war axe.")
    s.push(1, 0, 1.08)
    leg(s, (16, 34), (13, 42), (13.5, 49.5), far=True)
    bone(s, (13.5, 18), (9, 24), 2.2, BONE_SHADE)
    bone(s, (9, 24), (12, 29), 2.0, BONE_SHADE, knob=False)
    pelvis(s, 19, 33, rags=0x4A2A22)
    # A belt of iron and a trophy skull.
    s.line((13, 32.2), (25.5, 32.2), IRON, 1.6)
    s.blob([(13.5, 33.5), (16, 33), (16.8, 35.5), (14.5, 36.6), (12.8, 35.4)], BONE_SHADE, outline=INK, width=0.5)
    s.dot(15, 34.6, 0.6, HOLLOW)
    leg(s, (21.5, 34), (25, 41.5), (23.5, 49.5))
    ribcage(s, 19, 17, scale=1.1)
    # Heavy spiked pauldrons.
    s.blob([(10, 16), (14, 13.5), (18, 15), (17, 19.5), (11.5, 20)], IRON, outline=INK, width=0.7)
    s.blob([(20, 15.5), (25, 13.2), (29.5, 16), (28.5, 21), (23, 20.5)], IRON, outline=INK, width=0.7)
    for sx, sy, tx, ty in ((22.5, 14.5, 21.5, 10.5), (26, 14, 27, 9.8), (13, 14.5, 11.8, 11)):
        s.taper([(sx, sy), (tx, ty)], IRON_LIGHT, 1.8, 0.1, outline=INK, width=0.4)
    s.blob([(24, 18.5), (27, 18), (26.2, 20.5)], RUST)
    # War axe held high across the body.
    s.line((24.5, 38), (33.5, 6), 0x4A3020, 2.2)
    s.line((24.9, 37), (33.7, 6.5), 0x6A4A30, 0.6)
    head = [(31.5, 5.5), (36, 1.5), (41, 3), (41.5, 12), (38.5, 15.5), (35, 12.5), (31, 13)]
    s.poly(head, STEEL, outline=INK, width=0.8)
    s.poly([(36.5, 3), (40, 4), (40.4, 11.4), (38.4, 13.6)], 0xC0BEB6)
    s.poly([(40.6, 6), (39.2, 7), (40.8, 8.2)], (0x2E2A26, 0.9))
    s.blob([(33, 7), (35, 6.5), (35.6, 10), (33.4, 10.5)], (RUST, 0.85))
    bone(s, (26, 19), (29, 25), 2.1)
    bone(s, (29, 25), (30.5, 18), 1.9, knob=False)
    s.ellipse(29.4, 16.6, 3, 3, BONE, outline=INK, width=0.5)
    skull(s, 13, 3, scale=1.05, jaw_open=0.8, helm="horned")
    s.pop()
    return s


def bone_colossus():
    s = Sprite("boneColossus", 72, 86, foot=83, doc="Dozens of the dead fused into one lumbering giant, grave-fire at its heart.")
    s.push(0, 8)
    # Legs: thick, built of stacked bones.
    for hx, kx, ax, far in ((27, 22, 21, True), (41, 46, 45, False)):
        color = BONE_SHADE if far else BONE
        s.taper([(hx, 52), (kx, 62), (ax, 72)], color, 6.5, 5, outline=INK, width=0.9)
        s.ellipse(kx - 3.6, 58.5, 7.2, 7, color, outline=INK, width=0.8)
        s.poly([(ax - 4, 70.5), (ax + 7, 71), (ax + 7.5, 74.5), (ax - 4.5, 74.5)], color, outline=INK, width=0.8)
        for t in (65, 68):
            s.line((ax - 2.2, t), (ax + 2.6, t + 0.4), BONE_DARK, 0.6)
    # Far arm dragging a gravestone slab as a shield.
    s.taper([(22, 24), (12, 36), (11, 48)], BONE_SHADE, 5.5, 4.5, outline=INK, width=0.8)
    slab = [(2, 40), (4, 33), (13, 31.5), (18, 36), (17, 60), (3, 61)]
    s.poly(slab, 0x5C5850, outline=INK, width=1)
    s.poly([(4, 34.5), (12.5, 33.4), (15.5, 37), (5, 38)], 0x74706A)
    s.curve([(7, 44), (9.5, 47), (8, 51), (11, 55)], 0x2E2A26, 0.8)
    s.line((5, 42), (14, 42), (0x3A3632, 0.8), 0.9)
    # Pelvis and hanging chains.
    s.blob([(23, 48), (34, 45), (46, 48), (47, 54), (34, 56), (22, 54)], BONE_SHADE, outline=INK, width=0.9)
    s.curve([(24, 52), (27, 58), (31, 55)], IRON, 1.1)
    s.curve([(38, 54), (42, 60), (46, 55)], IRON, 1.1)
    # Torso: a great ribcage around a core of grave-fire.
    torso = [(19, 22), (31, 14), (47, 15), (54, 25), (51, 40), (42, 48), (27, 48), (20, 39)]
    s.blob(torso, HOLLOW, outline=INK, width=1.1)
    s.glow(36, 32, 16, SOUL, 0.75)
    s.dot(36, 32, 3.2, SOUL_HOT)
    s.curve([(30, 13), (29, 26), (30, 38), (33, 48)], BONE_SHADE, 3.6)
    for index, ry in enumerate((18, 23, 28, 33, 38)):
        w = 1 - index * 0.05
        s.curve([(30, ry), (41 * w + 4, ry - 1), (50 * w + 2, ry + 3), (47 * w + 2, ry + 7)], BONE, 2.2)
        s.curve([(29.5, ry), (24, ry + 0.5), (21.5, ry + 4)], BONE_SHADE, 1.8)
    for skull_at in ((21, 40), (43, 42)):
        s.blob([(skull_at[0], skull_at[1]), (skull_at[0] + 3, skull_at[1] - 2), (skull_at[0] + 6, skull_at[1]),
                (skull_at[0] + 5.5, skull_at[1] + 4), (skull_at[0] + 1, skull_at[1] + 4)], BONE_SHADE, outline=INK, width=0.6)
        s.dot(skull_at[0] + 2, skull_at[1] + 1.2, 0.8, HOLLOW)
        s.dot(skull_at[0] + 4.3, skull_at[1] + 1.2, 0.8, HOLLOW)
    for vy in (16, 21, 26, 31, 36, 41, 46):
        s.dot(29.6, vy, 1.2, BONE_DARK)
    # Shoulder of fused skulls and spines.
    s.blob([(38, 16), (46, 10), (56, 12), (59, 20), (52, 25), (43, 22)], BONE, outline=INK, width=0.9)
    for sx, tx, ty in ((45, 43, 4), (50, 51, 3), (55, 58, 6)):
        s.taper([(sx, 13), (tx, ty)], BONE_SHADE, 3, 0.2, outline=INK, width=0.5)
    s.dot(48, 17, 1.1, HOLLOW)
    s.dot(53, 17.5, 1.1, HOLLOW)
    s.glow(48, 17, 2.4, SOUL, 0.6)
    # Near arm: a huge forearm ending in a cleaver of fused bone.
    s.taper([(53, 21), (60, 33), (59, 44)], BONE, 6, 5, outline=INK, width=0.9)
    s.ellipse(56.5, 30, 7, 7, BONE, outline=INK, width=0.8)
    blade = [(55, 44), (70, 40), (71, 54), (66, 62), (59, 58), (56, 50)]
    s.poly(blade, BONE_SHADE, outline=INK, width=1)
    s.poly([(62, 44), (69.5, 42), (70, 53), (66, 59)], BONE)
    for nx, ny in ((70.8, 47), (69.4, 55.5)):
        s.poly([(nx, ny), (nx - 2.2, ny + 0.9), (nx - 0.4, ny + 2.4)], HOLLOW)
    s.ellipse(55.5, 41.5, 6, 6, BONE, outline=INK, width=0.7)
    # Head: a horned skull sunk between the shoulders.
    skull(s, 33, 1.5, scale=1.35, jaw_open=1.2, helm="horned")
    s.pop()
    return s


# ---------------------------------------------------------------------------
# Beasts
# ---------------------------------------------------------------------------

def tiger(name="tiger", coat=0xC8701E, coat_light=0xE8A048, belly=0xEADCC0, stripe=0x1E120C, eye=0xF2C230,
          scars=True, doc=""):
    s = Sprite(name, 64, 42, foot=40, doc=doc)
    shade = _mix(coat, 0x000000, 0.35)
    # Tail lashing up behind.
    s.curve([(12, 17), (5, 16), (2.5, 9), (5, 3.5)], coat, 3.4)
    s.curve([(3, 7), (4.8, 3.2)], stripe, 3.2)
    s.curve([(2.6, 11), (3.6, 9.4)], stripe, 3.4)
    # Far legs.
    s.taper([(17, 24), (13, 31), (14, 38)], shade, 5.4, 4, outline=INK, width=0.7)
    s.taper([(42, 24), (46, 31), (44.5, 38)], shade, 5, 3.8, outline=INK, width=0.7)
    # Body: a long, muscled wedge, heavier at the shoulders.
    body = [(9, 18), (16, 12.5), (30, 13), (43, 10), (51, 14), (50, 24), (42, 28), (26, 27), (13, 27)]
    s.blob(body, coat, outline=INK, width=1.1)
    s.blob([(14, 22), (26, 24.5), (41, 24.5), (46, 22), (43, 27.5), (26, 27.5), (14, 26)], belly)
    s.blob([(16, 13.5), (30, 13.8), (42, 11), (47, 13), (40, 15), (28, 16), (17, 16)], coat_light)
    for sx in (15, 20, 25, 30, 35, 40):
        lift = -2 if sx > 32 else 0
        s.taper([(sx, 13 + lift * 0.3), (sx + 1.8, 17.5), (sx + 0.4, 22)], stripe, 2.1, 0.2)
    # Near legs, forward stride; heavy paws with claws.
    s.taper([(20, 22), (22.5, 30), (20, 37.5)], coat, 6, 4.4, outline=INK, width=0.8)
    s.taper([(44, 20), (49, 28), (50.5, 37)], coat, 6.4, 4.6, outline=INK, width=0.8)
    for px, py in ((20, 37.5), (50.5, 37)):
        s.ellipse(px - 3, py - 1.8, 6.5, 3.6, coat, outline=INK, width=0.7)
        for cx in (1.5, 2.8, 4):
            s.taper([(px + cx - 1, py + 1), (px + cx + 0.4, py + 2.4)], BONE, 0.8, 0.1)
    s.taper([(47, 26), (48.5, 31)], stripe, 1.6, 0.2)
    s.taper([(22, 27), (23, 32)], stripe, 1.6, 0.2)
    # Head: broad, low, snarling, with a ruff.
    s.blob([(45, 8), (50, 4.5), (55, 4), (58.5, 7), (59, 12), (56, 16.5), (49, 18), (45, 14)], coat, outline=INK, width=1)
    s.blob([(44.5, 11), (47, 15), (50.5, 19.5), (47, 19.2), (44, 16.4)], belly, outline=INK, width=0.6)
    s.poly([(48, 6), (49, 1.2), (52.5, 4.6)], coat, outline=INK, width=0.7)
    s.poly([(49, 5.4), (49.6, 3), (51.3, 4.8)], 0x3A2418)
    # Muzzle and bared fangs.
    s.blob([(55, 9.5), (60, 9), (63, 11.5), (61.5, 14.5), (57, 15), (54.5, 13)], belly, outline=INK, width=0.8)
    s.poly([(55.5, 14.2), (62, 13.6), (60.5, 17.5), (56.5, 17.8)], 0x5A1A16, outline=INK, width=0.6)
    s.taper([(57.2, 14.2), (57.6, 17.4)], BONE, 1.1, 0.1)
    s.taper([(60.4, 14), (60.4, 16.6)], BONE, 1.0, 0.1)
    s.ellipse(61.2, 10, 2.2, 1.7, INK)
    # Brow stripes and a burning eye.
    for a, b in (((52, 4.6), (53.5, 8.2)), ((54.8, 4.8), (55.2, 7.4)), ((50, 10), (53, 12))):
        s.taper([a, b], stripe, 1.4, 0.2)
    s.poly([(54, 8.2), (57.8, 7.6), (57, 9.5)], INK)
    s.poly([(54.6, 8.6), (57.3, 8.1), (56.6, 9.3)], eye)
    s.glow(56, 8.8, 3, eye, 0.5)
    if scars:
        s.line((51, 5.5), (54.5, 12.5), (0xF2E2C8, 0.8), 0.5)
        s.line((30, 14), (33, 20), (0xF2E2C8, 0.6), 0.5)
    return s


def wolf(name="wolf", coat=0x6E6C68, coat_light=0x9A968E, shade=0x45423E, eye=0xF2D24C, doc="", embers=False):
    s = Sprite(name, 58, 42, foot=40, doc=doc)
    # Bushy, ragged tail.
    s.blob([(11, 16), (5, 14), (1, 17), (0.8, 22), (4, 20), (6, 23), (9, 20), (12, 20)], shade, outline=INK, width=0.8)
    s.taper([(15, 23), (12.5, 30), (13.5, 38.5)], shade, 4.4, 3, outline=INK, width=0.6)
    s.taper([(38, 23), (41.5, 30), (40, 38.5)], shade, 4.2, 3, outline=INK, width=0.6)
    body = [(9, 18), (15, 13), (27, 13.5), (37, 11), (43, 14), (42, 23), (33, 26.5), (20, 26), (11, 24)]
    s.blob(body, coat, outline=INK, width=1)
    # Shaggy fur: jagged mane along the back and shoulders.
    s.poly([(15, 14.5), (17, 10.5), (19.5, 13.5), (22, 9.5), (24.5, 13), (27.5, 9), (30, 12.5), (33, 8), (35, 11.5),
            (38, 7.5), (40, 12), (37, 16), (18, 17.5)], coat, outline=None)
    s.blob([(17, 14.5), (27, 13), (37, 11), (39, 13.5), (28, 16), (18, 17)], coat_light)
    s.poly([(16, 24), (19, 28), (22, 25.5), (25, 29), (28, 25.5), (31, 28.5), (34, 25)], coat)
    for fx in (19, 24, 29, 34):
        s.curve([(fx, 16.5), (fx + 1.5, 19), (fx + 0.8, 22)], (shade, 0.7), 0.7)
    # Near legs.
    s.taper([(19, 22), (20.5, 30), (18.5, 38)], coat, 4.8, 3.3, outline=INK, width=0.7)
    s.taper([(38, 20), (43, 28.5), (44, 38)], coat, 5, 3.4, outline=INK, width=0.7)
    for px, py in ((18.5, 38), (44, 38)):
        s.ellipse(px - 2.2, py - 1.4, 5.4, 3, coat, outline=INK, width=0.6)
        for cx in (1.4, 2.6):
            s.taper([(px + cx, py + 1), (px + cx + 1, py + 2)], BONE, 0.7, 0.1)
    # Head: long wedge snout, laid-back ears, snarl.
    head = [(37, 9), (41, 5), (45.5, 6), (51, 9.5), (57.5, 12), (57, 15.5), (51.5, 17), (44, 18.5), (38.5, 16)]
    s.poly(head, coat, outline=INK, width=0.9)
    s.poly([(41, 5.8), (40, -0.2), (44.2, 5.4)], coat, outline=INK, width=0.7)
    s.poly([(41.2, 4.6), (40.8, 1.6), (43, 4.8)], 0x2A2420)
    s.poly([(44.5, 6.2), (46, 1), (47.6, 7.6)], shade, outline=INK, width=0.6)
    s.poly([(45, 9.5), (56, 12.4), (51, 13.4), (44.5, 12.5)], coat_light)
    s.poly([(49, 15.2), (57, 14.6), (55, 17.8), (50, 18.4)], 0x4A1614, outline=INK, width=0.5)
    s.taper([(51, 15), (51.3, 17.8)], BONE, 0.9, 0.1)
    s.taper([(54.6, 14.8), (54.8, 17)], BONE, 0.8, 0.1)
    s.ellipse(56, 11.4, 2.2, 1.8, INK)
    s.poly([(44.5, 8.6), (48.5, 9.6), (47.5, 10.8)], INK)
    s.poly([(45.1, 9), (48, 9.8), (47.3, 10.5)], eye)
    s.glow(46.6, 9.8, 2.8, eye, 0.55)
    if embers:
        for ex, ey in ((20, 14), (27, 12.5), (34, 10.5), (39, 9.5), (24, 20), (31, 19)):
            s.line((ex, ey), (ex + 1.5, ey + 2.5), 0xFF8A2A, 0.8)
        for fx, fy, h in ((18, 12, 5), (24, 10.5, 6), (30, 9.5, 7), (36, 8, 6), (41, 6, 5)):
            s.taper([(fx, fy + 1), (fx - 1.4, fy - h * 0.5), (fx - 0.4, fy - h)], (0xFF7A1E, 0.9), 2.8, 0.1)
            s.taper([(fx, fy + 0.5), (fx - 0.8, fy - h * 0.45)], 0xFFD070, 1.2, 0.1)
        s.glow(46.6, 9.8, 4, 0xFF6A1A, 0.6)
    return s


def bear(name="bear", fur=0x4A3424, fur_light=0x6E5238, shade=0x2E2016, doc="", armored=False):
    s = Sprite(name, 72, 56, foot=53, doc=doc)
    s.taper([(18, 34), (14, 42), (15, 50)], shade, 8, 6.5, outline=INK, width=0.8)
    s.taper([(51, 32), (55, 41), (53, 50)], shade, 7.5, 6, outline=INK, width=0.8)
    # Massive body with a shoulder hump.
    body = [(6, 30), (10, 19), (22, 15), (36, 9), (48, 11), (57, 18), (56, 34), (46, 40), (26, 40), (10, 39)]
    s.blob(body, fur, outline=INK, width=1.2)
    s.blob([(14, 20), (24, 16.5), (36, 11), (46, 12.5), (50, 16), (40, 17), (27, 21), (15, 24)], fur_light)
    # Ragged fur edges.
    s.poly([(8, 36), (11, 41), (14, 37.5), (18, 42), (21, 38), (25, 42.5), (29, 38.5), (33, 42.5), (37, 38.5),
            (41, 42), (45, 38), (48, 40.5), (50, 35)], fur)
    for fx, fy in ((16, 25), (22, 22), (29, 19), (35, 17), (20, 31), (28, 29), (36, 26), (43, 24)):
        s.curve([(fx, fy), (fx + 1.6, fy + 2.6), (fx + 1, fy + 5)], (shade, 0.6), 0.8)
    s.line((33, 11.5), (38, 22), (0xE8D8C0, 0.55), 0.5)
    s.line((35.5, 10.5), (40.5, 20.5), (0xE8D8C0, 0.55), 0.5)
    if armored:
        # Rune-carved bone plates bound over the hump with leather cord.
        s.blob([(24, 15.5), (33, 10), (43, 10.5), (46, 16), (38, 19), (27, 20)], BONE_SHADE, outline=INK, width=0.9)
        s.blob([(26, 15), (33, 11.4), (42, 11.8), (43.5, 15), (37, 17), (28, 18)], BONE)
        s.curve([(29, 14.5), (32, 13), (35, 14.5), (38, 13.2)], 0x5CE08A, 0.9)
        s.glow(34, 14, 6, 0x5CE08A, 0.45)
        for cx in (29, 39):
            s.line((cx, 11), (cx + 1.5, 21), 0x3A2418, 1)
        for sx, tx, ty in ((31, 29, 4), (37, 37.5, 2.5), (43, 46, 5)):
            s.taper([(sx, 11.5), (tx, ty)], BONE, 2.6, 0.2, outline=INK, width=0.5)
    # Near legs: thick pillars with hooked claws.
    s.taper([(22, 33), (24.5, 42), (22.5, 50)], fur, 9, 7, outline=INK, width=0.9)
    s.taper([(50, 30), (56, 40), (58, 49.5)], fur, 9, 7, outline=INK, width=0.9)
    for px, py in ((22.5, 50), (58, 49.5)):
        s.ellipse(px - 4.2, py - 2.4, 9.2, 4.6, fur, outline=INK, width=0.8)
        for cx in (2.2, 4, 5.8):
            s.taper([(px + cx - 1.6, py + 1.2), (px + cx + 0.6, py + 3.2)], 0xE0D6C0, 1.1, 0.1, outline=INK, width=0.3)
    # Head: heavy brow, small ears, snout with a roar.
    head = [(50, 15), (54, 10), (60, 9), (65, 12), (67, 17), (65, 23.5), (58, 26), (51.5, 23)]
    s.blob(head, fur, outline=INK, width=1.1)
    s.ellipse(51.5, 8.2, 6, 5.6, fur, outline=INK, width=0.8)
    s.ellipse(53, 9.6, 3, 2.8, shade)
    s.blob([(60, 15.5), (66, 14.5), (70.5, 17), (70, 21), (64, 22.5), (60, 20.5)], 0x8C7054, outline=INK, width=0.8)
    s.poly([(61, 21.5), (69.5, 20.5), (67.5, 26), (62, 26.5)], 0x4A1614, outline=INK, width=0.6)
    for tx, ty in ((63, 21.4), (68.2, 20.8)):
        s.taper([(tx, ty), (tx + 0.2, ty + 3)], BONE, 1.3, 0.1)
    s.ellipse(68.3, 15.8, 2.8, 2.2, INK)
    s.poly([(56.5, 13.5), (61.5, 13), (60, 15.2)], INK)
    eye = 0x7CF08A if armored else 0xE8A030
    s.poly([(57.2, 13.8), (60.8, 13.5), (59.6, 14.8)], eye)
    s.glow(59, 14.2, 3.2, eye, 0.55)
    return s


def dire_wolf_form():
    s = wolf("direWolfForm", coat=0x3E3C3A, coat_light=0x6A6660, shade=0x262422, eye=0x7CF08A,
             doc="Lupine Form: a scarred dire wolf, druid runes glowing along its flank.")
    s.curve([(21, 17.5), (24, 16), (27, 18), (30, 16.4), (33, 18)], 0x5CE08A, 0.9)
    s.glow(27, 17, 7, 0x5CE08A, 0.4)
    s.line((38, 7), (41, 14), (0xE8E0D0, 0.6), 0.5)
    # A torn ear and a bone-bead collar.
    for bx in (36.5, 38.5, 40.5):
        s.ellipse(bx - 1, 15.5 + (bx - 36.5) * 0.4, 2, 2.4, BONE, outline=INK, width=0.4)
    return s


def war_bear_form():
    return bear("warBearForm", fur=0x3A2A1E, fur_light=0x5E4632, shade=0x241810, armored=True,
                doc="Ursine Form: a war bear in rune-carved bone plate.")


def owl():
    s = Sprite("owl", 40, 36, anchor=(0.5, -0.8), doc="A great horned owl, wings spread, eyes like lanterns.")
    feather = 0x5E4630
    light = 0x8A6C4A
    dark = 0x3A2A1C
    for side in (1, -1):
        s.push(20, 0, flip=side < 0)
        wing = [(-4, 13), (4, 8), (12, 6), (19, 9), (17, 12), (19.5, 15), (16, 16.5), (17.5, 20), (12, 19.5),
                (8, 22), (2, 20)]
        s.poly([(x, y) for x, y in wing], feather, outline=INK, width=0.8)
        for fx, fy in ((6, 11), (10, 10), (14, 10)):
            s.curve([(fx, fy), (fx + 2, fy + 4), (fx + 1, fy + 8)], dark, 0.7)
        s.curve([(2, 10.5), (10, 7.5), (18, 9.5)], light, 0.8)
        s.pop()
    body = [(14, 10), (20, 6.5), (26, 10), (27, 22), (24, 30), (20, 32), (16, 30), (13, 22)]
    s.blob(body, feather, outline=INK, width=0.9)
    s.blob([(16, 17), (20, 15), (24, 17), (25, 25), (20, 30), (15, 25)], 0xB89A72)
    for fy in (19, 22.5, 26):
        for fx in (17.5, 20, 22.5):
            s.poly([(fx - 0.9, fy), (fx + 0.9, fy), (fx, fy + 1.2)], dark)
    s.poly([(14.5, 9.5), (13, 2.5), (17.5, 7.5)], feather, outline=INK, width=0.6)
    s.poly([(25.5, 9.5), (27, 2.5), (22.5, 7.5)], feather, outline=INK, width=0.6)
    s.ellipse(14.2, 8.2, 11.6, 9.4, 0xC8B08A, outline=INK, width=0.6)
    s.curve([(20, 8.6), (20, 13)], dark, 0.6)
    for ex in (17, 23):
        s.ellipse(ex - 2.5, 10, 5, 5, 0xF2B830, outline=INK, width=0.6)
        s.dot(ex, 12.5, 1.2, INK)
        s.glow(ex, 12.5, 4, 0xF2C040, 0.35)
    s.poly([(19, 14), (21, 14), (20, 17)], 0x2A2016)
    for tx in (18, 22):
        s.taper([(tx, 30.5), (tx + 0.6, 33.5)], 0x2A2016, 1.4, 0.2)
    return s


def imp(name="imp", hide=0x8A2420, hide_light=0xB8402C, doc="A cackling imp on leathery wings."):
    s = Sprite(name, 38, 40, anchor=(0.5, -0.2), doc=doc)
    wing_dark = 0x3A0E0E
    for flip in (False, True):
        s.push(19, 0, flip=flip)
        wing = [(-3, 16), (2, 6), (8, 1.5), (16, 3), (14, 9), (17.5, 13), (13, 14.5), (15, 19.5), (9, 18),
                (4, 21)]
        s.poly(wing, wing_dark, outline=INK, width=0.7)
        for tip in ((14, 9), (13, 14.5), (9, 18)):
            s.line((-1, 14), tip, 0x5A1A16, 0.8)
        s.pop()
    s.curve([(16, 30), (11, 33), (7, 31), (5, 35)], hide, 1.6)
    s.poly([(5.8, 33.5), (2.6, 38), (7.6, 36)], hide, outline=INK, width=0.4)
    body = [(13, 18), (19, 15), (25, 18), (25, 27), (21, 31), (16, 31), (12.5, 26)]
    s.blob(body, hide, outline=INK, width=0.8)
    s.blob([(15, 19), (20, 17), (23.5, 19.5), (22, 24), (16, 24)], hide_light)
    s.taper([(15.5, 30), (14, 34), (15.5, 37.5)], hide, 2.4, 1.4, outline=INK, width=0.5)
    s.taper([(21.5, 30), (23, 34), (22, 37.5)], hide, 2.4, 1.4, outline=INK, width=0.5)
    # A flame cupped in its claw.
    s.taper([(24, 21), (27.5, 24), (30, 22)], hide, 2.2, 1.4, outline=INK, width=0.5)
    s.glow(31, 19.5, 6, 0xFF8A2A, 0.8)
    s.taper([(31, 22), (30, 18.5), (31.5, 14.5)], 0xFFB040, 3.2, 0.1)
    s.taper([(31, 21.5), (30.8, 18.5)], 0xFFF0B0, 1.4, 0.1)
    head = [(12, 10), (15, 5.5), (21, 4.5), (26.5, 7.5), (27.5, 12), (24.5, 16.5), (17, 17), (12.5, 14)]
    s.blob(head, hide, outline=INK, width=0.8)
    s.taper([(15, 6.5), (11.5, 2.5), (12, -1)], 0x2A1410, 2.4, 0.2, outline=INK, width=0.4)
    s.taper([(21.5, 5), (24, 0.5), (27.5, -0.5)], 0x2A1410, 2.4, 0.2, outline=INK, width=0.4)
    s.poly([(12.5, 10), (8, 7.5), (12, 13)], hide, outline=INK, width=0.5)
    s.poly([(18, 13), (27, 12), (25, 15), (20, 15.5)], 0x2A0808, outline=INK, width=0.4)
    for tx in (19.5, 21.5, 23.5, 25.4):
        s.poly([(tx, 12.6), (tx + 1.2, 12.5), (tx + 0.6, 14)], BONE)
    for ex in (19, 24):
        s.poly([(ex - 1.4, 8.4), (ex + 1.6, 8.8), (ex, 10.2)], 0xFFD23C)
        s.glow(ex, 9.2, 2.6, 0xFFB030, 0.5)
    return s


def pit_fiend():
    s = Sprite("pitFiend", 76, 84, foot=79, doc="A towering pit fiend wreathed in smoke, horns scraping the sky.")
    s.push(5, 6)
    hide = 0x6A1812
    light = 0x9A2A1C
    dark = 0x3A0A08
    magma = 0xFF7A1E
    # Wings: tattered and vast.
    for flip, dx in ((True, 26), (False, 34)):
        s.push(dx, 0, flip=flip)
        wing = [(0, 24), (6, 10), (16, 2), (28, 0.5), (26, 10), (31, 16), (24, 18), (27, 26), (19, 25), (18, 34),
                (10, 30)]
        s.poly(wing, dark, outline=INK, width=0.9)
        for tip in ((26, 10), (24, 18), (19, 25), (10, 30)):
            s.line((2, 22), tip, 0x5A1410, 1.1)
        s.pop()
    # Legs: digitigrade, hooved.
    for hip, knee, hock, hoof, color in (((25, 50), (19, 58), (23, 64), (21, 71), dark),
                                        ((40, 50), (45, 57), (41, 64), (43.5, 71), hide)):
        s.taper([hip, knee], color, 8, 6, outline=INK, width=0.9)
        s.taper([knee, hock, hoof], color, 6, 4, outline=INK, width=0.9)
        s.poly([(hoof[0] - 3.5, hoof[1] - 1), (hoof[0] + 4.5, hoof[1] - 1), (hoof[0] + 5, hoof[1] + 2.5),
                (hoof[0] - 3.8, hoof[1] + 2.5)], 0x1A1412, outline=INK, width=0.7)
    # Tail.
    s.curve([(24, 48), (13, 54), (8, 64), (3, 66)], hide, 2.6)
    s.poly([(4.5, 64), (0.5, 66.5), (4, 69)], dark, outline=INK, width=0.5)
    # Torso: barrel chest, cracked with magma.
    torso = [(20, 26), (32, 20), (46, 23), (50, 34), (45, 48), (34, 53), (24, 50), (18, 38)]
    s.blob(torso, hide, outline=INK, width=1.1)
    s.blob([(24, 26), (33, 22), (44, 25), (46, 32), (38, 30), (27, 32)], light)
    for crack in (((30, 30), (33, 36), (31, 42), (34, 47)), ((40, 28), (38, 34), (42, 40)),
                  ((24, 36), (27, 41))):
        s.curve(list(crack), magma, 1.3)
        s.curve(list(crack), 0xFFD070, 0.5)
    s.glow(33, 38, 12, magma, 0.35)
    s.blob([(23, 46), (34, 48), (45, 45), (44, 52), (34, 55), (24, 52)], 0x2A1410, outline=INK, width=0.7)
    # Arms: far arm trails; near arm hefts a burning chain whip.
    s.taper([(22, 28), (14, 38), (13, 48)], dark, 6.5, 5, outline=INK, width=0.8)
    for cx in (11.5, 13.5, 15.5):
        s.taper([(cx, 48.5), (cx - 0.6, 52)], BONE, 1.3, 0.1)
    s.taper([(45, 27), (52, 37), (57, 33)], hide, 7, 5.5, outline=INK, width=0.8)
    s.ellipse(54.5, 29.5, 6.5, 6.5, hide, outline=INK, width=0.8)
    links = [(59, 31), (62, 26), (63, 19), (61, 12), (63.5, 6)]
    s.curve(links, 0x2A2624, 2.4)
    for lx, ly in links:
        s.ellipse(lx - 1.4, ly - 1.1, 2.8, 2.2, None or 0x4A4440, outline=INK, width=0.4)
    s.glow(63.5, 6, 6, magma, 0.8)
    s.taper([(63.5, 8), (62.5, 3), (64, -1)], 0xFFB040, 3.4, 0.1)
    # Head: bull-like, heavy horns, burning eyes.
    head = [(38, 14), (42, 9), (48, 8.5), (53, 12), (53.5, 18), (49, 22), (41, 22), (37.5, 18)]
    s.blob(head, hide, outline=INK, width=1)
    s.taper([(41, 10), (35, 5), (33.5, -1), (37, -4)], 0x2A2420, 4, 0.3, outline=INK, width=0.6)
    s.taper([(48, 9), (53, 4), (58, 3.5), (61, 0)], 0x3A3430, 4, 0.3, outline=INK, width=0.6)
    s.poly([(45, 17), (54.5, 16.5), (53, 21.5), (46, 21.5)], 0x1A0404, outline=INK, width=0.5)
    s.glow(50, 19, 4, magma, 0.7)
    for tx in (47, 49.5, 52):
        s.poly([(tx, 16.8), (tx + 1.3, 16.7), (tx + 0.6, 18.6)], BONE)
    s.poly([(43.5, 12.4), (48, 12.8), (46, 14.8)], 0xFFD23C)
    s.poly([(49.6, 12.6), (52.8, 12.4), (51.4, 14.4)], 0xFFD23C)
    s.glow(47, 13.4, 5, 0xFFA020, 0.6)
    s.pop()
    return s


def treant():
    s = Sprite("treant", 60, 76, foot=73, doc="An Ancient: a gnarled oak roused to war, moss hanging from its limbs.")
    bark = 0x4A3826
    bark_light = 0x6A5236
    bark_dark = 0x2A2016
    leaf = 0x2E4A22
    leaf_light = 0x4A6E2E
    spirit = 0x9CF070
    # Roots.
    for pts in (((22, 60), (14, 66), (6, 72)), ((24, 62), (20, 68), (17, 73)), ((36, 62), (40, 68), (46, 73)),
                ((38, 60), (47, 65), (55, 71))):
        s.taper(list(pts), bark_dark, 5, 1.2, outline=INK, width=0.6)
    trunk = [(18, 64), (16, 44), (15, 30), (20, 22), (38, 21), (44, 30), (42, 46), (41, 64)]
    s.poly(trunk, bark, outline=INK, width=1.1)
    s.poly([(20, 24), (28, 22.5), (27, 62), (20, 63)], bark_light)
    for x0, pts in ((0, ((22, 26), (21, 40), (23, 52), (22, 62))), (0, ((31, 25), (33, 38), (31, 50), (33, 62))),
                    (0, ((38, 28), (37, 40), (39, 55)))):
        s.curve(list(pts), bark_dark, 1.1)
    # A face in the bark: brow ridge, deep eyes of green light, a knot mouth.
    s.poly([(21, 32), (29, 30), (37, 32), (36, 34), (29, 33), (22, 34.5)], bark_dark)
    for ex in (24.5, 33):
        s.ellipse(ex - 2, 34, 4, 3.4, HOLLOW)
        s.glow(ex, 35.6, 4.5, spirit, 0.7)
        s.dot(ex, 35.6, 0.9, 0xF0FFD0)
    s.blob([(25, 42), (29, 40.5), (33, 42.5), (31.5, 46), (27, 46)], HOLLOW, outline=bark_dark, width=0.8)
    s.glow(29, 43.5, 3.5, spirit, 0.35)
    # Branch arms: gnarled, clawed.
    s.taper([(17, 32), (8, 40), (4, 50), (6, 56)], bark, 7, 2.6, outline=INK, width=0.9)
    for tip in ((2, 58), (6, 60), (9.5, 58)):
        s.taper([(6, 55), tip], bark_dark, 2, 0.2)
    s.taper([(42, 31), (51, 38), (55, 47), (54, 54)], bark, 7, 2.6, outline=INK, width=0.9)
    for tip in ((51, 57), (55, 58.5), (58, 55.5)):
        s.taper([(54, 53), tip], bark_dark, 2, 0.2)
    # Hanging moss.
    for mx, my, h in ((10, 42, 9), (13, 38, 6), (48, 38, 7), (52, 42, 10), (30, 21, 6), (40, 24, 8)):
        s.taper([(mx, my), (mx + 0.5, my + h * 0.5), (mx - 0.4, my + h)], (0x6A8A3A, 0.85), 1.8, 0.4)
    # Crown of dark leaves.
    for cx, cy, w, h, color in ((4, 8, 24, 19, leaf), (22, 2, 26, 21, leaf), (36, 9, 22, 17, leaf),
                                (12, 13, 36, 14, leaf_light), (15, 5, 14, 10, leaf_light), (30, 4, 13, 9, leaf_light)):
        s.ellipse(cx, cy, w, h, color, outline=INK if color == leaf and h > 15 else None, width=0.7)
    for lx, ly in ((10, 12), (18, 9), (27, 6), (36, 8), (44, 13), (50, 18), (8, 20), (40, 19)):
        s.dot(lx, ly, 1.3, 0x5E8A3A)
    for fx, fy in ((14, 15), (34, 12), (46, 16)):
        s.dot(fx, fy, 0.8, spirit)
        s.glow(fx, fy, 2.4, spirit, 0.6)
    return s


def _mix(a, b, t):
    ca = [(a >> 16) & 255, (a >> 8) & 255, a & 255]
    cb = [(b >> 16) & 255, (b >> 8) & 255, b & 255]
    c = [int(round(x + (y - x) * t)) for x, y in zip(ca, cb)]
    return (c[0] << 16) | (c[1] << 8) | c[2]


def all_sprites():
    return [
        skeleton_warrior(),
        skeleton_archer(),
        skeleton_brute(),
        bone_colossus(),
        tiger(doc="A scarred war tiger, fangs bared."),
        tiger("tigerWhite", coat=0xD8D2C4, coat_light=0xF2EEE4, belly=0xF6F2EA, stripe=0x241E1C, eye=0x7ACCF2,
              doc="A pale snow tiger, eyes like ice."),
        wolf(doc="A grey timber wolf, hackles raised."),
        wolf("wolfBlack", coat=0x2E2C2C, coat_light=0x4A4644, shade=0x1C1A1A, eye=0xF2A83C,
             doc="A black wolf, amber-eyed."),
        wolf("hellhound", coat=0x3A1410, coat_light=0x6A2014, shade=0x220806, eye=0xFFD23C, embers=True,
             doc="A hellhound with a burning mane."),
        bear(doc="A great brown bear, reared for the fight."),
        owl(),
        imp(),
        pit_fiend(),
        treant(),
        war_bear_form(),
        dire_wolf_form(),
    ]


HEADER = '''import UIKit

// Generated by tools/art/creatures.py. Edit the Python and rerun it; do not
// edit this file by hand.

/// Summons and shapeshift forms: the risen dead, beasts, fiends and the
/// druid's forms. All face right (+x) and stand on their feet.
extension PlaceholderArt {
    // MARK: - Drawing helpers

    fileprivate static func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: x, y: y)
    }

    fileprivate static func fillOval(_ ctx: CGContext, _ rect: CGRect, _ color: UIColor) {
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: rect)
    }

    fileprivate static func strokeOval(_ ctx: CGContext, _ rect: CGRect, _ color: UIColor, width: CGFloat) {
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(width)
        ctx.strokeEllipse(in: rect)
    }

    /// A closed quadratic B-spline through the midpoints of `points`.
    fileprivate static func smoothPath(_ points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        let count = points.count
        guard count > 2 else { return path }
        func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        }
        path.move(to: mid(points[0], points[1]))
        for index in 0..<count {
            let control = points[(index + 1) % count]
            path.addQuadCurve(to: mid(control, points[(index + 2) % count]), control: control)
        }
        path.closeSubpath()
        return path
    }

    fileprivate static func fillSmooth(_ ctx: CGContext, _ points: [CGPoint], _ color: UIColor) {
        ctx.setFillColor(color.cgColor)
        ctx.addPath(smoothPath(points))
        ctx.fillPath()
    }

    fileprivate static func strokeSmooth(_ ctx: CGContext, _ points: [CGPoint], _ color: UIColor, width: CGFloat) {
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(width)
        ctx.setLineJoin(.round)
        ctx.addPath(smoothPath(points))
        ctx.strokePath()
    }

    /// An open stroke through `points`, rounded through the middle ones.
    fileprivate static func strokeCurve(_ ctx: CGContext, _ points: [CGPoint], _ color: UIColor, width: CGFloat) {
        guard let first = points.first else { return }
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(width)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.move(to: first)
        if points.count < 3 {
            points.dropFirst().forEach { ctx.addLine(to: $0) }
        } else {
            for index in 1..<(points.count - 1) {
                let control = points[index]
                let next = points[index + 1]
                let end = index == points.count - 2
                    ? next
                    : CGPoint(x: (control.x + next.x) / 2, y: (control.y + next.y) / 2)
                ctx.addQuadCurve(to: end, control: control)
            }
        }
        ctx.strokePath()
    }
'''


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    sprites = all_sprites()
    preview_sheet(sprites, os.path.join(here, "allies-preview.png"))
    if "--preview" in sys.argv:
        return
    root = os.path.dirname(os.path.dirname(here))
    out = os.path.join(root, "FateLost", "Rendering", "PlaceholderArt+Allies.swift")
    body = "\n\n".join("    // MARK: - " + s.name + "\n\n" + s.swift_source() for s in sprites)
    with open(out, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(HEADER + "\n" + body + "\n}\n")
    print(f"wrote {len(sprites)} sprites")


if __name__ == "__main__":
    main()
