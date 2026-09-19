"""A tiny vector sketchbook for FateLost's placeholder creatures.

Each sprite is drawn once in Python with a handful of primitives. The same
drawing is rasterised with Pillow for a preview sheet and emitted as Swift
for `PlaceholderArt`, so what you see in the preview is what ships.

Coordinates are points, origin top-left, y down (UIKit). Colours are 0xRRGGBB
ints, optionally with an alpha as a (hex, alpha) tuple.
"""
import math

import numpy as np
from PIL import Image, ImageDraw

SUPERSAMPLE = 8


def _rgba(color):
    if isinstance(color, tuple):
        hex_value, alpha = color
    else:
        hex_value, alpha = color, 1.0
    return ((hex_value >> 16) & 255, (hex_value >> 8) & 255, hex_value & 255, int(round(alpha * 255)))


def _swift_color(color):
    if isinstance(color, tuple):
        return f"UIColor(rgb: 0x{color[0]:06X}, alpha: {_num(color[1])})"
    return f"UIColor(rgb: 0x{color:06X})"


def _num(value):
    text = f"{value:.2f}".rstrip("0").rstrip(".")
    return "0" if text in ("-0", "") else text


def _smooth_closed(points, steps=10):
    """Quadratic B-spline through the midpoints of a closed control polygon."""
    out = []
    n = len(points)
    for i in range(n):
        p0, p1, p2 = points[i], points[(i + 1) % n], points[(i + 2) % n]
        a = ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2)
        b = ((p1[0] + p2[0]) / 2, (p1[1] + p2[1]) / 2)
        for s in range(steps):
            t = s / steps
            out.append(_quad(a, p1, b, t))
    return out


def _smooth_open(points, steps=10):
    if len(points) < 3:
        return list(points)
    out = [points[0]]
    start = points[0]
    for i in range(1, len(points) - 1):
        end = points[i + 1] if i == len(points) - 2 else (
            (points[i][0] + points[i + 1][0]) / 2, (points[i][1] + points[i + 1][1]) / 2)
        for s in range(1, steps + 1):
            out.append(_quad(start, points[i], end, s / steps))
        start = end
    return out


def _quad(a, c, b, t):
    u = 1 - t
    return (u * u * a[0] + 2 * u * t * c[0] + t * t * b[0], u * u * a[1] + 2 * u * t * c[1] + t * t * b[1])


class Sprite:
    def __init__(self, name, width, height, foot=None, anchor=None, doc=""):
        self.name = name
        self.width = width
        self.height = height
        self.foot = foot
        self.anchor = anchor
        self.doc = doc
        self.ops = []
        self.swift = []
        self._stack = [(0.0, 0.0, 1.0, 1.0)]  # dx, dy, sx, sy

    # -- transforms ---------------------------------------------------------

    def push(self, dx=0, dy=0, scale=1, flip=False):
        ox, oy, sx, sy = self._stack[-1]
        nsx = sx * scale * (-1 if flip else 1)
        self._stack.append((ox + dx * sx, oy + dy * sy, nsx, sy * scale))

    def pop(self):
        self._stack.pop()

    def _p(self, point):
        ox, oy, sx, sy = self._stack[-1]
        return (ox + point[0] * sx, oy + point[1] * sy)

    def _w(self, width):
        return width * abs(self._stack[-1][3])

    def _pts(self, points):
        return [self._p(p) for p in points]

    @staticmethod
    def _swift_points(points):
        return "[" + ", ".join(f"P({_num(x)}, {_num(y)})" for x, y in points) + "]"

    # -- primitives ---------------------------------------------------------

    def poly(self, points, color, outline=None, width=1.0):
        pts = self._pts(points)
        self.ops.append(("poly", pts, color))
        self.swift.append(f"fillPolygon(ctx, {self._swift_points(pts)}, {_swift_color(color)})")
        if outline is not None:
            self.ops.append(("line", pts + [pts[0]], outline, self._w(width)))
            self.swift.append(f"strokePolygon(ctx, {self._swift_points(pts)}, {_swift_color(outline)}, "
                              f"width: {_num(self._w(width))})")

    def blob(self, points, color, outline=None, width=1.0):
        """A smooth closed shape through the midpoints of `points`."""
        pts = self._pts(points)
        smooth = _smooth_closed(pts)
        self.ops.append(("poly", smooth, color))
        self.swift.append(f"fillSmooth(ctx, {self._swift_points(pts)}, {_swift_color(color)})")
        if outline is not None:
            self.ops.append(("line", smooth + [smooth[0]], outline, self._w(width)))
            self.swift.append(f"strokeSmooth(ctx, {self._swift_points(pts)}, {_swift_color(outline)}, "
                              f"width: {_num(self._w(width))})")

    def line(self, a, b, color, width=1.0):
        pa, pb = self._p(a), self._p(b)
        self.ops.append(("line", [pa, pb], color, self._w(width)))
        self.swift.append(f"stroke(ctx, from: P({_num(pa[0])}, {_num(pa[1])}), to: P({_num(pb[0])}, {_num(pb[1])}), "
                          f"{_swift_color(color)}, width: {_num(self._w(width))})")

    def curve(self, points, color, width=1.0):
        """A smooth open stroke through `points` (tails, bones, tendrils)."""
        pts = self._pts(points)
        self.ops.append(("line", _smooth_open(pts), color, self._w(width)))
        self.swift.append(f"strokeCurve(ctx, {self._swift_points(pts)}, {_swift_color(color)}, "
                          f"width: {_num(self._w(width))})")

    def taper(self, points, color, base, tip=0.0, outline=None, width=0.8):
        """A tapering horn, claw, fang or blade of grass along `points`."""
        pts = self._pts(points)
        smooth = _smooth_open(pts, steps=6)
        base_w, tip_w = self._w(base), self._w(tip)
        left, right = [], []
        for i, point in enumerate(smooth):
            nxt = smooth[min(i + 1, len(smooth) - 1)]
            prv = smooth[max(i - 1, 0)]
            dx, dy = nxt[0] - prv[0], nxt[1] - prv[1]
            length = math.hypot(dx, dy) or 1
            nx, ny = -dy / length, dx / length
            t = i / (len(smooth) - 1)
            half = (base_w + (tip_w - base_w) * t) / 2
            left.append((point[0] + nx * half, point[1] + ny * half))
            right.append((point[0] - nx * half, point[1] - ny * half))
        outline_pts = left + right[::-1]
        self.ops.append(("poly", outline_pts, color))
        self.swift.append(f"fillPolygon(ctx, {self._swift_points([(round(x, 2), round(y, 2)) for x, y in outline_pts])}, "
                          f"{_swift_color(color)})")
        if outline is not None:
            self.ops.append(("line", outline_pts + [outline_pts[0]], outline, self._w(width)))
            self.swift.append(f"strokePolygon(ctx, {self._swift_points([(round(x, 2), round(y, 2)) for x, y in outline_pts])}, "
                              f"{_swift_color(outline)}, width: {_num(self._w(width))})")

    def ellipse(self, x, y, w, h, color, outline=None, width=1.0):
        cx, cy = self._p((x + w / 2, y + h / 2))
        sw, sh = self._w(w), self._w(h)
        rect = (cx - sw / 2, cy - sh / 2, sw, sh)
        self.ops.append(("ellipse", rect, color))
        self.swift.append(f"fillOval(ctx, CGRect(x: {_num(rect[0])}, y: {_num(rect[1])}, width: {_num(sw)}, "
                          f"height: {_num(sh)}), {_swift_color(color)})")
        if outline is not None:
            self.ops.append(("ellipseLine", rect, outline, self._w(width)))
            self.swift.append(f"strokeOval(ctx, CGRect(x: {_num(rect[0])}, y: {_num(rect[1])}, width: {_num(sw)}, "
                              f"height: {_num(sh)}), {_swift_color(outline)}, width: {_num(self._w(width))})")

    def dot(self, x, y, r, color):
        self.ellipse(x - r, y - r, 2 * r, 2 * r, color)

    def glow(self, x, y, r, color, alpha=0.9):
        cx, cy = self._p((x, y))
        radius = self._w(r)
        self.ops.append(("glow", (cx, cy, radius), color, alpha))
        self.swift.append(f"radialGradient(ctx, center: P({_num(cx)}, {_num(cy)}), radius: {_num(radius)}, "
                          f"inner: UIColor(rgb: 0x{color:06X}, alpha: {_num(alpha)}), "
                          f"outer: UIColor(rgb: 0x{color:06X}, alpha: 0))")

    # -- output -------------------------------------------------------------

    def render(self, scale=3):
        k = scale * SUPERSAMPLE
        size = (int(self.width * k), int(self.height * k))
        canvas = Image.new("RGBA", size, (0, 0, 0, 0))
        for op in self.ops:
            layer = Image.new("RGBA", size, (0, 0, 0, 0))
            draw = ImageDraw.Draw(layer)
            kind = op[0]
            if kind == "poly":
                draw.polygon([(x * k, y * k) for x, y in op[1]], fill=_rgba(op[2]))
            elif kind == "line":
                pts = [(x * k, y * k) for x, y in op[1]]
                w = max(1, int(round(op[3] * k)))
                draw.line(pts, fill=_rgba(op[2]), width=w, joint="curve")
                for px, py in (pts[0], pts[-1]):
                    draw.ellipse((px - w / 2, py - w / 2, px + w / 2, py + w / 2), fill=_rgba(op[2]))
            elif kind == "ellipse":
                x, y, w, h = op[1]
                draw.ellipse((x * k, y * k, (x + w) * k, (y + h) * k), fill=_rgba(op[2]))
            elif kind == "ellipseLine":
                x, y, w, h = op[1]
                draw.ellipse((x * k, y * k, (x + w) * k, (y + h) * k), outline=_rgba(op[2]),
                             width=max(1, int(round(op[3] * k))))
            elif kind == "glow":
                cx, cy, r = op[1]
                yy, xx = np.mgrid[0:size[1], 0:size[0]]
                d = np.sqrt((xx - cx * k) ** 2 + (yy - cy * k) ** 2) / (r * k)
                a = np.clip(1 - d, 0, 1) * op[3]
                rgb = _rgba(op[2])
                arr = np.zeros((size[1], size[0], 4), dtype=np.uint8)
                arr[..., 0], arr[..., 1], arr[..., 2] = rgb[0], rgb[1], rgb[2]
                arr[..., 3] = (a * 255).astype(np.uint8)
                layer = Image.fromarray(arr, "RGBA")
            canvas = Image.alpha_composite(canvas, layer)
        return canvas.resize((int(self.width * scale), int(self.height * scale)), Image.LANCZOS)

    def swift_source(self):
        if self.anchor is not None:
            anchor = f"CGPoint(x: {_num(self.anchor[0])}, y: {_num(self.anchor[1])})"
        else:
            anchor = f"CGPoint(x: 0.5, y: {_num((self.height - self.foot) / self.height)})"
        lines = []
        if self.doc:
            lines.append(f"    /// {self.doc}")
        lines.append(f"    static func {self.name}() -> Sprite {{")
        lines.append(f"        let image = render(CGSize(width: {_num(self.width)}, height: {_num(self.height)})) {{ ctx in")
        for statement in self.swift:
            lines.append(f"            {statement}")
        lines.append("        }")
        lines.append(f"        return Sprite(image: image, anchor: {anchor})")
        lines.append("    }")
        return "\n".join(lines)


def preview_sheet(sprites, path, scale=3, zoom=2, columns=4):
    """Lays the sprites out on the realm's ash-grey ground, at game scale and
    zoomed, so both readability and detail can be judged."""
    cells = []
    for sprite in sprites:
        img = sprite.render(scale * zoom)
        cells.append((sprite.name, img))
    cell_w = max(img.width for _, img in cells) + 40
    cell_h = max(img.height for _, img in cells) + 60
    rows = math.ceil(len(cells) / columns)
    sheet = Image.new("RGBA", (cell_w * columns, cell_h * rows), (46, 42, 40, 255))
    draw = ImageDraw.Draw(sheet)
    for index, (name, img) in enumerate(cells):
        cx = (index % columns) * cell_w
        cy = (index // columns) * cell_h
        sheet.alpha_composite(img, (cx + 20, cy + 40))
        draw.text((cx + 20, cy + 12), name, fill=(220, 210, 190, 255))
    sheet.save(path)
