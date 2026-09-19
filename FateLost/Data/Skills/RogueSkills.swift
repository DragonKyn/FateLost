import Foundation

/// Rogue: precision, stealth and misdirection. Assassins end things,
/// Shadows are never where you look, Tricksters fill the air with steel.
enum RogueSkills: SkillContent {
    static let archetype = ArchetypeID.rogue

    static let definition = ArchetypeDefinition(
        id: .rogue, name: "Rogue", tagline: "Strike from nowhere. Be gone before they fall.",
        symbol: "eye.slash.fill", color: RGBA(hex: 0x6A7A8A),
        paths: [
            PathDefinition(id: pathID("assassin"), name: "Assassin",
                           summary: "Backstabs, bleeding wounds and killing blows."),
            PathDefinition(id: pathID("shadow"), name: "Shadow",
                           summary: "Vanish, step through darkness, strike unseen."),
            PathDefinition(id: pathID("trickster"), name: "Trickster",
                           summary: "Thrown knives, caltrops, smoke and ricochets."),
        ],
        resonance: [StatModifier(.critChance, .flat, 0.004), StatModifier(.moveSpeed, .increased, 0.005)],
        resonanceText: "+0.4% critical chance and +0.5% movement speed per point"
    )

    // MARK: Core

    static let fanOfKnives = skill(
        "core.fanOfKnives", "Fan of Knives", tier: .one, ranks: 5, kind: .active, symbol: "asterisk",
        text: "Hurl {0} knives in every direction, each dealing {1%} power and piercing one enemy.",
        values: [rv(8, 1), rv(1.0, 0.2)],
        effects: [ability("fanOfKnives", "Fan of Knives", symbol: "asterisk", cooldown: rv(9, -0.5),
                          .volley(VolleySpec(count: rv(8, 1), pattern: .radial,
                                             damage: dmg(1.0, 0.2, .physical, [.projectile, .ability]),
                                             speed: 13, pierce: 1, range: 7, sprite: .projectileKnife,
                                             visual: .physical)))],
        tags: [.projectile]
    )

    static let keenEdge = skill(
        "core.keenEdge", "Keen Edge", tier: .one, ranks: 5, kind: .passive, symbol: "scope",
        text: "+{0%} critical chance and +{1%} critical damage.",
        values: [rv(0.03, 0.03), rv(0.1, 0.1)],
        effects: [flat(.critChance, 0.03), flat(.critDamage, 0.1)]
    )

    static let lightFeet = skill(
        "core.lightFeet", "Light Feet", tier: .one, ranks: 5, kind: .passive, symbol: "figure.run",
        text: "+{0%} dodge chance and +{1%} movement speed.",
        values: [rv(0.03, 0.03), rv(0.03, 0.03)],
        effects: [flat(.dodgeChance, 0.03), inc(.moveSpeed, 0.03)]
    )

    // MARK: Assassin

    static let backstab = skill(
        "assassin.backstab", "Backstab", path: "assassin", tier: .two, ranks: 3, kind: .passive,
        symbol: "arrow.turn.down.right",
        text: "+{0%} damage against enemies facing away from you.",
        values: [rv(0.35, 0.15)],
        effects: [.damageAgainst(.facingAway, rv(0.35, 0.15))]
    )

    static let lacerate = skill(
        "assassin.lacerate", "Lacerate", path: "assassin", tier: .two, ranks: 3, kind: .proc, symbol: "drop.fill",
        text: "Critical hits open a wound bleeding for {0%} power per second.",
        values: [rv(0.8, 0.3)],
        effects: [proc(.criticalHit, .afflict(status(.bleed, potency: rv(0.8, 0.3), duration: 4), radius: 0))]
    )

    static let markForDeath = skill(
        "assassin.markForDeath", "Mark for Death", path: "assassin", tier: .three, ranks: 3, kind: .active,
        symbol: "target",
        text: "Mark every enemy nearby for 8 s: +{0%} critical chance against them, and they take 15% more damage.",
        values: [rv(0.3, 0.1)],
        effects: [ability("markForDeath", "Mark for Death", symbol: "target", cooldown: rv(14, -1),
                          .all([.afflict(status(.mark, potency: rv(0.3, 0.1), duration: 8), radius: 3.5),
                                .afflict(status(.curse, potency: 0.15, duration: 8), radius: 3.5)]))],
        requires: ["assassin.backstab", "assassin.lacerate"]
    )

    static let opportunist = skill(
        "assassin.opportunist", "Opportunist", path: "assassin", tier: .three, ranks: 3, kind: .passive,
        symbol: "eye.fill",
        text: "+{0%} critical chance against enemies suffering any affliction.",
        values: [rv(0.1, 0.05)],
        effects: [.critChanceAgainst(.afflicted, rv(0.1, 0.05))],
        requires: ["assassin.backstab", "assassin.lacerate"]
    )

    static let thousandCuts = skill(
        "assassin.thousandCuts", "Thousand Cuts", path: "assassin", tier: .four, ranks: 3, kind: .ultimate,
        symbol: "sparkle",
        text: "A blur of steel around you: {0%} power with +50% critical chance, and everything struck bleeds.",
        values: [rv(6, 1.5)],
        effects: [ability("thousandCuts", "Thousand Cuts", symbol: "sparkle", cooldown: rv(50, -4), ultimate: true,
                          nova(rv(3.5), dmg(6, 1.5, .physical, [.melee, .area, .ability], knockback: 0.4, crit: 0.5),
                               status: status(.bleed, potency: 1, duration: 4), .blood))],
        requires: ["assassin.markForDeath", "assassin.opportunist"]
    )

    static let killingEdge = skill(
        "assassin.killingEdge", "Killing Edge", path: "assassin", tier: .capstone, ranks: 1, kind: .passive,
        symbol: "bolt.heart.fill",
        text: "Critical hits deal +400% critical damage to enemies above 90% health.",
        effects: [.critDamageAgainst(.healthAbove(0.9), 4), flat(.critChance, 0.05)],
        requires: ["assassin.thousandCuts"]
    )

    // MARK: Shadow

    static let vanish = skill(
        "shadow.vanish", "Vanish", path: "shadow", tier: .two, ranks: 3, kind: .active, symbol: "eye.slash.fill",
        text: "Disappear for {0} s: enemies lose you, you move 50% faster, and every hit is a critical.",
        values: [rv(2.5, 0.5)],
        effects: [ability("vanish", "Vanish", symbol: "eye.slash.fill", cooldown: rv(18, -1.5),
                          .all([.stealth(rv(2.5, 0.5)),
                                buff("vanishHaste", [mod(.moveSpeed, .increased, 0.5)], duration: rv(2.5, 0.5))]))]
    )

    static let umbralBlades = skill(
        "shadow.umbralBlades", "Umbral Blades", path: "shadow", tier: .two, ranks: 3, kind: .passive,
        symbol: "moon.fill",
        text: "Your weapon deals an extra {0%} of its damage as shadow.",
        values: [rv(0.2, 0.1)],
        effects: [.weapon(.addedDamage(.shadow, rv(0.2, 0.1)))]
    )

    static let shadowstep = skill(
        "shadow.shadowstep", "Shadowstep", path: "shadow", tier: .three, ranks: 3, kind: .active,
        symbol: "arrow.right.to.line",
        text: "Step through the shadows, cutting everything you pass for {0%} power, then vanish for 1 s.",
        values: [rv(2, 0.6)],
        effects: [ability("shadowstep", "Shadowstep", symbol: "arrow.right.to.line", cooldown: rv(8, -0.8),
                          .all([.dash(DashSpec(distance: rv(3.8), damage: dmg(2, 0.6, .shadow, [.melee, .ability]),
                                               visual: .shadow)),
                                .stealth(1)]))],
        requires: ["shadow.vanish", "shadow.umbralBlades"]
    )

    static let nightfall = skill(
        "shadow.nightfall", "Nightfall", path: "shadow", tier: .three, ranks: 3, kind: .passive,
        symbol: "moon.stars.fill",
        text: "While stealthed: +{0%} damage. +{1%} shadow damage at all times.",
        values: [rv(0.4, 0.15), rv(0.1, 0.05)],
        effects: [whileIn(.stealthed, .damage, .increased, 0.4, 0.15), inc(.shadowDamage, 0.1, 0.05)],
        requires: ["shadow.vanish", "shadow.umbralBlades"]
    )

    static let shadowLegion = skill(
        "shadow.shadowLegion", "Shadow Legion", path: "shadow", tier: .four, ranks: 3, kind: .ultimate,
        symbol: "person.2.fill",
        text: "Call {0} shadows of yourself to fight for {1} s.",
        values: [rv(2, 1), rv(8, 1)],
        effects: [ability("shadowLegion", "Shadow Legion", symbol: "person.2.fill", cooldown: rv(40, -3),
                          ultimate: true,
                          .summon(SummonCatalog.with(SummonCatalog.shadowClone, count: rv(2, 1), duration: rv(8, 1))))],
        requires: ["shadow.shadowstep", "shadow.nightfall"]
    )

    static let oneWithShadow = skill(
        "shadow.oneWithShadow", "One with Shadow", path: "shadow", tier: .capstone, ranks: 1, kind: .proc,
        symbol: "moon.circle.fill",
        text: "Every 10 s you slip into shadow for 1.5 s on your own.",
        effects: [proc(.interval(10), .stealth(1.5)), inc(.shadowDamage, 0.2, 0)],
        requires: ["shadow.shadowLegion"]
    )

    // MARK: Trickster

    static let hiddenKnives = skill(
        "trickster.hiddenKnives", "Hidden Knives", path: "trickster", tier: .two, ranks: 3, kind: .proc,
        symbol: "arrowshape.turn.up.right.fill",
        text: "Every 3rd attack also flings {0} knives at nearby enemies for {1%} power each.",
        values: [rv(3, 1), rv(0.8, 0.2)],
        effects: [proc(.everyNthAttack(3), .volley(VolleySpec(count: rv(3, 1), pattern: .aimed(spreadDegrees: 22),
                                                                damage: dmg(0.8, 0.2, .physical, [.projectile]),
                                                                speed: 14, range: 6.5, sprite: .projectileKnife,
                                                                visual: .physical)))]
    )

    static let caltrops = skill(
        "trickster.caltrops", "Caltrops", path: "trickster", tier: .two, ranks: 3, kind: .active,
        symbol: "circle.hexagongrid.fill",
        text: "Scatter caltrops for 6 s: enemies inside are slowed and take {0%} power every half second.",
        values: [rv(0.4, 0.15)],
        effects: [ability("caltrops", "Caltrops", symbol: "circle.hexagongrid.fill", cooldown: rv(12, -1),
                          .zone(zone(rv(2.3), duration: 6, tick: 0.5, dmg(0.4, 0.15, .physical, [.area, .ability], knockback: 0),
                                     status: status(.chill, potency: 0.45, duration: 0.8), .physical)))]
    )

    static let ricochet = skill(
        "trickster.ricochet", "Ricochet", path: "trickster", tier: .three, ranks: 3, kind: .passive,
        symbol: "arrow.triangle.branch",
        text: "Projectiles pierce {0} more enemies; melee attacks have a {1%} chance to strike twice.",
        values: [rv(1, 1), rv(0.1, 0.05)],
        effects: [flat(.pierce, 1), .weapon(.multistrike(rv(0.1, 0.05)))],
        requires: ["trickster.hiddenKnives", "trickster.caltrops"]
    )

    static let smokeBomb = skill(
        "trickster.smokeBomb", "Smoke Bomb", path: "trickster", tier: .three, ranks: 3, kind: .proc,
        symbol: "smoke.fill",
        text: "When struck, burst into smoke: enemies around you are confused for {0} s.",
        values: [rv(2, 0.5)],
        effects: [proc(.hurt, cooldown: 6, .afflict(status(.confuse, duration: rv(2, 0.5)), radius: 2.6))],
        requires: ["trickster.hiddenKnives", "trickster.caltrops"]
    )

    static let bladeWaltz = skill(
        "trickster.bladeWaltz", "Blade Waltz", path: "trickster", tier: .four, ranks: 3, kind: .ultimate,
        symbol: "circle.dashed",
        text: "{0} blades orbit you for {1} s, cutting everything they touch.",
        values: [rv(6, 1), rv(8, 1)],
        effects: [ability("bladeWaltz", "Blade Waltz", symbol: "circle.dashed", cooldown: rv(45, -3), ultimate: true,
                          .summon(SummonCatalog.with(SummonCatalog.blade, count: rv(6, 1), duration: rv(8, 1))))],
        requires: ["trickster.ricochet", "trickster.smokeBomb"]
    )

    static let sleight = skill(
        "trickster.sleight", "Sleight of Hand", path: "trickster", tier: .capstone, ranks: 1, kind: .proc,
        symbol: "sparkles",
        text: "Dodging an attack answers with a ring of 10 knives. +10% dodge chance.",
        effects: [proc(.dodge, cooldown: 0.3, .volley(VolleySpec(count: 10, pattern: .radial,
                                                                  damage: dmg(1.2, 0, .physical, [.projectile]),
                                                                  speed: 14, pierce: 1, range: 6.5,
                                                                  sprite: .projectileKnife, visual: .physical))),
                  flat(.dodgeChance, 0.1, 0)],
        requires: ["trickster.bladeWaltz"]
    )

    static let skills: [SkillDefinition] = [
        fanOfKnives, keenEdge, lightFeet,
        backstab, lacerate, markForDeath, opportunist, thousandCuts, killingEdge,
        vanish, umbralBlades, shadowstep, nightfall, shadowLegion, oneWithShadow,
        hiddenKnives, caltrops, ricochet, smokeBomb, bladeWaltz, sleight,
    ]
}
