import CoreGraphics
import Foundation

/// A minion, companion or orbiting blade fighting for the player.
struct Ally {
    let id: Int
    let spec: SummonSpec
    var position: CGPoint
    /// Seconds left; infinite for companions.
    var remaining: Double
    var cooldown: Double = 0
    /// Orbit angle for orbiting allies.
    var angle: CGFloat
    var heading = CGPoint(x: 1, y: 0)
    /// Set for companions the build keeps alive.
    let companionKey: String?
    /// Resting spot around the player, as an angle, so allies don't stack.
    let restAngle: CGFloat
    /// Seconds since it last attacked, for presentation.
    var timeSinceAttack: Double = 10
}

/// A lasting area effect: a placed field or an aura following the player.
struct Zone {
    let id: Int
    let spec: ZoneSpec
    var position: CGPoint
    /// Seconds left; infinite for auras.
    var remaining: Double
    var tickTimer: Double
    /// A permanent aura from a passive skill.
    let isAura: Bool
    let depth: Int
    /// Current radius, after area size.
    var radius: CGFloat
    var age: Double = 0
}

/// An impact on its way down.
struct PendingStrike {
    var position: CGPoint
    var remaining: Double
    let radius: CGFloat
    let damage: DamageSpec?
    let status: StatusApplication?
    let visual: VisualStyle
    let depth: Int
}

/// Experience lying in the world, waiting to be collected.
struct ExperienceOrb {
    let id: Int
    var position: CGPoint
    var value: Int
    /// Drawn toward the player once they come close.
    var attracted = false
    var speed: CGFloat = 0
}

/// An effect waiting to run. Triggers queue these instead of acting
/// immediately, so an effect never runs in the middle of another system's
/// loop over the enemy arrays.
struct QueuedAction {
    let action: EffectAction
    let origin: CGPoint
    /// The enemy involved, if any, by stable id (indices move on removal).
    let targetID: Int?
    let direction: CGPoint
    let depth: Int
    /// The ability being cast, for statistics.
    let ability: AbilityID?
}

/// The player facts conditions test, refreshed once per step.
struct ConditionState {
    var isMoving = false
    var timeStationary: Double = 0
    var healthFraction: Double = 1
    var timeSinceKill: Double = .infinity
    var timeSinceHit: Double = .infinity
    var timeSinceDodge: Double = .infinity
    var nearbyEnemies = 0
    var isShielded = false
    var isStealthed = false
    var isTransformed = false

    func holds(_ condition: PlayerCondition) -> Bool {
        switch condition {
        case .moving: return isMoving
        case .stationary: return !isMoving && timeStationary >= 0.5
        case .healthBelow(let fraction): return healthFraction < fraction
        case .healthAbove(let fraction): return healthFraction > fraction
        case .recentKill(let seconds): return timeSinceKill <= seconds
        case .recentlyHurt(let seconds): return timeSinceHit <= seconds
        case .surrounded(let count): return nearbyEnemies >= count
        case .shielded: return isShielded
        case .stealthed: return isStealthed
        case .transformed: return isTransformed
        case .recentDodge(let seconds): return timeSinceDodge <= seconds
        }
    }
}

/// Character-level scaling shared by weapons and skills.
///
/// Both grow with level at the same rate, so a weapon-focused build and a
/// skill-focused build keep pace with each other and with the horde.
enum SkillPower {
    /// Skill power at level 1: a starter sword blow.
    static let reference: Double = 10

    static func growth(level: Int, perLevel: Double) -> Double {
        1 + perLevel * Double(max(level, 1) - 1)
    }
}
