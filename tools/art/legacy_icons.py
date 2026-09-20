"""The Legacy board's own icons: one silhouette per strand, and the echo mark.

    python tools/art/legacy_icons.py            # writes the Swift and a preview
    python tools/art/legacy_icons.py --preview  # preview sheet only

The Swift lands in FateLost/UI/Components/LegacyGlyphData.swift. Each icon is a
few path strings on a 24 x 24 grid, drawn in the parchment colour on the
strand's tint. Commands (all absolute): M x y, L x y, Q cx cy x y,
C c1x c1y c2x c2y x y, E cx cy rx ry (an ellipse), Z.

A style is "fill", "shade" (a darker cut into the silhouette) or "stroke:W"
(a line W wide, optionally "stroke:W:A" with an opacity A).
"""
import math
import os
import re
import sys

from PIL import Image, ImageDraw

INK = (14, 12, 8)

GLYPHS = {
    # A sword: broad blade, fuller, swept guard, grip and pommel.
    "blade": [
        ("fill", "M12 0.8 L15.2 4.2 L15.2 15.2 L8.8 15.2 L8.8 4.2 Z"),
        ("fill", "M3.6 14.8 Q12 12.8 20.4 14.8 L20.4 17.6 Q12 15.8 3.6 17.6 Z"),
        ("fill", "M10.6 17 L13.4 17 L13.4 21 L10.6 21 Z"),
        ("fill", "E 12 22.1 1.6 1.6"),
        ("stroke:1:0.4", "M12 3.6 L12 14"),
    ],
    # An eye: what the mind can hold, seen.
    "focus": [
        ("fill", "M1 12 Q12 1.6 23 12 Q12 22.4 1 12 Z"),
        ("shade", "E 12 12 5 5"),
        ("fill", "E 12 12 2.2 2.2"),
        ("fill", "E 10.6 10.6 1 1"),
    ],
    # A four-leaf clover on its stem.
    "fortune": [
        ("fill", "E 8.1 8.1 4.6 4.6"),
        ("fill", "E 15.9 8.1 4.6 4.6"),
        ("fill", "E 8.1 15.9 4.6 4.6"),
        ("fill", "E 15.9 15.9 4.6 4.6"),
        ("stroke:1.7", "M12 12 Q13.4 18.5 9.4 23"),
        ("stroke:0.8:0.3", "M12 12 L6.6 6.6 M12 12 L17.4 6.6 M12 12 L6.6 17.4 M12 12 L17.4 17.4"),
    ],
    # A hooded head with two eyes in the dark.
    "shadow": [
        ("fill", "M12 1.2 C6.4 1.6 3.4 6.6 4.4 12.6 L2.4 22.8 L21.6 22.8 L19.6 12.6 C20.6 6.6 17.6 1.6 12 1.2 Z"),
        ("shade", "M12 6.4 C8.8 6.4 7.2 9.6 7.7 13 C8.1 15.8 9.8 17 12 17 C14.2 17 15.9 15.8 16.3 13 C16.8 9.6 15.2 6.4 12 6.4 Z"),
        ("fill", "E 10.1 12 1 1.3"),
        ("fill", "E 13.9 12 1 1.3"),
    ],
    # A paw print: what comes when called.
    "bond": [
        ("fill", "M12 12 C8.4 12 5.6 15.2 5.6 18.2 C5.6 20.8 8 21.6 10.2 21.1 C11.2 20.9 11.6 20.6 12 20.6 C12.4 20.6 12.8 20.9 13.8 21.1 C16 21.6 18.4 20.8 18.4 18.2 C18.4 15.2 15.6 12 12 12 Z"),
        ("fill", "E 4.6 10.4 2.1 2.9"),
        ("fill", "E 9.2 5.8 2.2 3.1"),
        ("fill", "E 14.8 5.8 2.2 3.1"),
        ("fill", "E 19.4 10.4 2.1 2.9"),
    ],
    # An hourglass: what was always going to happen, running out.
    "fate": [
        ("fill", "M5.2 1.6 L18.8 1.6 L18.8 3.8 Q18.8 8.6 13.6 12 Q18.8 15.4 18.8 20.2 L18.8 22.4 L5.2 22.4 L5.2 20.2 Q5.2 15.4 10.4 12 Q5.2 8.6 5.2 3.8 Z"),
        ("shade", "M8.6 19.6 Q12 15.4 15.4 19.6 Z"),
        ("shade", "M9 4.4 L15 4.4 Q14.4 6.6 12 8.4 Q9.6 6.6 9 4.4 Z"),
        ("stroke:0.8:0.5", "M12 9.4 L12 15"),
    ],
    # Ripples spreading from a point: what a run leaves behind.
    "echo": [
        ("fill", "E 12 12 2.8 2.8"),
        ("stroke:1.7", "E 12 12 6.2 6.2"),
        ("stroke:1.7:0.65", "E 12 12 10.2 10.2"),
    ],
}


def _parse(d):
    """Flatten a path string to lists of points, one list per subpath."""
    tokens = re.sub(r"([A-Za-z])", lambda m: " " + m.group(1) + " ", d).replace(",", " ").split()
    subpaths = []
    current = []
    i = 0
    pos = (0.0, 0.0)

    def number(k):
        return float(tokens[k])

    while i < len(tokens):
        command = tokens[i]
        i += 1
        if command == "M":
            if current:
                subpaths.append(current)
            pos = (number(i), number(i + 1))
            i += 2
            current = [pos]
        elif command == "L":
            pos = (number(i), number(i + 1))
            i += 2
            current.append(pos)
        elif command == "Q":
            cx, cy, x, y = (number(i + k) for k in range(4))
            i += 4
            for step in range(1, 13):
                t = step / 12
                px = (1 - t) ** 2 * pos[0] + 2 * (1 - t) * t * cx + t * t * x
                py = (1 - t) ** 2 * pos[1] + 2 * (1 - t) * t * cy + t * t * y
                current.append((px, py))
            pos = (x, y)
        elif command == "C":
            c1x, c1y, c2x, c2y, x, y = (number(i + k) for k in range(6))
            i += 6
            for step in range(1, 13):
                t = step / 12
                px = ((1 - t) ** 3 * pos[0] + 3 * (1 - t) ** 2 * t * c1x
                      + 3 * (1 - t) * t * t * c2x + t ** 3 * x)
                py = ((1 - t) ** 3 * pos[1] + 3 * (1 - t) ** 2 * t * c1y
                      + 3 * (1 - t) * t * t * c2y + t ** 3 * y)
                current.append((px, py))
            pos = (x, y)
        elif command == "E":
            cx, cy, rx, ry = (number(i + k) for k in range(4))
            i += 4
            if current:
                subpaths.append(current)
            current = [(cx + rx * math.cos(a * math.pi / 24), cy + ry * math.sin(a * math.pi / 24)) for a in range(49)]
            subpaths.append(current)
            current = []
        elif command == "Z":
            if current:
                current.append(current[0])
                subpaths.append(current)
                current = []
    if current:
        subpaths.append(current)
    return subpaths


def draw(glyph, size, ink, background):
    scale = 8
    big = size * scale
    layer = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    canvas = ImageDraw.Draw(layer, "RGBA")
    k = big / 24
    for style, d in GLYPHS[glyph]:
        for points in _parse(d):
            pts = [(x * k, y * k) for x, y in points]
            if style == "fill":
                canvas.polygon(pts, fill=ink + (255,))
            elif style == "shade":
                canvas.polygon(pts, fill=(14, 12, 8, 150))
            else:
                parts = style.split(":")
                width = float(parts[1])
                alpha = float(parts[2]) if len(parts) > 2 else 1.0
                colour = ink + (int(255 * alpha),)
                canvas.line(pts, fill=colour, width=max(1, int(width * k)), joint="curve")
    out = Image.new("RGBA", (big, big), background + (255,))
    out.alpha_composite(layer)
    return out.resize((size, size), Image.LANCZOS)


TINTS = {
    "blade": 0xC0C4CC, "focus": 0x8A7BE0, "fortune": 0xE8C25A, "shadow": 0x7A5A9E,
    "bond": 0x6FBF7A, "fate": 0xE0B060, "echo": 0xFFB359,
}
PARCHMENT = (0xE6, 0xDB, 0xC7)


def preview(path):
    names = list(GLYPHS)
    sheet = Image.new("RGBA", (len(names) * 150, 350), (40, 36, 34, 255))
    for column, name in enumerate(names):
        tint = TINTS[name]
        rgb = ((tint >> 16) & 255, (tint >> 8) & 255, tint & 255)
        for row, (size, circle) in enumerate(((120, 112), (40, 40), (20, 20))):
            tile = Image.new("RGBA", (circle, circle), (0, 0, 0, 0))
            back = Image.new("RGBA", (circle, circle), rgb + (0,))
            d = ImageDraw.Draw(back)
            d.ellipse((0, 0, circle - 1, circle - 1), fill=tuple(int(c * 0.55) for c in rgb) + (255,),
                      outline=(92, 79, 64, 255))
            glyph = draw(name, int(circle * 0.62), PARCHMENT, (0, 0, 0))
            mask = draw(name, int(circle * 0.62), PARCHMENT, (0, 0, 0)).convert("RGBA")
            # Composite the glyph over the disc (transparent where nothing is drawn).
            layer = _transparent_glyph(name, int(circle * 0.62))
            offset = (circle - layer.width) // 2
            back.alpha_composite(layer, (offset, offset))
            tile.alpha_composite(back)
            y = [10, 140, 200][row]
            sheet.alpha_composite(tile, (column * 150 + 15, y))
        label = ImageDraw.Draw(sheet)
        label.text((column * 150 + 15, 330), name, fill=(200, 200, 200, 255))
    sheet.save(path)


def _transparent_glyph(name, size):
    scale = 8
    big = size * scale
    layer = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    canvas = ImageDraw.Draw(layer, "RGBA")
    k = big / 24
    for style, d in GLYPHS[name]:
        for points in _parse(d):
            pts = [(x * k, y * k) for x, y in points]
            if style == "fill":
                canvas.polygon(pts, fill=PARCHMENT + (255,))
            elif style == "shade":
                canvas.polygon(pts, fill=(14, 12, 8, 150))
            else:
                parts = style.split(":")
                width = float(parts[1])
                alpha = float(parts[2]) if len(parts) > 2 else 1.0
                canvas.line(pts, fill=PARCHMENT + (int(255 * alpha),), width=max(1, int(width * k)), joint="curve")
    return layer.resize((size, size), Image.LANCZOS)


HEADER = """import Foundation

// Generated by tools/art/legacy_icons.py. Edit the Python and rerun it; do not
// edit this file by hand.

/// The Legacy board's icons as path strings on a 24 x 24 grid. See
/// `LegacyGlyph` for how they are read and drawn.
enum LegacyGlyphData {
    /// (style, path) pairs, drawn in order.
    static let shapes: [String: [(style: String, path: String)]] = [
"""


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    preview(os.path.join(here, "legacy-icons-preview.png"))
    if "--preview" in sys.argv:
        return
    root = os.path.dirname(os.path.dirname(here))
    out = os.path.join(root, "FateLost", "UI", "Components", "LegacyGlyphData.swift")
    lines = []
    for name, parts in GLYPHS.items():
        lines.append(f'        "{name}": [')
        for style, d in parts:
            lines.append(f'            ("{style}", "{d}"),')
        lines.append("        ],")
    with open(out, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(HEADER + "\n".join(lines) + "\n    ]\n}\n")
    print(f"wrote {len(GLYPHS)} glyphs")


if __name__ == "__main__":
    main()
