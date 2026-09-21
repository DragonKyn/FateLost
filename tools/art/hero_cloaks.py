"""The hero's cloaks and outfits, one function per style. Each takes a `Geo`
and returns a layer; see herokit.py and hero.py."""
import math

from herokit import (BELT, BONE_SHADE, CX, FOOT, INK, LEATHER, LEATHER_DARK, STEEL, STEEL_DARK, STEEL_LIGHT, STEEL_MID,
                     IVORY, VOID, Geo, belt, cap, layer, leaf, rect, star)

FEATHER = 0xF3F1EA
FEATHER_SHADE = 0xC9CCD8
FEATHER_EDGE = 0x9299AE
GOLD = 0xD9B45A


def hooded(g):
    s = layer(f"heroCloakHooded{cap(g.build)}", f"A straight wayfarer's cloak on a {g.build} frame.")
    peak = (CX, g.sy - 8)
    body = [peak, (CX - g.sw, g.sy), (CX - g.hw, g.hem), (CX + g.hw, g.hem), (CX + g.sw, g.sy)]
    s.poly(body, "cloak")
    s.poly([peak, (CX + g.sw, g.sy), (CX + g.hw, g.hem), (CX + 1, g.hem)], "cloak:0.75")
    s.outline(body, INK, 1.2)
    s.line((CX - g.hw + 2, g.hem - 2.6), (CX + g.hw - 2, g.hem - 2.6), ("trim", 0.75), 1.3)
    belt(s, g, g.sy + 12)
    s.dot(CX, g.sy + 1.5, 1.3, "trim")
    return s


def mantle(g):
    s = layer(f"heroCloakMantle{cap(g.build)}", f"A tunic under a short shoulder mantle on a {g.build} frame.")
    tunic = [(CX - g.sw + 1, g.sy), (CX + g.sw - 1, g.sy), (CX + g.hw - 2, g.hem), (CX - g.hw + 2, g.hem)]
    s.poly(tunic, LEATHER)
    s.poly([(CX, g.sy), (CX + g.sw - 1, g.sy), (CX + g.hw - 2, g.hem), (CX, g.hem)], LEATHER_DARK)
    s.outline(tunic, INK, 1.1)
    rect(s, CX - g.hw + 2, g.hem - 2.4, 2 * g.hw - 4, 2.4, "trim:0.7")
    belt(s, g, g.sy + 13.5)
    cape = [(CX, g.sy - 3), (CX - g.sw - 1.5, g.sy + 0.5), (CX - g.sw - 5, g.sy + 10),
            (CX - g.sw * 0.4, g.sy + 12), (CX + g.sw * 0.4, g.sy + 12), (CX + g.sw + 5, g.sy + 10),
            (CX + g.sw + 1.5, g.sy + 0.5)]
    s.poly(cape, "cloak")
    s.poly([(CX, g.sy - 3), (CX + g.sw + 1.5, g.sy + 0.5), (CX + g.sw + 5, g.sy + 10),
            (CX + g.sw * 0.4, g.sy + 12), (CX, g.sy + 11.4)], "cloak:0.75")
    s.outline(cape, INK, 1.2)
    s.curve([(CX - g.sw - 4.4, g.sy + 9.2), (CX - g.sw * 0.4, g.sy + 11.2), (CX + g.sw * 0.4, g.sy + 11.2),
             (CX + g.sw + 4.4, g.sy + 9.2)], "trim", 1.2)
    s.dot(CX, g.sy - 0.5, 1.4, "trim")
    return s


def long_coat(g):
    s = layer(f"heroCloakLongCoat{cap(g.build)}", f"A buttoned coat to the knee on a {g.build} frame.")
    hem = g.hem + 5
    lo = g.hw - 1
    body = [(CX, g.sy - 5), (CX - g.sw, g.sy), (CX - lo, hem), (CX + lo, hem), (CX + g.sw, g.sy)]
    s.poly(body, "cloak")
    s.poly([(CX, g.sy - 5), (CX + g.sw, g.sy), (CX + lo, hem), (CX, hem)], "cloak:0.75")
    s.outline(body, INK, 1.2)
    s.poly([(CX, g.sy - 1), (CX - 4.6, g.sy + 1), (CX - 1.6, g.sy + 9)], "cloak:1.3", outline=INK, width=0.7)
    s.poly([(CX, g.sy - 1), (CX + 4.6, g.sy + 1), (CX + 1.6, g.sy + 9)], "cloak:1.05", outline=INK, width=0.7)
    s.line((CX, g.sy + 9), (CX, hem), "cloak:0.4", 1.0)
    for dy in (11, 16, 21):
        s.dot(CX + 2.2, g.sy + dy, 0.95, "trim")
    belt(s, g, g.sy + 12)
    rect(s, CX - lo + 1.5, hem - 2.4, 2 * lo - 3, 2.4, "trim:0.7")
    return s


def shroud(g):
    s = layer(f"heroCloakShroud{cap(g.build)}", f"A ragged shroud with a torn hem on a {g.build} frame.")
    peak = (CX, g.sy - 8)
    steps = 7
    ragged = []
    for i in range(steps + 1):
        x = CX - g.hw - 1 + i * (2 * g.hw + 2) / steps
        ragged.append((x, g.hem + 3 + (3.4 if i % 2 == 0 else -1.6)))
    body = [peak, (CX - g.sw, g.sy)] + ragged + [(CX + g.sw, g.sy)]
    s.poly(body, "cloak:0.92")
    yb = g.hem - 5
    s.poly([(CX - g.edge(yb), yb)] + ragged + [(CX + g.edge(yb), yb)], ("cloak:0.6", 0.7))
    s.poly([peak, (CX + g.sw, g.sy), ragged[-1], ragged[len(ragged) // 2]], ("cloak:0.6", 0.55))
    s.outline(body, INK, 1.2)
    for i in (1, 3, 5):
        x, y = ragged[i]
        s.line((x, y - 1.2), (x + 0.4, y - 6.5), "cloak:0.35", 0.8)
    rect(s, CX - g.sw + 1, g.sy + 12, 2 * g.sw - 2, 2.2, "trim:0.55")
    s.dot(CX + 3.4, g.sy + 13.4, 1.5, "trim:0.8")
    s.line((CX + 3.4, g.sy + 14), (CX + 5, g.sy + 19), "trim:0.55", 1.0)
    return s


def pilgrim(g):
    s = layer(f"heroCloakPilgrim{cap(g.build)}", f"A long cloak, a yoke and a high collar on a {g.build} frame.")
    peak = (CX, g.sy - 8)
    body = [peak, (CX - g.sw, g.sy), (CX - g.hw, g.hem), (CX + g.hw, g.hem), (CX + g.sw, g.sy)]
    s.poly(body, "cloak")
    s.poly([peak, (CX + g.sw, g.sy), (CX + g.hw, g.hem), (CX + 1, g.hem)], "cloak:0.75")
    s.outline(body, INK, 1.2)
    belt(s, g, g.sy + 13.5)
    yoke = [(CX, g.sy - 3), (CX - g.sw - 4, g.sy + 1.5), (CX - g.sw - 5, g.sy + 11),
            (CX + g.sw + 5, g.sy + 11), (CX + g.sw + 4, g.sy + 1.5)]
    s.poly(yoke, "cloak:1.2")
    s.poly([(CX, g.sy - 3), (CX + g.sw + 4, g.sy + 1.5), (CX + g.sw + 5, g.sy + 11), (CX, g.sy + 11)], "cloak:0.95")
    s.outline(yoke, INK, 1.2)
    s.line((CX - g.sw - 4.4, g.sy + 9.6), (CX + g.sw + 4.4, g.sy + 9.6), "trim", 1.3)
    s.poly([(CX - 3, g.sy - 7), (CX - 8.5, g.sy - 11.5), (CX - 9.5, g.sy + 0.5), (CX - 3, g.sy + 1.5)],
           "cloak:0.9", outline=INK, width=1.0)
    s.poly([(CX + 3, g.sy - 7), (CX + 8.5, g.sy - 11.5), (CX + 9.5, g.sy + 0.5), (CX + 3, g.sy + 1.5)],
           "cloak:0.62", outline=INK, width=1.0)
    s.line((CX - 8.5, g.sy - 10), (CX - 9, g.sy - 1), "trim", 0.9)
    s.line((CX + 8.5, g.sy - 10), (CX + 9, g.sy - 1), "trim", 0.9)
    return s


def vampire(g):
    s = layer(f"heroCloakVampire{cap(g.build)}", f"A high-collared opera cloak, lined in colour, on a {g.build} frame.")
    hem = g.hem + 4
    flare = g.hw + 5
    # The waistcoat and frilled shirt showing through the open front.
    s.poly([(CX - 6, g.sy), (CX + 6, g.sy), (CX + 7, hem - 3), (CX - 7, hem - 3)], 0x1C1820, outline=INK, width=0.8)
    s.poly([(CX - 4, g.sy - 1), (CX + 4, g.sy - 1), (CX + 3, g.sy + 4), (CX + 1.5, g.sy + 6), (CX, g.sy + 4.4),
            (CX - 1.5, g.sy + 6), (CX - 3, g.sy + 4)], IVORY, outline=INK, width=0.6)
    for dy in (9, 13):
        s.dot(CX, g.sy + dy, 0.8, "trim")
    # Two long panels of cloak, the lining showing along each inside edge.
    left = [(CX - 3, g.sy - 3), (CX - g.sw - 1, g.sy), (CX - flare, hem), (CX - 5.5, hem)]
    right = [(CX + 3, g.sy - 3), (CX + g.sw + 1, g.sy), (CX + flare, hem), (CX + 5.5, hem)]
    s.poly(left, "cloak")
    s.poly(right, "cloak:0.72")
    s.poly([(CX - 3, g.sy - 3), (CX - 5.5, hem), (CX - 8.5, hem), (CX - 6, g.sy)], "trim:0.7")
    s.poly([(CX + 3, g.sy - 3), (CX + 5.5, hem), (CX + 8.5, hem), (CX + 6, g.sy)], "trim:0.5")
    s.outline(left, INK, 1.1)
    s.outline(right, INK, 1.1)
    # The collar, standing up behind the head in two points.
    s.poly([(CX - 4, g.sy - 1), (CX - 12.5, g.sy - 17), (CX - 10.5, g.sy + 1)], "cloak:0.9", outline=INK, width=1.0)
    s.poly([(CX - 4, g.sy - 1), (CX - 10.8, g.sy - 14), (CX - 9.6, g.sy - 1)], "trim:0.7")
    s.poly([(CX + 4, g.sy - 1), (CX + 12.5, g.sy - 17), (CX + 10.5, g.sy + 1)], "cloak:0.65", outline=INK, width=1.0)
    s.poly([(CX + 4, g.sy - 1), (CX + 10.8, g.sy - 14), (CX + 9.6, g.sy - 1)], "trim:0.5")
    # A clasp and its chain.
    s.dot(CX - 4.6, g.sy + 1.5, 1.3, "trim")
    s.dot(CX + 4.6, g.sy + 1.5, 1.3, "trim")
    s.curve([(CX - 4.6, g.sy + 2.4), (CX, g.sy + 5), (CX + 4.6, g.sy + 2.4)], "trim", 0.6)
    return s


def wizard(g):
    s = layer(f"heroCloakWizard{cap(g.build)}", f"A long star-strewn robe with bell sleeves on a {g.build} frame.")
    hem = FOOT - 3
    bottom = g.hw + 2
    body = [(CX, g.sy - 7), (CX - g.sw, g.sy), (CX - bottom, hem), (CX + bottom, hem), (CX + g.sw, g.sy)]
    s.poly(body, "cloak")
    s.poly([(CX, g.sy - 7), (CX + g.sw, g.sy), (CX + bottom, hem), (CX + 1, hem)], "cloak:0.75")
    s.outline(body, INK, 1.2)
    # Bell sleeves hanging from the shoulders.
    for side in (-1, 1):
        shade = "cloak:0.9" if side < 0 else "cloak:0.68"
        x0 = CX + side * g.sw
        sleeve = [(x0 - side * 1.5, g.sy + 1), (x0 + side * 3.5, g.sy + 3), (x0 + side * 9, g.sy + 21),
                  (x0 + side * 0.5, g.sy + 23)]
        s.poly(sleeve, shade, outline=INK, width=1.0)
        s.line((x0 + side * 9, g.sy + 21), (x0 + side * 0.5, g.sy + 23), "trim", 1.6)
    # A rope belt with tassels, and stars.
    rect(s, CX - g.sw + 1, g.sy + 13, 2 * g.sw - 2, 2, "trim:0.7")
    s.line((CX + 2, g.sy + 15), (CX + 2.6, g.sy + 22), "trim:0.7", 1.0)
    s.line((CX + 4.4, g.sy + 15), (CX + 5, g.sy + 21), "trim:0.7", 1.0)
    for x, y, r in ((CX - 4, g.sy + 22, 1.9), (CX + 4, g.sy + 30, 1.6), (CX - 7, g.sy + 33, 1.3), (CX - 1, g.sy + 5, 1.5)):
        if y < hem - 3:
            star(s, x, y, r, "trim")
    rect(s, CX - bottom + 1, hem - 2.6, 2 * bottom - 2, 2.6, "trim:0.7")
    return s


def ninja(g):
    s = layer(f"heroCloakNinja{cap(g.build)}", f"A wrapped shinobi garb with a knotted scarf on a {g.build} frame.")
    hem = g.hem - 3
    # Shin wraps over the legs.
    for x in g.legs_x:
        for y in (FOOT - 13, FOOT - 10, FOOT - 7):
            rect(s, x - 0.3, y, g.leg + 0.6, 1.8, "cloak:0.55")
    body = [(CX - g.sw, g.sy - 1), (CX + g.sw, g.sy - 1), (CX + g.hw - 3, hem), (CX - g.hw + 3, hem)]
    s.poly(body, "cloak:0.5")
    s.poly([(CX, g.sy - 1), (CX + g.sw, g.sy - 1), (CX + g.hw - 3, hem), (CX, hem)], "cloak:0.38")
    s.outline(body, INK, 1.1)
    # A wrapped sash crossing the chest, and the belt.
    s.poly([(CX - g.sw + 0.5, g.sy + 1), (CX - g.sw + 4.5, g.sy + 1), (CX + 3.5, g.sy + 14), (CX - 0.5, g.sy + 14)],
           "trim:0.55")
    rect(s, CX - g.sw + 1, g.sy + 13.5, 2 * g.sw - 2, 3, "trim:0.4")
    s.dot(CX + 4, g.sy + 15, 1.4, "trim")
    star(s, CX - 5, g.sy + 15.4, 2.1, STEEL_LIGHT)
    # The scarf: knotted at the neck, its two tails hanging down the back. They
    # are cloth, so they hang; the sway (CapeSway) lifts and trails them.
    s.blob([(CX - 2, g.sy - 3.5), (CX - 8, g.sy - 3), (CX - 9.5, g.sy + 1), (CX - 4, g.sy + 2.5), (CX - 1.5, g.sy + 0.5)],
           "trim:0.85", outline=INK, width=0.9)
    long_tail = [(CX - 7, g.sy + 0.5), (CX - 11.5, g.sy + 1.5), (CX - 13.5, g.sy + 12), (CX - 14.5, g.sy + 19),
                 (CX - 11.5, g.sy + 17), (CX - 8.5, g.sy + 19), (CX - 6.5, g.sy + 8)]
    s.blob(long_tail, "trim:0.7", outline=INK, width=0.8)
    short_tail = [(CX - 4, g.sy + 1), (CX - 8, g.sy + 3), (CX - 9.5, g.sy + 11), (CX - 7.5, g.sy + 10.5), (CX - 5.5, g.sy + 12),
                  (CX - 3.6, g.sy + 5)]
    s.blob(short_tail, "trim:0.55", outline=INK, width=0.7)
    s.curve([(CX - 8, g.sy + 3), (CX - 10.4, g.sy + 10), (CX - 11.6, g.sy + 16)], "trim:0.42", 0.5)
    return s


def samurai(g):
    s = layer(f"heroCloakSamurai{cap(g.build)}", f"A kimono, hakama and winged shoulders on a {g.build} frame.")
    waist = g.sy + g.torso * 0.5
    hakama = [(CX - g.sw + 1, waist), (CX + g.sw - 1, waist), (CX + g.hw + 3, g.hem + 4), (CX - g.hw - 3, g.hem + 4)]
    s.poly(hakama, "cloak:0.55")
    s.poly([(CX, waist), (CX + g.sw - 1, waist), (CX + g.hw + 3, g.hem + 4), (CX, g.hem + 4)], "cloak:0.42")
    s.outline(hakama, INK, 1.1)
    for i in (-2, -1, 1, 2):
        s.line((CX + i * 2.6, waist + 3), (CX + i * 3.8, g.hem + 3), "cloak:0.3", 0.6)
    top = [(CX - g.sw, g.sy), (CX + g.sw, g.sy), (CX + g.sw - 1, waist + 1), (CX - g.sw + 1, waist + 1)]
    s.poly(top, "cloak")
    s.poly([(CX, g.sy), (CX + g.sw, g.sy), (CX + g.sw - 1, waist + 1), (CX, waist + 1)], "cloak:0.78")
    s.outline(top, INK, 1.1)
    # The crossed collar.
    s.poly([(CX - 4.6, g.sy - 1), (CX - 1, g.sy - 1), (CX + 3, waist - 1), (CX - 0.4, waist - 1)], IVORY,
           outline=INK, width=0.6)
    s.poly([(CX + 4.6, g.sy - 1), (CX + 1, g.sy - 1), (CX - 3, waist - 1), (CX + 0.4, waist - 1)], "trim:0.9",
           outline=INK, width=0.6)
    rect(s, CX - g.sw + 1, waist - 1, 2 * g.sw - 2, 3.4, "trim:0.7")
    # The winged shoulders of a formal jacket.
    for side in (-1, 1):
        shade = "cloak:1.12" if side < 0 else "cloak:0.85"
        x0 = CX + side * 2
        wing = [(x0, g.sy - 4), (CX + side * (g.sw + 8), g.sy - 1.5), (CX + side * (g.sw + 5.5), g.sy + 10),
                (x0, g.sy + 8)]
        s.poly(wing, shade, outline=INK, width=1.0)
        s.line((CX + side * (g.sw + 7.6), g.sy - 0.4), (CX + side * (g.sw + 5.2), g.sy + 9), "trim:0.8", 0.9)
    s.ellipse(CX - 2.4, g.sy + 3.2, 4.8, 4.8, "trim:0.85", outline=INK, width=0.5)
    return s


def druid(g):
    s = layer(f"heroCloakDruid{cap(g.build)}", f"A leaf-mantled robe with a vine belt on a {g.build} frame.")
    peak = (CX, g.sy - 8)
    steps = 6
    points = []
    for i in range(steps + 1):
        x = CX - g.hw + i * 2 * g.hw / steps
        points.append((x, g.hem + (4 if i % 2 == 0 else -0.5)))
    body = [peak, (CX - g.sw, g.sy)] + points + [(CX + g.sw, g.sy)]
    s.poly(body, "cloak:0.7")
    s.poly([peak, (CX + g.sw, g.sy), points[-1], points[3]], "cloak:0.52")
    s.outline(body, INK, 1.2)
    # A vine belt with a small pouch.
    s.curve([(CX - g.sw, g.sy + 12), (CX - g.sw * 0.4, g.sy + 14), (CX + g.sw * 0.4, g.sy + 11), (CX + g.sw, g.sy + 13)],
            "trim:0.7", 1.5)
    rect(s, CX + 2, g.sy + 12, 5, 5, LEATHER, outline=INK, width=0.6)
    # A mantle of overlapping leaves.
    for i in range(4):
        x = CX + (i - 1.5) * g.sw / 1.7
        leaf(s, x, g.sy + 4, math.pi / 2 + (i - 1.5) * 0.32, 9, 3.4, "cloak:1.15" if i % 2 else "cloak:1.4", rib="cloak:0.35")
    for i in range(5):
        x = CX + (i - 2) * g.sw / 1.9
        leaf(s, x, g.sy - 1 + abs(i - 2) * 0.9, math.pi / 2 + (i - 2) * 0.42, 10, 3.6,
             "cloak:1.5" if i % 2 == 0 else "cloak:1.25", rib="cloak:0.35")
    # Leaves at the hem, and a berry.
    for i in (-2, 0, 2):
        leaf(s, CX + i * g.hw / 2.4, g.hem - 2, math.pi / 2 + i * 0.15, 7, 2.4, "cloak:1.1", rib="cloak:0.5")
    s.dot(CX - 3, g.sy + 15, 1.1, "trim")
    return s


def paladin(g):
    s = layer(f"heroCloakPaladin{cap(g.build)}", f"A steel-clad knight's tabard and mantle on a {g.build} frame.")
    # The cloak hanging behind.
    cape = [(CX - g.sw - 2, g.sy + 1), (CX - g.hw - 6, g.hem + 6), (CX + g.hw + 6, g.hem + 6), (CX + g.sw + 2, g.sy + 1)]
    s.poly(cape, "cloak:0.72", outline=INK, width=1.0)
    s.poly([(CX + 2, g.sy + 1), (CX + g.sw + 2, g.sy + 1), (CX + g.hw + 6, g.hem + 6), (CX + 2, g.hem + 6)], "cloak:0.55")
    # The steel beneath.
    armour = [(CX - g.sw, g.sy), (CX + g.sw, g.sy), (CX + g.hw - 2, g.hem), (CX - g.hw + 2, g.hem)]
    s.poly(armour, STEEL)
    s.poly([(CX + 2, g.sy), (CX + g.sw, g.sy), (CX + g.hw - 2, g.hem), (CX + 2, g.hem)], STEEL_MID)
    s.outline(armour, INK, 1.1)
    # The tabard.
    tabard = [(CX - g.sw * 0.66, g.sy - 1), (CX + g.sw * 0.66, g.sy - 1), (CX + g.hw * 0.7, g.hem + 5),
              (CX - g.hw * 0.7, g.hem + 5)]
    s.poly(tabard, "cloak")
    s.poly([(CX, g.sy - 1), (CX + g.sw * 0.66, g.sy - 1), (CX + g.hw * 0.7, g.hem + 5), (CX, g.hem + 5)], "cloak:0.78")
    s.outline(tabard, INK, 1.1)
    s.line((CX, g.sy + 2), (CX, g.sy + 16), "trim", 2.0)
    s.line((CX - 4.4, g.sy + 6), (CX + 4.4, g.sy + 6), "trim", 2.0)
    rect(s, CX - g.hw * 0.7 + 1, g.hem + 2.4, 2 * g.hw * 0.7 - 2, 2.2, "trim:0.7")
    belt(s, g, g.sy + 13.5)
    # A gorget at the neck and plates at the shoulder.
    s.poly([(CX - 6.4, g.sy - 3.5), (CX + 6.4, g.sy - 3.5), (CX + 7.6, g.sy + 1), (CX - 7.6, g.sy + 1)], STEEL_LIGHT,
           outline=INK, width=0.9)
    for side in (-1, 1):
        s.ellipse(CX + side * g.sw - 4.6, g.sy - 2, 9.2, 6.2, STEEL_LIGHT if side < 0 else STEEL, outline=INK, width=0.9)
        s.line((CX + side * g.sw - 3, g.sy + 0.4), (CX + side * g.sw + 3, g.sy + 0.4), "trim", 0.8)
    return s


def _petal(s, x, y, w, h, color, edge=INK):
    """One rounded feather, hanging from (x, y)."""
    s.blob([(x - w / 2, y), (x + w / 2, y), (x + w * 0.52, y + h * 0.55), (x, y + h), (x - w * 0.52, y + h * 0.55)],
           color, outline=edge, width=0.5)
    s.line((x, y + h * 0.18), (x, y + h * 0.78), FEATHER_EDGE, 0.35)


def angelic(g):
    s = layer(f"heroCloakAngelic{cap(g.build)}", f"A robe under a mantle of white feathers, gilded, on a {g.build} frame.")
    hem = g.hem + 3
    lo = g.hw + 1
    body = [(CX, g.sy - 6), (CX - g.sw, g.sy), (CX - lo, hem), (CX + lo, hem), (CX + g.sw, g.sy)]
    s.poly(body, "cloak")
    s.poly([(CX, g.sy - 6), (CX + g.sw, g.sy), (CX + lo, hem), (CX + 1, hem)], "cloak:0.75")
    s.outline(body, INK, 1.2)
    # Folds falling from the sash.
    for i in (-2, 0, 2):
        s.line((CX + i * 3, g.sy + 16), (CX + i * 3.8, hem - 3), "cloak:0.5", 0.6)
    # A gilded hem, and a fringe of small feathers below it.
    rect(s, CX - lo + 1, hem - 3, 2 * lo - 2, 2.4, GOLD)
    for i in range(6):
        x = CX - lo + 2.4 + i * (2 * lo - 4.8) / 5
        _petal(s, x, hem - 1.2, 4.6, 5.2, FEATHER if i % 2 == 0 else FEATHER_SHADE)
    # The sash, tied at the side.
    rect(s, CX - g.sw + 1, g.sy + 13, 2 * g.sw - 2, 2.4, GOLD)
    s.line((CX + 3, g.sy + 15.4), (CX + 4.2, g.sy + 22), GOLD, 1.1)
    s.line((CX + 5.4, g.sy + 15.4), (CX + 6.2, g.sy + 21), GOLD, 1.1)
    # The mantle: three tiers of feathers over the shoulders, longest at the bottom.
    span = g.sw + 3.4
    s.poly([(CX - span, g.sy + 1.5), (CX, g.sy - 4.4), (CX + span, g.sy + 1.5), (CX + span - 0.4, g.sy + 7),
            (CX - span + 0.4, g.sy + 7)], FEATHER_SHADE, outline=INK, width=1.0)
    for tier, (y, w, h, count) in enumerate(((g.sy + 3.6, 5.8, 6.4, 5), (g.sy + 1.2, 5.0, 5.4, 6), (g.sy - 1.4, 4.2, 4.2, 5))):
        for i in range(count):
            x = CX - span + 1.6 + i * (2 * span - 3.2) / (count - 1)
            _petal(s, x, y, w, h, FEATHER if (i + tier) % 2 == 0 else 0xFFFFFF)
    s.line((CX - span + 0.8, g.sy + 1.2), (CX, g.sy - 3.6), GOLD, 1.0)
    s.line((CX + span - 0.8, g.sy + 1.2), (CX, g.sy - 3.6), GOLD, 1.0)
    # A sun-clasp at the throat.
    s.dot(CX, g.sy + 1.6, 2.0, GOLD)
    s.dot(CX, g.sy + 1.6, 0.8, 0xFFF3C4)
    return s


def demonic(g):
    s = layer(f"heroCloakDemonic{cap(g.build)}", f"A tattered cloak with a burning hem and spiked shoulders on a {g.build} frame.")
    hem = g.hem + 2
    steps = 7
    teeth = []
    for i in range(steps + 1):
        x = CX - g.hw - 1 + i * (2 * g.hw + 2) / steps
        teeth.append((x, hem + (5.6 if i % 2 == 0 else -1.4)))
    body = [(CX, g.sy - 6), (CX - g.sw, g.sy)] + teeth + [(CX + g.sw, g.sy)]
    s.poly(body, "cloak:0.62")
    s.poly([(CX, g.sy - 6), (CX + g.sw, g.sy), teeth[-1], teeth[steps // 2]], "cloak:0.45")
    s.outline(body, INK, 1.2)
    # The inside, lit from below: an open front over a dark chest with a glowing sigil.
    s.poly([(CX - 4, g.sy), (CX + 4, g.sy), (CX + 6, hem - 2), (CX - 6, hem - 2)], VOID)
    s.poly([(CX - 3.6, g.sy + 5.5), (CX + 3.6, g.sy + 5.5), (CX, g.sy + 13.5)], ("trim", 0.2), outline="trim:0.9", width=0.6)
    s.dot(CX, g.sy + 7.6, 0.9, "trim")
    # Embers running up from the torn hem: cracks in the cloth.
    for i, dx in enumerate((-9, -4, 3, 8)):
        x, y = teeth[[1, 3, 4, 6][i]]
        s.curve([(x, y - 1), (x + dx * 0.08, y - 5.5), (x - dx * 0.1, y - 9.5)], "trim:0.85", 0.7)
    for x, y in teeth[1::2]:
        s.dot(x, y - 0.6, 0.7, "trim")
    # Spikes rising from each shoulder, and a bone ridge along the top of the cloak.
    for side in (-1, 1):
        x0 = CX + side * (g.sw - 1)
        s.taper([(x0, g.sy + 2), (x0 + side * 4.4, g.sy - 3.4), (x0 + side * 5.6, g.sy - 11.5)], 0x2C1B1F, 4.4, 0.2,
                outline=INK, width=0.7)
        s.line((x0 + side * 1.2, g.sy - 0.6), (x0 + side * 4.4, g.sy - 8.2), "trim:0.85", 0.6)
        s.taper([(x0 - side * 3, g.sy + 3.4), (x0 + side * 0.6, g.sy - 0.4), (x0 + side * 1.6, g.sy - 5.8)], 0x3A252A, 3.0,
                0.2, outline=INK, width=0.6)
        s.dot(x0 + side * 1.2, g.sy + 6.4, 1.0, BONE_SHADE)
    return s


BUILDERS = {
    "hooded": hooded, "mantle": mantle, "longCoat": long_coat, "shroud": shroud, "pilgrim": pilgrim,
    "vampire": vampire, "angelic": angelic, "demonic": demonic, "wizard": wizard, "ninja": ninja, "samurai": samurai, "druid": druid, "paladin": paladin,
}
