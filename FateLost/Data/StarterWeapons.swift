import Foundation

/// Starter weapon catalogue. Balance lives here, not in combat code.
///
/// A starter weapon only shapes the opening minutes of a run; it never
/// determines class. Three are yours from the first run; the rest are bought
/// from the Armoury with echoes, and every one of them can be mastered.
///
/// They sit within a hand's breadth of each other on damage per second on
/// purpose. What separates them is how that damage arrives — one heavy blow
/// or six light ones, in an arc or down a line — so the choice is about how
/// a run feels to play rather than which weapon is correct.
enum StarterWeapons {
    // MARK: - Yours from the start

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

    // MARK: - Bought from the Armoury

    static let sai = WeaponDefinition(
        id: "starter.sai",
        name: "Paired Sai",
        summary: "Short, blindingly fast, and never more than an arm away.",
        baseDamage: 6,
        attackSpeed: 2.0,
        range: 1.5,
        damageType: .physical,
        tags: [.melee, .weapon, .physical],
        delivery: .meleeArc(arcDegrees: 100),
        targeting: .nearest,
        rarity: .uncommon,
        spriteID: .weaponSai
    )

    static let katana = WeaponDefinition(
        id: "starter.katana",
        name: "Katana",
        summary: "One clean cut at a time, and each one counts.",
        baseDamage: 15,
        attackSpeed: 0.85,
        range: 1.9,
        damageType: .physical,
        tags: [.melee, .weapon, .physical],
        delivery: .meleeArc(arcDegrees: 90),
        targeting: .nearest,
        rarity: .rare,
        spriteID: .weaponKatana
    )

    static let dualDaggers = WeaponDefinition(
        id: "starter.dualDaggers",
        name: "Dual Daggers",
        summary: "A flurry at arm's length. Nothing here is meant to be parried.",
        baseDamage: 5,
        attackSpeed: 2.4,
        range: 1.4,
        damageType: .physical,
        tags: [.melee, .weapon, .physical],
        delivery: .meleeArc(arcDegrees: 80),
        targeting: .nearest,
        rarity: .uncommon,
        spriteID: .weaponDualDaggers
    )

    static let boStaff = WeaponDefinition(
        id: "starter.boStaff",
        name: "Bo Staff",
        summary: "A sweep that clears the whole circle and puts them on their backs.",
        baseDamage: 8,
        attackSpeed: 1.3,
        range: 2.1,
        damageType: .physical,
        tags: [.melee, .weapon, .physical, .twoHanded],
        delivery: .meleeArc(arcDegrees: 260),
        targeting: .nearest,
        rarity: .uncommon,
        spriteID: .weaponBoStaff
    )

    static let flail = WeaponDefinition(
        id: "starter.flail",
        name: "Flail",
        summary: "Heavy, wide, and impossible to guard against.",
        baseDamage: 14,
        attackSpeed: 0.8,
        range: 1.8,
        damageType: .physical,
        tags: [.melee, .weapon, .physical],
        delivery: .meleeArc(arcDegrees: 160),
        targeting: .densestCluster,
        rarity: .rare,
        spriteID: .weaponFlail
    )

    static let warHammer = WeaponDefinition(
        id: "starter.warHammer",
        name: "War Hammer",
        summary: "Slow as winter, and nothing it lands on gets up.",
        baseDamage: 24,
        attackSpeed: 0.5,
        range: 2.0,
        damageType: .physical,
        tags: [.melee, .weapon, .physical, .twoHanded],
        delivery: .meleeArc(arcDegrees: 130),
        targeting: .nearest,
        rarity: .rare,
        spriteID: .weaponWarHammer
    )

    /// The heaviest blade on the rack. It gives up speed for reach, arc and a
    /// blow that lands hard: about the damage per second of the hammer, arriving
    /// in fewer, wider, longer swings.
    static let claymore = WeaponDefinition(
        id: "starter.claymore",
        name: "Claymore",
        summary: "Two hands, a long reach and a wide, slow sweep that ends arguments.",
        baseDamage: 21,
        attackSpeed: 0.6,
        range: 2.4,
        damageType: .physical,
        tags: [.melee, .weapon, .physical, .twoHanded],
        delivery: .meleeArc(arcDegrees: 170),
        targeting: .nearest,
        rarity: .epic,
        spriteID: .weaponClaymore
    )

    static let boomerang = WeaponDefinition(
        id: "starter.boomerang",
        name: "Boomerang",
        summary: "Cuts a line through them going out, and again coming back.",
        baseDamage: 9,
        attackSpeed: 0.9,
        range: 6.5,
        damageType: .physical,
        tags: [.projectile, .ranged, .weapon, .physical],
        delivery: .projectile(ProjectileProfile(
            speed: 11,
            count: 1,
            pierce: 3,
            splashRadius: 0,
            spriteID: .projectileBoomerang,
            returns: true
        )),
        targeting: .densestCluster,
        rarity: .rare,
        spriteID: .weaponBoomerang
    )

    static let emberWand = WeaponDefinition(
        id: "starter.emberWand",
        name: "Ember Wand",
        summary: "Gouts of fire that burst where they land.",
        baseDamage: 11,
        attackSpeed: 0.8,
        range: 6.0,
        damageType: .fire,
        tags: [.projectile, .spell, .magic, .area],
        delivery: .projectile(ProjectileProfile(
            speed: 10,
            count: 1,
            pierce: 0,
            splashRadius: 1.1,
            spriteID: .projectileEmberBolt
        )),
        targeting: .densestCluster,
        rarity: .uncommon,
        spriteID: .weaponEmberWand
    )

    static let rimeWand = WeaponDefinition(
        id: "starter.rimeWand",
        name: "Rime Wand",
        summary: "Shards of ice that pass through the first thing they find.",
        baseDamage: 9,
        attackSpeed: 0.9,
        range: 6.2,
        damageType: .cold,
        tags: [.projectile, .spell, .magic],
        delivery: .projectile(ProjectileProfile(
            speed: 12,
            count: 1,
            pierce: 1,
            splashRadius: 0,
            spriteID: .projectileFrostBolt
        )),
        targeting: .nearestInRange,
        rarity: .uncommon,
        spriteID: .weaponRimeWand
    )

    static let stormWand = WeaponDefinition(
        id: "starter.stormWand",
        name: "Storm Wand",
        summary: "Charges thrown fast enough to run a whole rank through.",
        baseDamage: 8,
        attackSpeed: 1.1,
        range: 5.8,
        damageType: .lightning,
        tags: [.projectile, .spell, .magic],
        delivery: .projectile(ProjectileProfile(
            speed: 18,
            count: 1,
            pierce: 2,
            splashRadius: 0,
            spriteID: .projectileStormBolt
        )),
        targeting: .nearestInRange,
        rarity: .rare,
        spriteID: .weaponStormWand
    )

    /// Every starter in display order.
    static let all: [WeaponDefinition] = [
        sword, bow, staff,
        sai, dualDaggers, katana,
        boStaff, flail, warHammer,
        claymore, boomerang, emberWand, rimeWand, stormWand,
    ]

    /// Starters available with no Legacy unlocks.
    static let defaultUnlocked: Set<WeaponID> = [sword.id, bow.id, staff.id]

    static func definition(for id: WeaponID) -> WeaponDefinition? {
        all.first { $0.id == id }
    }
}
