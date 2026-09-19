import CoreGraphics
import Foundation

/// Enemy catalogue. Balance lives here, not in the systems that use it.
///
/// The Ashen Wilds' goblin warband: each kind asks for a different answer,
/// so no single build handles every one of them for free.
enum EnemyCatalog {
    /// Small, quick and fragile. Dangerous only in numbers.
    static let goblin = EnemyDefinition(
        id: "enemy.goblin", name: "Goblin",
        maxHealth: 18, moveSpeed: 2.5, radius: 0.3,
        attackDamage: 7, attackReach: 0.28, attackWindup: 0.32, attackCooldown: 1.1,
        knockbackResistance: 0, damageType: .physical, behavior: .melee,
        experience: 1, spawnWeight: 1, earliestMinute: 0,
        spriteVariants: [.enemyGoblin, .enemyGoblinHooded, .enemyGoblinHelmed]
    )

    /// Lean and fast, with twin knives. Punishes standing still.
    static let skulker = EnemyDefinition(
        id: "enemy.goblinSkulker", name: "Goblin Skulker",
        maxHealth: 11, moveSpeed: 3.5, radius: 0.26,
        attackDamage: 5, attackReach: 0.24, attackWindup: 0.22, attackCooldown: 0.85,
        knockbackResistance: 0, damageType: .physical, behavior: .melee,
        experience: 1, spawnWeight: 0.45, earliestMinute: 0.6,
        spriteVariants: [.enemyGoblinSkulker, .enemyGoblinSkulkerPale]
    )

    /// Long reach behind a spear. Keeps its distance a heartbeat longer.
    static let spearman = EnemyDefinition(
        id: "enemy.goblinSpearman", name: "Goblin Spearman",
        maxHealth: 26, moveSpeed: 2.2, radius: 0.32,
        attackDamage: 9, attackReach: 0.8, attackWindup: 0.5, attackCooldown: 1.4,
        knockbackResistance: 0.2, damageType: .physical, behavior: .melee,
        experience: 2, spawnWeight: 0.3, earliestMinute: 2,
        spriteVariants: [.enemyGoblinSpearman, .enemyGoblinSpearmanRed]
    )

    /// A hulking club-wielder. Shrugs off shoves and hits very hard.
    static let brute = EnemyDefinition(
        id: "enemy.goblinBrute", name: "Goblin Brute",
        maxHealth: 80, moveSpeed: 1.8, radius: 0.46,
        attackDamage: 17, attackReach: 0.42, attackWindup: 0.6, attackCooldown: 1.7,
        knockbackResistance: 0.65, damageType: .physical, behavior: .melee,
        experience: 5, spawnWeight: 0.14, earliestMinute: 1.5,
        spriteVariants: [.enemyGoblinBrute, .enemyGoblinBruteScarred]
    )

    /// Carries a lit powder keg. Its long fuse is the warning.
    static let sapper = EnemyDefinition(
        id: "enemy.goblinSapper", name: "Goblin Sapper",
        maxHealth: 14, moveSpeed: 3.1, radius: 0.3,
        attackDamage: 24, attackReach: 0.5, attackWindup: 0.9, attackCooldown: 1,
        knockbackResistance: 0, damageType: .fire, behavior: .exploder(radius: 1.6),
        experience: 2, spawnWeight: 0.1, earliestMinute: 3.5,
        spriteVariants: [.enemyGoblinSapper]
    )

    static let all: [EnemyDefinition] = [goblin, skulker, spearman, brute, sapper]

    static func definition(for id: EnemyKindID) -> EnemyDefinition? {
        all.first { $0.id == id }
    }

    /// Enemies that spawn in a realm. Each realm gets its own roster as its
    /// bestiary is built out; until then every realm fields the goblin warband.
    static func roster(for realm: RealmID) -> [EnemyDefinition] {
        all
    }
}
