"""Previews the cloak's sway: the same warp the game applies, drawn on the art.

Run from the repo root:

    python tools/art/hero_sway.py

It writes tools/art/hero-sway.png (gitignored): each cloak at rest, at a full
walk, at full walk with the spring's overshoot, and turning. The swing here is
the one in FateLost/Scenes/Gameplay/Entities/CapeSway.swift; keep them together.
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

import artkit
import hero
from herokit import CX, FOOT, H, W, Geo

HANG = 23.0        # CapeSway.hangLength
MAX_ANGLE = 0.11   # CapeSway.maxAngle, radians


def angle_for(offset_x, cloth):
    return max(-MAX_ANGLE, min(MAX_ANGLE, math.atan2(offset_x * cloth, HANG)))


def sway_image(sprite_img, angle, pivot, scale):
    """The cloak turned by `angle` (radians, counter-clockwise) about the shoulders: a plain rotation, no bend."""
    return sprite_img.rotate(math.degrees(angle), resample=Image.BICUBIC, center=(pivot[0] * scale, pivot[1] * scale))


def figure(build, cloak, head, look, offset_x, cloth, scale, **extras):
    g = Geo(build)
    artkit.INK.clear()
    artkit.INK.update(hero.LOOKS[look])
    from artkit import Sprite
    hero_cloaks, hero_extras, hero_heads = hero.hero_cloaks, hero.hero_extras, hero.hero_heads

    def part(builders, name):
        s = Sprite("p", W, H, foot=FOOT)
        s.ops.extend(builders[name](g).ops)
        return s

    behind = Sprite("b", W, H, foot=FOOT)
    if extras.get("wings"):
        behind.ops.extend(hero_extras.WINGS[extras["wings"]](g).ops)
    behind.ops.extend(hero.legs(build).ops)
    front = Sprite("f", W, H, foot=FOOT)
    if extras.get("detail"):
        front.ops.extend(hero_extras.DETAILS[extras["detail"]](g).ops)
    front.ops.extend(hero_heads.BUILDERS[head](g).ops)
    cloak_layer = part(hero_cloaks.BUILDERS, cloak)
    image = behind.render(scale)
    image.alpha_composite(sway_image(cloak_layer.render(scale), angle_for(offset_x, cloth), (CX, g.sy), scale))
    image.alpha_composite(front.render(scale))
    return image


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    scale = 4
    cloth = {"hooded": 1, "longCoat": 0.9, "ninja": 0.6, "paladin": 0.3, "vampire": 1, "mantle": 0.8}
    poses = [("rest", 0), ("walk", -2.6), ("swing", -3.1), ("turn", 2.0)]
    names = list(cloth)
    cell_w, cell_h = W * scale + 10, H * scale + 30
    sheet = Image.new("RGBA", (cell_w * len(poses), cell_h * len(names)), (46, 42, 40, 255))
    draw = ImageDraw.Draw(sheet)
    for row, name in enumerate(names):
        for col, (label, offset_x) in enumerate(poses):
            img = figure("standard", name, "hood", list(hero.LOOKS)[row % 6], offset_x, cloth[name], scale)
            x, y = col * cell_w, row * cell_h
            sheet.alpha_composite(img, (x + 5, y + 24))
            draw.text((x + 6, y + 6), f"{name} {label}", fill=(220, 210, 190, 255))
    sheet.save(os.path.join(here, "hero-sway.png"))
    print("wrote hero-sway.png")


if __name__ == "__main__":
    main()
