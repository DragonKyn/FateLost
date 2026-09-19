"""FateLost's bestiary: everything that wants the player dead.

Run from the repo root:

    python tools/art/bestiary.py            # writes the Swift and a preview
    python tools/art/bestiary.py --preview  # preview sheet only

The Swift lands in FateLost/Rendering/PlaceholderArt+Bestiary.swift; the
preview in tools/art/bestiary-preview.png (gitignored).

Creatures are built from a handful of archetypes — robed humanoid, armoured
humanoid, quadruped, hulk, floater, flier. Each archetype is drawn in full
detail once: plate edges, straps, rivets, ribs, hocks, claws and folds. A
creature then chooses a palette and a fistful of switches — what it wears on
its head, what it swings, what grows out of its back. The shape says what it
is, the palette says where it is from, the details say how it fights.

Everything faces +x. Coordinates are top-left origin, y downward.
"""
import os
import sys

from artkit import Sprite, preview_sheet

INK = 0x0E0C08

# Bone and grave-fire, shared with the summons.
BONE = 0xD8CDB0
BONE_SHADE = 0xA89C80
BONE_DARK = 0x6E6450
HOLLOW = 0x16110E
SOUL = 0x8CF2D2
SOUL_HOT = 0xE6FFF6

# Worked metal.
IRON = 0x5E5A54
IRON_LIGHT = 0x8E8A80
STEEL = 0x9C9A92
RUST = 0x7A5A40
GOLD = 0xC9A24A
GOLD_DARK = 0x8A6A22

# Cloth and leather.
CLOTH_DARK = 0x2A2420
CLOTH_RED = 0x6E2320
CLOTH_GREEN = 0x3A4A2A
CLOTH_PALE = 0xB8AE96
LEATHER = 0x4A3A2A

# Family accents.
GOBLIN_SKIN = 0x6F8A4A
ROT = 0x76853F
EMBER = 0xE2792A
EMBER_HOT = 0xFFD07A
VOID = 0x5A3F8C
VOID_HOT = 0xC79BFF
FROST = 0x9FD8EA
FROST_DEEP = 0x4C87A6
BLOOD = 0x7A1F1C


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


# ---------------------------------------------------------------------------
# Shared parts
# ---------------------------------------------------------------------------

def gaze(s, x, y, color, glow=True, spacing=2.8, size=0.8):
    """Two lights in a dark face, the far one smaller and dimmer."""
    if glow:
        s.glow(x, y, size * 4.5, color, 0.6)
    s.dot(x, y, size, color)
    s.dot(x + 0.25, y - 0.2, size * 0.45, _light(color, 0.7))
    s.dot(x - spacing, y + 0.5, size * 0.55, _shade(color, 0.2))


def horn_pair(s, left, right, color=BONE, curl=1.0, width=2.6, ridged=True):
    """A swept pair of horns, ridged along the outer curve."""
    for (bx, by), sign in ((left, -1), (right, 1)):
        tip = (bx + sign * 2.0 * curl, by - 9 * curl)
        mid = (bx + sign * 3.6 * curl, by - 4.6 * curl)
        s.taper([(bx, by), mid, tip], color, width, 0.25, outline=INK, width=0.5)
        if ridged:
            for step in (0.3, 0.55, 0.78):
                rx = bx + (mid[0] - bx) * (1 + step) * 0.6
                ry = by + (tip[1] - by) * step
                s.line((rx - sign * 0.9, ry), (rx + sign * 0.9, ry - 0.3), _shade(color, 0.45), 0.5)


def rags(s, points, color, length=6.0, width=2.4):
    """Torn cloth hanging from a hem, each strip a different length."""
    for index, (x, y) in enumerate(points):
        drop = length * (0.55 + 0.45 * ((index * 3) % 5) / 4)
        sway = -0.9 if index % 2 else 0.7
        s.taper([(x, y), (x + sway * 0.5, y + drop * 0.55), (x + sway, y + drop)], color, width, 0.25)
        s.line((x, y), (x + sway * 0.6, y + drop * 0.7), _shade(color, 0.35), 0.4)


def rivets(s, points, color, r=0.5):
    for x, y in points:
        s.dot(x, y, r, color)
        s.dot(x - r * 0.3, y - r * 0.3, r * 0.4, _light(color, 0.5))


def claw_hand(s, x, y, size, skin, nail=BONE, spread=1.0):
    """A grasping hand: palm, thumb, and three hooked nails."""
    s.ellipse(x - size, y - size * 0.9, size * 2, size * 1.8, skin, outline=INK, width=0.6)
    s.taper([(x - size * 0.5, y + size * 0.2), (x - size * 1.3, y + size * 1.1)], skin, size * 0.8, size * 0.4)
    for index, offset in enumerate((-0.7, 0.1, 0.9)):
        fx = x + offset * size * spread
        s.taper([(fx, y + size * 0.5), (fx + offset * 0.4, y + size * 1.6), (fx + offset * 0.9, y + size * 2.3)],
                skin, size * 0.75, size * 0.3, outline=INK, width=0.35)
        s.taper([(fx + offset * 0.9, y + size * 2.1), (fx + offset * 1.6, y + size * 3.0)], nail,
                size * 0.55, 0.12)


def boot(s, x, y, width, color, toe=None):
    """A planted foot: sole, upper, and a turned-up toe."""
    s.blob([(x - width / 2, y - 3.4), (x + width / 2, y - 3.6), (x + width / 2 + 1.6, y - 0.8),
            (x - width / 2 - 0.8, y - 0.4)], color, outline=INK, width=0.7)
    s.poly([(x - width / 2 - 1, y - 1), (x + width / 2 + 2, y - 1.2), (x + width / 2 + 2, y + 0.6),
            (x - width / 2 - 1, y + 0.8)], _shade(color, 0.5), outline=INK, width=0.5)
    if toe is not None:
        for cx in (-0.6, 0.6, 1.8):
            s.taper([(x + cx + 1, y - 0.2), (x + cx + 2.2, y + 1.4)], toe, 0.9, 0.12)


def bone_arm(s, shoulder, elbow, hand, width=2.0, color=BONE):
    """Two bones and a knuckle, for anything that lost its flesh."""
    s.taper([shoulder, elbow], color, width, width * 0.8, outline=INK, width=0.5)
    s.taper([elbow, hand], color, width * 0.85, width * 0.7, outline=INK, width=0.5)
    s.dot(elbow[0], elbow[1], width * 0.7, color)
    s.dot(shoulder[0], shoulder[1], width * 0.8, color)


def weapon(s, kind, grip, skin):
    """A weapon held in a fist, drawn so the hand closes over the grip."""
    gx, gy = grip
    if kind == "sword":
        s.taper([(gx + 1, gy + 3), (gx + 4, gy - 8), (gx + 6, gy - 20)], STEEL, 3.6, 0.6,
                outline=INK, width=0.6)
        s.curve([(gx + 1.6, gy + 1), (gx + 5.6, gy - 18)], IRON_LIGHT, 0.6)
        s.poly([(gx - 2.4, gy + 2.4), (gx + 4.4, gy + 1.2), (gx + 4.8, gy + 3), (gx - 2, gy + 4.2)], GOLD_DARK,
               outline=INK, width=0.5)
        s.taper([(gx, gy + 4), (gx - 0.6, gy + 8)], LEATHER, 1.8, 1.5)
        s.dot(gx - 0.8, gy + 8.4, 1.0, GOLD)
    elif kind == "axe":
        s.taper([(gx - 1, gy + 10), (gx + 3, gy - 4), (gx + 5, gy - 16)], LEATHER, 2.0, 1.8,
                outline=INK, width=0.5)
        head = [(gx + 4, gy - 15), (gx + 12, gy - 12.5), (gx + 13, gy - 5.5), (gx + 5, gy - 4)]
        s.poly(head, STEEL, outline=INK, width=0.8)
        s.poly([(gx + 8, gy - 14.4), (gx + 12.4, gy - 12.2), (gx + 13, gy - 6), (gx + 8.6, gy - 5)],
               IRON_LIGHT)
        s.poly([(gx + 4, gy - 15.6), (gx + 6.6, gy - 15.2), (gx + 7, gy - 3.6), (gx + 4.4, gy - 3.8)], IRON,
               outline=INK, width=0.5)
        s.line((gx + 12.6, gy - 11.6), (gx + 13.2, gy - 6.6), BONE, 0.5)
    elif kind == "spear":
        s.taper([(gx - 4, gy + 14), (gx + 3, gy - 4), (gx + 7, gy - 18)], LEATHER, 1.8, 1.5,
                outline=INK, width=0.5)
        s.poly([(gx + 6, gy - 16), (gx + 9.4, gy - 25), (gx + 11, gy - 14), (gx + 7.6, gy - 13)], STEEL,
               outline=INK, width=0.6)
        s.line((gx + 8.4, gy - 23), (gx + 9.2, gy - 15), IRON_LIGHT, 0.5)
        s.curve([(gx + 5.6, gy - 12), (gx + 8.4, gy - 11.2)], CLOTH_RED, 1.4)
    elif kind == "maul":
        s.taper([(gx - 2, gy + 11), (gx + 3, gy - 3), (gx + 6, gy - 15)], LEATHER, 2.2, 2.0,
                outline=INK, width=0.5)
        s.poly([(gx + 0.5, gy - 20), (gx + 12, gy - 18.5), (gx + 12.8, gy - 9), (gx + 1.4, gy - 10.5)], IRON,
               outline=INK, width=0.9)
        s.poly([(gx + 8, gy - 19.4), (gx + 12.4, gy - 18.6), (gx + 13, gy - 9.4), (gx + 8.6, gy - 9.6)],
               IRON_LIGHT)
        rivets(s, [(gx + 3, gy - 17.4), (gx + 3.4, gy - 12), (gx + 10.4, gy - 16.6), (gx + 10.8, gy - 11.4)],
               STEEL, 0.6)
    elif kind == "knife":
        s.taper([(gx + 1, gy + 2), (gx + 4, gy - 4), (gx + 6.5, gy - 11)], STEEL, 2.6, 0.4,
                outline=INK, width=0.5)
        s.curve([(gx + 1.6, gy + 0.6), (gx + 6, gy - 9.6)], IRON_LIGHT, 0.5)
        s.taper([(gx, gy + 3), (gx - 0.6, gy + 7)], CLOTH_RED, 1.8, 1.4)
    elif kind == "bow":
        s.curve([(gx + 2, gy - 17), (gx + 8, gy - 1), (gx + 2, gy + 15)], LEATHER, 2.4)
        s.curve([(gx + 2.6, gy - 15.6), (gx + 7, gy - 1), (gx + 2.6, gy + 13.6)], _light(LEATHER, 0.3), 0.8)
        s.line((gx + 2, gy - 17), (gx + 2, gy + 15), CLOTH_PALE, 0.6)
        s.taper([(gx - 7, gy - 1), (gx + 5, gy - 1)], BONE, 1.1, 0.35)
        s.poly([(gx + 4.4, gy - 2.6), (gx + 8, gy - 1), (gx + 4.4, gy + 0.6)], STEEL, outline=INK, width=0.4)
        s.poly([(gx - 7, gy - 2.6), (gx - 4.5, gy - 1), (gx - 7, gy + 0.6)], CLOTH_DARK)
    if kind in ("sword", "axe", "spear", "maul", "knife"):
        s.ellipse(gx - 2.4, gy - 1.2, 5.2, 5.0, skin, outline=INK, width=0.6)
        s.curve([(gx - 2, gy + 0.6), (gx + 0.4, gy + 2.4), (gx + 2.6, gy + 0.8)], _shade(skin, 0.45), 0.6)


# ---------------------------------------------------------------------------
# Archetype: an armoured humanoid
# ---------------------------------------------------------------------------

def armoured(name, skin, armour, accent, eye, doc, arm="sword", helm="cap",
             width=44, height=56, bulk=1.0, cape=None, skeletal=False, ears=True):
    s = Sprite(name, width, height, foot=height - 3, doc=doc)
    mid = width / 2
    ground = height - 4
    plate = _shade(armour, 0.34)
    dark = _shade(armour, 0.6)
    hip = ground - 19
    chest = 22
    shoulder = 19

    if cape is not None:
        s.blob([(mid - 5, shoulder - 1), (mid - 12, 30), (mid - 14, ground - 6), (mid - 6, ground - 3),
                (mid - 2, 34), (mid - 1, shoulder)], cape, outline=INK, width=0.9)
        s.curve([(mid - 7, 24), (mid - 11, 36), (mid - 10, ground - 6)], _shade(cape, 0.4), 1.0)
        rags(s, [(mid - 12, ground - 5), (mid - 9, ground - 3.4), (mid - 6, ground - 3)],
             _shade(cape, 0.25), length=3.6, width=2.4)

    # Far leg, in shadow and set back.
    s.taper([(mid - 5, hip), (mid - 7.5, hip + 8), (mid - 6.5, ground - 3)], dark, 6.4 * bulk, 4.4,
            outline=INK, width=0.6)
    boot(s, mid - 6.5, ground - 0.5, 7.2 * bulk, dark)
    # Near leg, striding forward, with a knee plate.
    s.taper([(mid + 4, hip - 1), (mid + 7, hip + 8), (mid + 6, ground - 3)], plate, 7.0 * bulk, 4.8,
            outline=INK, width=0.8)
    s.blob([(mid + 3.4, hip + 6), (mid + 10, hip + 6.4), (mid + 10.4, hip + 11), (mid + 3.4, hip + 10.6)],
           armour, outline=INK, width=0.6)
    s.line((mid + 4.2, hip + 8.4), (mid + 9.8, hip + 8.6), _light(armour, 0.35), 0.5)
    boot(s, mid + 6, ground - 0.5, 8.0 * bulk, plate, toe=STEEL if not skeletal else BONE)

    if skeletal:
        # A gambeson hanging off ribs rather than a full harness.
        s.blob([(mid - 7, chest - 4), (mid - 4, hip + 2), (mid + 5, hip + 2), (mid + 8, chest - 5),
                (mid, chest - 9)], armour, outline=INK, width=0.9)
        for index in range(4):
            ry = chest - 2 + index * 3.2
            s.curve([(mid - 5.5, ry), (mid, ry + 1.6), (mid + 6, ry - 0.4)], BONE, 1.3)
        s.taper([(mid - 1, chest - 6), (mid - 0.6, hip + 1)], BONE_SHADE, 2.2, 1.8)
        s.blob([(mid - 6, hip - 2), (mid + 6, hip - 2), (mid + 5, hip + 4), (mid - 5, hip + 4)], BONE_SHADE,
               outline=INK, width=0.6)
    else:
        # Breastplate: a ridged wedge with a belt across the waist.
        s.blob([(mid - 9.5 * bulk, shoulder), (mid - 7, chest + 6), (mid - 5.5, hip + 2), (mid + 6, hip + 2),
                (mid + 8.5, chest + 5), (mid + 9.5 * bulk, shoulder - 1), (mid, chest - 6)], armour,
               outline=INK, width=1.0)
        s.blob([(mid - 7, shoulder + 1.5), (mid - 5.5, chest + 7), (mid - 2.5, hip + 1), (mid - 6, hip + 1)],
               plate)
        s.taper([(mid + 0.5, chest - 5), (mid + 1, hip)], _light(armour, 0.3), 1.6, 1.0)
        s.poly([(mid - 6.5, hip - 2.5), (mid + 7, hip - 3), (mid + 7.2, hip + 1), (mid - 6.4, hip + 1.4)],
               LEATHER, outline=INK, width=0.6)
        s.poly([(mid - 1, hip - 3), (mid + 2.6, hip - 3.2), (mid + 2.8, hip + 1.2), (mid - 0.8, hip + 1.4)],
               GOLD_DARK, outline=INK, width=0.5)
        rivets(s, [(mid - 5, chest + 2), (mid + 6, chest + 1), (mid - 4.4, chest + 8), (mid + 5.6, chest + 7)],
               accent)

    # Pauldrons: the far one small and dark, the near one a lipped shell.
    s.ellipse(mid - 13 * bulk, shoulder - 4, 9 * bulk, 8, dark, outline=INK, width=0.7)
    s.blob([(mid + 3, shoulder - 5), (mid + 9 * bulk, shoulder - 6.5), (mid + 13 * bulk, shoulder - 1),
            (mid + 11 * bulk, shoulder + 4.5), (mid + 4, shoulder + 4)], armour, outline=INK, width=0.9)
    s.curve([(mid + 4, shoulder + 2.6), (mid + 9 * bulk, shoulder + 3.6), (mid + 12 * bulk, shoulder + 0.6)],
            accent, 1.1)
    s.dot(mid + 8.5 * bulk, shoulder - 2.4, 0.9, accent)

    # Weapon arm, reaching forward.
    if skeletal:
        bone_arm(s, (mid + 9, shoulder + 1), (mid + 13.5, chest + 4), (mid + 16, chest), 2.0)
    else:
        s.taper([(mid + 9, shoulder + 1), (mid + 13.5, chest + 4), (mid + 16, chest)], armour, 5.0, 3.8,
                outline=INK, width=0.7)
        s.blob([(mid + 12, chest + 1), (mid + 16.5, chest - 0.5), (mid + 17, chest + 3.5),
                (mid + 12.5, chest + 5)], plate, outline=INK, width=0.5)
    weapon(s, arm, (mid + 17, chest), BONE if skeletal else skin)

    # Neck, then the head.
    s.taper([(mid, 17.5), (mid + 1, 14)], _shade(skin, 0.3), 4.0, 3.4)
    head_y = 5.5
    if skeletal:
        s.blob([(mid - 5, head_y + 5), (mid - 3.5, head_y + 1), (mid + 2, head_y - 1), (mid + 6, head_y + 1.5),
                (mid + 6.5, head_y + 5.5), (mid + 4, head_y + 8), (mid - 3, head_y + 8)], BONE,
               outline=INK, width=0.9)
        s.blob([(mid - 4.5, head_y + 4), (mid - 3, head_y + 1.4), (mid - 0.5, head_y + 2.4),
                (mid - 1.4, head_y + 7.4)], BONE_SHADE)
        s.poly([(mid + 0.5, head_y + 8), (mid + 6, head_y + 7.4), (mid + 5.6, head_y + 10.6),
                (mid + 0.8, head_y + 10.8)], BONE_SHADE, outline=INK, width=0.6)
        for tx in (1.8, 3.2, 4.6):
            s.line((mid + tx, head_y + 8.2), (mid + tx, head_y + 10), HOLLOW, 0.4)
        s.ellipse(mid + 2.2, head_y + 3, 3.4, 3.0, HOLLOW)
        s.ellipse(mid - 1.6, head_y + 3.4, 2.2, 2.6, HOLLOW)
        gaze(s, mid + 3.6, head_y + 4.4, eye, spacing=3.4, size=0.8)
    else:
        s.blob([(mid - 5, head_y + 6), (mid - 4, head_y + 1.5), (mid + 1, head_y - 1), (mid + 6, head_y + 1),
                (mid + 6.5, head_y + 6), (mid + 3.5, head_y + 9.5), (mid - 2.5, head_y + 9)], skin,
               outline=INK, width=0.9)
        s.blob([(mid - 4.5, head_y + 5), (mid - 3.4, head_y + 1.8), (mid - 0.6, head_y + 1),
                (mid - 1, head_y + 8.4)], _shade(skin, 0.28))
        if ears:
            s.poly([(mid - 4, head_y + 4), (mid - 10, head_y + 1.5), (mid - 4.5, head_y + 8)], skin,
                   outline=INK, width=0.6)
            s.line((mid - 5, head_y + 4.6), (mid - 8.4, head_y + 3.2), _shade(skin, 0.4), 0.5)
        gaze(s, mid + 3.8, head_y + 5, eye, glow=False, size=0.75, spacing=2.8)
        s.curve([(mid + 0.5, head_y + 4), (mid + 2.6, head_y + 3.2), (mid + 5, head_y + 3.8)],
                _shade(skin, 0.5), 0.7)
        s.curve([(mid + 0.6, head_y + 8), (mid + 3, head_y + 8.6), (mid + 5.4, head_y + 7.6)],
                _shade(skin, 0.6), 0.8)
        for tx in (2.0, 3.6):
            s.taper([(mid + tx, head_y + 8.2), (mid + tx + 0.3, head_y + 6.6)], BONE, 0.9, 0.1)

    if helm == "cap":
        s.blob([(mid - 5.4, head_y + 4), (mid - 4, head_y), (mid + 1, head_y - 2.6), (mid + 6.6, head_y),
                (mid + 7, head_y + 4)], armour, outline=INK, width=0.8)
        s.poly([(mid - 6, head_y + 3.2), (mid + 7.4, head_y + 2.6), (mid + 7.6, head_y + 4.6),
                (mid - 6.2, head_y + 5.2)], plate, outline=INK, width=0.6)
        rivets(s, [(mid - 3.4, head_y + 4), (mid + 1, head_y + 3.6), (mid + 5.4, head_y + 3.8)], accent, 0.45)
    elif helm == "horned":
        s.blob([(mid - 5.6, head_y + 4.5), (mid - 4, head_y - 0.6), (mid + 1, head_y - 3),
                (mid + 6.8, head_y - 0.4), (mid + 7, head_y + 4.5)], armour, outline=INK, width=0.8)
        s.taper([(mid + 1, head_y - 3), (mid + 1.2, head_y + 4)], _light(armour, 0.35), 1.4, 1.0)
        horn_pair(s, (mid - 4.4, head_y + 0.5), (mid + 6.4, head_y - 0.5), BONE, 1.05, 2.6)
    elif helm == "great":
        s.blob([(mid - 6, head_y + 10), (mid - 5.4, head_y - 0.5), (mid + 1, head_y - 3.4),
                (mid + 7.4, head_y - 0.2), (mid + 7.8, head_y + 9.4), (mid + 1, head_y + 12)], armour,
               outline=INK, width=1.0)
        s.blob([(mid - 5.4, head_y + 8), (mid - 4.6, head_y + 0.6), (mid - 2, head_y - 1),
                (mid - 2.4, head_y + 10)], plate)
        s.poly([(mid - 2.6, head_y + 3.6), (mid + 7.2, head_y + 2.8), (mid + 7.4, head_y + 5.6),
                (mid - 2.4, head_y + 6.2)], HOLLOW)
        s.glow(mid + 3.4, head_y + 4.6, 4.5, eye, 0.65)
        s.dot(mid + 4.2, head_y + 4.5, 0.85, eye)
        s.dot(mid + 0.6, head_y + 4.9, 0.6, _shade(eye, 0.2))
        for vx in (mid + 0.4, mid + 3.2, mid + 6):
            s.line((vx, head_y + 7), (vx, head_y + 10.2), plate, 0.7)
        s.curve([(mid - 1, head_y + 1.4), (mid + 3, head_y - 0.4), (mid + 6.6, head_y + 1.6)], accent, 0.8)
    elif helm == "hood":
        s.blob([(mid - 7, head_y + 12), (mid - 6.4, head_y + 2), (mid - 1, head_y - 3),
                (mid + 6, head_y - 1.4), (mid + 8.4, head_y + 4), (mid + 6.4, head_y + 11)], armour,
               outline=INK, width=0.9)
        s.blob([(mid - 2.4, head_y + 9.5), (mid - 1.6, head_y + 2.4), (mid + 3, head_y + 0.6),
                (mid + 6.4, head_y + 4), (mid + 5, head_y + 9.5)], HOLLOW)
        gaze(s, mid + 3.6, head_y + 5.5, eye, spacing=3.0)
    return s


# ---------------------------------------------------------------------------
# Archetype: a robed humanoid
# ---------------------------------------------------------------------------

def robed(name, robe, skin, eye, doc, hood=True, staff=None, trim=None, sigil=None,
          width=44, height=58, bony=False):
    s = Sprite(name, width, height, foot=height - 3, doc=doc)
    mid = width / 2
    hem = height - 5
    shoulder = 19
    dark = _shade(robe, 0.38)

    if staff is not None:
        s.taper([(mid - 10, hem - 1), (mid - 11.5, 24), (mid - 12.5, 8)], LEATHER, 2.2, 1.8,
                outline=INK, width=0.5)
        s.curve([(mid - 11, 30), (mid - 11.8, 18)], _light(LEATHER, 0.25), 0.6)
        for wy in (14, 21, 29):
            s.line((mid - 13.4, wy), (mid - 9.8, wy + 0.6), _shade(LEATHER, 0.4), 0.6)
        if staff == "skull":
            s.blob([(mid - 17, 6), (mid - 15.5, 2.4), (mid - 11.5, 1.8), (mid - 9, 4.6), (mid - 9.6, 8),
                    (mid - 13, 9.4), (mid - 16, 8.6)], BONE, outline=INK, width=0.7)
            s.poly([(mid - 13.6, 8.8), (mid - 9.6, 8.2), (mid - 10, 11), (mid - 13.4, 11.2)], BONE_SHADE,
                   outline=INK, width=0.5)
            s.ellipse(mid - 12.4, 4, 2.8, 2.6, HOLLOW)
            s.ellipse(mid - 15.6, 4.4, 1.8, 2.2, HOLLOW)
            s.glow(mid - 11.2, 5.2, 3.4, SOUL, 0.75)
            s.dot(mid - 11.2, 5.2, 0.7, SOUL_HOT)
        elif staff == "lantern":
            s.curve([(mid - 12.4, 8), (mid - 12, 5), (mid - 10.6, 4.2)], LEATHER, 1.0)
            s.glow(mid - 11, 9, 8, eye, 0.7)
            s.poly([(mid - 14.4, 5), (mid - 7.8, 4.4), (mid - 7, 12.6), (mid - 14.8, 13.2)], IRON,
                   outline=INK, width=0.7)
            s.poly([(mid - 13.4, 6.2), (mid - 8.8, 5.8), (mid - 8.4, 11.6), (mid - 13.6, 12)], HOLLOW)
            s.dot(mid - 11, 8.8, 2.2, eye)
            s.dot(mid - 11.4, 8.2, 0.9, _light(eye, 0.6))
            s.line((mid - 14, 8.6), (mid - 7.6, 8.2), IRON_LIGHT, 0.5)
        elif staff == "blade":
            s.taper([(mid - 12.5, 9), (mid - 13.4, 2), (mid - 13.8, -3)], STEEL, 3.2, 0.5,
                    outline=INK, width=0.6)
            s.curve([(mid - 12.8, 7.6), (mid - 13.6, -1.6)], IRON_LIGHT, 0.5)
            s.poly([(mid - 15.4, 9.6), (mid - 9.8, 9), (mid - 9.6, 10.8), (mid - 15.2, 11.4)], GOLD_DARK,
                   outline=INK, width=0.5)

    # The robe: a bell from the shoulders, with folds and a rope belt.
    s.blob([(mid - 8, shoulder), (mid - 11, 34), (mid - 12.5, hem - 3), (mid - 5, hem + 1),
            (mid + 3, hem + 1.5), (mid + 10.5, hem - 3), (mid + 9, 32), (mid + 7, shoulder - 1),
            (mid, shoulder - 3)], robe, outline=INK, width=1.0)
    s.blob([(mid - 7, shoulder + 2), (mid - 9.5, 34), (mid - 10.5, hem - 4), (mid - 4, hem - 2),
            (mid - 3.5, 30)], dark)
    for fold in (-4.5, 0.5, 5):
        s.curve([(mid + fold, 28), (mid + fold * 1.25, 38), (mid + fold * 1.5, hem - 3)],
                _shade(robe, 0.22), 0.9)
    # Mantle over the shoulders.
    s.blob([(mid - 9.5, shoulder + 1), (mid - 6, shoulder - 4), (mid + 1, shoulder - 5.5),
            (mid + 8, shoulder - 3), (mid + 10, shoulder + 2), (mid + 5, shoulder + 6),
            (mid - 4, shoulder + 6.5)], _light(robe, 0.12), outline=INK, width=0.8)
    if trim is not None:
        s.curve([(mid - 9, shoulder + 4.5), (mid, shoulder + 7), (mid + 9.5, shoulder + 3.5)], trim, 1.1)
        s.curve([(mid - 11.5, hem - 3), (mid - 1, hem + 0.5), (mid + 9.5, hem - 3.5)], trim, 1.1)
    s.poly([(mid - 9, 33), (mid + 8, 32.4), (mid + 8.2, 35), (mid - 8.8, 35.6)], LEATHER,
           outline=INK, width=0.6)
    s.taper([(mid + 6, 35), (mid + 7.5, 42), (mid + 6.5, 46)], LEATHER, 1.4, 0.8)
    if sigil is not None:
        s.glow(mid - 0.5, 40, 6, sigil, 0.55)
        s.poly([(mid - 0.5, 36.5), (mid + 3, 40), (mid - 0.5, 43.5), (mid - 4, 40)], sigil,
               outline=INK, width=0.5)
        s.dot(mid - 0.5, 40, 0.9, _light(sigil, 0.7))
    rags(s, [(mid - 11, hem - 1), (mid - 6, hem + 1), (mid - 1, hem + 1.8), (mid + 4, hem + 1),
             (mid + 9, hem - 1.5)], dark, length=4.8, width=2.8)

    # An arm reaching out of the sleeve.
    s.taper([(mid + 6, shoulder + 3), (mid + 12, 26), (mid + 16, 23.5)], robe, 5.6, 3.6,
            outline=INK, width=0.8)
    s.curve([(mid + 7, shoulder + 5), (mid + 12.5, 27.5)], dark, 0.9)
    claw_hand(s, mid + 17, 22.5, 1.9, BONE if bony else skin, nail=BONE if bony else _shade(skin, 0.4))

    if hood:
        s.blob([(mid - 8, shoulder + 2), (mid - 8.5, 11), (mid - 3.5, 4), (mid + 4, 3), (mid + 9, 8.5),
                (mid + 8.5, 16), (mid + 2, 19)], robe, outline=INK, width=1.0)
        s.blob([(mid - 3, 17), (mid - 2.5, 9.5), (mid + 2.5, 6.5), (mid + 7, 10), (mid + 6, 16.5)], HOLLOW)
        s.curve([(mid - 7.5, 12), (mid - 3, 4.6), (mid + 4.5, 3.4)], _light(robe, 0.2), 1.0)
        gaze(s, mid + 4, 12, eye, spacing=3.2, size=0.95)
    else:
        s.blob([(mid - 4.5, 15), (mid - 4, 8), (mid + 1, 4.5), (mid + 6, 7), (mid + 6.5, 13),
                (mid + 3, 16.5), (mid - 2, 16)], skin, outline=INK, width=0.9)
        s.blob([(mid - 4, 13), (mid - 3.4, 8.4), (mid - 1, 7), (mid - 1.4, 15.4)], _shade(skin, 0.28))
        # Bandage wraps over the eyes.
        s.poly([(mid - 4.6, 9.4), (mid + 6.8, 8.4), (mid + 7, 12), (mid - 4.4, 13)], CLOTH_PALE,
               outline=INK, width=0.6)
        s.curve([(mid - 4, 10.6), (mid + 1, 10.2), (mid + 6.6, 10.8)], _shade(CLOTH_PALE, 0.3), 0.6)
        s.dot(mid + 4, 11, 1.0, eye)
        s.curve([(mid + 0.6, 15), (mid + 3, 15.8), (mid + 5.6, 14.8)], _shade(skin, 0.6), 0.8)
    return s


# ---------------------------------------------------------------------------
# Archetype: a quadruped
# ---------------------------------------------------------------------------

def quadruped(name, coat, belly, eye, doc, mane=None, antlers=False, skeletal=False,
              width=64, height=46, tail="lash", tufts=True):
    s = Sprite(name, width, height, foot=height - 3, doc=doc)
    ground = height - 4
    shade = _shade(coat, 0.38)
    dark = _shade(coat, 0.58)
    back = height - 28
    haunch = 17
    chest = width - 24

    # Tail.
    if tail == "lash":
        s.curve([(haunch - 2, back + 3), (10, back), (5, back - 7), (8, back - 13)], coat, 3.4)
        s.curve([(6.4, back - 6), (8.4, back - 12)], shade, 2.0)
        if tufts:
            for ty in (back - 11, back - 8):
                s.taper([(7, ty), (3.5, ty - 2.5)], coat, 2.0, 0.2)
    elif tail == "bone":
        for index in range(5):
            bx = haunch - 2 - index * 2.6
            by = back + 2 - index * 2.2
            s.taper([(bx, by), (bx - 2.2, by - 1.8)], BONE, 2.0, 1.4, outline=INK, width=0.4)
            s.dot(bx - 2.2, by - 1.8, 1.0, BONE_SHADE)
    elif tail == "flame":
        s.glow(9, back - 5, 11, eye, 0.55)
        s.taper([(haunch - 2, back + 2), (10, back - 5), (6, back - 15)], eye, 4.4, 0.3)
        s.taper([(haunch - 3, back + 1), (12, back - 3), (10, back - 10)], _light(eye, 0.5), 2.4, 0.2)

    # Far legs: shaded, with a bent hock.
    for fx, forward in ((haunch + 3, -1), (chest - 2, 1)):
        s.taper([(fx, back + 6), (fx + forward * 2.5, back + 13), (fx - forward * 1, ground - 4)], dark,
                4.8, 3.2, outline=INK, width=0.6)
        s.ellipse(fx - forward * 3, ground - 4.5, 6, 3.4, dark, outline=INK, width=0.5)

    # Body: a deep chest and a high haunch, joined by a dipped back.
    body = [(haunch - 4, back + 4), (haunch - 2, back - 5), (haunch + 5, back - 8),
            (width / 2, back - 5), (chest - 2, back - 9), (chest + 6, back - 6),
            (chest + 8, back + 4), (chest, back + 12), (width / 2, back + 13),
            (haunch + 2, back + 12)]
    s.blob(body, coat, outline=INK, width=1.1)
    s.blob([(haunch, back + 8), (width / 2, back + 11), (chest + 2, back + 9), (chest + 5, back + 5),
            (chest, back + 13), (width / 2, back + 14), (haunch, back + 12)], belly)
    # Shoulder and haunch masses.
    s.blob([(chest - 4, back - 7), (chest + 5, back - 5), (chest + 6, back + 5), (chest - 5, back + 6)],
           _light(coat, 0.1))
    s.blob([(haunch - 3, back - 4), (haunch + 6, back - 6), (haunch + 7, back + 7), (haunch - 2, back + 8)],
           _light(coat, 0.08))
    s.curve([(haunch + 6, back - 6), (width / 2, back - 3.5), (chest - 1, back - 7.5)], shade, 1.0)

    if skeletal:
        for index in range(5):
            rx = haunch + 5 + index * 3.6
            s.curve([(rx, back - 4), (rx + 1.4, back + 3), (rx - 0.6, back + 10)], BONE_SHADE, 1.4)
        s.blob([(haunch + 1, back - 4), (haunch + 6, back - 6), (haunch + 5, back + 9), (haunch, back + 8)],
               BONE_SHADE)
        s.taper([(haunch + 4, back - 6), (width / 2, back - 3), (chest, back - 7)], BONE, 1.8, 1.4)
    elif tufts:
        for index in range(4):
            tx = haunch + 5 + index * 4.5
            s.taper([(tx, back - 6), (tx - 1.6, back - 10), (tx + 0.6, back - 12)], shade, 2.6, 0.2)

    if mane is not None:
        s.glow(chest - 2, back - 10, 13, mane, 0.45)
        for index in range(5):
            mx = chest - 8 + index * 3.4
            lift = 14 + (index % 2) * 4
            s.taper([(mx, back - 5), (mx - 2.5, back - lift * 0.6), (mx + 1.5, back - lift)], mane, 3.6, 0.3)
            s.taper([(mx + 0.5, back - 5), (mx - 1, back - lift * 0.5)], _light(mane, 0.5), 1.8, 0.2)

    # Near legs: lit, striding, with paws.
    for nx, forward in ((haunch + 6, -1), (chest + 3, 1)):
        s.taper([(nx, back + 5), (nx + forward * 3.5, back + 14), (nx - forward * 1.5, ground - 2)], coat,
                5.6, 3.8, outline=INK, width=0.8)
        s.ellipse(nx - forward * 1.5 - 3.4, back + 12, 5.6, 4.4, _light(coat, 0.06), outline=INK, width=0.5)
        px = nx - forward * 1.5
        s.ellipse(px - 3.6, ground - 3.4, 7.2, 3.8, shade, outline=INK, width=0.6)
        for cx in (-2.0, -0.4, 1.2, 2.6):
            s.taper([(px + cx, ground - 1), (px + cx + 0.6, ground + 1.4)], BONE, 0.9, 0.12)

    # Head: brow, cheek, muzzle, jaw.
    hx = width - 17
    hy = back - 10
    s.taper([(chest, back - 6), (hx - 1, hy + 4)], coat, 8.0, 6.0, outline=INK, width=0.7)
    s.blob([(hx - 3, hy + 3), (hx, hy - 4), (hx + 6, hy - 5), (hx + 10, hy - 1), (hx + 10, hy + 5),
            (hx + 4, hy + 8), (hx - 2, hy + 7)], coat, outline=INK, width=1.0)
    s.blob([(hx - 2, hy + 4), (hx + 1, hy - 2.5), (hx + 4, hy - 2), (hx + 3, hy + 7)], _light(coat, 0.1))
    # Muzzle and jaw.
    s.blob([(hx + 7, hy - 1), (hx + 14, hy - 0.5), (hx + 16, hy + 3), (hx + 13, hy + 6.5),
            (hx + 7, hy + 6)], belly, outline=INK, width=0.8)
    s.poly([(hx + 8, hy + 4.2), (hx + 15.2, hy + 3.6), (hx + 14, hy + 7.2), (hx + 8.4, hy + 7.6)], BLOOD,
           outline=INK, width=0.5)
    # Fangs hang from the upper jaw and rise from the lower, inside the mouth.
    for fx in (1.6, 4.4):
        s.taper([(hx + 8 + fx, hy + 4.3), (hx + 8.3 + fx, hy + 6.4)], BONE, 1.0, 0.12)
    for fx in (2.8, 5.6):
        s.taper([(hx + 8 + fx, hy + 7.3), (hx + 8.2 + fx, hy + 5.4)], BONE, 0.9, 0.12)
    s.ellipse(hx + 14, hy + 0.4, 2.6, 2.0, INK)
    s.curve([(hx + 7.5, hy + 1.6), (hx + 11, hy + 1.2)], _shade(belly, 0.3), 0.6)
    # Brow ridge and eye.
    s.taper([(hx + 3, hy + 0.6), (hx + 8.5, hy - 0.6)], _shade(coat, 0.5), 2.0, 1.2)
    gaze(s, hx + 7.5, hy + 1.8, eye, glow=skeletal or mane is not None, size=0.9, spacing=4.0)

    if antlers:
        for bx, sign in (((hx + 1), -1), ((hx + 6), 1)):
            s.taper([(bx, hy - 4), (bx + sign * 3, hy - 13), (bx + sign * 7, hy - 19)], BONE_SHADE, 2.8, 0.3,
                    outline=INK, width=0.5)
            s.taper([(bx + sign * 2.2, hy - 10), (bx + sign * 7.5, hy - 12)], BONE_SHADE, 1.9, 0.2,
                    outline=INK, width=0.35)
            s.taper([(bx + sign * 4.2, hy - 15), (bx + sign * 9.5, hy - 16.5)], BONE_SHADE, 1.7, 0.2,
                    outline=INK, width=0.35)
            s.taper([(bx + sign * 5.6, hy - 17.5), (bx + sign * 9, hy - 22)], BONE_SHADE, 1.5, 0.2)
    else:
        s.poly([(hx + 1, hy - 3), (hx - 1.5, hy - 10), (hx + 5, hy - 4.5)], coat, outline=INK, width=0.6)
        s.poly([(hx + 1.6, hy - 4), (hx - 0.2, hy - 8.6), (hx + 3.6, hy - 5)], _shade(coat, 0.45))
        s.poly([(hx + 5.5, hy - 4.5), (hx + 6, hy - 11), (hx + 9.5, hy - 3.5)], coat, outline=INK, width=0.6)
        s.poly([(hx + 6.2, hy - 5.2), (hx + 6.6, hy - 9.4), (hx + 8.6, hy - 4.6)], _shade(coat, 0.45))
    return s


# ---------------------------------------------------------------------------
# Archetype: a hulk
# ---------------------------------------------------------------------------

def hulk(name, body_color, accent, eye, doc, arms="fists", crown=None, core=None,
         build="stone", width=62, height=70):
    """A heavy that fills the screen.

    `build` is not a texture switch: it changes the whole silhouette, because
    nine creatures lean on this archetype and a golem must not read as a
    corpse-pile in grey. Stone is squared off and symmetrical, flesh is
    lopsided and hunched with one arm dragging, bone is tall and narrow with
    daylight showing through the ribs."""
    s = Sprite(name, width, height, foot=height - 3, doc=doc)
    mid = width / 2
    ground = height - 4
    dark = _shade(body_color, 0.42)
    deep = _shade(body_color, 0.62)
    light = _light(body_color, 0.12)

    stone = build == "stone"
    flesh = build == "flesh"
    bony = build == "bone"

    # Proportions per build: how far the shoulders spread, how high the head
    # sits, and how far each arm hangs.
    spread = 21 if stone else (23 if flesh else 16)
    shoulder = 20 if stone else (24 if flesh else 17)
    chest = 26 if stone else (30 if flesh else 24)
    hip = ground - (20 if stone else (16 if flesh else 24))
    head_y = 6 if stone else (12 if flesh else 3)
    # Flesh drags one side; the others are even.
    lean = 3 if flesh else 0

    # Legs.
    if bony:
        # Long shanks with a knee knob, standing close together.
        for lx, sign in ((mid - 7, -1), (mid + 7, 1)):
            s.taper([(lx, hip - 2), (lx + sign * 2, hip + 12), (lx + sign * 1, ground - 5)],
                    dark if sign < 0 else body_color, 8, 5, outline=INK, width=0.8)
            s.dot(lx + sign * 2, hip + 12, 4.0, deep)
            s.ellipse(lx + sign - 8, ground - 6, 16, 6, deep, outline=INK, width=0.8)
            for cx in (-5, -1, 3, 6):
                s.taper([(lx + sign + cx, ground - 3), (lx + sign + cx * 1.2, ground + 1)], BONE, 1.8, 0.2,
                        outline=INK, width=0.35)
    else:
        for lx, sign in ((mid - 11, -1), (mid + 10 + lean, 1)):
            wide = 8 if stone else 7
            s.blob([(lx - wide, hip - 2), (lx + wide, hip - 2), (lx + wide + sign, ground - 8),
                    (lx + wide - 1, ground - 2), (lx - wide + 1, ground - 2), (lx - wide + sign, ground - 8)],
                   dark if sign < 0 else body_color, outline=INK, width=0.9)
            s.blob([(lx - wide + 2, hip + 1), (lx + 1, hip + 1), (lx + 1, ground - 6),
                    (lx - wide + 2, ground - 6)], deep)
            s.ellipse(lx - wide - 2, ground - 5, wide * 2 + 4, 6.5, deep, outline=INK, width=0.8)
            if stone:
                for tx in (-5, 0, 5):
                    s.taper([(lx + tx, ground - 3.5), (lx + tx * 1.2, ground + 0.5)], light, 2.4, 1.2)
            else:
                for cx in (-5.5, -1.5, 2.5, 6):
                    s.taper([(lx + cx, ground - 3), (lx + cx * 1.15, ground + 1)], BONE, 1.8, 0.2,
                            outline=INK, width=0.35)

    # Torso.
    if stone:
        # Squared-off slabs; a trapezoid, not a blob.
        torso = [(mid - spread, shoulder - 2), (mid - spread + 3, chest + 10), (mid - 13, hip),
                 (mid + 12, hip), (mid + spread - 3, chest + 8), (mid + spread, shoulder - 3),
                 (mid + 9, 15), (mid - 9, 15.5)]
        s.poly(torso, body_color, outline=INK, width=1.2)
        s.poly([(mid - spread + 2, shoulder), (mid - spread + 4, chest + 9), (mid - 10, hip - 1),
                (mid - 14, hip - 1)], dark)
        s.curve([(mid - 15, chest - 2), (mid, chest + 1), (mid + 16, chest - 3)], deep, 1.2)
        s.curve([(mid - 13, chest + 10), (mid + 1, chest + 12), (mid + 14, chest + 9)], deep, 1.1)
        s.taper([(mid - 1, 16), (mid, hip - 2)], deep, 1.8, 1.4)
        s.poly([(mid + 9, chest - 6), (mid + 16, chest - 4), (mid + 14, chest + 2), (mid + 8, chest)], light)
        s.poly([(mid - 14, chest + 2), (mid - 8, chest + 4), (mid - 11, chest + 10)], deep)
    elif flesh:
        # A lopsided mound, one shoulder far higher than the other.
        torso = [(mid - spread + 4, shoulder + 4), (mid - 17, chest + 6), (mid - 12, hip),
                 (mid + 13, hip), (mid + 19, chest + 2), (mid + spread, shoulder - 6),
                 (mid + 6, 14), (mid - 7, 19)]
        s.blob(torso, body_color, outline=INK, width=1.2)
        s.blob([(mid - spread + 6, shoulder + 6), (mid - 15, chest + 7), (mid - 9, hip - 1),
                (mid - 15, hip - 1)], dark)
        # Growths and seams where the parts were sewn together.
        for sy in (chest - 3, chest + 7, chest + 15):
            s.curve([(mid - 13, sy), (mid + 1, sy + 3), (mid + 15, sy - 2)], deep, 1.2)
            for step in range(-4, 5):
                sx = mid + step * 3.4
                s.line((sx, sy - 1.8 + abs(step) * 0.12), (sx + 1.4, sy + 2.6), BONE_SHADE, 0.6)
        s.blob([(mid + 5, chest - 4), (mid + 16, chest + 1), (mid + 13, chest + 11), (mid + 3, chest + 8)],
               _light(body_color, 0.2))
        s.blob([(mid - 10, chest + 12), (mid - 3, chest + 14), (mid - 5, chest + 20), (mid - 12, chest + 18)],
               _light(body_color, 0.16))
        for bx, by in ((mid + 12, chest - 6), (mid - 12, chest + 2), (mid + 6, chest + 18)):
            s.taper([(bx, by), (bx + 3, by - 5)], BONE, 2.0, 0.2, outline=INK, width=0.4)
    else:
        # A ribcage on a spine, with the dark showing between the bones.
        s.blob([(mid - 14, shoulder - 2), (mid - 11, chest + 8), (mid - 8, hip), (mid + 8, hip),
                (mid + 12, chest + 6), (mid + 15, shoulder - 3), (mid + 6, 13), (mid - 6, 13.5)],
               HOLLOW, outline=INK, width=1.0)
        s.taper([(mid - 1, 14), (mid, hip)], BONE_SHADE, 3.4, 2.4, outline=INK, width=0.5)
        for index in range(6):
            ry = shoulder + 2 + index * 4.2
            spanl = 13 - abs(index - 2) * 1.2
            s.curve([(mid - spanl, ry), (mid, ry + 3.4), (mid + spanl - 1, ry - 0.5)], BONE, 2.0)
            s.curve([(mid - spanl + 1, ry + 0.6), (mid, ry + 3.8)], BONE_SHADE, 0.8)
        s.blob([(mid - 12, hip - 5), (mid + 11, hip - 5), (mid + 9, hip + 3), (mid - 10, hip + 3)],
               body_color, outline=INK, width=0.9)

    if core is not None:
        cy = chest + (6 if not bony else 4)
        s.glow(mid, cy, 16, core, 0.8)
        if stone:
            # A furnace behind a grate.
            s.poly([(mid - 7, cy - 6), (mid + 7, cy - 6), (mid + 6, cy + 7), (mid - 6, cy + 7)], core,
                   outline=INK, width=0.8)
            for gy in (cy - 3, cy, cy + 3):
                s.line((mid - 6.5, gy), (mid + 6.5, gy), _shade(body_color, 0.7), 1.1)
        elif flesh:
            # A heart that never stopped.
            s.blob([(mid - 5, cy - 2), (mid - 2, cy - 6), (mid + 1, cy - 2), (mid + 4, cy - 6),
                    (mid + 6, cy), (mid, cy + 8)], core, outline=INK, width=0.8)
            s.dot(mid + 1, cy, 1.6, _light(core, 0.6))
        else:
            # Grave-fire loose in the ribs.
            s.dot(mid, cy, 4.6, core)
            s.dot(mid + 1.2, cy - 1.2, 2.0, _light(core, 0.7))

    # Arms.
    for sign, ax, front in ((-1, mid - spread + 1, False), (1, mid + spread - 1 + lean, True)):
        limb = body_color if front else dark
        reach = ground - (14 if not flesh else (8 if front else 16))
        if bony:
            bone_arm(s, (ax, shoulder), (ax + sign * 7, chest + 10), (ax + sign * 6, reach), 4.2,
                     BONE if front else BONE_SHADE)
            fx = ax + sign * 6
        else:
            if stone:
                s.poly([(ax - 9, shoulder - 7), (ax + 9, shoulder - 8), (ax + 9, shoulder + 5),
                        (ax - 9, shoulder + 6)], limb, outline=INK, width=1.0)
                s.poly([(ax - 7, shoulder - 6), (ax + 3, shoulder - 7), (ax + 2, shoulder - 2),
                        (ax - 7, shoulder - 1)], _light(limb, 0.16))
            else:
                s.blob([(ax - 9, shoulder - 7), (ax + 9, shoulder - 8), (ax + 10, shoulder + 5),
                        (ax - 9, shoulder + 6)], limb, outline=INK, width=1.0)
            s.taper([(ax + sign * 1, shoulder + 5), (ax + sign * 6, chest + 12), (ax + sign * 5, reach)],
                    limb, 13 if front else 11, 9, outline=INK, width=0.9)
            s.curve([(ax + sign * 2, chest), (ax + sign * 6, chest + 12)], _shade(limb, 0.3), 1.2)
            fx = ax + sign * 5
        if arms == "fists":
            s.blob([(fx - 8, reach - 4), (fx + 8, reach - 4), (fx + 9, reach + 7), (fx - 8, reach + 8)],
                   _light(limb, 0.1), outline=INK, width=0.9)
            for ky in (reach - 1, reach + 2.5):
                s.curve([(fx - 6, ky), (fx, ky + 1), (fx + 7, ky - 0.6)], _shade(limb, 0.4), 1.0)
        elif arms == "claws":
            s.blob([(fx - 7, reach - 3), (fx + 7, reach - 3), (fx + 7, reach + 6), (fx - 7, reach + 7)],
                   _light(limb, 0.1), outline=INK, width=0.9)
            for cx in (-5.5, -2, 1.5, 5):
                s.taper([(fx + cx, reach + 5), (fx + cx * 1.2, reach + 11), (fx + cx * 1.5, reach + 16)],
                        BONE, 2.2, 0.25, outline=INK, width=0.4)
        elif arms == "blades":
            s.blob([(fx - 6, reach - 3), (fx + 6, reach - 3), (fx + 5, reach + 4), (fx - 5, reach + 4)],
                   _light(limb, 0.1), outline=INK, width=0.8)
            s.poly([(fx - 5, reach + 2), (fx + 5, reach + 2), (fx + sign * 11, reach + 16),
                    (fx - sign * 3, reach + 13)], STEEL, outline=INK, width=0.8)
            s.line((fx + sign * 3, reach + 4), (fx + sign * 9, reach + 14.5), IRON_LIGHT, 0.7)

    # Head.
    hy = head_y
    if bony:
        s.taper([(mid, 14), (mid + 0.5, 11)], BONE_SHADE, 4.5, 4.0)
        s.blob([(mid - 7, hy + 9), (mid - 6, hy + 2), (mid, hy - 2), (mid + 7, hy + 1.5),
                (mid + 8, hy + 8), (mid + 2, hy + 11)], BONE, outline=INK, width=1.0)
        s.blob([(mid - 6.5, hy + 7), (mid - 5.5, hy + 2.5), (mid - 2.5, hy + 1), (mid - 2, hy + 10)],
               BONE_SHADE)
        s.poly([(mid + 1, hy + 10.5), (mid + 7.5, hy + 9.5), (mid + 7, hy + 14), (mid + 1.4, hy + 14.5)],
               BONE_SHADE, outline=INK, width=0.6)
        for tx in (2.4, 4.0, 5.6):
            s.line((mid + tx, hy + 10.8), (mid + tx, hy + 13.4), HOLLOW, 0.45)
        s.ellipse(mid + 2, hy + 3, 4.2, 3.8, HOLLOW)
        s.ellipse(mid - 2.8, hy + 3.6, 2.6, 3.0, HOLLOW)
        gaze(s, mid + 4, hy + 5, eye, spacing=4.6, size=1.1)
    else:
        neck = 7.0 if stone else 8.5
        s.taper([(mid, shoulder - 2), (mid + 1, hy + 11)], deep, neck, neck * 0.85)
        if stone:
            s.poly([(mid - 9, hy + 11), (mid - 8, hy + 1), (mid, hy - 2.5), (mid + 9, hy + 1),
                    (mid + 9.5, hy + 10.5), (mid, hy + 13.5)], light, outline=INK, width=1.0)
            s.poly([(mid - 8, hy + 9), (mid - 7, hy + 1.5), (mid - 3.5, hy + 0), (mid - 3, hy + 12)], dark)
        else:
            s.blob([(mid - 9, hy + 10), (mid - 7, hy + 2), (mid + 1, hy - 2), (mid + 9, hy + 2),
                    (mid + 10, hy + 9), (mid + 3, hy + 13)], light, outline=INK, width=1.0)
            s.blob([(mid - 8, hy + 8), (mid - 6, hy + 2.5), (mid - 3, hy + 1), (mid - 2.5, hy + 11)], dark)
        s.poly([(mid - 5, hy + 4.5), (mid + 8, hy + 3.4), (mid + 8.4, hy + 7.4), (mid - 4.6, hy + 8.4)],
               HOLLOW)
        gaze(s, mid + 4.5, hy + 6, eye, spacing=5.0, size=1.15)
        if flesh:
            for step in range(-2, 3):
                s.line((mid + step * 3, hy + 10.5), (mid + step * 3 + 1, hy + 13.5), BONE_SHADE, 0.55)
        else:
            for tx in (-3.5, -0.5, 2.5, 5.5):
                s.taper([(mid + tx, hy + 9.5), (mid + tx + 0.3, hy + 12.5)], BONE, 1.1, 0.12)

    if crown == "horns":
        horn_pair(s, (mid - 7, hy + 2), (mid + 8, hy + 1), BONE, 1.35, 3.4)
    elif crown == "spikes":
        for index, sx in enumerate((mid - 7, mid - 2.5, mid + 2, mid + 6.5)):
            tall = 7 + (index % 2) * 3
            s.taper([(sx, hy + 2), (sx + 0.8, hy + 2 - tall)], accent, 2.6, 0.2, outline=INK, width=0.45)
    elif crown == "crown":
        s.poly([(mid - 9, hy + 2.5), (mid + 9.5, hy + 1), (mid + 9, hy - 4), (mid + 5, hy - 0.5),
                (mid + 1, hy - 6), (mid - 3.5, hy - 1), (mid - 8, hy - 4.5)], GOLD, outline=INK, width=0.8)
        rivets(s, [(mid - 5.5, hy + 0.5), (mid + 1, hy - 1), (mid + 6.5, hy + 0)], BLOOD, 0.7)
    return s


# ---------------------------------------------------------------------------
# Archetype: a floater
# ---------------------------------------------------------------------------

def floater(name, body_color, glow_color, doc, shape="shroud", width=42, height=52):
    s = Sprite(name, width, height, anchor=(0.5, -0.12), doc=doc)
    mid = width / 2
    dark = _shade(body_color, 0.4)
    s.glow(mid, height * 0.44, width * 0.6, glow_color, 0.38)

    if shape == "shroud":
        # A cowl and shoulders over a body that frays away into nothing.
        s.blob([(mid - 12, 30), (mid - 11, 16), (mid - 6, 7), (mid + 3, 5), (mid + 11, 11),
                (mid + 12, 24), (mid + 8, 34), (mid - 5, 35)], body_color, outline=INK, width=1.0)
        s.blob([(mid - 11, 28), (mid - 10, 17), (mid - 5, 9), (mid - 1, 8), (mid - 3, 34)], dark)
        for fold in (-5, 1, 6):
            s.curve([(mid + fold, 22), (mid + fold * 1.2, 29), (mid + fold * 1.35, 35)], dark, 0.9)
        s.blob([(mid - 4, 26), (mid - 3, 13), (mid + 3, 9), (mid + 9, 13), (mid + 7, 25)], HOLLOW)
        s.curve([(mid - 10, 17), (mid - 4, 7.5), (mid + 4, 5.5)], _light(body_color, 0.22), 1.1)
        rags(s, [(mid - 9, 33), (mid - 4, 35), (mid + 1, 35.5), (mid + 6, 34), (mid + 10, 31)],
             body_color, length=11, width=4.2)
        # A reaching arm out of the sleeve.
        s.taper([(mid + 9, 19), (mid + 15, 23), (mid + 18, 21)], body_color, 5.0, 2.4,
                outline=INK, width=0.7)
        claw_hand(s, mid + 19, 20.5, 1.7, _light(body_color, 0.3), nail=glow_color)
        gaze(s, mid + 4.5, 15, glow_color, size=1.1, spacing=3.8)
    elif shape == "orb":
        # One great eye on a curtain of tendrils.
        for index, tx in enumerate((mid - 10, mid - 4, mid + 3, mid + 9, mid + 13)):
            sway = -2 + index
            s.curve([(tx, 30), (tx + sway, 38), (tx + sway * 0.4, height - 3)], dark, 2.4)
            s.dot(tx + sway * 0.4, height - 3.5, 1.1, dark)
        s.ellipse(mid - 14, 6, 28, 27, body_color, outline=INK, width=1.2)
        s.blob([(mid - 13, 18), (mid - 9, 9), (mid, 6.5), (mid + 10, 10), (mid + 13, 19),
                (mid + 7, 28), (mid - 6, 28)], _light(body_color, 0.14))
        # Veins over the sclera.
        for vy, vx in ((14, -10), (22, -8), (26, 4)):
            s.curve([(mid + vx, vy), (mid + vx * 0.5, vy + 2), (mid + vx * 0.2, vy + 4)], dark, 0.7)
        s.ellipse(mid - 5, 12, 16, 15, HOLLOW, outline=INK, width=0.9)
        s.glow(mid + 3, 19.5, 9, glow_color, 0.8)
        s.dot(mid + 3, 19.5, 4.4, glow_color)
        s.dot(mid + 3, 19.5, 2.0, HOLLOW)
        s.dot(mid + 4.6, 17.6, 1.5, 0xFFFFFF)
        # A heavy lid, half closed.
        s.blob([(mid - 14, 12), (mid - 6, 5), (mid + 5, 5), (mid + 14, 11), (mid + 6, 9), (mid - 5, 9)],
               dark, outline=INK, width=0.8)
        for ex in (mid - 11, mid - 3, mid + 6, mid + 12):
            s.dot(ex, 9.5, 1.0, glow_color)
    elif shape == "shard":
        # A core splinter with lesser shards turning around it.
        for sx, sy, h, w in ((mid - 14, 17, 11, 4), (mid + 13, 13, 9, 3.4), (mid - 10, 34, 8, 3),
                             (mid + 12, 32, 7, 2.8), (mid - 2, 44, 6, 2.4)):
            s.poly([(sx, sy - h / 2), (sx + w, sy), (sx, sy + h / 2), (sx - w, sy)], body_color,
                   outline=INK, width=0.6)
            s.poly([(sx, sy - h / 2), (sx + w, sy), (sx, sy)], _light(body_color, 0.4))
        s.poly([(mid, 3), (mid + 11, 23), (mid, 42), (mid - 11, 23)], body_color, outline=INK, width=1.1)
        s.poly([(mid, 3), (mid + 11, 23), (mid, 23)], _light(body_color, 0.45))
        s.poly([(mid, 23), (mid - 11, 23), (mid, 42)], dark)
        s.glow(mid, 23, 14, glow_color, 0.75)
        s.poly([(mid, 12), (mid + 5, 23), (mid, 34), (mid - 5, 23)], _light(glow_color, 0.3))
        s.dot(mid, 23, 2.6, 0xFFFFFF)
        s.line((mid - 6, 16), (mid + 4, 30), _light(body_color, 0.6), 0.6)
    elif shape == "mote":
        # A knot of flame with a face somewhere inside it.
        s.glow(mid, 24, 22, glow_color, 0.8)
        s.blob([(mid - 10, 26), (mid - 8, 14), (mid - 2, 4), (mid + 5, 12), (mid + 10, 26),
                (mid + 5, 36), (mid - 4, 36)], body_color, outline=INK, width=0.9)
        s.blob([(mid - 6, 26), (mid - 4, 16), (mid, 8), (mid + 4, 16), (mid + 6, 27),
                (mid + 2, 33), (mid - 3, 33)], _light(body_color, 0.35))
        s.blob([(mid - 2.5, 26), (mid - 1, 18), (mid + 1.5, 14), (mid + 3, 20), (mid + 2.5, 29)],
               _light(glow_color, 0.4))
        gaze(s, mid + 2.5, 23, 0xFFFFFF, glow=False, size=1.0, spacing=4.0)
        s.curve([(mid - 2, 28.5), (mid + 1, 30), (mid + 4.5, 28)], HOLLOW, 0.9)
        for index in range(3):
            fx = mid - 6 + index * 6
            s.taper([(fx, 35), (fx + 1 - index, height - 5)], body_color, 3.0, 0.3)
    return s


# ---------------------------------------------------------------------------
# Archetype: a small flier
# ---------------------------------------------------------------------------

def flier(name, skin, wing, eye, doc, width=48, height=42):
    s = Sprite(name, width, height, anchor=(0.5, -0.18), doc=doc)
    mid = width / 2
    dark = _shade(skin, 0.4)
    membrane = _light(wing, 0.12)
    # Far wing, swept back.
    s.blob([(mid - 3, 15), (mid - 11, 4), (mid - 20, 7), (mid - 17, 14), (mid - 9, 20)], _shade(wing, 0.35),
           outline=INK, width=0.8)
    for wx in (-17, -13, -9):
        s.curve([(mid - 4, 15), (mid + wx * 0.85, 8.5)], _shade(wing, 0.6), 0.7)
    # Near wing, forward and open, with finger bones.
    s.blob([(mid + 2, 14), (mid + 10, 2), (mid + 21, 5), (mid + 19, 14), (mid + 8, 21)], membrane,
           outline=INK, width=0.9)
    for wx, wy in ((19, 5.5), (15, 3.5), (10.5, 3)):
        s.taper([(mid + 3, 14.5), (mid + wx, wy)], _shade(wing, 0.45), 1.4, 0.5)
    s.curve([(mid + 10, 2.5), (mid + 21, 5.5)], _shade(wing, 0.6), 0.7)
    # Body: a narrow ribcage and a pot belly.
    s.blob([(mid - 6, 16), (mid - 4, 9), (mid + 3, 8), (mid + 7, 14), (mid + 6, 22), (mid, 27),
            (mid - 5, 24)], skin, outline=INK, width=0.9)
    s.blob([(mid - 5, 17), (mid - 3.5, 10), (mid - 1, 9.5), (mid - 1.5, 25)], dark)
    for ry in (14, 17.5):
        s.curve([(mid - 3, ry), (mid + 1, ry + 1.2), (mid + 5.5, ry - 0.4)], dark, 0.7)
    # Barbed tail.
    s.curve([(mid - 1, 25), (mid - 7, 30), (mid - 3, 36)], skin, 1.9)
    s.poly([(mid - 4.5, 34), (mid - 0.5, 37.5), (mid - 5.5, 38.5)], skin, outline=INK, width=0.5)
    # Legs tucked under, claws out.
    for lx in (mid - 2, mid + 4):
        s.taper([(lx, 23), (lx + 1.5, 28)], skin, 2.6, 1.3, outline=INK, width=0.5)
        for cx in (-1.2, 0.4, 1.8):
            s.taper([(lx + 1.5 + cx * 0.6, 28), (lx + 1.8 + cx * 1.2, 31.5)], BONE, 0.9, 0.12)
    # Head: a snout, a grin and horns.
    s.blob([(mid - 3, 11), (mid - 2, 5), (mid + 3, 2.5), (mid + 8, 5), (mid + 8.5, 10),
            (mid + 4, 13.5), (mid - 1, 13)], skin, outline=INK, width=0.9)
    s.blob([(mid - 2.5, 10), (mid - 1.5, 5.5), (mid + 1, 4.5), (mid + 0.5, 12.5)], dark)
    s.blob([(mid + 6, 6.5), (mid + 11, 7), (mid + 12, 10), (mid + 8, 11.5), (mid + 5.5, 10.5)], skin,
           outline=INK, width=0.7)
    s.ellipse(mid + 10, 7.8, 1.8, 1.4, INK)
    horn_pair(s, (mid + 0.5, 4), (mid + 7, 3.2), BONE_SHADE, 0.8, 2.0)
    gaze(s, mid + 5.5, 7, eye, size=0.85, spacing=3.2)
    # A wide row of little teeth.
    s.poly([(mid + 2, 11), (mid + 9.5, 10.4), (mid + 9, 12.6), (mid + 2.4, 13)], HOLLOW,
           outline=INK, width=0.5)
    for tx in (3, 4.6, 6.2, 7.8):
        s.taper([(mid + tx, 11), (mid + tx + 0.2, 12.6)], BONE, 0.85, 0.1)
    return s


# ---------------------------------------------------------------------------
# Archetype: an arachnid
# ---------------------------------------------------------------------------

def arachnid(name, body_color, marking, eye, doc, width=62, height=46):
    s = Sprite(name, width, height, foot=height - 3, doc=doc)
    mid = width / 2
    ground = height - 4
    dark = _shade(body_color, 0.42)
    light = _light(body_color, 0.12)
    hub = (mid + 2, ground - 16)

    # Eight legs: four behind in shadow, four in front, each with a knee.
    for index, (reach, lift) in enumerate(((-19, 15), (-13, 19), (-4, 20), (7, 17),
                                           (-16, 13), (-8, 17), (3, 18), (13, 15))):
        far = index < 4
        color = dark if far else body_color
        knee = (hub[0] + reach * 0.55, hub[1] - lift)
        foot = (hub[0] + reach * 1.25, ground - 1)
        s.taper([hub, knee], color, 3.2 if far else 3.8, 2.4, outline=INK, width=0.5)
        s.taper([knee, ((knee[0] + foot[0]) / 2, knee[1] + lift * 0.55), foot], color, 2.6, 1.0,
                outline=INK, width=0.5)
        s.dot(knee[0], knee[1], 1.6 if far else 2.0, _shade(color, 0.25))
    # Abdomen: fat, marked, with spinnerets behind.
    s.ellipse(mid - 27, ground - 27, 27, 23, body_color, outline=INK, width=1.2)
    s.blob([(mid - 24, ground - 18), (mid - 20, ground - 26), (mid - 9, ground - 25),
            (mid - 6, ground - 16), (mid - 14, ground - 9)], marking)
    s.blob([(mid - 20, ground - 22), (mid - 14, ground - 23), (mid - 13, ground - 17),
            (mid - 19, ground - 16)], _shade(marking, 0.35))
    s.curve([(mid - 25, ground - 22), (mid - 14, ground - 27), (mid - 3, ground - 22)], light, 0.9)
    for tx in (mid - 27, mid - 25):
        s.taper([(tx, ground - 14), (tx - 3, ground - 10)], dark, 2.0, 0.4)
    # Thorax.
    s.ellipse(mid - 6, ground - 24, 20, 17, light, outline=INK, width=1.0)
    s.curve([(mid - 4, ground - 20), (mid + 4, ground - 22), (mid + 11, ground - 18)], dark, 0.9)
    # Head with a bank of eyes and fangs.
    s.blob([(mid + 8, ground - 22), (mid + 16, ground - 21), (mid + 21, ground - 16),
            (mid + 17, ground - 10), (mid + 8, ground - 11)], body_color, outline=INK, width=0.9)
    s.glow(mid + 17, ground - 17, 7, eye, 0.55)
    for ex, ey, r in ((mid + 19, ground - 17.5, 1.5), (mid + 15.5, ground - 19, 1.1),
                      (mid + 19.5, ground - 13.5, 0.9), (mid + 15, ground - 14, 0.8),
                      (mid + 12, ground - 18, 0.7), (mid + 12, ground - 15, 0.6)):
        s.dot(ex, ey, r, eye)
        s.dot(ex + r * 0.3, ey - r * 0.3, r * 0.4, _light(eye, 0.6))
    for fx, drop in ((mid + 15, 4), (mid + 19, 3)):
        s.taper([(fx, ground - 11), (fx + 1.5, ground - 11 + drop), (fx + 1, ground - 4)], BONE, 2.4, 0.2,
                outline=INK, width=0.45)
    s.dot(mid + 16.5, ground - 4.5, 0.8, 0x8CC24A)
    return s


# ---------------------------------------------------------------------------
# The roster
# ---------------------------------------------------------------------------

def rank_and_file():
    """Everything that fills a wave."""
    return [
        # -- Goblinoid: the Ashen Wilds warband ----------------------------
        armoured("goblinArcher", GOBLIN_SKIN, CLOTH_GREEN, RUST, 0xE8C24A,
                 "A goblin archer in a bark jerkin, arrow already nocked.",
                 arm="bow", helm="bare", bulk=0.85),
        robed("goblinShaman", 0x4A5A2E, GOBLIN_SKIN, 0x9FE04A,
              "A goblin shaman rattling a skull-topped stave, calling the warband in.",
              staff="skull", trim=RUST, sigil=0x9FE04A, hood=True),
        armoured("hobgoblin", 0x8A7A38, IRON, BLOOD, 0xE85C2A,
                 "A hobgoblin captain in looted plate, half a head taller than its kin.",
                 arm="axe", helm="horned", bulk=1.25, cape=CLOTH_RED, width=50, height=60),

        # -- Undead --------------------------------------------------------
        armoured("skeletonWarrior", BONE, IRON, RUST, SOUL,
                 "A dead soldier still holding the line, grave-fire in its sockets.",
                 arm="sword", helm="cap"),
        armoured("skeletonArcherFoe", BONE, CLOTH_DARK, BONE_DARK, SOUL,
                 "A fleshless archer, ribs showing through a rotted gambeson.",
                 arm="bow", helm="bare", bulk=0.85),
        quadruped("boneHound", BONE_SHADE, BONE, SOUL,
                  "A hound stripped to the bone, running on will alone.",
                  skeletal=True, tail="bone", width=58),
        floater("wraith", 0x35304A, SOUL,
                "A wraith: a hood, two cold lights, and nothing underneath.",
                shape="shroud"),
        robed("necromancer", 0x241E2E, 0xBFB6A0, SOUL,
              "A necromancer holding a soul-lantern, raising what you have already killed.",
              staff="lantern", trim=SOUL, hood=True, height=58),
        hulk("rotHulk", ROT, BONE, 0xC8E04A,
             "A mound of corpses sewn into one body, still leaking.",
             arms="claws", crown="horns", build="flesh"),

        # -- Beast ---------------------------------------------------------
        quadruped("direWolf", 0x4A4038, 0x8C7E6A, 0xE8C24A,
                  "A dire wolf, shoulders at a man's chest, breath steaming.",
                  width=66, height=46),
        arachnid("giantSpider", 0x3A2A32, 0x9A4A3A, 0xE8D24A,
                 "A spider the size of a cart, venom beading on its fangs."),
        quadruped("corruptedStag", 0x5A4A38, 0x8A7A5E, 0x9FE04A,
                  "A stag the forest rot got into: antlers gone to bone, eyes gone green.",
                  antlers=True, width=66, height=50),

        # -- Demon ---------------------------------------------------------
        flier("impling", 0x9A3A2A, 0x5A1E18, EMBER_HOT,
              "An impling, wings snapping, a cinder already lit in its claws."),
        armoured("hornedFiend", 0x8A3524, 0x4A2018, EMBER, EMBER_HOT,
                 "A horned fiend with a cleaver of black iron.",
                 arm="axe", helm="horned", bulk=1.1, width=48, height=58),
        quadruped("emberHound", 0x5A2318, 0x8A3A22, EMBER_HOT,
                  "A hound out of the Depths, its mane still burning.",
                  mane=EMBER, tail="flame", width=62),
        hulk("brimstoneBrute", 0x6E2A1E, EMBER, EMBER_HOT,
             "A brimstone brute: cracked stone skin over a furnace.",
             arms="fists", crown="spikes", core=EMBER, width=64, height=72, build="stone"),

        # -- Construct -----------------------------------------------------
        armoured("animatedArmour", IRON, IRON_LIGHT, GOLD, 0x7FD8FF,
                 "An empty suit of plate, holding its oath long after the knight stopped.",
                 arm="sword", helm="great", bulk=1.1),
        armoured("runeSentinel", STEEL, 0x4A5668, 0x7FD8FF, 0x7FD8FF,
                 "A sentinel of carved stone, runes lit along its arm.",
                 arm="maul", helm="great", bulk=1.15, width=48, height=58),
        hulk("siegeGolem", 0x4E4A46, GOLD, 0xFFB24A,
             "A siege golem, built to walk through walls and never told to stop.",
             arms="fists", crown="crown", core=0xFFB24A, width=66, height=74, build="stone"),

        # -- Aberration ----------------------------------------------------
        floater("voidling", VOID, VOID_HOT,
                "A voidling: a hole in the world that learned to want.",
                shape="mote", width=38, height=44),
        floater("gazer", 0x4A3A5E, VOID_HOT,
                "A gazer, one great eye hanging in the air on a curtain of tendrils.",
                shape="orb", width=44, height=52),
        hulk("fleshHorror", 0x7A4A54, BLOOD, VOID_HOT,
             "A flesh horror, stitched out of whatever the Shattered Realm had to hand.",
             arms="claws", crown="spikes", width=64, height=70, build="flesh"),

        # -- Cultist -------------------------------------------------------
        robed("cultist", CLOTH_DARK, 0xC2B49A, 0xE85C2A,
              "A hooded cultist with a sacrificial knife, past caring what happens to it.",
              staff="blade", trim=BLOOD, hood=True),
        robed("flagellant", CLOTH_PALE, 0xC2A490, BLOOD,
              "A flagellant wrapped in bloodied linen, running at you with arms wide.",
              staff=None, hood=False, trim=BLOOD),
        robed("cultLeader", 0x3A1E28, 0xC2B49A, 0xE8C24A,
              "A cult leader with a gilded stave, calling the faithful forward.",
              staff="skull", trim=GOLD, sigil=GOLD, hood=True, height=60),

        # -- Elemental -----------------------------------------------------
        floater("frostShard", FROST_DEEP, FROST,
                "A shard of living ice, turning slowly on nothing.",
                shape="shard", width=40, height=46),
        floater("emberWisp", EMBER, EMBER_HOT,
                "An ember wisp, all appetite and no body.",
                shape="mote", width=36, height=42),
        hulk("iceGolem", 0x6E9EB8, FROST, FROST,
             "A golem of black river ice, the cold coming off it in sheets.",
             arms="blades", crown="spikes", core=FROST, width=62, height=70, build="stone"),
    ]


def champions():
    """The realms' bosses.

    Each one holds a wave open by itself, so each one gets a silhouette
    nothing else in its realm shares, and a size to match."""
    return [
        armoured("bossWarchief", 0x7A8A3A, 0x6A5A2E, BLOOD, 0xE8A02A,
                 "Grask the Warchief: the goblin that ate the others.",
                 arm="axe", helm="horned", bulk=1.5, cape=CLOTH_RED, width=62, height=74),
        hulk("bossDrownedKing", 0x3A5A5E, SOUL, SOUL_HOT,
             "The Drowned King, still crowned, still full of the marsh that took him.",
             arms="claws", crown="crown", core=SOUL, width=70, height=80, build="bone"),
        quadruped("bossHollowStag", 0x4A3A2E, BONE_SHADE, 0x9FE04A,
                  "The Hollow Stag: antlers like a dead orchard, and nothing behind the eyes.",
                  antlers=True, mane=0x9FE04A, width=86, height=66),
        hulk("bossRimeTyrant", 0x5A8EAE, FROST, FROST,
             "The Rime Tyrant, who stops hearts at a distance and takes its time walking over.",
             arms="blades", crown="spikes", core=FROST, width=74, height=84, build="stone"),
        robed("bossPlagueMonarch", 0x4A5A2E, ROT, 0xC8E04A,
              "The Plague Monarch, whose court is everything it has already buried.",
              staff="lantern", trim=GOLD, sigil=0xC8E04A, hood=True, width=58, height=76),
        hulk("bossEmberLord", 0x8A2A1A, EMBER, EMBER_HOT,
             "Vaskar the Ember Lord: the Depths stood up and put on a crown.",
             arms="fists", crown="horns", core=EMBER_HOT, width=76, height=88, build="stone"),
        floater("bossVoidmaw", 0x3A2A52, VOID_HOT,
                "Voidmaw, which is only an eye, and only ever looking at you.",
                shape="orb", width=66, height=78),
        armoured("bossIronSaint", 0xA8A49C, IRON, GOLD, 0xFFD07A,
                 "The Iron Saint, still keeping a vow the Citadel forgot it asked for.",
                 arm="maul", helm="great", bulk=1.5, cape=CLOTH_PALE, width=64, height=80),
        hulk("bossGraveWarden", 0x4A4450, BONE, SOUL_HOT,
             "The Grave Warden, who keeps the gate, and has never once opened it.",
             arms="blades", crown="horns", core=SOUL, width=78, height=92, build="bone"),
        floater("bossAbyssalEcho", 0x2A2438, VOID_HOT,
                "The Abyssal Echo: whatever the Abyss has decided you look like.",
                shape="shroud", width=58, height=72),
    ]


def all_sprites():
    return rank_and_file() + champions()


HEADER = '''import UIKit

// Generated by tools/art/bestiary.py. Edit the Python and rerun it; do not
// edit this file by hand.

/// The bestiary: everything that walks a realm looking for the player, and
/// the ten champions that hold a wave open. All face right (+x) and stand on
/// their feet; floaters hang above the ground instead.
///
/// The drawing primitives these call live in PlaceholderArt+Drawing.swift.
extension PlaceholderArt {
'''


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    sprites = all_sprites()
    preview_sheet(sprites, os.path.join(here, "bestiary-preview.png"), columns=6)
    if "--preview" in sys.argv:
        return
    root = os.path.dirname(os.path.dirname(here))
    out = os.path.join(root, "FateLost", "Rendering", "PlaceholderArt+Bestiary.swift")
    body = "\n\n".join("    // MARK: - " + s.name + "\n\n" + s.swift_source() for s in sprites)
    with open(out, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(HEADER + "\n" + body + "\n}\n")
    print(f"wrote {len(sprites)} sprites")


if __name__ == "__main__":
    main()
