import CoreGraphics
import Foundation

typealias EnemyKindID = String

/// Static description of an enemy type. Balance lives in `EnemyCatalog`;
/// systems only read these numbers.
struct EnemyDefinition: Identifiable, Codable, Equatable {
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
    /// 0 takes full knockback, 1 ignores it.
    let knockbackResistance: CGFloat
    let damageType: DamageType
    let spriteID: SpriteID
}
