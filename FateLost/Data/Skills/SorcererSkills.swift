import Foundation

/// Sorcerer: raw, innate power let loose. Stormborn chain lightning through
/// crowds, Chaos Mages gamble on unstable magic, Pyromancers overcharge
/// everything into fire.
enum SorcererSkills: SkillContent {
    static let archetype = ArchetypeID.sorcerer

    static let definition = ArchetypeDefinition(
        id: .sorcerer, name: "Sorcerer", tagline: "Power you were born with, and can barely hold.",
        symbol: "bolt.fill", color: RGBA(hex: 0x9A4AD0),
        paths: [
            PathDefinition(id: pathID("stormborn"), name: "Stormborn",
                           summary: "Lightning that leaps, forks and never stops."),
            PathDefinition(id: pathID("chaos"), name: "Chaos Mage",
                           summary: "Wild surges, twinned spells and rifts in the world."),
            PathDefinition(id: pathID("pyromancer"), name: "Pyromancer",
                           summary: "Overcharged fire and burning everything."),
        ],
        resonance: [StatModifier(.magicDamage, .increased, 0.015), StatModifier(.critDamage, .flat, 0.01)],
        resonanceText: "+1.5% magic damage and +1% critical damage per point"
    )

    // MARK: Core

    static let forkedLightning = skill(
        "core.forkedLightning", "Forked Lightning", tier: .one, ranks: 5, kind: .active, symbol: "bolt.fill",
        text: "Lightning leaps between {0} enemies for {1%} power each, shocking them.",
        values: [rv(4, 1), rv(1.6, 0.35)],
        effects: [ability("forkedLightning", "Forked Lightning", symbol: "bolt.fill", cooldown: rv(7, -0.4),
                          .chain(ChainSpec(jumps: rv(4, 1), damage: dmg(1.6, 0.35, .lightning, [.spell, .ability]),
                                           status: status(.shock, chance: 0.6, potency: 0.1, duration: 3),
                                           visual: .lightning)))],
        tags: [.spell]
    )

    static let wellspring = skill(
        "core.wellspring", "Wellspring", tier: .one, ranks: 5, kind: .passive, symbol: "drop.fill",
        text: "+{0%} magic damage and +{1%} critical chance.",
        values: [rv(0.06, 0.06), rv(0.02, 0.02)],
        effects: [inc(.magicDamage, 0.06), flat(.critChance, 0.02)]
    )

    static let dragonBlood = skill(
        "core.dragonBlood", "Dragon's Blood", tier: .one, ranks: 5, kind: .passive, symbol: "heart.fill",
        text: "+{0%} max health and +{1%} area size.",
        values: [rv(0.08, 0.08), rv(0.04, 0.04)],
        effects: [inc(.maxHealth, 0.08), inc(.areaSize, 0.04)]
    )

    // MARK: Stormborn

    static let staticField = skill(
        "stormborn.staticField", "Static Field", path: "stormborn", tier: .two, ranks: 3, kind: .aura,
        symbol: "bolt.circle.fill",
        text: "Crackling static around you strikes {0} nearby enemies each second for {1%} power.",
        values: [rv(2, 1), rv(0.8, 0.3)],
        effects: [.aura(ZoneSpec(radius: rv(2.4), duration: 0, tick: 1,
                                 damage: dmg(0.8, 0.3, .lightning, [.spell], knockback: 0.2),
                                 status: status(.shock, chance: 0.3, potency: 0.1, duration: 2),
                                 strikesPerTick: 2, follows: true, visual: .lightning))]
    )

    static let conductivity = skill(
        "stormborn.conductivity", "Conductivity", path: "stormborn", tier: .two, ranks: 3, kind: .passive,
        symbol: "point.3.connected.trianglepath.dotted",
        text: "Chains leap {0} more times. +{1%} lightning damage.",
        values: [rv(1, 1), rv(0.1, 0.1)],
        effects: [flat(.chainJumps, 1), inc(.lightningDamage, 0.1)]
    )

    static let arcFlash = skill(
        "stormborn.arcFlash", "Arc Flash", path: "stormborn", tier: .three, ranks: 3, kind: .proc,
        symbol: "bolt.horizontal.fill",
        text: "Critical hits release lightning that leaps to {0} enemies for {1%} power.",
        values: [rv(2, 1), rv(1, 0.3)],
        effects: [proc(.criticalHit, cooldown: 0.4,
                       .chain(ChainSpec(jumps: rv(2, 1), damage: dmg(1, 0.3, .lightning, [.spell]), visual: .lightning)))],
        requires: ["stormborn.staticField", "stormborn.conductivity"]
    )

    static let ballLightning = skill(
        "stormborn.ballLightning", "Ball Lightning", path: "stormborn", tier: .three, ranks: 3, kind: .active,
        symbol: "circle.dotted",
        text: "Release {0} slow orbs of lightning that pass through everything for {1%} power.",
        values: [rv(3, 1), rv(1.2, 0.3)],
        effects: [ability("ballLightning", "Ball Lightning", symbol: "circle.dotted", cooldown: rv(10, -1),
                          .volley(VolleySpec(count: rv(3, 1), pattern: .aimed(spreadDegrees: 50),
                                             damage: dmg(1.2, 0.3, .lightning, [.spell, .projectile, .ability], knockback: 0.2),
                                             speed: 4.5, pierce: 99, size: 0.5, range: 9,
                                             status: status(.shock, chance: 0.5, potency: 0.1, duration: 2),
                                             sprite: .projectileBolt, visual: .lightning)))],
        requires: ["stormborn.staticField", "stormborn.conductivity"]
    )

    static let tempest = skill(
        "stormborn.tempest", "Tempest", path: "stormborn", tier: .four, ranks: 3, kind: .ultimate,
        symbol: "tropicalstorm",
        text: "Become the eye of a storm for {0} s: bolts strike 3 enemies around you four times a second for {1%} power.",
        values: [rv(8, 1), rv(2, 0.5)],
        effects: [ability("tempest", "Tempest", symbol: "tropicalstorm", cooldown: rv(55, -4), ultimate: true,
                          .zone(ZoneSpec(radius: rv(5), duration: rv(8, 1), tick: 0.25,
                                         damage: dmg(2, 0.5, .lightning, [.spell, .ability], knockback: 0.3),
                                         status: status(.shock, chance: 0.5, potency: 0.15, duration: 2),
                                         strikesPerTick: 3, follows: true, visual: .lightning)))],
        requires: ["stormborn.arcFlash", "stormborn.ballLightning"]
    )

    static let livingStorm = skill(
        "stormborn.livingStorm", "Living Storm", path: "stormborn", tier: .capstone, ranks: 1, kind: .proc,
        symbol: "cloud.bolt.rain.fill",
        text: "Every 5 s, lightning leaps from you through 6 enemies on its own. Chains leap 2 more times.",
        effects: [proc(.interval(5), .chain(ChainSpec(jumps: 6, damage: dmg(1.8, 0, .lightning, [.spell]),
                                                      visual: .lightning))),
                  flat(.chainJumps, 2, 0)],
        requires: ["stormborn.tempest"]
    )

    // MARK: Chaos Mage

    static let wildSurge = skill(
        "chaos.wildSurge", "Wild Surge", path: "chaos", tier: .two, ranks: 3, kind: .proc, symbol: "dice.fill",
        text: "Attacks have a {0%} chance to unleash a random spell.",
        values: [rv(0.12, 0.05)],
        effects: [proc(.attack, chance: rv(0.12, 0.05), cooldown: 0.5, SorcererSkills.surge)]
    )

    static let twinnedSpell = skill(
        "chaos.twinnedSpell", "Twinned Spell", path: "chaos", tier: .two, ranks: 3, kind: .passive,
        symbol: "square.on.square",
        text: "Abilities have a {0%} chance to cast twice.",
        values: [rv(0.12, 0.06)],
        effects: [flat(.spellEcho, 0.12, 0.06)]
    )

    static let entropy = skill(
        "chaos.entropy", "Entropy", path: "chaos", tier: .three, ranks: 3, kind: .passive, symbol: "hurricane",
        text: "+{0%} damage, at the cost of {1%} max health.",
        values: [rv(0.15, 0.08), rv(0.05, 0.02)],
        effects: [inc(.damage, 0.15, 0.08), inc(.maxHealth, -0.05, -0.02)],
        requires: ["chaos.wildSurge", "chaos.twinnedSpell"]
    )

    static let chaosRift = skill(
        "chaos.chaosRift", "Chaos Rift", path: "chaos", tier: .three, ranks: 3, kind: .active, symbol: "circle.dashed",
        text: "Tear open a rift that drags enemies in and deals {0%} arcane power every half second for 4 s.",
        values: [rv(0.8, 0.3)],
        effects: [ability("chaosRift", "Chaos Rift", symbol: "circle.dashed", cooldown: rv(14, -1),
                          .zone(zone(rv(2.6), duration: 4, tick: 0.5, dmg(0.8, 0.3, .arcane, [.spell, .area, .ability], knockback: 0),
                                     pull: 3.5, at: .cluster, .arcane)))],
        requires: ["chaos.wildSurge", "chaos.twinnedSpell"]
    )

    static let unravel = skill(
        "chaos.unravel", "Unravel", path: "chaos", tier: .four, ranks: 3, kind: .ultimate,
        symbol: "sparkle.magnifyingglass",
        text: "Reality comes apart around you: {0%} arcane power in a wide ring, then three random spells.",
        values: [rv(6, 1.5)],
        effects: [ability("unravel", "Unravel", symbol: "sparkle.magnifyingglass", cooldown: rv(55, -4), ultimate: true,
                          .all([nova(rv(6), dmg(6, 1.5, .arcane, [.spell, .area, .ability], knockback: 1.6), .arcane),
                                SorcererSkills.surge, SorcererSkills.surge, SorcererSkills.surge]))],
        requires: ["chaos.entropy", "chaos.chaosRift"]
    )

    static let paradox = skill(
        "chaos.paradox", "Paradox", path: "chaos", tier: .capstone, ranks: 1, kind: .proc, symbol: "infinity",
        text: "Every ability you use also unleashes a Wild Surge. +15% chance for abilities to cast twice.",
        effects: [proc(.abilityCast, SorcererSkills.surge), flat(.spellEcho, 0.15, 0)],
        requires: ["chaos.unravel"]
    )

    // MARK: Pyromancer

    static let cinderbolt = skill(
        "pyromancer.cinderbolt", "Cinderbolt", path: "pyromancer", tier: .two, ranks: 3, kind: .active,
        symbol: "flame.fill",
        text: "Hurl a fireball that bursts for {0%} fire power and sets the ground's occupants alight.",
        values: [rv(3, 0.8)],
        effects: [ability("cinderbolt", "Cinderbolt", symbol: "flame.fill", cooldown: rv(5, -0.3),
                          .volley(VolleySpec(count: 1, pattern: .aimed(spreadDegrees: 0),
                                             damage: dmg(3, 0.8, .fire, [.spell, .projectile, .area, .ability], knockback: 1),
                                             speed: 10, splash: 2.2, size: 0.35, range: 8,
                                             status: status(.burn, potency: 0.5, duration: 3),
                                             sprite: .projectileBolt, visual: .fire)))]
    )

    static let kindling = skill(
        "pyromancer.kindling", "Kindling", path: "pyromancer", tier: .two, ranks: 3, kind: .passive,
        symbol: "flame",
        text: "Hits have a {0%} chance to burn for {1%} power per second.",
        values: [rv(0.2, 0.1), rv(0.5, 0.2)],
        effects: [.inflict(.any, status(.burn, chance: rv(0.2, 0.1), potency: rv(0.5, 0.2), duration: 4))]
    )

    static let overcharge = skill(
        "pyromancer.overcharge", "Overcharge", path: "pyromancer", tier: .three, ranks: 3, kind: .proc,
        symbol: "bolt.batteryblock.fill",
        text: "Every 4th attack is overcharged, exploding on the target for {0%} fire power.",
        values: [rv(2, 0.7)],
        effects: [proc(.everyNthAttack(4), nova(rv(1.6), dmg(2, 0.7, .fire, [.spell, .area], knockback: 1),
                                                at: .origin, .fire))],
        requires: ["pyromancer.cinderbolt", "pyromancer.kindling"]
    )

    static let heatwave = skill(
        "pyromancer.heatwave", "Heatwave", path: "pyromancer", tier: .three, ranks: 3, kind: .aura,
        symbol: "sun.max.fill",
        text: "Searing heat surrounds you, setting nearby enemies alight for {0%} power per second.",
        values: [rv(0.4, 0.2)],
        effects: [.aura(zone(rv(2.6), duration: 0, tick: 0.8, nil,
                             status: status(.burn, potency: rv(0.4, 0.2), duration: 1.6), follows: true, .fire))],
        requires: ["pyromancer.cinderbolt", "pyromancer.kindling"]
    )

    static let inferno = skill(
        "pyromancer.inferno", "Inferno", path: "pyromancer", tier: .four, ranks: 3, kind: .ultimate,
        symbol: "flame.circle.fill",
        text: "Erupt in flame for 3 s: {0%} fire power four times a second to everything around you.",
        values: [rv(1.2, 0.4)],
        effects: [ability("inferno", "Inferno", symbol: "flame.circle.fill", cooldown: rv(45, -4), ultimate: true,
                          .zone(zone(rv(4), duration: 3, tick: 0.25,
                                     dmg(1.2, 0.4, .fire, [.spell, .area, .ability], knockback: 0.5),
                                     status: status(.burn, potency: 0.8, duration: 3), follows: true, .fire)))],
        requires: ["pyromancer.overcharge", "pyromancer.heatwave"]
    )

    static let phoenixHeart = skill(
        "pyromancer.phoenixHeart", "Phoenix Heart", path: "pyromancer", tier: .capstone, ranks: 1, kind: .passive,
        symbol: "bird.fill",
        text: "Once every 120 s, rise from a killing blow at half health in an explosion of 1000% fire power.",
        effects: [.cheatDeath(CheatDeathSpec(cooldown: 120, restore: 0.5, invulnerability: 2,
                                             action: nova(rv(4.5), dmg(10, 0, .fire, [.spell, .area], knockback: 3),
                                                          status: status(.burn, potency: 1, duration: 4), .fire))),
                  inc(.fireDamage, 0.2, 0)],
        requires: ["pyromancer.inferno"]
    )

    /// The pool a Wild Surge draws from.
    static let surge: EffectAction = .random([
        nova(rv(2.2), dmg(2, 0, .fire, [.spell, .area], knockback: 0.8),
             status: status(.burn, potency: 0.5, duration: 3), .fire),
        .chain(ChainSpec(jumps: 4, damage: dmg(1.6, 0, .lightning, [.spell]), visual: .lightning)),
        nova(rv(2.4), dmg(1.4, 0, .cold, [.spell, .area]), status: status(.freeze, duration: 1), .frost),
        .volley(VolleySpec(count: 8, pattern: .radial, damage: dmg(1.2, 0, .arcane, [.spell, .projectile]),
                           speed: 11, pierce: 1, range: 7, sprite: .projectileBolt, visual: .arcane)),
    ])

    static let skills: [SkillDefinition] = [
        forkedLightning, wellspring, dragonBlood,
        staticField, conductivity, arcFlash, ballLightning, tempest, livingStorm,
        wildSurge, twinnedSpell, entropy, chaosRift, unravel, paradox,
        cinderbolt, kindling, overcharge, heatwave, inferno, phoenixHeart,
    ]
}
