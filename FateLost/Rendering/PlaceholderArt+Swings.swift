import UIKit

/// The signature trail of each family of melee weapon (see `SwingStyle`).
/// Every one is drawn white, pointing along +x on a 128-point square, and
/// is tinted and animated by `EffectsRenderer`.
extension PlaceholderArt {
    private static let swingCanvas: CGFloat = 128

    static func swingSprite(for id: SpriteID) -> Sprite? {
        switch id {
        case .fxSwingHeavy: return swing { heavyCleave($0) }
        case .fxSwingThin: return swing { hairlineCut($0) }
        case .fxSwingReap: return swing { reapingArc($0) }
        case .fxSwingClaw: return swing { clawRakes($0) }
        case .fxSwingLash: return swing { whipLash($0) }
        case .fxSwingRing: return swing { spinRing($0) }
        default: return nil
        }
    }

    private static func swing(_ draw: (CGContext) -> Void) -> Sprite {
        let image = render(CGSize(width: swingCanvas, height: swingCanvas), draw: draw)
        return Sprite(image: image, anchor: CGPoint(x: 0.5, y: 0.5))
    }

    private static var centre: CGPoint { CGPoint(x: swingCanvas / 2, y: swingCanvas / 2) }
    private static var reach: CGFloat { swingCanvas / 2 - 1 }

    /// A crescent from `-half` to `+half` degrees, in nested bands that get
    /// brighter toward the rim. `width(u)` is the band's thickness along the
    /// arc (u from 0 at one tip to 1 at the other) and `outer(u)` its outer
    /// radius, both as fractions of the reach.
    private static func crescent(_ ctx: CGContext, half: CGFloat, bands: [(inner: CGFloat, alpha: CGFloat)],
                                 steps: Int = 64, width: (CGFloat) -> CGFloat,
                                 outer: (CGFloat) -> CGFloat = { _ in 1 }) {
        for band in bands {
            var points: [CGPoint] = []
            points.reserveCapacity(steps * 2 + 2)
            for step in 0...steps {
                let u = CGFloat(step) / CGFloat(steps)
                let angle = (-half + 2 * half * u) * .pi / 180
                let radius = reach * outer(u)
                points.append(CGPoint(x: centre.x + radius * cos(angle), y: centre.y + radius * sin(angle)))
            }
            for step in stride(from: steps, through: 0, by: -1) {
                let u = CGFloat(step) / CGFloat(steps)
                let angle = (-half + 2 * half * u) * .pi / 180
                let radius = reach * outer(u) * (1 - (1 - band.inner) * width(u))
                points.append(CGPoint(x: centre.x + radius * cos(angle), y: centre.y + radius * sin(angle)))
            }
            fillPolygon(ctx, points, UIColor(white: 1, alpha: band.alpha))
        }
    }

    /// Thickest in the middle and drawn to a point at each tip.
    private static func taper(_ u: CGFloat) -> CGFloat {
        pow(max(0, sin(.pi * u)), 0.6)
    }

    /// Claymore, war hammer, heavy axe: a broad crescent with a rough,
    /// broken rim, as if the air itself was torn.
    private static func heavyCleave(_ ctx: CGContext) {
        crescent(ctx, half: 75,
                 bands: [(0.38, 0.10), (0.55, 0.22), (0.70, 0.45), (0.84, 0.80), (0.93, 1.0)],
                 steps: 104, width: taper,
                 outer: { u in
                     let notch = Int(u * 26)
                     let wobble = (sin(Double(notch) * 91.37) * 437.585).truncatingRemainder(dividingBy: 1)
                     return 0.955 + 0.045 * CGFloat(abs(wobble))
                 })
    }

    /// Katana and daggers: a hairline crescent, all edge.
    private static func hairlineCut(_ ctx: CGContext) {
        crescent(ctx, half: 55, bands: [(0.80, 0.15), (0.88, 0.45), (0.94, 1.0)], width: taper)
    }

    /// Scythe and halberd: a long crescent, thin at the trailing tip and
    /// swelling to a heavy leading edge.
    private static func reapingArc(_ ctx: CGContext) {
        crescent(ctx, half: 85, bands: [(0.62, 0.12), (0.74, 0.28), (0.84, 0.55), (0.93, 0.95)], steps: 96,
                 width: { u in (0.15 + 0.85 * pow(u, 1.4)) * pow(max(0, sin(.pi * min(1, u * 1.05))), 0.35) })
    }

    /// A tapered stroke along a slight curve, sharp at both ends.
    private static func lens(_ ctx: CGContext, from start: CGPoint, to end: CGPoint, width: CGFloat,
                             alpha: CGFloat, bulge: CGFloat) {
        let dx = end.x - start.x, dy = end.y - start.y
        let length = max(0.001, (dx * dx + dy * dy).squareRoot())
        let normal = CGPoint(x: -dy / length, y: dx / length)
        var near: [CGPoint] = [], far: [CGPoint] = []
        for step in 0...24 {
            let s = CGFloat(step) / 24
            let bend = bulge * sin(.pi * s)
            let base = CGPoint(x: start.x + dx * s + normal.x * bend, y: start.y + dy * s + normal.y * bend)
            let half = width * pow(max(0, sin(.pi * s)), 0.7) / 2
            near.append(CGPoint(x: base.x + normal.x * half, y: base.y + normal.y * half))
            far.append(CGPoint(x: base.x - normal.x * half, y: base.y - normal.y * half))
        }
        fillPolygon(ctx, near + far.reversed(), UIColor(white: 1, alpha: alpha))
    }

    /// Hand claws and sai: three parallel rakes across whatever is ahead.
    private static func clawRakes(_ ctx: CGContext) {
        for offset: CGFloat in [-0.16, 0, 0.16] {
            let start = CGPoint(x: centre.x + (0.52 + offset) * reach, y: centre.y - 0.46 * reach)
            let end = CGPoint(x: centre.x + (0.90 + offset) * reach, y: centre.y + 0.46 * reach)
            lens(ctx, from: start, to: end, width: 12, alpha: 0.18, bulge: 6)
            lens(ctx, from: start, to: end, width: 6, alpha: 0.5, bulge: 6)
            lens(ctx, from: start, to: end, width: 2.6, alpha: 1, bulge: 6)
        }
    }

    /// Whip, flail, nunchaku: a curling line that straightens toward a bright
    /// tip, where the crack is.
    private static func whipLash(_ ctx: CGContext) {
        func point(_ s: CGFloat) -> CGPoint {
            CGPoint(x: centre.x + (0.10 + 0.86 * s) * reach,
                    y: centre.y + 0.20 * reach * pow(1 - s, 0.9) * sin(2 * .pi * 1.3 * s))
        }
        for (widest, alpha) in [(CGFloat(11), CGFloat(0.15)), (6, 0.45), (2.8, 1)] {
            var near: [CGPoint] = [], far: [CGPoint] = []
            for step in 0...60 {
                let s = CGFloat(step) / 60
                let here = point(s)
                let ahead = point(min(1, s + 0.01))
                let behind = point(max(0, s - 0.01))
                let dx = ahead.x - behind.x, dy = ahead.y - behind.y
                let length = max(0.001, (dx * dx + dy * dy).squareRoot())
                let half = widest * (1 - 0.75 * s) / 2
                near.append(CGPoint(x: here.x - dy / length * half, y: here.y + dx / length * half))
                far.append(CGPoint(x: here.x + dy / length * half, y: here.y - dx / length * half))
            }
            fillPolygon(ctx, near + far.reversed(), UIColor(white: 1, alpha: alpha))
        }
        let tip = point(1)
        for (radius, alpha) in [(CGFloat(9), CGFloat(0.25)), (5, 0.6), (2.5, 1)] {
            ctx.setFillColor(UIColor(white: 1, alpha: alpha).cgColor)
            ctx.fillEllipse(in: CGRect(x: tip.x - radius, y: tip.y - radius, width: radius * 2, height: radius * 2))
        }
    }

    /// Bo staff: a full ring, bright where the staff is and fading behind it,
    /// so spinning it reads as a blur chasing itself.
    private static func spinRing(_ ctx: CGContext) {
        let segments = 90
        for segment in 0..<segments {
            let from = CGFloat(segment) / CGFloat(segments) * 2 * .pi
            let to = CGFloat(segment + 1) / CGFloat(segments) * 2 * .pi + 0.012
            let alpha = 0.95 * pow(1 - CGFloat(segment) / CGFloat(segments), 1.3)
            let path = CGMutablePath()
            path.addArc(center: centre, radius: reach, startAngle: from, endAngle: to, clockwise: false)
            path.addArc(center: centre, radius: reach * 0.74, startAngle: to, endAngle: from, clockwise: true)
            path.closeSubpath()
            ctx.setFillColor(UIColor(white: 1, alpha: alpha).cgColor)
            ctx.addPath(path)
            ctx.fillPath()
        }
    }
}
