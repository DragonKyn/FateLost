import Foundation

/// Druid: the wild, in body and in spirit. Shifters become the beast,
/// Thornspeakers turn the ground against their foes, Wildhearts call the
/// forest to war.
enum DruidSkills: SkillContent {
    static let archetype = ArchetypeID.druid

    static let definition = ArchetypeDefinition(
        id: .druid, name: "Druid", tagline: "Claw, thorn and root. The wild does not forgive.",
        symbol: "leaf.fill", color: RGBA(hex: 0x4A9A5A),
        paths: [
            PathDefinition(id: pathID("shifter"), name: "Shifter",
                           summary: "Bear and wolf forms that change how you fight."),
            PathDefinition(id: pathID("thornspeaker"), name: "Thornspeaker",
                           summary: "Roots, venom and spreading rot."),
            PathDefinition(id: pathID("wildheart"), name: "Wildheart",
                           summary: "Spirit wolves, swarms and an ancient of the forest."),
        ],
        resonance: [StatModifier(.maxHealth, .increased, 0.008), StatModifier(.healthRegen, .flat, 0.15)],
        resonanceText: "+0.8% max health and +0.15 health per second per point"
    )

    // MARK: Core

    static let ursineForm = skill(
        "core.ursineForm", "Ursine Form", tier: .one, ranks: 5, kind: .form, symbol: "pawprint.circle.fill",
        text: "Become a great bear: wide crushing swipes, much more health and armour, a little slower. Use again to return.",
        effects: [ability("ursineForm", "Ursine Form", symbol: "pawprint.circle.fill", cooldown: 3,
                          .transform(FormCatalog.bear.id))],
        tags: [.melee]
    )

    static let thornskin = skill(
        "core.thornskin", "Thornskin", tier: .one, ranks: 5, kind: .proc, symbol: "leaf.arrow.triangle.circlepath",
        text: "When struck, thorns tear at everything touching you for {0%} power and poison it.",
        values: [rv(1, 0.4)],
        effects: [proc(.hurt, cooldown: 0.3, nova(rv(1.5), dmg(1, 0.4, .physical, [.area], knockback: 0.8),
                                                   status: status(.poison, potency: 0.3, duration: 3), .nature))]
    )

    static let verdantBlood = skill(
        "core.verdantBlood", "Verdant Blood", tier: .one, ranks: 5, kind: .passive, symbol: "heart.fill",
        text: "+{0} health per second and +{1%} max health.",
        values: [rv(1.5, 1.5), rv(0.05, 0.05)],
        effects: [flat(.healthRegen, 1.5), inc(.maxHealth, 0.05)]
    )

    // MARK: Shifter

    static let lupineForm = skill(
        "shifter.lupineForm", "Lupine Form", path: "shifter", tier: .two, ranks: 3, kind: .form,
        symbol: "hare.fill",
        text: "Become a wolf: rapid bites, much faster movement and keen critical strikes. Use again to return.",
        effects: [ability("lupineForm", "Lupine Form", symbol: "hare.fill", cooldown: 3,
                          .transform(FormCatalog.wolf.id))]
    )

    static let feralMight = skill(
        "shifter.feralMight", "Feral Might", path: "shifter", tier: .two, ranks: 5, kind: .passive,
        symbol: "bolt.heart.fill",
        text: "In any form: +{0%} damage and +{1%} attack speed.",
        values: [rv(0.12, 0.12), rv(0.06, 0.06)],
        effects: [whileIn(.transformed, .damage, .increased, 0.12), whileIn(.transformed, .attackSpeed, .increased, 0.06)]
    )

    static let savageMaul = skill(
        "shifter.savageMaul", "Savage Maul", path: "shifter", tier: .three, ranks: 3, kind: .proc,
        symbol: "burst.fill",
        text: "In a form, every 4th attack mauls for {0%} power around the target and leaves it bleeding.",
        values: [rv(2, 0.6)],
        effects: [proc(.everyNthAttack(4), requires: .transformed,
                       nova(rv(1.5), dmg(2, 0.6, .physical, [.melee, .area], knockback: 1),
                            status: status(.bleed, potency: 0.6, duration: 3), at: .origin, .blood))],
        requires: ["shifter.lupineForm", "shifter.feralMight"]
    )

    static let primalHide = skill(
        "shifter.primalHide", "Primal Hide", path: "shifter", tier: .three, ranks: 3, kind: .passive,
        symbol: "shield.fill",
        text: "In a form: +{0} armour and +{1%} dodge chance.",
        values: [rv(15, 8), rv(0.03, 0.02)],
        effects: [whileIn(.transformed, .armor, .flat, 15, 8), whileIn(.transformed, .dodgeChance, .flat, 0.03, 0.02)],
        requires: ["shifter.lupineForm", "shifter.feralMight"]
    )

    static let rampage = skill(
        "shifter.rampage", "Rampage", path: "shifter", tier: .four, ranks: 3, kind: .ultimate,
        symbol: "flame.fill",
        text: "Go berserk for {0} s: +50% attack speed, +30% movement speed, and heal 20% of your max health.",
        values: [rv(8, 1)],
        effects: [ability("rampage", "Rampage", symbol: "flame.fill", cooldown: rv(45, -4), ultimate: true,
                          .all([buff("rampage", [mod(.attackSpeed, .increased, 0.5), mod(.moveSpeed, .increased, 0.3),
                                                 mod(.damage, .increased, 0.2)], duration: rv(8, 1)),
                                .heal(0.2)]))],
        requires: ["shifter.savageMaul", "shifter.primalHide"]
    )

    static let apexShifter = skill(
        "shifter.apexShifter", "Apex Shifter", path: "shifter", tier: .capstone, ranks: 1, kind: .proc,
        symbol: "crown.fill",
        text: "Taking a form lets out a roar: 300% power around you and nearby enemies flee. Forms deal 30% more damage.",
        effects: [proc(.transform, .all([nova(rv(3), dmg(3, 0, .physical, [.area], knockback: 2), .nature),
                                         .afflict(status(.fear, duration: 2), radius: 3.5)])),
                  .statWhile(.transformed, mod(.damage, .more, 0.3))],
        requires: ["shifter.rampage"]
    )

    // MARK: Thornspeaker

    static let graspingRoots = skill(
        "thornspeaker.graspingRoots", "Grasping Roots", path: "thornspeaker", tier: .two, ranks: 3, kind: .active,
        symbol: "tree.fill",
        text: "Roots burst up under the crowd for 4 s, holding enemies fast and poisoning them for {0%} power per second.",
        values: [rv(0.4, 0.15)],
        effects: [ability("graspingRoots", "Grasping Roots", symbol: "tree.fill", cooldown: rv(12, -1),
                          .zone(zone(rv(2.6), duration: 4, tick: 0.5,
                                     dmg(0.2, 0.075, .poison, [.spell, .area, .ability], knockback: 0),
                                     status: status(.root, duration: 0.8), at: .cluster, .nature)))]
    )

    static let venomousThorns = skill(
        "thornspeaker.venomousThorns", "Venomous Thorns", path: "thornspeaker", tier: .two, ranks: 3, kind: .passive,
        symbol: "drop.triangle.fill",
        text: "Hits have a {0%} chance to poison for {1%} power per second. Poison stacks.",
        values: [rv(0.2, 0.1), rv(0.4, 0.15)],
        effects: [.inflict(.any, status(.poison, chance: rv(0.2, 0.1), potency: rv(0.4, 0.15), duration: 4))]
    )

    static let brambleRing = skill(
        "thornspeaker.brambleRing", "Bramble Ring", path: "thornspeaker", tier: .three, ranks: 3, kind: .active,
        symbol: "circle.hexagongrid.circle.fill",
        text: "A ring of brambles follows you for 8 s, tearing at everything inside for {0%} power and slowing it.",
        values: [rv(0.6, 0.2)],
        effects: [ability("brambleRing", "Bramble Ring", symbol: "circle.hexagongrid.circle.fill", cooldown: rv(18, -1.5),
                          .zone(zone(rv(2.1), duration: 8, tick: 0.4, dmg(0.6, 0.2, .physical, [.area, .ability], knockback: 0.2),
                                     status: status(.chill, potency: 0.4, duration: 0.8), follows: true, .nature)))],
        requires: ["thornspeaker.graspingRoots", "thornspeaker.venomousThorns"]
    )

    static let rot = skill(
        "thornspeaker.rot", "Rot", path: "thornspeaker", tier: .three, ranks: 3, kind: .passive,
        symbol: "allergens",
        text: "+{0%} damage against poisoned enemies. +{1%} damage over time.",
        values: [rv(0.15, 0.08), rv(0.15, 0.1)],
        effects: [.damageAgainst(.status(.poison), rv(0.15, 0.08)), inc(.dotDamage, 0.15, 0.1)],
        requires: ["thornspeaker.graspingRoots", "thornspeaker.venomousThorns"]
    )

    static let worldroot = skill(
        "thornspeaker.worldroot", "Worldroot", path: "thornspeaker", tier: .four, ranks: 3, kind: .ultimate,
        symbol: "mountain.2.fill",
        text: "{0} great thorns erupt around you for {1%} power each, rooting what survives.",
        values: [rv(14, 3), rv(3, 0.8)],
        effects: [ability("worldroot", "Worldroot", symbol: "mountain.2.fill", cooldown: rv(50, -4), ultimate: true,
                          .strikes(StrikeSpec(count: rv(14, 3), radius: rv(1.4), scatter: 4.5, delay: 0.35,
                                              damage: dmg(3, 0.8, .physical, [.area, .ability], knockback: 0.8),
                                              status: status(.root, duration: 2), anchor: .player, visual: .nature)))],
        requires: ["thornspeaker.brambleRing", "thornspeaker.rot"]
    )

    static let overgrowth = skill(
        "thornspeaker.overgrowth", "Overgrowth", path: "thornspeaker", tier: .capstone, ranks: 1, kind: .proc,
        symbol: "crown.fill",
        text: "Poisoned enemies spread their poison to everything within 2.5 m when they die.",
        effects: [proc(.kill(killedBy: nil), target: .status(.poison),
                       .afflict(status(.poison, potency: 0.6, duration: 4), radius: 2.5)),
                  inc(.poisonDamage, 0.25, 0)],
        requires: ["thornspeaker.worldroot"]
    )

    // MARK: Wildheart

    static let spiritWolves = skill(
        "wildheart.spiritWolves", "Spirit Wolves", path: "wildheart", tier: .two, ranks: 3, kind: .summon,
        symbol: "pawprint.fill",
        text: "{0} spirit wolves run with you, biting for {1%} power.",
        values: [rv(2, 0.5), rv(0.8, 0.3)],
        effects: [.companion(SummonCatalog.with(SummonCatalog.spiritWolf, count: rv(2, 0.5), duration: 0))]
    )

    static let rejuvenation = skill(
        "wildheart.rejuvenation", "Rejuvenation", path: "wildheart", tier: .two, ranks: 3, kind: .proc,
        symbol: "leaf.circle.fill",
        text: "Every 8 s, heal {0%} of your max health.",
        values: [rv(0.06, 0.02)],
        effects: [proc(.interval(8), .heal(rv(0.06, 0.02)))]
    )

    static let hornetSwarm = skill(
        "wildheart.hornetSwarm", "Hornet Swarm", path: "wildheart", tier: .three, ranks: 3, kind: .active,
        symbol: "ant.fill",
        text: "A cloud of {0} hornets circles you for 8 s, stinging and poisoning.",
        values: [rv(8, 2)],
        effects: [ability("hornetSwarm", "Hornet Swarm", symbol: "ant.fill", cooldown: rv(18, -1.5),
                          .summon(SummonCatalog.with(SummonCatalog.hornet, count: rv(8, 2), duration: 8)))],
        requires: ["wildheart.spiritWolves", "wildheart.rejuvenation"]
    )

    static let naturesBond = skill(
        "wildheart.naturesBond", "Nature's Bond", path: "wildheart", tier: .three, ranks: 3, kind: .passive,
        symbol: "link",
        text: "+{0%} summon damage and +{1} health per second.",
        values: [rv(0.15, 0.1), rv(2, 1)],
        effects: [inc(.summonDamage, 0.15, 0.1), flat(.healthRegen, 2, 1)],
        requires: ["wildheart.spiritWolves", "wildheart.rejuvenation"]
    )

    static let awakenTheAncient = skill(
        "wildheart.awakenTheAncient", "Awaken the Ancient", path: "wildheart", tier: .four, ranks: 3, kind: .ultimate,
        symbol: "tree.fill",
        text: "An ancient of the forest walks with you for {0} s, drawing enemies and crushing them for {1%} power.",
        values: [rv(20, 4), rv(3, 1)],
        effects: [ability("awakenTheAncient", "Awaken the Ancient", symbol: "tree.fill", cooldown: rv(70, -5),
                          ultimate: true,
                          .summon(SummonCatalog.with(SummonCatalog.treant, count: 1, duration: rv(20, 4))))],
        requires: ["wildheart.hornetSwarm", "wildheart.naturesBond"]
    )

    static let heartOfTheWild = skill(
        "wildheart.heartOfTheWild", "Heart of the Wild", path: "wildheart", tier: .capstone, ranks: 1, kind: .passive,
        symbol: "crown.fill",
        text: "Every summon brings one more, and 8% of summon damage returns to you as health.",
        effects: [flat(.summonCount, 1, 0), flat(.summonLifeSteal, 0.08, 0), inc(.summonDamage, 0.2, 0)],
        requires: ["wildheart.awakenTheAncient"]
    )

    static let skills: [SkillDefinition] = [
        ursineForm, thornskin, verdantBlood,
        lupineForm, feralMight, savageMaul, primalHide, rampage, apexShifter,
        graspingRoots, venomousThorns, brambleRing, rot, worldroot, overgrowth,
        spiritWolves, rejuvenation, hornetSwarm, naturesBond, awakenTheAncient, heartOfTheWild,
    ]
}
