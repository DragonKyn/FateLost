import CoreGraphics
import Foundation

typealias EnemyKindID = String

/// How an enemy fights.
enum EnemyBehavior: Equatable {
    /// Closes in and strikes.
    case melee
    /// Closes in, lights a fuse (the windup) and explodes, hurting the
    /// player and its own kind alike.
    case exploder(radius: CGFloat)
}

/// Static description of an enemy type. Balance lives in `EnemyCatalog`;
/// systems only read these numbers.
struct EnemyDefinition: Identifiable, Equatable {
    let id: EnemyKindID
    let name: String
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
    /// Experience its death leaves behind.
    let experience: Int
    /// Relative chance to be chosen when an enemy spawns.
    let spawnWeight: Double
    /// Minutes into a run before it can appear.
    let earliestMinute: Double
    /// Looks it may take; one is chosen per enemy.
    let spriteVariants: [SpriteID]

    var spriteID: SpriteID { spriteVariants.first ?? .enemyGoblin }

    func sprite(forEnemyID id: Int) -> SpriteID {
        guard !spriteVariants.isEmpty else { return .enemyGoblin }
        return spriteVariants[abs(id) % spriteVariants.count]
    }
}
