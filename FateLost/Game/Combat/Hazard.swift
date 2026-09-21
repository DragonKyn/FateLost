import CoreGraphics
import Foundation

/// Ground a champion has marked and is about to strike.
///
/// A hazard is the boss fight's promise that nothing is unavoidable: it is
/// drawn on the ground from the moment it exists, fills as its warning runs
/// out, and only then hurts whoever is still standing in it. Stepping out of
/// the marked ground during the warning is always a complete answer.
///
/// It is host-owned and replicated whole (see `NetHazard`), so every player
/// in a party sees the same marks at the same time.
struct Hazard: Equatable {
    enum Shape: UInt8 {
        /// A disc around `position`: `size` is its radius.
        case circle
        /// A wedge from `position` along `direction`: `size` is its reach and
        /// `width` its half-angle in radians.
        case cone
        /// A strip from `position` along `direction`: `size` is its length and
        /// `width` its half-width.
        case lane
    }

    /// How long the ground stays lit after it lands.
    static let afterglow: Double = 0.3

    var id: Int
    var shape: Shape
    var position: CGPoint
    var direction: CGPoint
    var size: CGFloat
    var width: CGFloat
    /// Seconds between appearing and landing.
    var warning: Double
    /// Seconds since it appeared.
    var age: Double = 0
    var damage: Double
    var type: DamageType
    var visual: VisualStyle
    var hasLanded = false

    /// Seconds it stays dangerous after landing (a burning pool, a sweeping
    /// beam), hurting `tickDamage` every `tickEvery` seconds to whoever is in it.
    var linger: Double = 0
    var tickDamage: Double = 0
    var tickEvery: Double = 0.5
    var tickTimer: Double = 0
    /// Radians a second the strip turns while it lingers (a sweeping beam).
    var spin: CGFloat = 0
    /// The hero it follows until `lockTime` seconds before it lands (a hunt).
    var follows: Int?
    var lockTime: Double = 0
    /// The champion that appears here as it lands (a blink).
    var carriesBoss: Int?
    /// Drawn to show where something will happen, and never hurts by itself.
    var isGuide = false

    /// 0 as it appears, 1 as it lands.
    var progress: Double { warning > 0 ? max(0, min(1, age / warning)) : 1 }
    var isFinished: Bool { age >= warning + max(Self.afterglow, linger) }
    /// Landed, and still hurting.
    var isActive: Bool { hasLanded && linger > 0 && age < warning + linger }

    /// Whether a body of `radius` at `point` is inside the marked ground.
    func covers(_ point: CGPoint, radius: CGFloat, world: ToroidalWorld) -> Bool {
        let offset = world.delta(from: position, to: point)
        switch shape {
        case .circle:
            return offset.length <= size + radius
        case .cone:
            let distance = offset.length
            guard distance <= size + radius else { return false }
            // Right at the point of the wedge there is no direction to speak of.
            if distance <= radius + 0.3 { return true }
            let cosine = max(-1, min(1, offset.dot(direction) / distance))
            let slack = asin(min(1, radius / distance))
            return acos(cosine) <= width + slack
        case .lane:
            let along = offset.dot(direction)
            let across = abs(offset.x * direction.y - offset.y * direction.x)
            return along >= -radius && along <= size + radius && across <= width + radius
        }
    }
}
