import SwiftUI

/// Draws one of the Legacy board's own icons.
///
/// The strands and the echo mark are silhouettes on a 24 x 24 grid, kept as
/// short path strings (`LegacyGlyphData`, generated from
/// `tools/art/legacy_icons.py`) and drawn here in whatever colour they are
/// given, so they sit on any tint in the same dark-fantasy line as the rest of
/// the game and stay sharp at every size. Being vector, they need no image
/// asset and no scale variants.
struct LegacyGlyph: View {
    let name: String
    var color: Color = FLTheme.Palette.parchment

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 24
            let origin = CGPoint(x: (size.width - 24 * scale) / 2, y: (size.height - 24 * scale) / 2)
            let transform = CGAffineTransform(translationX: origin.x, y: origin.y).scaledBy(x: scale, y: scale)
            for piece in LegacyGlyph.pieces(named: name) {
                let path = piece.path.applying(transform)
                switch piece.style {
                case .fill:
                    context.fill(path, with: .color(color))
                case .shade:
                    context.fill(path, with: .color(Color.black.opacity(0.55)))
                case .stroke(let width, let opacity):
                    context.stroke(path, with: .color(color.opacity(opacity)),
                                   style: StrokeStyle(lineWidth: width * scale, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: Reading the data

    enum Style: Equatable {
        case fill
        case shade
        case stroke(width: CGFloat, opacity: Double)
    }

    struct Piece {
        let style: Style
        let path: Path
    }

    /// Every glyph there is.
    static var names: [String] { LegacyGlyphData.shapes.keys.sorted() }

    private static let cache: [String: [Piece]] = {
        var built: [String: [Piece]] = [:]
        for (name, parts) in LegacyGlyphData.shapes {
            built[name] = parts.map { Piece(style: LegacyGlyph.style(from: $0.style), path: LegacyGlyph.path(from: $0.path)) }
        }
        return built
    }()

    static func pieces(named name: String) -> [Piece] {
        cache[name] ?? []
    }

    static func style(from text: String) -> Style {
        let parts = text.split(separator: ":")
        guard parts.first == "stroke" else { return parts.first == "shade" ? .shade : .fill }
        let width = parts.count > 1 ? Double(parts[1]) ?? 1 : 1
        let opacity = parts.count > 2 ? Double(parts[2]) ?? 1 : 1
        return .stroke(width: CGFloat(width), opacity: opacity)
    }

    /// Reads "M x y L x y Q cx cy x y C c1x c1y c2x c2y x y E cx cy rx ry Z".
    static func path(from text: String) -> Path {
        var tokens: [String] = []
        var number = ""
        func flush() {
            if !number.isEmpty { tokens.append(number) }
            number = ""
        }
        for character in text {
            if character.isLetter {
                flush()
                tokens.append(String(character))
            } else if character == " " || character == "," {
                flush()
            } else {
                number.append(character)
            }
        }
        flush()

        var path = Path()
        var index = 0
        func next() -> CGFloat {
            defer { index += 1 }
            return index < tokens.count ? CGFloat(Double(tokens[index]) ?? 0) : 0
        }
        while index < tokens.count {
            let command = tokens[index]
            index += 1
            switch command {
            case "M":
                path.move(to: CGPoint(x: next(), y: next()))
            case "L":
                path.addLine(to: CGPoint(x: next(), y: next()))
            case "Q":
                let control = CGPoint(x: next(), y: next())
                path.addQuadCurve(to: CGPoint(x: next(), y: next()), control: control)
            case "C":
                let first = CGPoint(x: next(), y: next())
                let second = CGPoint(x: next(), y: next())
                path.addCurve(to: CGPoint(x: next(), y: next()), control1: first, control2: second)
            case "E":
                let centre = CGPoint(x: next(), y: next())
                let radiusX = next()
                let radiusY = next()
                path.addEllipse(in: CGRect(x: centre.x - radiusX, y: centre.y - radiusY,
                                           width: radiusX * 2, height: radiusY * 2))
            case "Z":
                path.closeSubpath()
            default:
                break
            }
        }
        return path
    }
}

/// A strand's icon: its own silhouette where it has one, otherwise the system
/// symbol that already suited it.
struct LegacyBranchIcon: View {
    let branch: LegacyBranch
    /// The square the icon is drawn in.
    var size: CGFloat = 20
    var color: Color = FLTheme.Palette.parchment

    var body: some View {
        if let glyph = branch.glyph {
            LegacyGlyph(name: glyph, color: color)
                .frame(width: size, height: size)
        } else {
            Image(systemName: branch.symbol)
                .font(.system(size: size * 0.75, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: size, height: size)
        }
    }
}

/// The mark for echoes, the currency Legacy is bought with.
struct EchoGlyph: View {
    var size: CGFloat = 16
    var color: Color = FLTheme.Palette.abyss

    var body: some View {
        LegacyGlyph(name: "echo", color: color)
            .frame(width: size, height: size)
    }
}
