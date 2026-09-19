import CoreGraphics
import Foundation

/// A fact about the player that skills can depend on ("while moving…",
/// "below half health…"). Evaluated once per step into `PlayerConditionState`.
enum PlayerCondition: Equatable {
    case moving
    /// Has stood still for at least half a second.
    case stationary
    case healthBelow(Double)
    case healthAbove(Double)
    /// Killed an enemy within this many seconds.
    case recentKill(Double)
    /// Was struck within this many seconds.
    case recentlyHurt(Double)
    /// At least this many enemies within 2.5 units.
    case surrounded(Int)
    /// Has a barrier up.
    case shielded
    case stealthed
    /// In any shapeshifted form.
    case transformed
    /// Dodged an attack within this many seconds.
    case recentDodge(Double)
}

/// A fact about the enemy being hit.
enum TargetCondition: Equatable {
    case status(StatusKind)
    /// Has any status at all.
    case afflicted
    /// Has at least this many different elemental statuses.
    case elementalStatuses(Int)
    case healthBelow(Double)
    case healthAbove(Double)
    /// Facing away from the player (a backstab).
    case facingAway
    case within(CGFloat)
    case beyond(CGFloat)
}

/// What sets a proc off.
enum SkillTrigger: Equatable {
    /// A direct hit (weapon, ability or summon, not damage over time) that
    /// carries all of `tags`, and is of `type` when given.
    case hit(tags: TagMask, type: DamageType?)
    case criticalHit
    /// An enemy died. `killedBy` narrows to killing blows of one type.
    case kill(killedBy: DamageType?)
    /// The player was struck.
    case hurt
    case dodge
    /// Every `seconds`.
    case interval(Double)
    /// The player used an ability.
    case abilityCast
    /// The player took on a form.
    case transform
    /// The weapon attacked.
    case attack
    /// Every nth weapon attack.
    case everyNthAttack(Int)
}

/// How an effect looks and sounds. Presentation maps each style to colours,
/// particles and a sound; the simulation only passes it along.
enum VisualStyle: String, Codable, CaseIterable {
    case physical
    case fire
    case frost
    case lightning
    case arcane
    case holy
    case shadow
    case nature
    case poison
    case sonic
    case blood
    case fate

    static func matching(_ type: DamageType) -> VisualStyle {
        switch type {
        case .physical: return .physical
        case .fire: return .fire
        case .cold: return .frost
        case .lightning: return .lightning
        case .arcane: return .arcane
        case .holy: return .holy
        case .shadow: return .shadow
        case .poison: return .poison
        }
    }
}
