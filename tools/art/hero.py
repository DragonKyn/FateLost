"""FateLost's hero: one figure, dressed at runtime.

Run from the repo root:

    python tools/art/hero.py            # writes the Swift and the previews
    python tools/art/hero.py --preview  # previews only

The Swift lands in FateLost/Rendering/PlaceholderArt+HeroLayers.swift; the
previews in tools/art/hero-*.png (gitignored).

Unlike every other sprite here the hero is not one drawing. It is layers,
drawn back to front: wings, legs, cloak, metal details, chest emblem, head.
A build changes the proportions of all of them, so each layer exists once per
build (and once per style within it). Colours are not baked in: the drawings
ask for "cloak", "trim", "eyes", "skin" or "hair" (optionally shaded,
"cloak:0.75"), and the Swift asks the `HeroInk` it is handed. The preview
resolves the same names, so what you see here is what ships, in any colour.

The drawings live in herokit.py (canvas, builds, helpers), hero_cloaks.py,
hero_heads.py and hero_extras.py.
"""
import math
import os
import sys

import artkit
from artkit import Sprite
from herokit import BOOT, BUILDS, FOOT, H, LEG, W, Geo, cap, layer, rect
import hero_cloaks
import hero_extras
import hero_heads

BUILD_NAMES = list(BUILDS)
CLOAKS = list(hero_cloaks.BUILDERS)
HEADS = list(hero_heads.BUILDERS)
EMBLEMS = list(hero_extras.EMBLEMS)
DETAILS = list(hero_extras.DETAILS)
WINGS = list(hero_extras.WINGS)


def legs(build):
    g = Geo(build)
    s = layer(f"heroLegs{cap(build)}", f"The {build} hero's legs and boots.")
    top = g.hem - 3
    for x in g.legs_x:
        rect(s, x, top, g.leg, FOOT - 2 - top, LEG)
        rect(s, x - 1.25, FOOT - 5, g.leg + 2.5, 5, BOOT)
    return s


# -- assembly ---------------------------------------------------------------

def all_layers():
    layers = [legs(build) for build in BUILD_NAMES]
    groups = [
        (hero_cloaks.BUILDERS, CLOAKS), (hero_heads.BUILDERS, HEADS), (hero_extras.EMBLEMS, EMBLEMS),
        (hero_extras.DETAILS, DETAILS), (hero_extras.WINGS, WINGS),
    ]
    for builders, names in groups:
        for build in BUILD_NAMES:
            for name in names:
                layers.append(builders[name](Geo(build)))
    return layers


def dressed(build="standard", cloak="hooded", head="hood", emblem=None, detail=None, wings=None, name=None):
    """The layers composited into one sprite, for the preview."""
    g = Geo(build)
    parts = []
    if wings:
        parts.append(hero_extras.WINGS[wings](g))
    parts.append(legs(build))
    parts.append(hero_cloaks.BUILDERS[cloak](g))
    if detail:
        parts.append(hero_extras.DETAILS[detail](g))
    if emblem:
        parts.append(hero_extras.EMBLEMS[emblem](g))
    parts.append(hero_heads.BUILDERS[head](g))
    s = Sprite(name or f"{build}/{cloak}/{head}", W, H, foot=FOOT)
    for part in parts:
        s.ops.extend(part.ops)
    return s


LOOKS = {
    "crimson": dict(cloak=0x5B2323, trim=0xC9A55A, eyes=0xE8C07A, skin=0xE3C2A4, hair=0x1C1719),
    "midnight": dict(cloak=0x26365A, trim=0xB9BEC8, eyes=0x8FD8FF, skin=0xB98A5E, hair=0xC4C7CE),
    "moss": dict(cloak=0x40502C, trim=0xE0782A, eyes=0x6BE3A0, skin=0x8A5D3B, hair=0x8A3A22),
    "violet": dict(cloak=0x4C2C62, trim=0x4FB39A, eyes=0xC08CFF, skin=0x5C3B26, hair=0xEDEAE2),
    "bone": dict(cloak=0xA79E8A, trim=0x14121A, eyes=0xFF4A4A, skin=0x9C9A98, hair=0xC9A65C),
    "void": dict(cloak=0x1F1C22, trim=0xC9A55A, eyes=0xFF6A2A, skin=0xD2A17A, hair=0x5A3A26),
}


def sheet(path, cells, columns=6, scale=4):
    """cells: (label, sprite, look-name). Draws each on a dark ground."""
    from PIL import Image, ImageDraw
    cell_w, cell_h = W * scale + 14, H * scale + 34
    rows = math.ceil(len(cells) / columns)
    image = Image.new("RGBA", (cell_w * columns, cell_h * rows), (46, 42, 40, 255))
    draw = ImageDraw.Draw(image)
    for index, (label, sprite, look) in enumerate(cells):
        artkit.INK.clear()
        artkit.INK.update(LOOKS[look])
        art = sprite.render(scale)
        cx, cy = (index % columns) * cell_w, (index // columns) * cell_h
        image.alpha_composite(art, (cx + 7, cy + 26))
        draw.text((cx + 7, cy + 8), label, fill=(220, 210, 190, 255))
    image.save(path)


def previews(here):
    looks = list(LOOKS)
    builds = [(b, dressed(b, "hooded", "hood"), "crimson") for b in BUILD_NAMES]
    builds += [(f"{b} bare", dressed(b, "mantle", "bare"), "midnight") for b in BUILD_NAMES[:1]]
    sheet(os.path.join(here, "hero-builds.png"), builds, columns=6)

    cloaks = [(c, dressed("standard", c, "hood"), looks[i % len(looks)]) for i, c in enumerate(CLOAKS)]
    sheet(os.path.join(here, "hero-cloaks.png"), cloaks, columns=6)

    heads = [(h, dressed("standard", "hooded", h), looks[(i + 1) % len(looks)]) for i, h in enumerate(HEADS)]
    sheet(os.path.join(here, "hero-heads.png"), heads, columns=5)

    extras = []
    for i, e in enumerate(EMBLEMS):
        extras.append((f"emblem {e}", dressed("standard", "hooded", "hood", emblem=e), looks[i % len(looks)]))
    for i, d in enumerate(DETAILS):
        extras.append((f"detail {d}", dressed("standard", "mantle", "hood", detail=d), looks[(i + 2) % len(looks)]))
    for i, w in enumerate(WINGS):
        extras.append((f"wings {w}", dressed("standard", "hooded", "hood", wings=w), looks[i % len(looks)]))
    sheet(os.path.join(here, "hero-extras.png"), extras, columns=6)

    every_build = []
    for i, b in enumerate(BUILD_NAMES):
        every_build.append((f"{b} paladin helm wings", dressed(b, "paladin", "greatHelm", "celestial", "warPlate",
                                                               "angel"), looks[i % len(looks)]))
    for i, b in enumerate(BUILD_NAMES):
        every_build.append((f"{b} wizard hat", dressed(b, "wizard", "wizardHat", "runes", "filigree"), looks[(i + 2) % 6]))
    for i, b in enumerate(BUILD_NAMES):
        every_build.append((f"{b} vampire demon", dressed(b, "vampire", "plague", "skulls", "studs", "demon"),
                            looks[(i + 4) % 6]))
    sheet(os.path.join(here, "hero-combos.png"), every_build, columns=5)


HEADER = '''import UIKit

// Generated by tools/art/hero.py. Edit the Python and rerun it; do not edit
// this file by hand.

/// The hero, in layers: wings, legs, cloak, metal details, chest emblem and
/// head, once for each build and style. Each draws into a context the caller
/// owns and takes its colours from an `ink`, so any combination the player
/// picks is a few calls, not a sprite baked in advance. The composition lives
/// in PlaceholderArt+HeroFigure.swift.
extension PlaceholderArt {
'''


def dispatch():
    lines = []
    lines.append("    static func drawHeroLegs(_ build: BodyBuild, _ ctx: CGContext, _ ink: HeroInk) {")
    lines.append("        switch build {")
    for build in BUILD_NAMES:
        lines.append(f"        case .{build}: heroLegs{cap(build)}(ctx, ink)")
    lines.append("        }")
    lines.append("    }")
    groups = [
        ("Cloak", "CloakStyle", CLOAKS, None), ("Head", "HeadStyle", HEADS, None),
        ("Emblem", "EmblemStyle", EMBLEMS, "plain"), ("Detail", "MetalDetail", DETAILS, "plain"),
        ("Wings", "WingStyle", WINGS, "plain"),
    ]
    for label, enum, names, empty in groups:
        lines.append("")
        lines.append(f"    static func drawHero{label}(_ style: {enum}, _ build: BodyBuild, _ ctx: CGContext, "
                     f"_ ink: HeroInk) {{")
        lines.append("        switch (style, build) {")
        if empty:
            lines.append(f"        case (.{empty}, _): break")
        for name in names:
            for build in BUILD_NAMES:
                lines.append(f"        case (.{name}, .{build}): hero{label}{cap(name)}{cap(build)}(ctx, ink)")
        lines.append("        }")
        lines.append("    }")
    return "\n".join(lines)


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    previews(here)
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
