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

    /// A long thrust with real reach and a narrow arc: fewer enemies in the
    /// cone than a sword, but caught at a distance nothing else here matches
    /// this early.
    static let spear = WeaponDefinition(
        id: "starter.spear",
        name: "Spear",
        summary: "A thrust with real reach. Keeps whatever it hits at arm's length.",
        baseDamage: 10,
        attackSpeed: 1.15,
        range: 2.6,
        damageType: .physical,
        tags: [.melee, .weapon, .physical],
        delivery: .meleeArc(arcDegrees: 45),
        targeting: .nearest,
        rarity: .uncommon,
        spriteID: .weaponSpear
    )

    /// A heavier, slower spear with the longest reach and narrowest arc of
    /// any melee weapon: one target, hit hard, from further away than
    /// anything gets close enough to answer.
    static let lance = WeaponDefinition(
        id: "starter.lance",
        name: "Lance",
        summary: "The longest reach in the rack, and the least room for error.",
        baseDamage: 23,
        attackSpeed: 0.55,
        range: 2.8,
        damageType: .physical,
        tags: [.melee, .weapon, .physical, .twoHanded],
        delivery: .meleeArc(arcDegrees: 45),
        targeting: .nearest,
        rarity: .epic,
        spriteID: .weaponLance
    )

    /// An axe blade, a hook and a spike on one long haft: the reach of a
    /// spear with a wider bite than either a spear or an axe manages alone.
    static let halberd = WeaponDefinition(
        id: "starter.halberd",
        name: "Halberd",
        summary: "An axe, a hook and a spike, all at the reach of a spear.",
        baseDamage: 16.5,
        attackSpeed: 0.78,
        range: 2.5,
        damageType: .physical,
        tags: [.melee, .weapon, .physical, .twoHanded],
        delivery: .meleeArc(arcDegrees: 150),
        targeting: .nearest,
        rarity: .rare,
        spriteID: .weaponHalberd
    )

    /// A wide, low sweep that reaps everything in its arc, dealt in the
    /// unlikeliest damage type on the rack.
    static let scythe = WeaponDefinition(
        id: "starter.scythe",
        name: "Scythe",
        summary: "A wide, low sweep. It does not distinguish between one enemy and several.",
        baseDamage: 13,
        attackSpeed: 0.78,
        range: 2.2,
        damageType: .shadow,
        tags: [.melee, .weapon, .physical, .twoHanded],
        delivery: .meleeArc(arcDegrees: 220),
        targeting: .densestCluster,
        rarity: .rare,
        spriteID: .weaponScythe
    )

    /// The single hardest-hitting weapon in the rack, at the cost of the
    /// slowest attack speed and a plain arc.
    static let heavyAxe = WeaponDefinition(
        id: "starter.heavyAxe",
        name: "Heavy Axe",
        summary: "It does not ask twice.",
        baseDamage: 27,
        attackSpeed: 0.48,
        range: 2.0,
        damageType: .physical,
        tags: [.melee, .weapon, .physical, .twoHanded],
        delivery: .meleeArc(arcDegrees: 140),
        targeting: .nearest,
        rarity: .epic,
        spriteID: .weaponHeavyAxe
    )

    /// The longest reach of any weapon that isn't thrown or shot, and the
    /// narrowest hitbox: a thin line rather than an arc or a cone.
    static let whip = WeaponDefinition(
        id: "starter.whip",
        name: "Whip",
        summary: "Reach without ever closing the distance.",
        baseDamage: 6,
        attackSpeed: 1.9,
        range: 3.2,
        damageType: .physical,
        tags: [.melee, .weapon, .physical],
        delivery: .meleeArc(arcDegrees: 30),
        targeting: .nearest,
        rarity: .uncommon,
        spriteID: .weaponWhip
    )

    /// A blurring flurry at the shortest range in the rack: nothing hits
    /// faster, and nothing asks to be this close.
    static let nunchaku = WeaponDefinition(
        id: "starter.nunchaku",
        name: "Nunchaku",
        summary: "Never quite where you'd expect. Blindingly fast, up close.",
        baseDamage: 6.5,
        attackSpeed: 2.0,
        range: 1.5,
        damageType: .physical,
        tags: [.melee, .weapon, .physical],
        delivery: .meleeArc(arcDegrees: 100),
        targeting: .nearest,
        rarity: .rare,
        spriteID: .weaponNunchaku
    )

    /// Four curved blades over the knuckles: fast, close, and at its best in
    /// a shapeshifted form, where the claws are hardly the strangest thing
    /// about the hand wearing them.
    static let handClaws = WeaponDefinition(
        id: "starter.handClaws",
        name: "Hand Claws",
        summary: "Fast, close, and at their best mid-transformation.",
        baseDamage: 5,
        attackSpeed: 2.5,
        range: 1.3,
        damageType: .physical,
        tags: [.melee, .weapon, .physical],
        delivery: .meleeArc(arcDegrees: 70),
        targeting: .nearest,
        rarity: .rare,
        spriteID: .weaponHandClaws
    )

    /// A slow, hard bolt with real pierce: fewer shots than the bow, each
    /// one worth more, and able to run a whole rank through.
    static let crossbow = WeaponDefinition(
        id: "starter.crossbow",
        name: "Crossbow",
        summary: "Fewer bolts than the bow loosed, and each one worth more.",
        baseDamage: 15,
        attackSpeed: 0.7,
        range: 8.2,
        damageType: .physical,
        tags: [.projectile, .ranged, .weapon, .physical],
        delivery: .projectile(ProjectileProfile(
            speed: 20,
            count: 1,
            pierce: 2,
            splashRadius: 0,
            spriteID: .projectileCrossbowBolt
        )),
        targeting: .nearestInRange,
        rarity: .uncommon,
        spriteID: .weaponCrossbow
    )

    /// A pair of stars thrown at once, fast and low-damage but built to pass
    /// clean through a crowd: what a hand full of pierce and crit turns into
    /// a real weapon.
    static let shuriken = WeaponDefinition(
        id: "starter.shuriken",
        name: "Shuriken",
        summary: "Thrown in pairs, fast, and built to pass clean through a crowd.",
        baseDamage: 4.5,
        attackSpeed: 2.2,
        range: 5.5,
        damageType: .physical,
        tags: [.projectile, .ranged, .weapon, .physical],
        delivery: .projectile(ProjectileProfile(
            speed: 16,
            count: 2,
            pierce: 3,
            splashRadius: 0,
            spriteID: .projectileShuriken
        )),
        targeting: .densestCluster,
        rarity: .rare,
        spriteID: .weaponShuriken
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
        spear, whip, nunchaku, handClaws, crossbow, shuriken,
        halberd, scythe, heavyAxe, lance,
    ]

    /// Starters available with no Legacy unlocks.
    static let defaultUnlocked: Set<WeaponID> = [sword.id, bow.id, staff.id]

    static func definition(for id: WeaponID) -> WeaponDefinition? {
        all.first { $0.id == id }
    }
}
