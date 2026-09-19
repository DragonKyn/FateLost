import Foundation

/// Warlock: forbidden power, paid for. Necromancers raise the fallen,
/// Demonologists bind fiends, Dark Mages curse and drain.
enum WarlockSkills: SkillContent {
    static let archetype = ArchetypeID.warlock

    static let definition = ArchetypeDefinition(
        id: .warlock, name: "Warlock", tagline: "Every pact has a price. Make someone else pay it.",
        symbol: "moon.haze.fill", color: RGBA(hex: 0x6A3A8A),
        paths: [
            PathDefinition(id: pathID("necromancer"), name: "Necromancer",
                           summary: "Skeleton hordes, corpse blasts and harvested souls."),
            PathDefinition(id: pathID("demonologist"), name: "Demonologist",
                           summary: "Imps, hellhounds and a pit fiend on a leash."),
            PathDefinition(id: pathID("darkmage"), name: "Dark Mage",
                           summary: "Curses, contagion and life drained from the living."),
        ],
        resonance: [StatModifier(.shadowDamage, .increased, 0.015), StatModifier(.lifeSteal, .flat, 0.001)],
        resonanceText: "+1.5% shadow damage and +0.1% life steal per point"
    )

    // MARK: Core

    static let raiseTheFallen = skill(
        "core.raiseTheFallen", "Raise the Fallen", tier: .one, ranks: 5, kind: .active, symbol: "person.3.fill",
        text: "Raise {0} skeletons from the ground to fight for 12 s.",
        values: [rv(3, 1)],
        effects: [ability("raiseTheFallen", "Raise the Fallen", symbol: "person.3.fill", cooldown: rv(16, -1),
                          .summon(SummonCatalog.with(SummonCatalog.skeleton, count: rv(3, 1), duration: 12)))],
        tags: [.summon]
    )

    static let siphon = skill(
        "core.siphon", "Siphon", tier: .one, ranks: 5, kind: .passive, symbol: "drop.triangle.fill",
        text: "{0%} of damage you deal returns to you as health.",
        values: [rv(0.015, 0.015)],
        effects: [flat(.lifeSteal, 0.015)]
    )

    static let hex = skill(
        "core.hex", "Hex", tier: .one, ranks: 5, kind: .passive, symbol: "eye.trianglebadge.exclamationmark",
        text: "Hits have a {0%} chance to curse for 5 s: cursed enemies take 15% more damage.",
        values: [rv(0.1, 0.05)],
        effects: [.inflict(.any, status(.curse, chance: rv(0.1, 0.05), potency: 0.15, duration: 5))]
    )

    // MARK: Necromancer

    static let boneLegion = skill(
        "necromancer.boneLegion", "Bone Legion", path: "necromancer", tier: .two, ranks: 3, kind: .passive,
        symbol: "plus.circle.fill",
        text: "Every summon brings {0} more, and they last {1%} longer.",
        values: [rv(1, 0.5), rv(0.15, 0.1)],
        effects: [flat(.summonCount, 1, 0.5), inc(.effectDuration, 0.15, 0.1)]
    )

    static let corpseBlast = skill(
        "necromancer.corpseBlast", "Corpse Blast", path: "necromancer", tier: .two, ranks: 3, kind: .proc,
        symbol: "burst.fill",
        text: "Enemies have a {0%} chance to explode when they die, dealing {1%} shadow power around them.",
        values: [rv(0.1, 0.05), rv(2, 0.6)],
        effects: [proc(.kill(killedBy: nil), chance: rv(0.1, 0.05),
                       nova(rv(1.8), dmg(2, 0.6, .shadow, [.area], knockback: 0.8), at: .origin, .shadow))]
    )

    static let boneColossus = skill(
        "necromancer.boneColossus", "Bone Colossus", path: "necromancer", tier: .three, ranks: 3, kind: .summon,
        symbol: "figure.stand",
        text: "A towering construct of bone guards you, drawing enemies and crushing them for {0%} power.",
        values: [rv(1.6, 0.5)],
        effects: [.companion(SummonCatalog.boneColossus)],
        requires: ["necromancer.boneLegion", "necromancer.corpseBlast"]
    )

    static let soulHarvest = skill(
        "necromancer.soulHarvest", "Soul Harvest", path: "necromancer", tier: .three, ranks: 3, kind: .proc,
        symbol: "sparkles",
        text: "Kills grant +{0%} damage for 6 s, stacking up to 15 times.",
        values: [rv(0.02, 0.01)],
        effects: [proc(.kill(killedBy: nil),
                       buff("soulHarvest", [mod(.damage, .increased, 0.02, 0.01)], duration: 6, stacks: 15))],
        requires: ["necromancer.boneLegion", "necromancer.corpseBlast"]
    )

    static let graveTide = skill(
        "necromancer.graveTide", "Grave Tide", path: "necromancer", tier: .four, ranks: 3, kind: .ultimate,
        symbol: "person.3.sequence.fill",
        text: "The dead answer all at once: {0} skeletons rise for {1} s.",
        values: [rv(10, 3), rv(10, 2)],
        effects: [ability("graveTide", "Grave Tide", symbol: "person.3.sequence.fill", cooldown: rv(60, -5),
                          ultimate: true,
                          .summon(SummonCatalog.with(SummonCatalog.skeleton, count: rv(10, 3), duration: rv(10, 2))))],
        requires: ["necromancer.boneColossus", "necromancer.soulHarvest"]
    )

    static let lichdom = skill(
        "necromancer.lichdom", "Lichdom", path: "necromancer", tier: .capstone, ranks: 1, kind: .proc,
        symbol: "crown.fill",
        text: "Enemies you kill have a 20% chance to rise as your skeletons for 8 s.",
        effects: [proc(.kill(killedBy: nil), chance: 0.2,
                       .summon(SummonCatalog.with(SummonCatalog.skeleton, count: 1, duration: 8))),
                  inc(.summonDamage, 0.25, 0)],
        requires: ["necromancer.graveTide"]
    )

    // MARK: Demonologist

    static let impFamiliar = skill(
        "demonologist.imp", "Imp Familiar", path: "demonologist", tier: .two, ranks: 3, kind: .summon,
        symbol: "flame.fill",
        text: "An imp flits beside you hurling firebolts for {0%} power. A second joins at rank 3.",
        values: [rv(0.9, 0.3)],
        effects: [.companion(SummonCatalog.with(SummonCatalog.imp, count: rv(1, 0.5), duration: 0))]
    )

    static let infernalPact = skill(
        "demonologist.infernalPact", "Infernal Pact", path: "demonologist", tier: .two, ranks: 5, kind: .passive,
        symbol: "signature",
        text: "+{0%} fire and shadow damage.",
        values: [rv(0.1, 0.1)],
        effects: [inc(.fireDamage, 0.1), inc(.shadowDamage, 0.1)]
    )

    static let hellhound = skill(
        "demonologist.hellhound", "Hellhound", path: "demonologist", tier: .three, ranks: 3, kind: .summon,
        symbol: "pawprint.fill",
        text: "A hellhound hunts at your side, its bite burning for {0%} power.",
        values: [rv(1.0, 0.35)],
        effects: [.companion(SummonCatalog.hellhound)],
        requires: ["demonologist.imp", "demonologist.infernalPact"]
    )

    static let bloodSacrifice = skill(
        "demonologist.bloodSacrifice", "Blood Sacrifice", path: "demonologist", tier: .three, ranks: 3,
        kind: .active, symbol: "drop.fill",
        text: "Spill 10% of your health for +{0%} damage and +{1%} summon damage over 8 s.",
        values: [rv(0.4, 0.15), rv(0.5, 0.2)],
        effects: [ability("bloodSacrifice", "Blood Sacrifice", symbol: "drop.fill", cooldown: rv(20, -2),
                          .all([.selfDamage(0.1),
                                buff("bloodSacrifice", [mod(.damage, .increased, 0.4, 0.15),
                                                        mod(.summonDamage, .increased, 0.5, 0.2)], duration: 8)]))],
        requires: ["demonologist.imp", "demonologist.infernalPact"]
    )

    static let pitFiend = skill(
        "demonologist.pitFiend", "Pit Fiend", path: "demonologist", tier: .four, ranks: 3, kind: .ultimate,
        symbol: "flame.circle.fill",
        text: "Tear open the pit: a fiend fights for {0} s, drawing enemies and cleaving them for {1%} fire power.",
        values: [rv(15, 3), rv(4, 1)],
        effects: [ability("pitFiend", "Pit Fiend", symbol: "flame.circle.fill", cooldown: rv(70, -5), ultimate: true,
                          .summon(SummonCatalog.with(SummonCatalog.fiend, count: 1, duration: rv(15, 3))))],
        requires: ["demonologist.hellhound", "demonologist.bloodSacrifice"]
    )

    static let lordOfThePit = skill(
        "demonologist.lordOfThePit", "Lord of the Pit", path: "demonologist", tier: .capstone, ranks: 1,
        kind: .passive, symbol: "crown.fill",
        text: "Every summon brings one more. 30% more summon damage, and 10% of it returns to you as health.",
        effects: [flat(.summonCount, 1, 0), more(.summonDamage, 0.3, 0), flat(.summonLifeSteal, 0.1, 0)],
        requires: ["demonologist.pitFiend"]
    )

    // MARK: Dark Mage

    static let umbralBolt = skill(
        "darkmage.umbralBolt", "Umbral Bolt", path: "darkmage", tier: .two, ranks: 3, kind: .active,
        symbol: "moon.fill",
        text: "Fire {0} bolts of shadow for {1%} power each. They curse what they hit.",
        values: [rv(3, 1), rv(1.4, 0.35)],
        effects: [ability("umbralBolt", "Umbral Bolt", symbol: "moon.fill", cooldown: rv(5, -0.3),
                          .volley(VolleySpec(count: rv(3, 1), pattern: .aimed(spreadDegrees: 30),
                                             damage: dmg(1.4, 0.35, .shadow, [.spell, .projectile, .ability]),
                                             speed: 12, range: 8,
                                             status: status(.curse, potency: 0.15, duration: 5),
                                             sprite: .projectileBolt, visual: .shadow)))]
    )

    static let withering = skill(
        "darkmage.withering", "Withering", path: "darkmage", tier: .two, ranks: 3, kind: .passive,
        symbol: "leaf.arrow.triangle.circlepath",
        text: "+{0%} damage against cursed enemies.",
        values: [rv(0.15, 0.1)],
        effects: [.damageAgainst(.status(.curse), rv(0.15, 0.1))]
    )

    static let soulLeech = skill(
        "darkmage.soulLeech", "Soul Leech", path: "darkmage", tier: .three, ranks: 3, kind: .aura,
        symbol: "wind",
        text: "Drain everything around you for {0%} shadow power every half second. +{1%} life steal.",
        values: [rv(0.4, 0.15), rv(0.02, 0.01)],
        effects: [.aura(zone(rv(2.5), duration: 0, tick: 0.5, dmg(0.4, 0.15, .shadow, [.spell, .area], knockback: 0),
                             follows: true, .shadow)),
                  flat(.lifeSteal, 0.02, 0.01)],
        requires: ["darkmage.umbralBolt", "darkmage.withering"]
    )

    static let contagion = skill(
        "darkmage.contagion", "Contagion", path: "darkmage", tier: .three, ranks: 3, kind: .proc,
        symbol: "allergens",
        text: "Cursed enemies pass their curse to everything within {0} m when they die.",
        values: [rv(2.4, 0.4)],
        effects: [proc(.kill(killedBy: nil), target: .status(.curse),
                       .afflict(status(.curse, potency: 0.15, duration: 5), radius: rv(2.4, 0.4)))],
        requires: ["darkmage.umbralBolt", "darkmage.withering"]
    )

    static let doomsayer = skill(
        "darkmage.doomsayer", "Doomsayer", path: "darkmage", tier: .four, ranks: 3, kind: .ultimate,
        symbol: "exclamationmark.octagon.fill",
        text: "Pronounce doom on everything around you: they take {0%} more damage and deal 30% less for 8 s.",
        values: [rv(0.4, 0.1)],
        effects: [ability("doomsayer", "Doomsayer", symbol: "exclamationmark.octagon.fill", cooldown: rv(45, -4),
                          ultimate: true,
                          .all([.afflict(status(.curse, potency: rv(0.4, 0.1), duration: 8), radius: 6),
                                .afflict(status(.weaken, potency: 0.3, duration: 8), radius: 6),
                                nova(rv(6), dmg(2, 0.5, .shadow, [.spell, .area, .ability], knockback: 0.4), .shadow)]))],
        requires: ["darkmage.soulLeech", "darkmage.contagion"]
    )

    static let forbiddenCovenant = skill(
        "darkmage.forbiddenCovenant", "Forbidden Covenant", path: "darkmage", tier: .capstone, ranks: 1,
        kind: .passive, symbol: "flame",
        text: "50% more damage and +5% life steal, but your life drains away by 2 per second.",
        effects: [more(.damage, 0.5, 0), flat(.lifeSteal, 0.05, 0), flat(.healthRegen, -2, 0)],
        requires: ["darkmage.doomsayer"]
    )

    static let skills: [SkillDefinition] = [
        raiseTheFallen, siphon, hex,
        boneLegion, corpseBlast, boneColossus, soulHarvest, graveTide, lichdom,
        impFamiliar, infernalPact, hellhound, bloodSacrifice, pitFiend, lordOfThePit,
        umbralBolt, withering, soulLeech, contagion, doomsayer, forbiddenCovenant,
    ]
}
