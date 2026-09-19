import CoreGraphics

/// The arena's topology: a rectangle whose opposite edges are joined.
///
/// All simulation positions are stored *wrapped* into `0..<width` and
/// `0..<height`, measured in world units (one unit is one ground tile).
/// Anything that compares two positions — chasing, targeting, pickup range,
/// projectile hits — must go through `delta(from:to:)` or `distance`, which
/// take the short way around the seam. That is what makes the arena feel
/// continuous rather than walled.
struct ToroidalWorld: Equatable {
    let width: CGFloat
    let height: CGFloat

    init(width: CGFloat, height: CGFloat) {
        precondition(width > 0 && height > 0, "World dimensions must be positive")
        self.width = width
        self.height = height
    }

    var size: CGSize { CGSize(width: width, height: height) }
    var center: CGPoint { CGPoint(x: width / 2, y: height / 2) }

    func wrap(_ point: CGPoint) -> CGPoint {
        CGPoint(x: Self.wrap(point.x, period: width), y: Self.wrap(point.y, period: height))
    }

    /// Shortest displacement from `a` to `b`, crossing the seam when shorter.
    func delta(from a: CGPoint, to b: CGPoint) -> CGPoint {
        CGPoint(
            x: Self.shortestDelta(b.x - a.x, period: width),
            y: Self.shortestDelta(b.y - a.y, period: height)
        )
    }

    func distanceSquared(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        delta(from: a, to: b).lengthSquared
    }

    func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        delta(from: a, to: b).length
    }

    static func wrap(_ value: CGFloat, period: CGFloat) -> CGFloat {
        let remainder = value.truncatingRemainder(dividingBy: period)
        let wrapped = remainder < 0 ? remainder + period : remainder
        // A tiny negative remainder plus the period can round up to exactly
        // `period`, which is outside the half-open range.
        return wrapped >= period ? 0 : wrapped
    }

    static func shortestDelta(_ raw: CGFloat, period: CGFloat) -> CGFloat {
        var d = raw.truncatingRemainder(dividingBy: period)
        let half = period / 2
        if d > half {
            d -= period
        } else if d < -half {
            d += period
        }
        return d
    }
}
