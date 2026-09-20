"""FateLost's hero: one figure, dressed at runtime.

Run from the repo root:

    python tools/art/hero.py            # writes the Swift and a preview
    python tools/art/hero.py --preview  # preview sheet only

The Swift lands in FateLost/Rendering/PlaceholderArt+HeroLayers.swift; the
preview in tools/art/hero-preview.png (gitignored).

Unlike every other sprite here the hero is not one drawing. It is three
layers, drawn in order: legs, cloak, head. A build changes the proportions
of all three, so each layer exists once per build (and once per style within
it). Colours are not baked in: the drawings ask for "cloak", "trim", "eyes",
"skin" or "hair" (optionally shaded, "cloak:0.75"), and the Swift asks the
`HeroInk` it is handed. The preview resolves the same names, so what you see
here is what ships, in any colour.

Coordinates are points on a 48 x 64 canvas, centred on x = 24, feet at 60.
"""
import math
import os
import sys

import artkit
from artkit import Sprite, preview_sheet

W, H = 48, 64
CX = 24
FOOT = 60

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

BUILDS = {
    "lithe": dict(sw=8, hw=12, leg=4.0, hood_w=17, hood_h=18, hem_up=10, torso=25),
    "standard": dict(sw=10, hw=14, leg=4.5, hood_w=19, hood_h=19, hem_up=9, torso=23),
    "broad": dict(sw=13, hw=17, leg=5.5, hood_w=21, hood_h=20, hem_up=9, torso=22),
}
CLOAKS = ["hooded", "mantle", "longCoat", "shroud", "pilgrim"]
HEADS = ["hood", "cowl", "bare", "helm"]


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


def layer(name, doc):
    return Sprite(name, W, H, foot=FOOT, doc=doc)


def rect(s, x, y, w, h, color, outline=None, width=1.0):
    s.poly([(x, y), (x + w, y), (x + w, y + h), (x, y + h)], color, outline=outline, width=width)


def belt(s, g, y):
    rect(s, CX - g.sw + 1, y, 2 * g.sw - 2, 3, BELT)
    rect(s, CX - 1.5, y - 0.5, 3, 4, "trim")


# -- legs -------------------------------------------------------------------

def legs(build):
    g = Geo(build)
    s = layer(f"heroLegs{cap(build)}", f"The {build} hero's legs and boots.")
    left = CX - 1.5 - g.leg
    right = CX + 1.5
    for x in (left, right):
        rect(s, x, FOOT - 15, g.leg, 13, LEG)
        rect(s, x - 1.25, FOOT - 5, g.leg + 2.5, 5, BOOT)
    return s


# -- cloaks -----------------------------------------------------------------

def cloak_hooded(g):
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


def cloak_mantle(g):
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


def cloak_long_coat(g):
    s = layer(f"heroCloakLongCoat{cap(g.build)}", f"A buttoned coat to the knee on a {g.build} frame.")
    hem = g.hem + 5
    lo = g.hw - 1
    body = [(CX, g.sy - 5), (CX - g.sw, g.sy), (CX - lo, hem), (CX + lo, hem), (CX + g.sw, g.sy)]
    s.poly(body, "cloak")
    s.poly([(CX, g.sy - 5), (CX + g.sw, g.sy), (CX + lo, hem), (CX, hem)], "cloak:0.75")
    s.outline(body, INK, 1.2)
    # Lapels, and the opening they fall away from.
    s.poly([(CX, g.sy - 1), (CX - 4.6, g.sy + 1), (CX - 1.6, g.sy + 9)], "cloak:1.3", outline=INK, width=0.7)
    s.poly([(CX, g.sy - 1), (CX + 4.6, g.sy + 1), (CX + 1.6, g.sy + 9)], "cloak:1.05", outline=INK, width=0.7)
    s.line((CX, g.sy + 9), (CX, hem), "cloak:0.4", 1.0)
    for dy in (11, 16, 21):
        s.dot(CX + 2.2, g.sy + dy, 0.95, "trim")
    belt(s, g, g.sy + 12)
    rect(s, CX - lo + 1.5, hem - 2.4, 2 * lo - 3, 2.4, "trim:0.7")
    return s


def cloak_shroud(g):
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


def cloak_pilgrim(g):
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
    # The collar, standing up around where the face will be.
    s.poly([(CX - 3, g.sy - 7), (CX - 8.5, g.sy - 11.5), (CX - 9.5, g.sy + 0.5), (CX - 3, g.sy + 1.5)],
           "cloak:0.9", outline=INK, width=1.0)
    s.poly([(CX + 3, g.sy - 7), (CX + 8.5, g.sy - 11.5), (CX + 9.5, g.sy + 0.5), (CX + 3, g.sy + 1.5)],
           "cloak:0.62", outline=INK, width=1.0)
    s.line((CX - 8.5, g.sy - 10), (CX - 9, g.sy - 1), "trim", 0.9)
    s.line((CX + 8.5, g.sy - 10), (CX + 9, g.sy - 1), "trim", 0.9)
    return s


CLOAK_BUILDERS = {
    "hooded": cloak_hooded, "mantle": cloak_mantle, "longCoat": cloak_long_coat,
    "shroud": cloak_shroud, "pilgrim": cloak_pilgrim,
}


# -- heads ------------------------------------------------------------------

def hood_shell(s, g):
    x, y = CX - g.hood_w / 2, g.sy - g.hood_h
    s.ellipse(x, y, g.hood_w, g.hood_h, "cloak:0.7", outline=INK, width=1.2)
    vx, vy = x + 4, y + 0.37 * g.hood_h
    vw, vh = g.hood_w - 8, 0.47 * g.hood_h
    s.ellipse(vx, vy, vw, vh, VOID)
    k = g.hood_w / 19
    eye_y = vy + 0.17 * g.hood_h
    s.ellipse(CX - 3.4 * k, eye_y, 2, 1.6, "eyes")
    s.ellipse(CX + 1.4 * k, eye_y, 2, 1.6, "eyes")
    r = 8 * k
    cy = y + 0.5 * g.hood_h
    arc = [(CX + r * math.cos(a), cy + r * math.sin(a)) for a in (1.05 * math.pi, 1.2 * math.pi,
                                                                  1.33 * math.pi, 1.45 * math.pi)]
    s.curve(arc, "cloak:1.7", 1.0)
    return vx, vy, vw, vh


def head_hood(g):
    s = layer(f"heroHeadHood{cap(g.build)}", f"A deep hood on a {g.build} frame, the face left in shadow.")
    hood_shell(s, g)
    return s


def head_cowl(g):
    s = layer(f"heroHeadCowl{cap(g.build)}", f"A hood with a cloth drawn across the mouth on a {g.build} frame.")
    vx, vy, vw, vh = hood_shell(s, g)
    top = vy + 0.55 * vh
    bottom = vy + vh
    s.poly([(vx + 0.4, top + 0.6), (CX, top - 1.2), (vx + vw - 0.4, top + 0.6), (vx + vw - 1, bottom),
            (CX, bottom + 1.6), (vx + 1, bottom)], "trim:0.55", outline=INK, width=0.8)
    s.line((vx + 1.2, top + 2.4), (vx + vw - 1.2, top + 3), "trim:0.35", 0.7)
    return s


def head_bare(g):
    s = layer(f"heroHeadBare{cap(g.build)}", f"A bare head on a {g.build} frame: skin, hair and open eyes.")
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
    s.line((CX - 1.2, y - 5.6), (CX + 1.2, y - 5.6), "skin:0.55", 0.7)
    return s


def head_helm(g):
    s = layer(f"heroHeadHelm{cap(g.build)}", f"An open iron helm on a {g.build} frame, with a crest and lit eyes.")
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
    s.poly([(CX - 1.9, y - 18.6), (CX, y - 24.5), (CX + 1.9, y - 18.6)], "trim", outline=INK, width=0.8)
    return s


HEAD_BUILDERS = {"hood": head_hood, "cowl": head_cowl, "bare": head_bare, "helm": head_helm}


# -- assembly ---------------------------------------------------------------

def all_layers():
    layers = []
    for build in BUILDS:
        layers.append(legs(build))
    for build in BUILDS:
        for style in CLOAKS:
            layers.append(CLOAK_BUILDERS[style](Geo(build)))
    for build in BUILDS:
        for style in HEADS:
            layers.append(HEAD_BUILDERS[style](Geo(build)))
    return layers


def dressed(build, cloak, head, name=None):
    """The three layers composited into one sprite, for the preview."""
    g = Geo(build)
    parts = [legs(build), CLOAK_BUILDERS[cloak](g), HEAD_BUILDERS[head](g)]
    s = Sprite(name or f"{build}/{cloak}/{head}", W, H, foot=FOOT)
    for part in parts:
        s.ops.extend(part.ops)
    return s


LOOKS = {
    "crimson": dict(cloak=0x5B2323, trim=0xC9A55A, eyes=0xE8C07A, skin=0xE3C2A4, hair=0x1C1719),
    "midnight": dict(cloak=0x26365A, trim=0xB9BEC8, eyes=0x8FD8FF, skin=0xB98A5E, hair=0xC4C7CE),
    "moss": dict(cloak=0x40502C, trim=0xE0782A, eyes=0x6BE3A0, skin=0x8A5D3B, hair=0x8A3A22),
    "violet": dict(cloak=0x4C2C62, trim=0x4FB39A, eyes=0xC08CFF, skin=0x5C3B26, hair=0xEDEAE2),
    "bone": dict(cloak=0xA79E8A, trim=0xA12222, eyes=0xFF4A4A, skin=0x9C9A98, hair=0xC9A65C),
}


def preview(path):
    """A grid of every build in every cloak, then every head, then colours."""
    rows = []
    artkit.INK.update(LOOKS["crimson"])
    for build in BUILDS:
        for cloak in CLOAKS:
            rows.append((f"{build} {cloak}", dressed(build, cloak, "hood"), dict(LOOKS["crimson"])))
    heads = []
    for build in ("standard", "broad", "lithe"):
        for head in HEADS:
            heads.append((f"{build} {head}", dressed(build, "hooded", head), dict(LOOKS["midnight"])))
    colours = []
    for index, (name, look) in enumerate(LOOKS.items()):
        cloak = CLOAKS[index % len(CLOAKS)]
        head = HEADS[index % len(HEADS)]
        build = list(BUILDS)[index % 3]
        colours.append((f"{name}: {build} {cloak} {head}", dressed(build, cloak, head), dict(look)))

    from PIL import Image, ImageDraw
    scale = 5
    groups = [rows, heads, colours]
    columns = 5
    cell_w, cell_h = W * scale + 30, H * scale + 44
    total = sum(math.ceil(len(g) / columns) for g in groups)
    sheet = Image.new("RGBA", (cell_w * columns, cell_h * total), (46, 42, 40, 255))
    draw = ImageDraw.Draw(sheet)
    row = 0
    for group in groups:
        for index, (label, sprite, ink) in enumerate(group):
            artkit.INK.clear()
            artkit.INK.update(ink)
            image = sprite.render(scale)
            cx = (index % columns) * cell_w
            cy = (row + index // columns) * cell_h
            sheet.alpha_composite(image, (cx + 15, cy + 34))
            draw.text((cx + 15, cy + 10), label, fill=(220, 210, 190, 255))
        row += math.ceil(len(group) / columns)
    sheet.save(path)


HEADER = '''import UIKit

// Generated by tools/art/hero.py. Edit the Python and rerun it; do not edit
// this file by hand.

/// The hero, in layers: legs, cloak and head, once for each build and style.
/// Each draws into a context the caller owns and takes its colours from an
/// `ink`, so any combination the player picks is a few calls, not a sprite
/// baked in advance. The composition lives in PlaceholderArt+HeroFigure.swift.
extension PlaceholderArt {
'''


def dispatch():
    lines = []
    lines.append("    static func drawHeroLegs(_ build: BodyBuild, _ ctx: CGContext, _ ink: HeroInk) {")
    lines.append("        switch build {")
    for build in BUILDS:
        lines.append(f"        case .{build}: heroLegs{cap(build)}(ctx, ink)")
    lines.append("        }")
    lines.append("    }")
    lines.append("")
    lines.append("    static func drawHeroCloak(_ style: CloakStyle, _ build: BodyBuild, _ ctx: CGContext, _ ink: HeroInk) {")
    lines.append("        switch (style, build) {")
    for style in CLOAKS:
        for build in BUILDS:
            lines.append(f"        case (.{style}, .{build}): heroCloak{cap(style)}{cap(build)}(ctx, ink)")
    lines.append("        }")
    lines.append("    }")
    lines.append("")
    lines.append("    static func drawHeroHead(_ style: HeadStyle, _ build: BodyBuild, _ ctx: CGContext, _ ink: HeroInk) {")
    lines.append("        switch (style, build) {")
    for style in HEADS:
        for build in BUILDS:
            lines.append(f"        case (.{style}, .{build}): heroHead{cap(style)}{cap(build)}(ctx, ink)")
    lines.append("        }")
    lines.append("    }")
    return "\n".join(lines)


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    preview(os.path.join(here, "hero-preview.png"))
    if "--preview" in sys.argv:
        return
    root = os.path.dirname(os.path.dirname(here))
    out = os.path.join(root, "FateLost", "Rendering", "PlaceholderArt+HeroLayers.swift")
    layers = all_layers()
    body = "\n\n".join("    // MARK: - " + s.name + "\n\n" + s.layer_source() for s in layers)
    with open(out, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(HEADER + "\n" + body + "\n\n    // MARK: - Dispatch\n\n" + dispatch() + "\n}\n")
    print(f"wrote {len(layers)} layers")


if __name__ == "__main__":
    main()
