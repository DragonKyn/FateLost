import CoreGraphics
import Foundation

/// Enemy catalogue. Balance lives here, not in the systems that use it.
enum EnemyCatalog {
    /// Small, quick and fragile. Dangerous only in numbers.
    static let goblin = EnemyDefinition(
        id: "enemy.goblin",
        name: "Goblin",
        maxHealth: 18,
        moveSpeed: 2.5,
        radius: 0.3,
        attackDamage: 7,
        attackReach: 0.28,
        attackWindup: 0.32,
        attackCooldown: 1.1,
        knockbackResistance: 0,
        damageType: .physical,
        spriteID: .enemyGoblin
    )

    static let all: [EnemyDefinition] = [goblin]

    static func definition(for id: EnemyKindID) -> EnemyDefinition? {
        all.first { $0.id == id }
    }

    /// Enemies that spawn in a realm. Each realm gets its own roster as its
    /// bestiary is built out; until then every realm fields goblins.
    static func roster(for realm: RealmID) -> [EnemyDefinition] {
        [goblin]
    }
}
