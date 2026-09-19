import Foundation

/// Starter weapon catalogue. Balance lives here, not in combat code.
///
/// A starter weapon only shapes the opening minutes of a run; it never
/// determines class. Further starters (Greatsword, Crossbow, Daggers, Wand,
/// Mace, Hand Wraps) will be added here and unlocked through Legacy.
enum StarterWeapons {
    static let sword = WeaponDefinition(
        id: "starter.sword",
        name: "Worn Sword",
        summary: "Close, quick cuts at whatever is nearest.",
        baseDamage: 10,
        attackSpeed: 1.25,
        range: 1.6,
        damageType: .physical,
        tags: [.melee, .weapon, .physical],
        delivery: .meleeArc(arcDegrees: 120),
        targeting: .nearest,
        rarity: .common,
        spriteID: .weaponSword
    )

    static let bow = WeaponDefinition(
        id: "starter.bow",
        name: "Hunter's Bow",
        summary: "Arrows loosed at foes from a safe distance.",
        baseDamage: 8,
        attackSpeed: 1.0,
        range: 7.5,
        damageType: .physical,
        tags: [.projectile, .ranged, .weapon, .physical],
        delivery: .projectile(ProjectileProfile(
            speed: 14,
            count: 1,
            pierce: 0,
            splashRadius: 0,
            spriteID: .projectileArrow
        )),
        targeting: .nearestInRange,
        rarity: .common,
        spriteID: .weaponBow
    )

    static let staff = WeaponDefinition(
        id: "starter.staff",
        name: "Ashwood Staff",
        summary: "Slow bolts of raw arcana that burst on impact.",
        baseDamage: 12,
        attackSpeed: 0.7,
        range: 6.0,
        damageType: .arcane,
        tags: [.projectile, .spell, .magic, .area],
        delivery: .projectile(ProjectileProfile(
            speed: 8,
            count: 1,
            pierce: 0,
            splashRadius: 1.2,
            spriteID: .projectileArcaneBolt
        )),
        targeting: .densestCluster,
        rarity: .common,
        spriteID: .weaponStaff
    )

    /// Every starter in display order.
    static let all: [WeaponDefinition] = [sword, bow, staff]

    /// Starters available with no Legacy unlocks.
    static let defaultUnlocked: Set<WeaponID> = [sword.id, bow.id, staff.id]

    static func definition(for id: WeaponID) -> WeaponDefinition? {
        all.first { $0.id == id }
    }
}
