import Foundation

typealias WeaponID = String

/// How a weapon's automatic attack is delivered.
enum AttackDelivery: Codable, Equatable {
    /// A sweep in front of the wielder hitting everything inside the arc.
    case meleeArc(arcDegrees: Double)
    case projectile(ProjectileProfile)
}

struct ProjectileProfile: Codable, Equatable {
    /// World units per second.
    var speed: Double
    var count: Int
    /// Enemies passed through before the projectile is spent.
    var pierce: Int
    /// World-unit radius of the impact splash; zero for none.
    var splashRadius: Double
    var spriteID: SpriteID
    /// Comes back to the thrower halfway through its flight, striking
    /// everything again on the return. Only the boomerang does this.
    var returns: Bool = false
}

/// How the automatic attack chooses a target. Kept on the weapon so a staff
/// can prefer clusters while a sword prefers whatever is closest.
enum TargetingPreference: String, Codable {
    case nearest
    case nearestInRange
    case densestCluster
}

/// Static definition of a weapon. Rolled instances (with affixes and a
/// rarity) will reference one of these by `id` once loot arrives in Phase 4.
struct WeaponDefinition: Identifiable, Codable, Equatable {
    let id: WeaponID
    let name: String
    let summary: String
    let baseDamage: Double
    /// Attacks per second.
    let attackSpeed: Double
    /// World units.
    let range: Double
    let damageType: DamageType
    let tags: Set<CombatTag>
    let delivery: AttackDelivery
    let targeting: TargetingPreference
    let rarity: ItemRarity
    let spriteID: SpriteID

    var damagePerSecond: Double { baseDamage * attackSpeed }
}
