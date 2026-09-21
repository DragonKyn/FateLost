import CoreGraphics
import Foundation

/// Secondary motion for loose cloth: a cloak that lags behind a walking hero,
/// swings a little when they turn and settles when they stop.
///
/// It is one damped spring on the hem, not a cloth simulation. The hem is
/// pulled toward a point opposite the hero's motion, springs there with a
/// little overshoot, and is clamped so it can never stretch, spin or fold over.
/// A few floating-point operations a frame per hero, and entirely visual: it
/// reads the velocity the hero is already drawn with, so it costs the network
/// nothing and cannot disagree with the game.
struct CapeSway {
    /// Where the hem is, relative to where it hangs at rest, in points. Positive
    /// x is toward the way the hero faces.
    private(set) var offset: CGPoint = .zero
    private var speed: CGPoint = .zero

    /// The furthest the hem may swing.
    static let maxHorizontal: CGFloat = 3.0
    static let maxVertical: CGFloat = 1.2
    /// How hard the cloth is pulled toward where the motion wants it, and how
    /// much it is held back. These give a damping ratio near 0.5: one soft
    /// overshoot, then rest.
    static let stiffness: CGFloat = 85
    static let damping: CGFloat = 9.2
    /// Points of hem lag per point-per-second of the hero's speed.
    static let lagPerSpeed: CGFloat = 0.028
    static let liftPerSpeed: CGFloat = 0.008
    /// A step longer than this is taken in pieces, so a stall cannot fling the cloth.
    static let maxStep: CGFloat = 1.0 / 60

    /// Advances the cloth.
    /// - Parameters:
    ///   - velocity: The hero's velocity in the figure's own space (x toward
    ///     the way it faces), in points per second.
    ///   - time: A steady clock for the idle breathing.
    mutating func step(dt: CGFloat, velocity: CGPoint, time: Double) {
        // Where the motion wants the hem: behind, and a touch low on the way up.
        let breathe = CGFloat(sin(time * 1.6)) * 0.35
        var target = CGPoint(x: -velocity.x * Self.lagPerSpeed + breathe,
                             y: -velocity.y * Self.liftPerSpeed)
        target.x = Self.clamp(target.x, Self.maxHorizontal)
        target.y = Self.clamp(target.y, Self.maxVertical)

        var remaining = min(max(dt, 0), 0.25)
        while remaining > 0.0001 {
            let piece = min(remaining, Self.maxStep)
            remaining -= piece
            speed.x += (Self.stiffness * (target.x - offset.x) - Self.damping * speed.x) * piece
            speed.y += (Self.stiffness * (target.y - offset.y) - Self.damping * speed.y) * piece
            offset.x += speed.x * piece
            offset.y += speed.y * piece
        }
        // Whatever the spring did, the hem stays inside its limits.
        offset.x = Self.clamp(offset.x, Self.maxHorizontal * 1.15)
        offset.y = Self.clamp(offset.y, Self.maxVertical * 1.15)
    }

    /// Forgets any swing: for a fallen hero, or a change of figure.
    mutating func reset() {
        offset = .zero
        speed = .zero
    }

    private static func clamp(_ value: CGFloat, _ limit: CGFloat) -> CGFloat {
        min(limit, max(-limit, value))
    }

    // MARK: How the sway bends the drawing

    /// Fractions of the cloak's height, from the hem up, at which the sway is
    /// applied, and how much of it each carries. The shoulders (the top) never
    /// move, which is what keeps armour worn on them, and the hood, rigid.
    static let rows: [(height: CGFloat, share: CGFloat)] = [
        (0, 1.0), (0.16, 0.85), (0.42, 0.25), (1, 0),
    ]
    /// The same across the width of the picture, from its back edge (the left
    /// of a figure facing right) to its front. Cloth trails: the back edge is
    /// thrown out and the front edge, the way the hero is going, hardly moves,
    /// so the hem flares rather than sliding over as one slab.
    static let columns: [(across: CGFloat, share: CGFloat)] = [
        (0, 1.0), (0.3, 1.0), (0.5, 0.65), (0.7, 0.3), (1, 0.2),
    ]

    /// The points of a warp grid of `columns.count - 1` by `rows.count - 1`
    /// cells for the current sway, in the unit square of the cloak's own image
    /// (y up): the source, and where each point is moved to. Row-major from the
    /// bottom left.
    /// - Parameter cloth: 0 for something rigid, 1 for free-hanging cloth.
    func warp(imageSize: CGSize, cloth: CGFloat) -> (source: [SIMD2<Float>], destination: [SIMD2<Float>]) {
        var source: [SIMD2<Float>] = []
        var destination: [SIMD2<Float>] = []
        let dx = Float(offset.x * cloth / max(imageSize.width, 1))
        let dy = Float(offset.y * cloth / max(imageSize.height, 1))
        for row in Self.rows {
            for column in Self.columns {
                let point = SIMD2<Float>(Float(column.across), Float(row.height))
                source.append(point)
                destination.append(SIMD2(point.x + dx * Float(row.share * column.share),
                                         point.y + dy * Float(row.share)))
            }
        }
        return (source, destination)
    }
}

extension CloakStyle {
    /// How freely a cloak hangs: 1 for a loose cape, less for cloth worn over
    /// armour or cut close. The shoulders never move at all (see `CapeSway.rows`).
    var clothiness: CGFloat {
        switch self {
        case .hooded, .shroud, .pilgrim, .vampire: return 1
        case .longCoat, .wizard, .angelic: return 0.9
        case .demonic: return 0.85
        case .druid, .mantle: return 0.8
        case .ninja: return 0.6
        case .samurai: return 0.4
        case .paladin: return 0.3
        }
    }
}
