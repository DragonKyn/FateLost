"""The hero's cloaks and outfits, one function per style. Each takes a `Geo`
and returns a layer; see herokit.py and hero.py."""
import math

from herokit import (BELT, CX, FOOT, INK, LEATHER, LEATHER_DARK, STEEL, STEEL_DARK, STEEL_LIGHT, STEEL_MID, IVORY,
                     Geo, belt, cap, layer, leaf, rect, star)


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
    s = layer(f"heroCloakNinja{cap(g.build)}", f"A wrapped shinobi garb with a trailing scarf on a {g.build} frame.")
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
    # The scarf, streaming behind.
    scarf = [(CX - 2, g.sy - 3), (CX - 9, g.sy - 6), (CX - 16, g.sy - 4), (CX - 23, g.sy - 8), (CX - 26, g.sy - 6),
             (CX - 21, g.sy - 1), (CX - 15, g.sy), (CX - 8, g.sy + 1.5), (CX - 2, g.sy + 1.5)]
    s.blob(scarf, "trim:0.8", outline=INK, width=0.9)
    tail = [(CX - 12, g.sy + 0.5), (CX - 17, g.sy + 5), (CX - 22, g.sy + 6), (CX - 20, g.sy + 9), (CX - 13, g.sy + 5),
            (CX - 9, g.sy + 2.5)]
    s.blob(tail, "trim:0.62", outline=INK, width=0.8)
    s.curve([(CX - 4, g.sy - 3), (CX - 12, g.sy - 4.4), (CX - 21, g.sy - 6.4)], "trim:0.5", 0.5)
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


BUILDERS = {
    "hooded": hooded, "mantle": mantle, "longCoat": long_coat, "shroud": shroud, "pilgrim": pilgrim,
    "vampire": vampire, "wizard": wizard, "ninja": ninja, "samurai": samurai, "druid": druid, "paladin": paladin,
}
