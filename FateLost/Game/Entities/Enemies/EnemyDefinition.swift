import CoreGraphics
import Foundation

typealias EnemyKindID = String

/// How an enemy fights.
///
/// Every behaviour is telegraphed: the windup is the warning, and the answer
/// to each one is different. A melee line is walked away from, a caster is
/// broken up, a charger is side-stepped, a summoner is killed first.
enum EnemyBehavior: Equatable {
    /// Closes in and strikes.
    case melee
    /// Closes in, lights a fuse (the windup) and explodes, hurting the
    /// player and its own kind alike.
    case exploder(radius: CGFloat)
    /// Keeps its distance and throws something. It backs away when crowded,
    /// so walking at it is the answer rather than waiting it out.
    case ranged(range: CGFloat, projectileSpeed: CGFloat, sprite: SpriteID)
    /// Winds up in place, then hurls itself along a straight line, damaging
    /// everything it passes through. Side-stepping beats it outright.
    case charger(range: CGFloat, speed: CGFloat, distance: CGFloat)
    /// Hangs back and calls its own kind in. Leaving one alive is a choice
    /// the player pays for.
    case summoner(spawns: EnemyKindID, count: Int, interval: Double, range: CGFloat)
}

/// What a landed blow leaves on the hero besides the damage.
///
/// Both are timed afflictions that show under the health bar, and both are
/// there to answer a way of playing: the bat's bite cuts regeneration so that
/// stacking it cannot make a hero unkillable, and the stalker's cut slows.
enum EnemyOnHit: Equatable {
    /// Health regeneration cut to a tenth (a bat's bite).
    case witherRegen(seconds: Double)
    /// Movement slowed (a stalker's blade across the back of the leg).
    case hamstring(seconds: Double, slow: Double)

    var buffID: String {
        switch self {
        case .witherRegen: return "affliction.wither"
        case .hamstring: return "affliction.hamstring"
        }
    }

    var name: String {
        switch self {
        case .witherRegen: return "Withered"
        case .hamstring: return "Hamstrung"
        }
    }

    var symbol: String {
        switch self {
        case .witherRegen: return "heart.slash.fill"
        case .hamstring: return "tortoise.fill"
        }
    }

    var blurb: String {
        switch self {
        case .witherRegen: return "A bat's bite: 90% of your health regeneration is lost until it fades."
        case .hamstring(_, let slow): return "Cut across the leg: you move \(Int((slow * 100).rounded()))% slower until it fades."
        }
    }

    var duration: Double {
        switch self {
        case .witherRegen(let seconds): return seconds
        case .hamstring(let seconds, _): return seconds
        }
    }

    var modifiers: [StatModifier] {
        switch self {
        case .witherRegen: return [StatModifier(.healthRegen, .more, -0.9)]
        case .hamstring(_, let slow): return [StatModifier(.moveSpeed, .more, -slow)]
        }
    }

    /// The affliction a buff id stands for, if it is one.
    static func forBuff(_ id: String) -> EnemyOnHit? {
        switch id {
        case "affliction.wither": return .witherRegen(seconds: 0)
        case "affliction.hamstring": return .hamstring(seconds: 0, slow: 0.3)
        default: return nil
        }
    }
}

/// Static description of an enemy type. Balance lives in `EnemyCatalog`;
/// systems only read these numbers.
struct EnemyDefinition: Identifiable, Equatable {
    let id: EnemyKindID
    let name: String
    let family: EnemyFamily
    var rank: EnemyRank = .soldier
    let maxHealth: Double
    /// World units per second.
    let moveSpeed: CGFloat
    /// Body radius in world units, for crowding and hits.
    let radius: CGFloat
    /// Damage dealt by one landed strike.
    let attackDamage: Double
    /// How far past touching the player a strike reaches.
    let attackReach: CGFloat
    /// Seconds between starting a strike and it landing. This is the
    /// telegraph: stepping out of reach during it dodges the blow.
    let attackWindup: Double
    /// Seconds after a strike before the next can begin.
    let attackCooldown: Double
    /// 0 takes full knockback, 1 ignores it. Also shortens crowd control.
    let knockbackResistance: CGFloat
    let damageType: DamageType
    let behavior: EnemyBehavior
    /// Experience its death leaves behind, before its rank's multiplier.
    let experience: Int
    /// Relative chance to be chosen when an enemy spawns.
    let spawnWeight: Double
    /// Waves into a run before it can appear.
    var earliestWave: Int = 1
    /// Looks it may take; one is chosen per enemy.
    let spriteVariants: [SpriteID]
    /// Drawn at this multiple of its sprite's natural size, so a boss reads
    /// as a boss without needing art four times over.
    var drawScale: CGFloat = 1
    /// Shown on the banner when this creature holds a wave open.
    var epithet: String?
    /// What a champion does besides its ordinary attack (see `BossSystem`).
    var kit: BossKit?
    /// What a landed blow leaves on the hero.
    var onHit: EnemyOnHit?
    /// Darts about while it closes in, so it is hard to pin down.
    var flutters = false
    /// Nearly invisible until it strikes.
    var isShrouded = false

    var spriteID: SpriteID { spriteVariants.first ?? .enemyGoblin }
    var isBoss: Bool { rank == .boss }

    /// Experience one of these is actually worth.
    var experienceValue: Int {
        max(1, Int((Double(experience) * rank.experienceMultiplier).rounded()))
    }

    func sprite(forEnemyID id: Int) -> SpriteID {
        guard !spriteVariants.isEmpty else { return .enemyGoblin }
        return spriteVariants[abs(id) % spriteVariants.count]
    }
}
