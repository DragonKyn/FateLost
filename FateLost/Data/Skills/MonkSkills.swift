import Foundation

/// Monk: the body as the weapon. Windwalkers are never where the blow
/// lands, Iron Fists break what they touch, Ascetics master themselves.
enum MonkSkills: SkillContent {
    static let archetype = ArchetypeID.monk

    static let definition = ArchetypeDefinition(
        id: .monk, name: "Monk", tagline: "Stillness, speed and a hundred strikes a breath.",
        symbol: "figure.martial.arts", color: RGBA(hex: 0xD08A3A),
        paths: [
            PathDefinition(id: pathID("windwalker"), name: "Windwalker",
                           summary: "Speed, dodges and counters that come from nowhere."),
            PathDefinition(id: pathID("ironfist"), name: "Iron Fist",
                           summary: "Combinations, stunning palms and empty hands."),
            PathDefinition(id: pathID("ascetic"), name: "Ascetic",
                           summary: "Chi barriers, meditation and transcendence."),
        ],
        resonance: [StatModifier(.attackSpeed, .increased, 0.008), StatModifier(.dodgeChance, .flat, 0.003)],
        resonanceText: "+0.8% attack speed and +0.3% dodge chance per point"
    )

    // MARK: Core

    static let hundredPalms = skill(
        "core.hundredPalms", "Hundred Palms", tier: .one, ranks: 5, kind: .active, symbol: "hand.raised.fingers.spread.fill",
        text: "A flurry of blows strikes everything around you eight times a second for {0} s, {1%} power each.",
        values: [rv(1.2, 0.15), rv(0.5, 0.1)],
        effects: [ability("hundredPalms", "Hundred Palms", symbol: "hand.raised.fingers.spread.fill", cooldown: rv(7, -0.4),
                          .zone(zone(rv(1.9), duration: rv(1.2, 0.15), tick: 0.125,
                                     dmg(0.5, 0.1, .physical, [.melee, .area, .ability], knockback: 0.2),
                                     follows: true, .physical)))],
        tags: [.melee]
    )

    static let flowingStrikes = skill(
        "core.flowingStrikes", "Flowing Strikes", tier: .one, ranks: 5, kind: .passive, symbol: "wind",
        text: "+{0%} attack speed and +{1%} dodge chance.",
        values: [rv(0.07, 0.07), rv(0.02, 0.02)],
        effects: [inc(.attackSpeed, 0.07), flat(.dodgeChance, 0.02)]
    )

    static let innerCalm = skill(
        "core.innerCalm", "Inner Calm", tier: .one, ranks: 5, kind: .passive, symbol: "leaf.fill",
        text: "+{0%} dodge chance and +{1} health per second.",
        values: [rv(0.04, 0.04), rv(1.5, 1.5)],
        effects: [flat(.dodgeChance, 0.04), flat(.healthRegen, 1.5)]
    )

    // MARK: Windwalker

    static let galeStep = skill(
        "windwalker.galeStep", "Gale Step", path: "windwalker", tier: .two, ranks: 3, kind: .active,
        symbol: "wind",
        text: "Dash on the wind, striking everything you pass for {0%} power.",
        values: [rv(1.5, 0.5)],
        effects: [ability("galeStep", "Gale Step", symbol: "wind", cooldown: rv(5, -0.4),
                          .dash(DashSpec(distance: 4, damage: dmg(1.5, 0.5, .physical, [.melee, .ability], knockback: 1),
                                         invulnerability: 0.3, visual: .physical)))]
    )

    static let swiftness = skill(
        "windwalker.swiftness", "Swiftness", path: "windwalker", tier: .two, ranks: 3, kind: .passive,
        symbol: "hare.fill",
        text: "+{0%} movement speed. While moving: +{1%} dodge chance.",
        values: [rv(0.06, 0.03), rv(0.03, 0.02)],
        effects: [inc(.moveSpeed, 0.06, 0.03), whileIn(.moving, .dodgeChance, .flat, 0.03, 0.02)]
    )

    static let counterCyclone = skill(
        "windwalker.counterCyclone", "Counter Cyclone", path: "windwalker", tier: .three, ranks: 3, kind: .proc,
        symbol: "tornado",
        text: "Dodging an attack answers with a spinning kick: {0%} power around you.",
        values: [rv(2, 0.6)],
        effects: [proc(.dodge, cooldown: 0.4, nova(rv(2.2), dmg(2, 0.6, .physical, [.melee, .area], knockback: 1.5),
                                                   .physical))],
        requires: ["windwalker.galeStep", "windwalker.swiftness"]
    )

    static let tailwind = skill(
        "windwalker.tailwind", "Tailwind", path: "windwalker", tier: .three, ranks: 3, kind: .passive,
        symbol: "wind",
        text: "While moving: +{0%} attack speed.",
        values: [rv(0.15, 0.05)],
        effects: [whileIn(.moving, .attackSpeed, .increased, 0.15, 0.05)],
        requires: ["windwalker.galeStep", "windwalker.swiftness"]
    )

    static let stormOfFists = skill(
        "windwalker.stormOfFists", "Storm of Fists", path: "windwalker", tier: .four, ranks: 3, kind: .ultimate,
        symbol: "tornado",
        text: "Become a whirlwind for {0} s: {1%} power to everything around you many times a second, and move 25% faster.",
        values: [rv(5, 1), rv(0.7, 0.2)],
        effects: [ability("stormOfFists", "Storm of Fists", symbol: "tornado", cooldown: rv(50, -4), ultimate: true,
                          .all([.zone(zone(rv(3), duration: rv(5, 1), tick: 0.15,
                                           dmg(0.7, 0.2, .physical, [.melee, .area, .ability], knockback: 0.3),
                                           follows: true, .physical)),
                                buff("stormOfFists", [mod(.moveSpeed, .increased, 0.25)], duration: rv(5, 1))]))],
        requires: ["windwalker.counterCyclone", "windwalker.tailwind"]
    )

    static let untouchable = skill(
        "windwalker.untouchable", "Untouchable", path: "windwalker", tier: .capstone, ranks: 1, kind: .proc,
        symbol: "crown.fill",
        text: "Each dodge grants +20% damage for 3 s (stacking 5 times) and half a second of immunity.",
        effects: [proc(.dodge, .all([buff("untouchable", [mod(.damage, .increased, 0.2)], duration: 3, stacks: 5),
                                     .invulnerable(0.5)])),
                  flat(.dodgeChance, 0.05, 0)],
        requires: ["windwalker.stormOfFists"]
    )

    // MARK: Iron Fist

    static let combination = skill(
        "ironfist.combination", "Combination", path: "ironfist", tier: .two, ranks: 5, kind: .proc,
        symbol: "hand.point.right.fill",
        text: "Every 3rd attack finishes the combination with a shockwave ahead for {0%} power.",
        values: [rv(1.5, 0.4)],
        effects: [proc(.everyNthAttack(3), .cone(ConeSpec(range: rv(2.2), arcDegrees: 90,
                                                            damage: dmg(1.5, 0.4, .physical, [.melee, .area], knockback: 1.2),
                                                            visual: .physical)))]
    )

    static let ironBody = skill(
        "ironfist.ironBody", "Iron Body", path: "ironfist", tier: .two, ranks: 3, kind: .passive,
        symbol: "figure.stand",
        text: "+{0} armour and +{1%} max health.",
        values: [rv(10, 6), rv(0.05, 0.05)],
        effects: [flat(.armor, 10, 6), inc(.maxHealth, 0.05)]
    )

    static let earthshakerPalm = skill(
        "ironfist.earthshakerPalm", "Earthshaker Palm", path: "ironfist", tier: .three, ranks: 3, kind: .active,
        symbol: "hand.raised.fill",
        text: "Strike the ground: {0%} power around you, stunning for 1 s.",
        values: [rv(3, 0.8)],
        effects: [ability("earthshakerPalm", "Earthshaker Palm", symbol: "hand.raised.fill", cooldown: rv(10, -0.8),
                          nova(rv(3), dmg(3, 0.8, .physical, [.melee, .area, .ability], knockback: 1.6),
                               status: status(.stun, duration: 1), .physical))],
        requires: ["ironfist.combination", "ironfist.ironBody"]
    )

    static let pressurePoints = skill(
        "ironfist.pressurePoints", "Pressure Points", path: "ironfist", tier: .three, ranks: 3, kind: .proc,
        symbol: "smallcircle.filled.circle",
        text: "Critical hits stun for {0} s.",
        values: [rv(0.4, 0.15)],
        effects: [proc(.criticalHit, .afflict(status(.stun, duration: rv(0.4, 0.15)), radius: 0)),
                  flat(.critChance, 0.03, 0.02)],
        requires: ["ironfist.combination", "ironfist.ironBody"]
    )

    static let dragonsFist = skill(
        "ironfist.dragonsFist", "Dragon's Fist", path: "ironfist", tier: .four, ranks: 3, kind: .ultimate,
        symbol: "flame.fill",
        text: "One perfect blow: {0%} power in a long line, hurling enemies away.",
        values: [rv(9, 2.5)],
        effects: [ability("dragonsFist", "Dragon's Fist", symbol: "flame.fill", cooldown: rv(40, -3), ultimate: true,
                          .cone(ConeSpec(range: rv(6), arcDegrees: 40,
                                         damage: dmg(9, 2.5, .physical, [.melee, .area, .ability], knockback: 3),
                                         visual: .fire)))],
        requires: ["ironfist.earthshakerPalm", "ironfist.pressurePoints"]
    )

    static let ironFist = skill(
        "ironfist.ironFist", "Way of the Iron Fist", path: "ironfist", tier: .capstone, ranks: 1, kind: .form,
        symbol: "crown.fill",
        text: "Put down your weapon for good: your fists strike nearly three times a second, and your combinations come faster.",
        effects: [.permanentForm(FormCatalog.ironFist.id), inc(.meleeDamage, 0.2, 0)],
        requires: ["ironfist.dragonsFist"]
    )

    // MARK: Ascetic

    static let chiBarrier = skill(
        "ascetic.chiBarrier", "Chi Barrier", path: "ascetic", tier: .two, ranks: 3, kind: .proc,
        symbol: "shield.lefthalf.filled",
        text: "Struck below half health: gain a barrier of {0%} of your max health (once every 20 s).",
        values: [rv(0.2, 0.08)],
        effects: [proc(.hurt, cooldown: 20, requires: .healthBelow(0.5), .barrier(rv(0.2, 0.08)))]
    )

    static let meditation = skill(
        "ascetic.meditation", "Meditation", path: "ascetic", tier: .two, ranks: 3, kind: .passive,
        symbol: "figure.mind.and.body",
        text: "Standing still: +{0} health per second and +{1%} cooldown reduction.",
        values: [rv(6, 3), rv(0.1, 0.05)],
        effects: [whileIn(.stationary, .healthRegen, .flat, 6, 3), whileIn(.stationary, .cooldownReduction, .flat, 0.1, 0.05)]
    )

    static let spiritPalm = skill(
        "ascetic.spiritPalm", "Spirit Palm", path: "ascetic", tier: .three, ranks: 3, kind: .active,
        symbol: "hand.wave.fill",
        text: "Project your spirit in a line for {0%} arcane power, healing 5% of your max health.",
        values: [rv(2.5, 0.7)],
        effects: [ability("spiritPalm", "Spirit Palm", symbol: "hand.wave.fill", cooldown: rv(6, -0.4),
                          .all([.volley(VolleySpec(count: 1, pattern: .aimed(spreadDegrees: 0),
                                                   damage: dmg(2.5, 0.7, .arcane, [.spell, .projectile, .ability], knockback: 1),
                                                   speed: 13, pierce: 99, size: 0.45, range: 9,
                                                   sprite: .projectileBolt, visual: .arcane)),
                                .heal(0.05)]))],
        requires: ["ascetic.chiBarrier", "ascetic.meditation"]
    )

    static let clarityOfMind = skill(
        "ascetic.clarityOfMind", "Clarity of Mind", path: "ascetic", tier: .three, ranks: 3, kind: .passive,
        symbol: "brain.head.profile",
        text: "+{0%} cooldown reduction and +{1%} magic damage.",
        values: [rv(0.06, 0.03), rv(0.08, 0.06)],
        effects: [flat(.cooldownReduction, 0.06, 0.03), inc(.magicDamage, 0.08, 0.06)],
        requires: ["ascetic.chiBarrier", "ascetic.meditation"]
    )

    static let transcendence = skill(
        "ascetic.transcendence", "Transcendence", path: "ascetic", tier: .four, ranks: 3, kind: .ultimate,
        symbol: "sparkles",
        text: "Leave your body for {0} s: untouchable, healing 30% of your max health, with a burst of {1%} arcane power.",
        values: [rv(3, 0.5), rv(4, 1)],
        effects: [ability("transcendence", "Transcendence", symbol: "sparkles", cooldown: rv(75, -6), ultimate: true,
                          .all([.invulnerable(rv(3, 0.5)), .heal(0.3),
                                nova(rv(3.5), dmg(4, 1, .arcane, [.spell, .area, .ability], knockback: 2), .arcane)]))],
        requires: ["ascetic.spiritPalm", "ascetic.clarityOfMind"]
    )

    static let perfectBalance = skill(
        "ascetic.perfectBalance", "Perfect Balance", path: "ascetic", tier: .capstone, ranks: 1, kind: .passive,
        symbol: "crown.fill",
        text: "Above 90% health: +35% damage. Below 40% health: regeneration tripled.",
        effects: [whileIn(.healthAbove(0.9), .damage, .increased, 0.35, 0),
                  whileIn(.healthBelow(0.4), .healthRegen, .more, 2, 0),
                  flat(.healthRegen, 3, 0)],
        requires: ["ascetic.transcendence"]
    )

    static let skills: [SkillDefinition] = [
        hundredPalms, flowingStrikes, innerCalm,
        galeStep, swiftness, counterCyclone, tailwind, stormOfFists, untouchable,
        combination, ironBody, earthshakerPalm, pressurePoints, dragonsFist, ironFist,
        chiBarrier, meditation, spiritPalm, clarityOfMind, transcendence, perfectBalance,
    ]
}
