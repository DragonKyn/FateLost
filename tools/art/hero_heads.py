"""The hero's heads, one function per style. Each takes a `Geo` and returns a
layer; see herokit.py and hero.py."""
import math

from herokit import (BONE, BONE_SHADE, CX, INK, STEEL, STEEL_DARK, STEEL_LIGHT, STEEL_MID, VOID, cap, layer, rect)


def hood_shell(s, g, void_scale=1.0):
    """The hood and the dark inside it. Returns the void's rectangle."""
    x, y = CX - g.hood_w / 2, g.sy - g.hood_h
    s.ellipse(x, y, g.hood_w, g.hood_h, "cloak:0.7", outline=INK, width=1.2)
    vx, vy = x + 4, y + 0.37 * g.hood_h
    vw, vh = g.hood_w - 8, 0.47 * g.hood_h * void_scale
    s.ellipse(vx, vy, vw, vh, VOID)
    k = g.hood_w / 19
    r = 8 * k
    cy = y + 0.5 * g.hood_h
    arc = [(CX + r * math.cos(a), cy + r * math.sin(a)) for a in (1.05 * math.pi, 1.2 * math.pi,
                                                                  1.33 * math.pi, 1.45 * math.pi)]
    s.curve(arc, "cloak:1.7", 1.0)
    return vx, vy, vw, vh


def eyes_in_hood(s, g, vy):
    k = g.hood_w / 19
    eye_y = vy + 0.17 * g.hood_h
    s.ellipse(CX - 3.4 * k, eye_y, 2, 1.6, "eyes")
    s.ellipse(CX + 1.4 * k, eye_y, 2, 1.6, "eyes")


def hood(g):
    s = layer(f"heroHeadHood{cap(g.build)}", f"A deep hood on a {g.build} frame, the face left in shadow.")
    _, vy, _, _ = hood_shell(s, g)
    eyes_in_hood(s, g, vy)
    return s


def cowl(g):
    s = layer(f"heroHeadCowl{cap(g.build)}", f"A hood with a cloth drawn across the mouth on a {g.build} frame.")
    vx, vy, vw, vh = hood_shell(s, g)
    eyes_in_hood(s, g, vy)
    top = vy + 0.55 * vh
    bottom = vy + vh
    s.poly([(vx + 0.4, top + 0.6), (CX, top - 1.2), (vx + vw - 0.4, top + 0.6), (vx + vw - 1, bottom),
            (CX, bottom + 1.6), (vx + 1, bottom)], "trim:0.55", outline=INK, width=0.8)
    s.line((vx + 1.2, top + 2.4), (vx + vw - 1.2, top + 3), "trim:0.35", 0.7)
    return s


def bare_face(s, g, beard=False):
    y = g.sy
    rect(s, CX - 2.1, y - 4.5, 4.2, 5.5, "skin:0.66")
    s.ellipse(CX - 7.6, y - 19.5, 15.2, 15, "hair:0.8", outline=INK, width=1.0)
    s.ellipse(CX - 6, y - 17, 12, 13.5, "skin", outline=INK, width=1.0)
    s.blob([(CX - 7, y - 8.5), (CX - 6.6, y - 14.5), (CX - 3.5, y - 18.4), (CX + 3.5, y - 18.4),
            (CX + 6.6, y - 14.5), (CX + 7, y - 8.5), (CX + 5.4, y - 11.8), (CX + 1.5, y - 14),
            (CX - 3, y - 12.4), (CX - 5.2, y - 10.8)], "hair", outline=INK, width=0.8)
    s.dot(CX - 2.4, y - 9.4, 1.1, VOID)
    s.dot(CX + 2.4, y - 9.4, 1.1, VOID)
    s.dot(CX - 2.4, y - 9.4, 0.75, "eyes")
    s.dot(CX + 2.4, y - 9.4, 0.75, "eyes")
    s.line((CX - 3.8, y - 11.4), (CX - 1.3, y - 10.9), "hair:0.7", 0.8)
    s.line((CX + 1.3, y - 10.9), (CX + 3.8, y - 11.4), "hair:0.7", 0.8)
    if not beard:
        s.line((CX - 1.2, y - 5.6), (CX + 1.2, y - 5.6), "skin:0.55", 0.7)


def bare(g):
    s = layer(f"heroHeadBare{cap(g.build)}", f"A bare head on a {g.build} frame: skin, hair and open eyes.")
    bare_face(s, g)
    return s


def helm_dome(s, g, crest):
    y = g.sy
    s.ellipse(CX - 7.8, y - 19, 15.6, 15, STEEL, outline=INK, width=1.2)
    s.poly([(CX + 1, y - 18.6), (CX + 7, y - 14), (CX + 7.6, y - 9), (CX + 1, y - 5)], ("cloak:0.2", 0.18))
    s.poly([(CX - 4.8, y - 12.6), (CX + 4.8, y - 12.6), (CX + 3.8, y - 4.6), (CX, y - 3), (CX - 3.8, y - 4.6)], VOID)
    s.poly([(CX - 7.4, y - 10), (CX - 6.6, y - 4.4), (CX - 3, y - 2.6), (CX - 2.6, y - 8.4)], STEEL_MID,
           outline=INK, width=0.9)
    s.poly([(CX + 7.4, y - 10), (CX + 6.6, y - 4.4), (CX + 3, y - 2.6), (CX + 2.6, y - 8.4)], STEEL_DARK,
           outline=INK, width=0.9)
    rect(s, CX - 7.6, y - 13.6, 15.2, 1.9, STEEL_MID, outline=INK, width=0.6)
    rect(s, CX - 0.9, y - 13, 1.8, 8.6, STEEL, outline=INK, width=0.6)
    s.ellipse(CX - 4.4, y - 10.6, 2.2, 1.6, "eyes")
    s.ellipse(CX + 2.2, y - 10.6, 2.2, 1.6, "eyes")
    s.curve([(CX - 5.6, y - 14.4), (CX - 4.6, y - 17), (CX - 1.6, y - 18.2)], STEEL_LIGHT, 1.0)
    if crest:
        s.poly([(CX - 1.9, y - 18.6), (CX, y - 24.5), (CX + 1.9, y - 18.6)], "trim", outline=INK, width=0.8)


def helm(g):
    s = layer(f"heroHeadHelm{cap(g.build)}", f"An open iron helm on a {g.build} frame, with a crest and lit eyes.")
    helm_dome(s, g, crest=True)
    return s


def eyeless(g):
    s = layer(f"heroHeadEyeless{cap(g.build)}", f"A hood on a {g.build} frame with nothing at all inside it.")
    x, y = CX - g.hood_w / 2, g.sy - g.hood_h
    s.ellipse(x, y, g.hood_w, g.hood_h, "cloak:0.55", outline=INK, width=1.2)
    # A deeper dark that runs the whole length of the face, and nothing in it.
    s.ellipse(x + 3.2, y + 0.3 * g.hood_h, g.hood_w - 6.4, 0.62 * g.hood_h, VOID)
    k = g.hood_w / 19
    r = 8 * k
    cy = y + 0.5 * g.hood_h
    arc = [(CX + r * math.cos(a), cy + r * math.sin(a)) for a in (1.05 * math.pi, 1.2 * math.pi,
                                                                  1.33 * math.pi, 1.45 * math.pi)]
    s.curve(arc, "cloak:1.5", 1.0)
    return s


def plague(g):
    s = layer(f"heroHeadPlague{cap(g.build)}", f"A wide brim and a beaked mask on a {g.build} frame.")
    x, y = CX - g.hood_w / 2, g.sy - g.hood_h
    s.ellipse(x, y, g.hood_w, g.hood_h, "cloak:0.5", outline=INK, width=1.2)
    vx, vy = x + 3.6, y + 0.34 * g.hood_h
    s.ellipse(vx, vy, g.hood_w - 7.2, 0.5 * g.hood_h, VOID)
    ey = vy + 0.16 * g.hood_h
    for cx in (CX - 3.3, CX + 3.3):
        s.dot(cx, ey + 1.4, 2.5, 0x2A2420)
        s.dot(cx, ey + 1.4, 1.9, "eyes")
        s.dot(cx - 0.5, ey + 0.8, 0.6, 0xFFFFFF)
    beak = [(CX - 3.6, ey + 2.6), (CX + 3.6, ey + 2.6), (CX + 0.9, ey + 12.5), (CX - 0.9, ey + 12.5)]
    s.poly(beak, 0xC9BFA6, outline=INK, width=0.9)
    s.poly([(CX, ey + 2.6), (CX + 3.6, ey + 2.6), (CX + 0.9, ey + 12.5), (CX, ey + 12.5)], 0xA79D86)
    s.line((CX, ey + 3), (CX, ey + 12), 0x8A806A, 0.5)
    # The hat: a wide flat brim and a low crown.
    s.ellipse(CX - g.hood_w * 0.72, y + 1.6, g.hood_w * 1.44, 5.4, 0x1F1A1C, outline=INK, width=1.0)
    s.poly([(CX - g.hood_w * 0.34, y + 3.6), (CX - g.hood_w * 0.28, y - 4.5), (CX + g.hood_w * 0.28, y - 4.5),
            (CX + g.hood_w * 0.34, y + 3.6)], 0x2A2427, outline=INK, width=1.0)
    rect(s, CX - g.hood_w * 0.33, y - 0.6, g.hood_w * 0.66, 2.2, "trim:0.8")
    return s


def great_helm(g):
    s = layer(f"heroHeadGreatHelm{cap(g.build)}", f"A closed great helm with a plume on a {g.build} frame.")
    y = g.sy
    body = [(CX - 7, y - 1.5), (CX - 8.4, y - 14), (CX - 5.6, y - 20), (CX + 5.6, y - 20), (CX + 8.4, y - 14),
            (CX + 7, y - 1.5)]
    # A plume of horsehair, fanned back from the crown.
    s.blob([(CX - 2, y - 19.6), (CX - 4.4, y - 25), (CX - 1, y - 30), (CX + 6, y - 29.6), (CX + 11.5, y - 24),
            (CX + 12, y - 18), (CX + 8.4, y - 21.6), (CX + 4, y - 19)], "trim", outline=INK, width=0.9)
    for dx, dy in ((-1, -26), (2.4, -27), (6, -26), (9.4, -22.4)):
        s.curve([(CX + dx - 1.2, y - 20.6), (CX + dx, y + dy + 1.6), (CX + dx + 1.4, y + dy)], "trim:0.65", 0.7)
    s.poly(body, STEEL)
    s.poly([(CX + 1.5, y - 19.6), (CX + 8.4, y - 14), (CX + 7, y - 1.5), (CX + 1.5, y - 1.5)], STEEL_MID)
    s.outline(body, INK, 1.2)
    rect(s, CX - 8, y - 12.6, 16, 2.4, VOID)
    s.ellipse(CX - 5.2, y - 12.3, 2.4, 1.8, "eyes")
    s.ellipse(CX + 2.8, y - 12.3, 2.4, 1.8, "eyes")
    rect(s, CX - 0.9, y - 20, 1.8, 18.2, STEEL_LIGHT, outline=INK, width=0.5)
    for dy in (-8, -6, -4):
        s.dot(CX + 4.4, y + dy, 0.55, VOID)
        s.dot(CX - 4.4, y + dy, 0.55, VOID)
    s.curve([(CX - 6.2, y - 14), (CX - 5.6, y - 17.4), (CX - 3.4, y - 19.2)], STEEL_LIGHT, 0.9)
    return s


def skull(g):
    s = layer(f"heroHeadSkull{cap(g.build)}", f"A hood with a bone mask on a {g.build} frame.")
    vx, vy, vw, vh = hood_shell(s, g, void_scale=1.05)
    top = vy - 0.4
    face = [(vx - 0.2, top + 3), (CX, top - 1.4), (vx + vw + 0.2, top + 3), (vx + vw - 0.6, top + 9),
            (CX + 3, top + 12.8), (CX - 3, top + 12.8), (vx + 0.6, top + 9)]
    s.blob(face, BONE, outline=INK, width=0.9)
    s.blob([(CX + 1, top - 0.6), (vx + vw + 0.2, top + 3), (vx + vw - 0.6, top + 9), (CX + 3, top + 12.8),
            (CX + 1, top + 11)], BONE_SHADE)
    for cx in (CX - 3.1, CX + 3.1):
        s.ellipse(cx - 1.9, top + 3.8, 3.8, 4.2, VOID)
        s.dot(cx, top + 6, 0.95, "eyes")
    s.poly([(CX, top + 7.6), (CX - 1, top + 9.6), (CX + 1, top + 9.6)], VOID)
    for dx in (-2, -0.7, 0.7, 2):
        s.line((CX + dx, top + 10.6), (CX + dx, top + 12.4), VOID, 0.55)
    s.curve([(CX + 3.4, top + 0.6), (CX + 2.4, top + 2.4), (CX + 3.2, top + 3.4)], VOID, 0.45)
    return s


def horned(g):
    s = layer(f"heroHeadHorned{cap(g.build)}", f"An iron helm with swept horns on a {g.build} frame.")
    y = g.sy
    for side in (-1, 1):
        s.taper([(CX + side * 7, y - 13), (CX + side * 12.4, y - 15.6), (CX + side * 14.6, y - 23),
                 (CX + side * 12.4, y - 28)], BONE, 3.6, 0.2, outline=INK, width=0.8)
        s.line((CX + side * 8.6, y - 14), (CX + side * 13.2, y - 21), BONE_SHADE, 0.6)
    helm_dome(s, g, crest=False)
    return s


def wizard_hat(g):
    s = layer(f"heroHeadWizardHat{cap(g.build)}", f"A pointed hat over a long beard on a {g.build} frame.")
    y = g.sy
    bare_face(s, g, beard=True)
    beard = [(CX - 5.6, y - 8.6), (CX + 5.6, y - 8.6), (CX + 4.6, y + 1), (CX + 2, y + 7), (CX, y + 9.4),
             (CX - 2, y + 7), (CX - 4.6, y + 1)]
    s.blob(beard, "hair:1.05", outline=INK, width=0.8)
    s.blob([(CX - 3.2, y - 8.4), (CX + 3.2, y - 8.4), (CX + 2.4, y - 6.4), (CX - 2.4, y - 6.4)], "hair:0.8")
    s.line((CX - 1, y - 2), (CX - 1.4, y + 5), "hair:0.7", 0.6)
    s.line((CX + 1.6, y - 3), (CX + 1.4, y + 4), "hair:0.7", 0.6)
    # The hat: a wide brim and a bent cone.
    s.ellipse(CX - 13, y - 21.5, 26, 7.5, "cloak:0.85", outline=INK, width=1.1)
    cone = [(CX - 8.2, y - 17.6), (CX + 8.2, y - 17.6), (CX + 4.6, y - 26), (CX + 5.4, y - 32), (CX + 12, y - 35),
            (CX + 3, y - 34), (CX - 2, y - 27)]
    s.poly(cone, "cloak:0.85", outline=INK, width=1.1)
    s.poly([(CX + 1, y - 17.6), (CX + 8.2, y - 17.6), (CX + 4.6, y - 26), (CX + 5.4, y - 32), (CX + 12, y - 35),
            (CX + 3, y - 34), (CX + 1.5, y - 26)], "cloak:0.66")
    rect(s, CX - 8.4, y - 20.2, 16.8, 2.6, "trim:0.85", outline=INK, width=0.5)
    s.dot(CX, y - 18.9, 1.1, "trim")
    return s


BUILDERS = {
    "hood": hood, "cowl": cowl, "bare": bare, "helm": helm, "eyeless": eyeless, "plague": plague,
    "greatHelm": great_helm, "skull": skull, "horned": horned, "wizardHat": wizard_hat,
}
