import Foundation

/// Warrior: skilled, powerful physical combat. Knight holds the line,
/// Slayer ends fights, Warlord commands them.
enum WarriorSkills: SkillContent {
    static let archetype = ArchetypeID.warrior

    static let definition = ArchetypeDefinition(
        id: .warrior, name: "Warrior", tagline: "Steel, discipline and the weight of every blow.",
        symbol: "shield.lefthalf.filled", color: RGBA(hex: 0xC0503A),
        paths: [
            PathDefinition(id: pathID("knight"), name: "Knight",
                           summary: "Armour, barriers and retribution. Stands where others fall."),
            PathDefinition(id: pathID("slayer"), name: "Slayer",
                           summary: "Wide cleaves, brutal crits and executions."),
            PathDefinition(id: pathID("warlord"), name: "Warlord",
                           summary: "War cries, banners and unstoppable momentum."),
        ],
        resonance: [StatModifier(.physicalDamage, .increased, 0.015), StatModifier(.armor, .flat, 1)],
        resonanceText: "+1.5% physical damage and +1 armour per point"
    )

    // MARK: Core

    static let sunderingSpin = skill(
        "core.sunderingSpin", "Sundering Spin", tier: .one, ranks: 5, kind: .active, symbol: "tornado",
        text: "Spin with your weapon for {0} s, striking everything around you for {1%} power several times a second.",
        values: [rv(2.4, 0.2), rv(0.9, 0.2)],
        effects: [ability("sunderingSpin", "Sundering Spin", symbol: "tornado", cooldown: rv(10, -0.5),
                          .zone(zone(rv(1.8), duration: rv(2.4, 0.2), tick: 0.3,
                                     dmg(0.9, 0.2, .physical, [.melee, .area, .ability], knockback: 0.8),
                                     follows: true, .physical)))],
        tags: [.melee, .area]
    )

    static let weaponDiscipline = skill(
        "core.weaponDiscipline", "Weapon Discipline", tier: .one, ranks: 5, kind: .passive, symbol: "hammer.fill",
        text: "+{0%} physical damage and +{1%} attack speed.",
        values: [rv(0.08, 0.08), rv(0.05, 0.05)],
        effects: [inc(.physicalDamage, 0.08), inc(.attackSpeed, 0.05)],
        tags: [.physical]
    )

    static let ironHide = skill(
        "core.ironHide", "Iron Hide", tier: .one, ranks: 5, kind: .passive, symbol: "shield.fill",
        text: "+{0} armour and +{1%} max health.",
        values: [rv(6, 6), rv(0.06, 0.06)],
        effects: [flat(.armor, 6), inc(.maxHealth, 0.06)]
    )

    // MARK: Knight

    static let retribution = skill(
        "knight.retribution", "Retribution", path: "knight", tier: .two, ranks: 3, kind: .proc,
        symbol: "arrow.uturn.backward.circle.fill",
        text: "When struck, lash out at everything within reach for {0%} power.",
        values: [rv(1.2, 0.4)],
        effects: [proc(.hurt, cooldown: 0.4, nova(rv(1.9), dmg(1.2, 0.4, .physical, [.melee, .area], knockback: 1.2),
                                                   .physical))]
    )

    static let bulwark = skill(
        "knight.bulwark", "Bulwark", path: "knight", tier: .two, ranks: 3, kind: .active, symbol: "shield.checkered",
        text: "Raise a barrier worth {0%} of your max health.",
        values: [rv(0.25, 0.05)],
        effects: [ability("bulwark", "Bulwark", symbol: "shield.checkered", cooldown: rv(18, -1.5),
                          .all([.barrier(rv(0.25, 0.05)),
                                nova(rv(1.6), nil, status: status(.stun, duration: 0.5), .holy)]))]
    )

    static let unbreakable = skill(
        "knight.unbreakable", "Unbreakable", path: "knight", tier: .three, ranks: 3, kind: .passive,
        symbol: "figure.stand",
        text: "Below half health, gain +{0} armour and +{1} health per second.",
        values: [rv(25, 10), rv(3, 1.5)],
        effects: [whileIn(.healthBelow(0.5), .armor, .flat, 25, 10),
                  whileIn(.healthBelow(0.5), .healthRegen, .flat, 3, 1.5)],
        requires: ["knight.retribution", "knight.bulwark"]
    )

    static let shieldSlam = skill(
        "knight.shieldSlam", "Shield Slam", path: "knight", tier: .three, ranks: 3, kind: .proc,
        symbol: "hand.raised.fill",
        text: "Every 5th attack slams ahead for {0%} power, stunning for {1} s.",
        values: [rv(1.5, 0.5), rv(0.8, 0.2)],
        effects: [proc(.everyNthAttack(5), .cone(ConeSpec(range: rv(2.2), arcDegrees: 100,
                                                            damage: dmg(1.5, 0.5, .physical, [.melee, .area], knockback: 1.4),
                                                            status: status(.stun, duration: rv(0.8, 0.2)),
                                                            visual: .physical)))],
        requires: ["knight.retribution", "knight.bulwark"]
    )

    static let aegis = skill(
        "knight.aegis", "Aegis of the Oath", path: "knight", tier: .four, ranks: 3, kind: .ultimate,
        symbol: "checkmark.shield.fill",
        text: "Gain a barrier of {0%} max health and a sanctified ring that scorches enemies for {1} s.",
        values: [rv(0.6, 0.1), rv(5, 1)],
        effects: [ability("aegis", "Aegis of the Oath", symbol: "checkmark.shield.fill", cooldown: rv(60, -5),
                          ultimate: true,
                          .all([.barrier(rv(0.6, 0.1)),
                                .zone(zone(rv(2.4), duration: rv(5, 1), tick: 0.4,
                                           dmg(1.1, 0.3, .holy, [.area, .ability], knockback: 0.6),
                                           follows: true, .holy))]))],
        requires: ["knight.unbreakable", "knight.shieldSlam"]
    )

    static let lastBastion = skill(
        "knight.lastBastion", "Last Bastion", path: "knight", tier: .capstone, ranks: 1, kind: .passive,
        symbol: "crown.fill",
        text: "Once every 90 s, a killing blow instead leaves you at 30% health with 3 s of immunity, and a shockwave hurls enemies away.",
        effects: [.cheatDeath(CheatDeathSpec(cooldown: 90, restore: 0.3, invulnerability: 3,
                                             action: nova(rv(3.5), dmg(4, 0, .physical, [.area], knockback: 3), .fate))),
                  flat(.armor, 15)],
        requires: ["knight.aegis"]
    )

    // MARK: Slayer

    static let cleave = skill(
        "slayer.cleave", "Cleave", path: "slayer", tier: .two, ranks: 3, kind: .passive, symbol: "scissors",
        text: "Melee attacks sweep {0}° wider (ranged attacks gain a small burst) and area size +{1%}.",
        values: [rv(25, 10), rv(0.08, 0.04)],
        effects: [.weapon(.cleave(rv(25, 10))), inc(.areaSize, 0.08, 0.04)]
    )

    static let brutalStrikes = skill(
        "slayer.brutalStrikes", "Brutal Strikes", path: "slayer", tier: .two, ranks: 5, kind: .passive,
        symbol: "bolt.fill",
        text: "+{0%} critical chance and +{1%} critical damage.",
        values: [rv(0.02, 0.02), rv(0.15, 0.15)],
        effects: [flat(.critChance, 0.02), flat(.critDamage, 0.15)]
    )

    static let executioner = skill(
        "slayer.executioner", "Executioner", path: "slayer", tier: .three, ranks: 3, kind: .passive,
        symbol: "exclamationmark.triangle.fill",
        text: "+{0%} damage against enemies below 30% health.",
        values: [rv(0.4, 0.15)],
        effects: [.damageAgainst(.healthBelow(0.3), rv(0.4, 0.15))],
        requires: ["slayer.cleave", "slayer.brutalStrikes"]
    )

    static let rend = skill(
        "slayer.rend", "Rend", path: "slayer", tier: .three, ranks: 3, kind: .proc, symbol: "drop.fill",
        text: "Melee hits have a {0%} chance to open a wound, bleeding for {1%} power per second.",
        values: [rv(0.25, 0.1), rv(0.6, 0.2)],
        effects: [.inflict(HitFilter(tags: .melee), status(.bleed, chance: rv(0.25, 0.1), potency: rv(0.6, 0.2),
                                                           duration: 3))],
        requires: ["slayer.cleave", "slayer.brutalStrikes"]
    )

    static let earthsplitter = skill(
        "slayer.earthsplitter", "Earthsplitter", path: "slayer", tier: .four, ranks: 3, kind: .ultimate,
        symbol: "bolt.horizontal.fill",
        text: "Split the ground before you: {0%} power in a long line, stunning for 1 s.",
        values: [rv(8, 2)],
        effects: [ability("earthsplitter", "Earthsplitter", symbol: "bolt.horizontal.fill", cooldown: rv(45, -4),
                          ultimate: true,
                          .cone(ConeSpec(range: rv(5.5, 0.5), arcDegrees: 50,
                                         damage: dmg(8, 2, .physical, [.melee, .area, .ability], knockback: 2),
                                         status: status(.stun, duration: 1), visual: .physical)))],
        requires: ["slayer.executioner", "slayer.rend"]
    )

    static let colossusBlow = skill(
        "slayer.colossusBlow", "Colossus Blow", path: "slayer", tier: .capstone, ranks: 1, kind: .proc,
        symbol: "burst.fill",
        text: "Every 6th attack unleashes a shockwave ahead of you for 400% power.",
        effects: [proc(.everyNthAttack(6), .cone(ConeSpec(range: rv(4), arcDegrees: 90,
                                                            damage: dmg(4, 0, .physical, [.melee, .area], knockback: 2),
                                                            visual: .physical))),
                  flat(.critDamage, 0.25)],
        requires: ["slayer.earthsplitter"]
    )

    // MARK: Warlord

    static let battleCry = skill(
        "warlord.battleCry", "Battle Cry", path: "warlord", tier: .two, ranks: 3, kind: .active,
        symbol: "megaphone.fill",
        text: "Roar: +{0%} damage and +{1%} attack speed for 6 s. Nearby enemies flee in terror.",
        values: [rv(0.25, 0.1), rv(0.15, 0.05)],
        effects: [ability("battleCry", "Battle Cry", symbol: "megaphone.fill", cooldown: rv(16, -1),
                          .all([buff("battleCry", [mod(.damage, .increased, 0.25, 0.1),
                                                   mod(.attackSpeed, .increased, 0.15, 0.05)], duration: 6),
                                nova(rv(2.6), nil, status: status(.fear, duration: 1.5), .fate)]))]
    )

    static let momentum = skill(
        "warlord.momentum", "Momentum", path: "warlord", tier: .two, ranks: 3, kind: .passive,
        symbol: "figure.run",
        text: "While moving: +{0%} attack speed and +{1%} movement speed.",
        values: [rv(0.1, 0.05), rv(0.05, 0.02)],
        effects: [whileIn(.moving, .attackSpeed, .increased, 0.1, 0.05),
                  whileIn(.moving, .moveSpeed, .increased, 0.05, 0.02)]
    )

    static let warBanner = skill(
        "warlord.warBanner", "War Banner", path: "warlord", tier: .three, ranks: 3, kind: .active,
        symbol: "flag.fill",
        text: "Plant a banner for {0} s. Inside its ring: +{1%} damage and +5 health per second, and enemies are weakened.",
        values: [rv(8, 1), rv(0.2, 0.08)],
        effects: [ability("warBanner", "War Banner", symbol: "flag.fill", cooldown: rv(20, -1.5),
                          .zone(zone(rv(3.4), duration: rv(8, 1), tick: 0.5, nil,
                                     status: status(.weaken, potency: 0.2, duration: 1),
                                     buff: [mod(.damage, .increased, 0.2, 0.08), mod(.healthRegen, .flat, 5)],
                                     .fate)))],
        requires: ["warlord.battleCry", "warlord.momentum"]
    )

    static let bloodForBlood = skill(
        "warlord.bloodForBlood", "Blood for Blood", path: "warlord", tier: .three, ranks: 3, kind: .proc,
        symbol: "heart.fill",
        text: "Kills heal {0%} of your max health.",
        values: [rv(0.01, 0.005)],
        effects: [proc(.kill(killedBy: nil), cooldown: 0.1, .heal(rv(0.01, 0.005)))],
        requires: ["warlord.battleCry", "warlord.momentum"]
    )

    static let commandingPresence = skill(
        "warlord.commandingPresence", "Commanding Presence", path: "warlord", tier: .four, ranks: 3, kind: .aura,
        symbol: "person.3.fill",
        text: "Enemies near you are weakened by {0%} and take {1%} more damage.",
        values: [rv(0.15, 0.05), rv(0.1, 0.05)],
        effects: [.aura(zone(rv(3), duration: 0, tick: 0.5, nil,
                             status: status(.weaken, potency: rv(0.15, 0.05), duration: 1), follows: true, .fate)),
                  .damageAgainst(.within(3), rv(0.1, 0.05))],
        requires: ["warlord.warBanner", "warlord.bloodForBlood"]
    )

    static let conqueror = skill(
        "warlord.conqueror", "Conqueror", path: "warlord", tier: .capstone, ranks: 1, kind: .proc,
        symbol: "flag.2.crossed.fill",
        text: "Every kill takes 0.3 s off all your ability cooldowns.",
        effects: [proc(.kill(killedBy: nil), .reduceCooldowns(0.3))],
        requires: ["warlord.commandingPresence"]
    )

    static let skills: [SkillDefinition] = [
        sunderingSpin, weaponDiscipline, ironHide,
        retribution, bulwark, unbreakable, shieldSlam, aegis, lastBastion,
        cleave, brutalStrikes, executioner, rend, earthsplitter, colossusBlow,
        battleCry, momentum, warBanner, bloodForBlood, commandingPresence, conqueror,
    ]
}
