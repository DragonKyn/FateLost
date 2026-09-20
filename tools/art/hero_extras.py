"""Extras: cosmetic layers that go over any outfit. Emblems on the chest,
metallic details, and wings behind the body. Each takes a `Geo` and returns a
layer; see herokit.py and hero.py."""
import math

from herokit import (BONE, BONE_SHADE, CX, FOOT, INK, STEEL, STEEL_DARK, STEEL_LIGHT, STEEL_MID, VOID, arc_points, cap,
                     layer, leaf, rect, star)

VINE = 0x4E9A3E
VINE_LIGHT = 0x7CCB58
VINE_DARK = 0x2F6A2A
FLOWER = 0xF0D8E8


# -- emblems ----------------------------------------------------------------

def dragon(g):
    s = layer(f"heroEmblemDragon{cap(g.build)}", f"A heraldic dragon's head across the chest of a {g.build} frame.")
    x, y = CX, g.sy + 6.5
    k = g.sw / 10
    k = max(0.85, min(1.2, k))
    # Swept wings either side of the head.
    for side in (-1, 1):
        s.taper([(x + side * 3.4 * k, y - 0.5), (x + side * 7.4 * k, y - 4.2), (x + side * 10.6 * k, y - 3.6)], "trim:0.85",
                1.8, 0.2, outline=INK, width=0.4)
        s.taper([(x + side * 3.4 * k, y + 1.6), (x + side * 7 * k, y + 0.4), (x + side * 9.4 * k, y + 2.6)], "trim:0.7",
                1.5, 0.2, outline=INK, width=0.4)
        s.taper([(x + side * 2.4 * k, y - 3), (x + side * 4 * k, y - 6.6), (x + side * 3.4 * k, y - 8.6)], "trim",
                1.6, 0.1, outline=INK, width=0.4)
    head = [(x - 3.4 * k, y - 2.4), (x, y - 4.4), (x + 3.4 * k, y - 2.4), (x + 2.4 * k, y + 2.2), (x, y + 5.2),
            (x - 2.4 * k, y + 2.2)]
    s.poly(head, "trim", outline=INK, width=0.6)
    s.poly([(x, y - 4.4), (x + 3.4 * k, y - 2.4), (x + 2.4 * k, y + 2.2), (x, y + 5.2)], "trim:0.75")
    for side in (-1, 1):
        s.ellipse(x + side * 1.7 * k - 0.9, y - 1.6, 1.8, 1.0, VOID)
        s.dot(x + side * 1.7 * k, y - 1.1, 0.42, "eyes")
        s.dot(x + side * 0.7 * k, y + 3.4, 0.4, VOID)
        s.poly([(x + side * 1.6 * k, y + 3.4), (x + side * 2 * k, y + 5), (x + side * 1.1 * k, y + 3.8)], 0xF2EEE4)
    return s


def runes(g):
    s = layer(f"heroEmblemRunes{cap(g.build)}", f"A ring of arcane runes on the chest of a {g.build} frame.")
    x, y = CX, g.sy + 6.5
    r = 5.6 * max(0.85, min(1.15, g.sw / 10))
    ring = arc_points(x, y, r, 0, 2 * math.pi, 22)
    s.curve(ring, ("eyes", 0.3), 2.6)
    s.curve(ring, "eyes", 0.8)
    inner = arc_points(x, y, r * 0.55, 0, 2 * math.pi, 16)
    s.curve(inner, ("eyes", 0.7), 0.5)
    # Three glyphs, and a mark in the middle.
    s.line((x, y - 4.2), (x, y - 1.6), "eyes", 0.8)
    s.line((x - 1.6, y - 3.4), (x, y - 2.2), "eyes", 0.8)
    s.line((x + 1.6, y - 3.4), (x, y - 2.2), "eyes", 0.8)
    s.line((x - 3.6, y + 0.6), (x - 1.2, y + 3.4), "eyes", 0.8)
    s.line((x - 1.2, y + 0.6), (x - 3.6, y + 3.4), "eyes", 0.8)
    s.curve([(x + 1.4, y + 0.6), (x + 3.4, y + 1.4), (x + 1.6, y + 2.2), (x + 3.4, y + 3.4)], "eyes", 0.8)
    s.dot(x, y + 0.2, 0.7, ("eyes", 0.9))
    return s


def skulls(g):
    s = layer(f"heroEmblemSkulls{cap(g.build)}", f"A skull and crossed bones on the chest of a {g.build} frame.")
    x, y = CX, g.sy + 6.5
    for side in (-1, 1):
        s.line((x - side * 5, y - 2.4), (x + side * 5, y + 5.2), BONE_SHADE, 1.7)
        s.dot(x - side * 5.2, y - 2.6, 1.05, BONE)
        s.dot(x + side * 5.2, y + 5.4, 1.05, BONE)
    s.ellipse(x - 3.8, y - 4.6, 7.6, 6.6, BONE, outline=INK, width=0.6)
    s.ellipse(x - 2.5, y + 0.6, 5, 3.4, BONE, outline=INK, width=0.5)
    s.ellipse(x - 3.6, y - 4.4, 3, 1.8, 0xFFFFFF)
    for side in (-1, 1):
        s.ellipse(x + side * 1.8 - 1.2, y - 2.6, 2.4, 2.6, VOID)
        s.dot(x + side * 1.8, y - 1.6, 0.5, "eyes")
    s.poly([(x, y - 0.5), (x - 0.7, y + 0.9), (x + 0.7, y + 0.9)], VOID)
    for dx in (-1.2, 0, 1.2):
        s.line((x + dx, y + 2), (x + dx, y + 3.6), VOID, 0.4)
    return s


def vines(g):
    s = layer(f"heroEmblemVines{cap(g.build)}", f"Vines climbing the outfit of a {g.build} frame.")
    # One climbs the left side from the hem, one the right, and they meet at the shoulder.
    left = [(CX - g.hw + 2, g.hem - 1), (CX - g.hw + 5, g.hem - 9), (CX - g.sw + 1.5, g.sy + 12),
            (CX - g.sw + 5, g.sy + 5), (CX - 3, g.sy + 1.5)]
    right = [(CX + g.hw - 2, g.hem - 1), (CX + g.hw - 5, g.hem - 8), (CX + g.sw - 1.5, g.sy + 14),
             (CX + g.sw - 4, g.sy + 8)]
    s.curve(left, VINE_DARK, 2.0)
    s.curve(left, VINE, 1.3)
    s.curve(right, VINE_DARK, 2.0)
    s.curve(right, VINE, 1.3)
    for points in (left, right):
        for i, (px, py) in enumerate(points[1:], start=1):
            side = -1 if i % 2 else 1
            leaf(s, px, py, math.pi / 2 * (1 + side * 0.9) - 0.4, 5.2, 1.9, VINE_LIGHT if i % 2 else VINE, rib=VINE_DARK)
    for px, py in ((left[2][0] + 1.2, left[2][1] - 1.6), (right[2][0] - 1.2, right[2][1] - 1.4), (left[4][0], left[4][1] + 0.6)):
        s.dot(px, py, 1.5, FLOWER)
        s.dot(px, py, 0.6, "trim")
    return s


def celestial(g):
    s = layer(f"heroEmblemCelestial{cap(g.build)}", f"A crescent and stars across the chest of a {g.build} frame.")
    x, y = CX, g.sy + 6.5
    k = max(0.85, min(1.15, g.sw / 10))
    outer = arc_points(x, y, 5.4 * k, math.radians(58), math.radians(302), 18)
    inner = arc_points(x + 2.6 * k, y, 4.4 * k, math.radians(300), math.radians(60), 18)
    s.poly(outer + inner, "trim", outline=INK, width=0.5)
    star(s, x + 4.2 * k, y - 3.2 * k, 2.2 * k, "trim")
    star(s, x + 5 * k, y + 3.4 * k, 1.5 * k, "trim")
    star(s, x - 6.4 * k, y + 5.6 * k, 1.4 * k, "trim")
    star(s, x - 7 * k, y - 3.6 * k, 1.1 * k, "trim")
    for dx, dy in ((-9, 0.5), (7.8, 0.8), (1.6, -6), (-4, 10), (5, 9.4)):
        s.dot(x + dx * k, y + dy, 0.55, ("trim", 0.85))
    return s


# -- metallic details -------------------------------------------------------

def studs(g):
    s = layer(f"heroDetailStuds{cap(g.build)}", f"Riveted metal studding on a {g.build} frame.")
    n = int(g.sw)
    for i in range(n // 2 + 1):
        for side in (-1, 1) if i else (1,):
            x = CX + side * i * 2.2
            if abs(x - CX) <= g.sw - 1:
                s.dot(x, g.sy + 1.6, 0.85, STEEL_LIGHT)
                s.dot(x, g.sy + 1.6, 0.4, STEEL_DARK)
    row = g.hem - 1.6
    for i in range(-int(g.hw // 2.4), int(g.hw // 2.4) + 1):
        s.dot(CX + i * 2.4, row, 0.85, STEEL_LIGHT)
        s.dot(CX + i * 2.4, row, 0.4, STEEL_DARK)
    for side in (-1, 1):
        for dy in (5, 9):
            s.dot(CX + side * (g.edge(g.sy + dy) - 1.4), g.sy + dy, 0.8, STEEL_LIGHT)
    return s


def filigree(g):
    s = layer(f"heroDetailFiligree{cap(g.build)}", f"Fine metalwork curling over a {g.build} frame.")
    for side in (-1, 1):
        s.curve([(CX + side * 3.6, g.sy + 1), (CX + side * 6.4, g.sy + 4.6), (CX + side * 3.4, g.sy + 8.2),
                 (CX + side * 5.6, g.sy + 11.6)], "trim", 0.9)
        s.curve([(CX + side * (g.sw - 1), g.sy + 3), (CX + side * (g.sw - 3.6), g.sy + 6), (CX + side * (g.sw - 2), g.sy + 9)],
                "trim:0.85", 0.7)
        s.dot(CX + side * 5.6, g.sy + 11.6, 0.9, "trim")
    # A scalloped line along the hem, and a bead at each turn.
    points = []
    steps = 8
    for i in range(steps + 1):
        x = CX - g.hw + 1.5 + i * (2 * g.hw - 3) / steps
        points.append((x, g.hem - 3.2 + (1.3 if i % 2 else 0)))
    s.curve(points, "trim", 0.9)
    for x, y in points[::2]:
        s.dot(x, y, 0.75, "trim")
    star(s, CX, g.sy + 3.6, 1.5, "trim")
    return s


def pauldrons(g):
    s = layer(f"heroDetailPauldrons{cap(g.build)}", f"Steel pauldrons on a {g.build} frame.")
    for side in (-1, 1):
        cx = CX + side * (g.sw + 0.5)
        s.ellipse(cx - 6, g.sy - 3, 12, 8.4, STEEL_LIGHT if side < 0 else STEEL, outline=INK, width=1.0)
        s.ellipse(cx - 4.6, g.sy - 1.4, 9.2, 6, STEEL if side < 0 else STEEL_MID)
        s.curve([(cx - 4.6, g.sy - 0.2), (cx, g.sy - 1.4), (cx + 4.6, g.sy - 0.2)], "trim", 0.9)
        s.line((cx - 3.6, g.sy + 3.4), (cx + 3.6, g.sy + 3.4), "trim:0.8", 0.8)
        s.dot(cx, g.sy + 1.4, 0.9, "trim")
        s.taper([(cx, g.sy - 2.6), (cx + side * 1.4, g.sy - 6), (cx + side * 1.8, g.sy - 9)], STEEL_LIGHT, 2.0, 0.1,
                outline=INK, width=0.5)
    return s


def war_plate(g):
    s = layer(f"heroDetailWarPlate{cap(g.build)}", f"Full plate over the chest, neck and shoulders of a {g.build} frame.")
    # Tassets at the hip.
    for side in (-1, 1):
        s.poly([(CX + side * 2, g.hem - 6), (CX + side * (g.hw - 1), g.hem - 6), (CX + side * (g.hw - 1.6), g.hem + 1),
                (CX + side * 3, g.hem + 1.6)], STEEL if side < 0 else STEEL_MID, outline=INK, width=0.8)
    # The breastplate.
    chest = [(CX - g.sw + 1, g.sy + 0.6), (CX + g.sw - 1, g.sy + 0.6), (CX + g.sw - 2.4, g.sy + 11), (CX, g.sy + 14),
             (CX - g.sw + 2.4, g.sy + 11)]
    s.poly(chest, STEEL_LIGHT, outline=INK, width=1.0)
    s.poly([(CX, g.sy + 0.6), (CX + g.sw - 1, g.sy + 0.6), (CX + g.sw - 2.4, g.sy + 11), (CX, g.sy + 14)], STEEL)
    s.line((CX, g.sy + 0.6), (CX, g.sy + 14), "trim", 1.0)
    s.curve([(CX - g.sw + 2, g.sy + 5.4), (CX, g.sy + 7.4), (CX + g.sw - 2, g.sy + 5.4)], "trim:0.8", 0.8)
    # Gorget.
    s.poly([(CX - 6.6, g.sy - 3.6), (CX + 6.6, g.sy - 3.6), (CX + 7.8, g.sy + 1.2), (CX - 7.8, g.sy + 1.2)], STEEL_LIGHT,
           outline=INK, width=0.9)
    s.line((CX - 6, g.sy - 1.2), (CX + 6, g.sy - 1.2), "trim:0.8", 0.7)
    # Spiked pauldrons.
    for side in (-1, 1):
        cx = CX + side * (g.sw + 1)
        s.ellipse(cx - 6.4, g.sy - 3.6, 12.8, 9.4, STEEL_LIGHT if side < 0 else STEEL, outline=INK, width=1.0)
        s.ellipse(cx - 5, g.sy - 2, 10, 6.4, STEEL if side < 0 else STEEL_MID)
        s.curve([(cx - 5, g.sy - 0.4), (cx, g.sy - 1.8), (cx + 5, g.sy - 0.4)], "trim", 1.0)
        s.taper([(cx, g.sy - 3), (cx + side * 1.6, g.sy - 7.4), (cx + side * 2.2, g.sy - 11)], STEEL_LIGHT, 2.4, 0.1,
                outline=INK, width=0.5)
        s.dot(cx, g.sy + 2.2, 1.0, "trim")
    return s


# -- wings ------------------------------------------------------------------

def angel(g):
    s = layer(f"heroWingsAngel{cap(g.build)}", f"A pair of white feathered wings behind a {g.build} frame.")
    for side in (-1, 1):
        bx, by = CX + side * 6, g.sy + 3
        # Two banks of feathers, the back one darker, fanned from up to down.
        for bank, (shade, edge, scale, count) in enumerate(((0xC9C3B4, 0xA6A08F, 1.0, 9),
                                                            (0xF4F1E8, 0xD6D1C2, 0.78, 8))):
            for j in range(count):
                t = j / (count - 1)
                angle = math.radians(-72 + t * 104)
                # Longest along the top edge, shortening toward the body.
                length = (24 - t * 8) * scale
                direction = (side * math.cos(angle), math.sin(angle))
                start = (bx + side * (1.0 + bank * 2), by - 3 + bank * 2 + t * 3)
                bend = 0.18 * side
                mid = (start[0] + direction[0] * length * 0.5, start[1] + direction[1] * length * 0.5)
                end = (start[0] + direction[0] * length + bend * length * 0.2, start[1] + direction[1] * length + length * 0.12)
                s.taper([start, mid, end], shade, 6.0 - bank * 0.6, 2.0, outline=INK, width=0.5)
                s.line(start, mid, edge, 0.4)
        # Short covert feathers where the wing meets the shoulder.
        for k in range(4):
            s.ellipse(bx + side * (2 + k * 3.4) - 2.6, by - 9 + k * 1.6, 5.6, 6.4, 0xFAF7EE, outline=INK, width=0.4)
        # The wing's arm, along the leading edge.
        s.curve([(bx, by - 1), (bx + side * 6, by - 11), (bx + side * 12, by - 17)], 0xE6E0D0, 2.0)
    return s


def demon(g):
    s = layer(f"heroWingsDemon{cap(g.build)}", f"A pair of leathery bat wings behind a {g.build} frame.")
    for side in (-1, 1):
        bx, by = CX + side * 6, g.sy + 2
        elbow = (bx + side * 8, by - 15)
        wrist = (bx + side * 21, by - 21)
        tips = [(bx + side * 24, by - 3), (bx + side * 20, by + 9), (bx + side * 14, by + 15), (bx + side * 7, by + 12)]
        # The membrane, scalloped between the finger bones.
        scallops = [wrist]
        for i, tip in enumerate(tips):
            scallops.append(tip)
            if i < len(tips) - 1:
                nxt = tips[i + 1]
                scallops.append(((tip[0] + nxt[0]) / 2 - side * 1.6, (tip[1] + nxt[1]) / 2 - 2.2))
        outline = [(bx, by), elbow] + scallops + [(bx + side * 2, by + 9)]
        s.poly(outline, 0x5A1418, outline=INK, width=0.9)
        s.poly([(bx, by + 3), (bx + side * 10, by - 4)] + scallops[2:] + [(bx + side * 2, by + 9)], ("cloak:0.5", 0.3))
        # Finger bones, and the arm.
        s.taper([(bx, by), elbow, wrist], 0x2E1A1A, 3.0, 1.2, outline=INK, width=0.5)
        for tip in tips:
            s.taper([elbow if tip == tips[0] else (bx + side * 4, by), (wrist[0] * 0.5 + tip[0] * 0.5, wrist[1] * 0.5 + tip[1] * 0.5), tip],
                    0x33201F, 1.6, 0.3, outline=INK, width=0.4)
        # A claw at the wrist.
        s.taper([wrist, (wrist[0] + side * 3, wrist[1] - 2), (wrist[0] + side * 4.6, wrist[1] - 5.8)], BONE, 1.8, 0.1,
                outline=INK, width=0.4)
        s.line((bx + side * 4, by - 6), (bx + side * 10, by - 9), 0x8A2A30, 0.5)
    return s


EMBLEMS = {"dragon": dragon, "runes": runes, "skulls": skulls, "vines": vines, "celestial": celestial}
DETAILS = {"studs": studs, "filigree": filigree, "pauldrons": pauldrons, "warPlate": war_plate}
WINGS = {"angel": angel, "demon": demon}
