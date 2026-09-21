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
    static let maxHorizontal: CGFloat = 2.6
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

    // MARK: How the sway turns the drawing

    /// How long the hanging cloth is in the art, shoulders to hem, in canvas
    /// points (the same units as `offset`).
    static let hangLength: CGFloat = 23
    /// The furthest the cloak may swing, in radians: about six degrees.
    static let maxAngle: CGFloat = 0.11

    /// The angle the cloak hangs at, in radians (counter-clockwise positive),
    /// turned about the shoulders so its hem trails by `offset.x`.
    ///
    /// It is a plain rotation of the whole cloak, not a bend: a rotation this
    /// small cannot skew it, stretch it or turn it sideways, and the shoulders,
    /// which stay under the hood and any armour worn there, hardly move.
    /// - Parameter cloth: 0 for something rigid, 1 for free-hanging cloth.
    func angle(cloth: CGFloat) -> CGFloat {
        let raw = atan2(offset.x * cloth, Self.hangLength)
        return min(Self.maxAngle, max(-Self.maxAngle, raw))
    }

    /// Where a sprite whose origin is at the feet must sit, once turned by
    /// `angle`, for the point `pivotHeight` above the feet to stay where it is.
    static func anchorShift(angle: CGFloat, pivotHeight: CGFloat) -> CGPoint {
        CGPoint(x: pivotHeight * sin(angle), y: pivotHeight * (1 - cos(angle)))
    }
}

extension CloakStyle {
    /// How freely a cloak hangs: 1 for a loose cape, less for cloth worn over
    /// armour or cut close. The shoulders never move at all (the cloak turns about them; see `CapeSway.angle`).
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
