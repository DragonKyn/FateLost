"""Previews the cloak's sway: the same warp the game applies, drawn on the art.

Run from the repo root:

    python tools/art/hero_sway.py

It writes tools/art/hero-sway.png (gitignored): each cloak at rest, at a full
walk, at full walk with the spring's overshoot, and turning. The warp here is
the one in FateLost/Scenes/Gameplay/Entities/CapeSway.swift; keep them together.
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

import artkit
import hero
from herokit import FOOT, H, W, Geo

# Fractions of the cloak's height from the hem, and of its width from the back
# edge, with the share of the sway each carries (CapeSway.rows / .columns).
ROWS = [(0.0, 1.0), (0.16, 0.85), (0.42, 0.25), (1.0, 0.0)]
COLUMNS = [(0.0, 1.0), (0.3, 1.0), (0.5, 0.65), (0.7, 0.3), (1.0, 0.2)]


def displacement(u, v, dx, dy, cloth):
    """How far (in canvas points, y up) the drawing at (u, v) is moved. v is 0 at the bottom."""
    row = np.interp(v, [r[0] for r in ROWS], [r[1] for r in ROWS])
    col = np.interp(u, [c[0] for c in COLUMNS], [c[1] for c in COLUMNS])
    share = row * col * cloth
    # The back edge is thrown out; the front edge hardly moves. The rise is the same all along the hem.
    return dx * share, dy * row * cloth


def sway_image(sprite_img, dx, dy, cloth):
    """Inverse-maps the picture (the offsets are small, so the first-order inverse is exact enough to judge by)."""
    arr = np.asarray(sprite_img).astype(np.float32)
    h, w = arr.shape[:2]
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    u = xs / w
    v = 1 - ys / h
    mx, my = displacement(u, v, dx, dy, cloth)
    scale = w / W
    sx = np.clip(xs - mx * scale, 0, w - 1)
    sy = np.clip(ys + my * scale, 0, h - 1)
    x0, y0 = np.floor(sx).astype(int), np.floor(sy).astype(int)
    x1, y1 = np.minimum(x0 + 1, w - 1), np.minimum(y0 + 1, h - 1)
    fx, fy = (sx - x0)[..., None], (sy - y0)[..., None]
    out = (arr[y0, x0] * (1 - fx) * (1 - fy) + arr[y0, x1] * fx * (1 - fy)
           + arr[y1, x0] * (1 - fx) * fy + arr[y1, x1] * fx * fy)
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def figure(build, cloak, head, look, dx, dy, cloth, scale, **extras):
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
    image.alpha_composite(sway_image(cloak_layer.render(scale), dx, dy, cloth))
    image.alpha_composite(front.render(scale))
    return image


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    scale = 4
    cloth = {"hooded": 1, "longCoat": 0.9, "ninja": 0.6, "paladin": 0.3, "vampire": 1, "mantle": 0.8}
    poses = [("rest", 0, 0), ("walk", -2.6, 0), ("swing", -3.0, 1.0), ("turn", 2.0, -0.8)]
    names = list(cloth)
    cell_w, cell_h = W * scale + 10, H * scale + 30
    sheet = Image.new("RGBA", (cell_w * len(poses), cell_h * len(names)), (46, 42, 40, 255))
    draw = ImageDraw.Draw(sheet)
    for row, name in enumerate(names):
        for col, (label, dx, dy) in enumerate(poses):
            img = figure("standard", name, "hood", list(hero.LOOKS)[row % 6], dx, dy, cloth[name], scale)
            x, y = col * cell_w, row * cell_h
            sheet.alpha_composite(img, (x + 5, y + 24))
            draw.text((x + 6, y + 6), f"{name} {label}", fill=(220, 210, 190, 255))
    sheet.save(os.path.join(here, "hero-sway.png"))
    print("wrote hero-sway.png")


if __name__ == "__main__":
    main()
