import Foundation

/// Cleric: faith as a weapon and a shield. Exorcists burn with judgment,
/// Priests will not stay down, Dawnbringers carry the sun.
enum ClericSkills: SkillContent {
    static let archetype = ArchetypeID.cleric

    static let definition = ArchetypeDefinition(
        id: .cleric, name: "Cleric", tagline: "Faith that heals you, and burns everything else.",
        symbol: "sun.max.fill", color: RGBA(hex: 0xE0B84A),
        paths: [
            PathDefinition(id: pathID("exorcist"), name: "Exorcist",
                           summary: "Purging light, judgment and holy wrath."),
            PathDefinition(id: pathID("priest"), name: "Priest",
                           summary: "Renewal, wards and miracles."),
            PathDefinition(id: pathID("dawnbringer"), name: "Dawnbringer",
                           summary: "Radiant auras, halos and a second sun."),
        ],
        resonance: [StatModifier(.healthRegen, .flat, 0.25), StatModifier(.holyDamage, .increased, 0.015)],
        resonanceText: "+0.25 health per second and +1.5% holy damage per point"
    )

    // MARK: Core

    static let hallowedGround = skill(
        "core.hallowedGround", "Hallowed Ground", tier: .one, ranks: 5, kind: .active, symbol: "circle.dotted.circle",
        text: "Consecrate the ground for 6 s: enemies inside take {0%} holy power every half second; you regenerate {1} health per second.",
        values: [rv(0.6, 0.15), rv(8, 2)],
        effects: [ability("hallowedGround", "Hallowed Ground", symbol: "circle.dotted.circle", cooldown: rv(16, -1),
                          .zone(zone(rv(3), duration: 6, tick: 0.5, dmg(0.6, 0.15, .holy, [.spell, .area, .ability], knockback: 0),
                                     buff: [mod(.healthRegen, .flat, 8, 2)], .holy)))],
        tags: [.holy, .area]
    )

    static let devotion = skill(
        "core.devotion", "Devotion", tier: .one, ranks: 5, kind: .passive, symbol: "hands.sparkles.fill",
        text: "+{0} health per second and +{1%} healing received.",
        values: [rv(1.5, 1.5), rv(0.06, 0.06)],
        effects: [flat(.healthRegen, 1.5), inc(.healingReceived, 0.06)]
    )

    static let radiantFaith = skill(
        "core.radiantFaith", "Radiant Faith", tier: .one, ranks: 5, kind: .passive, symbol: "sun.max.fill",
        text: "+{0%} holy damage, and your weapon deals an extra {1%} of its damage as holy.",
        values: [rv(0.08, 0.08), rv(0.08, 0.08)],
        effects: [inc(.holyDamage, 0.08), .weapon(.addedDamage(.holy, rv(0.08, 0.08)))]
    )

    // MARK: Exorcist

    static let purgingLight = skill(
        "exorcist.purgingLight", "Purging Light", path: "exorcist", tier: .two, ranks: 3, kind: .proc,
        symbol: "light.max",
        text: "Hits have a {0%} chance to erupt in light for {1%} holy power around the target.",
        values: [rv(0.1, 0.04), rv(1.5, 0.5)],
        effects: [proc(.hit(tags: [], type: nil), chance: rv(0.1, 0.04), cooldown: 0.25,
                       nova(rv(1.6), dmg(1.5, 0.5, .holy, [.spell, .area], knockback: 0.6), at: .origin, .holy))]
    )

    static let judgment = skill(
        "exorcist.judgment", "Judgment", path: "exorcist", tier: .two, ranks: 3, kind: .active,
        symbol: "sun.min.fill",
        text: "{0} pillars of light fall on nearby enemies, {1%} holy power each.",
        values: [rv(5, 1), rv(3, 0.8)],
        effects: [ability("judgment", "Judgment", symbol: "sun.min.fill", cooldown: rv(10, -0.8),
                          .strikes(StrikeSpec(count: rv(5, 1), radius: rv(1.2), scatter: 4, delay: 0.4,
                                              damage: dmg(3, 0.8, .holy, [.spell, .area, .ability], knockback: 0.6),
                                              anchor: .player, visual: .holy)))]
    )

    static let rebuke = skill(
        "exorcist.rebuke", "Rebuke", path: "exorcist", tier: .three, ranks: 3, kind: .passive,
        symbol: "hand.raised.fill",
        text: "Holy hits have a {0%} chance to stun for 0.6 s.",
        values: [rv(0.15, 0.05)],
        effects: [.inflict(HitFilter(type: .holy), status(.stun, chance: rv(0.15, 0.05), duration: 0.6))],
        requires: ["exorcist.purgingLight", "exorcist.judgment"]
    )

    static let zealotry = skill(
        "exorcist.zealotry", "Zealotry", path: "exorcist", tier: .three, ranks: 3, kind: .passive,
        symbol: "flame.fill",
        text: "Above 70% health: +{0%} attack speed and +{1%} holy damage.",
        values: [rv(0.08, 0.04), rv(0.15, 0.08)],
        effects: [whileIn(.healthAbove(0.7), .attackSpeed, .increased, 0.08, 0.04),
                  whileIn(.healthAbove(0.7), .holyDamage, .increased, 0.15, 0.08)],
        requires: ["exorcist.purgingLight", "exorcist.judgment"]
    )

    static let wrathOfHeaven = skill(
        "exorcist.wrathOfHeaven", "Wrath of Heaven", path: "exorcist", tier: .four, ranks: 3, kind: .ultimate,
        symbol: "sun.max.trianglebadge.exclamationmark",
        text: "The sky opens: {0} columns of light strike around you for {1%} holy power, stunning.",
        values: [rv(12, 3), rv(5, 1.2)],
        effects: [ability("wrathOfHeaven", "Wrath of Heaven", symbol: "sun.max.trianglebadge.exclamationmark",
                          cooldown: rv(55, -4), ultimate: true,
                          .strikes(StrikeSpec(count: rv(12, 3), radius: rv(1.6), scatter: 5, delay: 0.6,
                                              damage: dmg(5, 1.2, .holy, [.spell, .area, .ability], knockback: 1),
                                              status: status(.stun, duration: 1), anchor: .player, visual: .holy)))],
        requires: ["exorcist.rebuke", "exorcist.zealotry"]
    )

    static let exorcism = skill(
        "exorcist.exorcism", "Exorcism", path: "exorcist", tier: .capstone, ranks: 1, kind: .proc,
        symbol: "sparkles",
        text: "Enemies slain by holy damage explode in light for 250% holy power.",
        effects: [proc(.kill(killedBy: .holy), nova(rv(2), dmg(2.5, 0, .holy, [.spell, .area], knockback: 0.8),
                                                   at: .origin, .holy)),
                  inc(.holyDamage, 0.2, 0)],
        requires: ["exorcist.wrathOfHeaven"]
    )

    // MARK: Priest

    static let renewal = skill(
        "priest.renewal", "Renewal", path: "priest", tier: .two, ranks: 3, kind: .active, symbol: "cross.fill",
        text: "Heal {0%} of your max health, then {1} more per second for 5 s.",
        values: [rv(0.25, 0.05), rv(10, 4)],
        effects: [ability("renewal", "Renewal", symbol: "cross.fill", cooldown: rv(18, -1.5),
                          .all([.heal(rv(0.25, 0.05)),
                                buff("renewal", [mod(.healthRegen, .flat, 10, 4)], duration: 5)]))]
    )

    static let sacredWard = skill(
        "priest.sacredWard", "Sacred Ward", path: "priest", tier: .two, ranks: 3, kind: .proc,
        symbol: "shield.fill",
        text: "When struck, a {0%} chance to gain a barrier of 10% max health.",
        values: [rv(0.25, 0.1)],
        effects: [proc(.hurt, chance: rv(0.25, 0.1), cooldown: 4, .barrier(0.1))]
    )

    static let sanctuary = skill(
        "priest.sanctuary", "Sanctuary", path: "priest", tier: .three, ranks: 3, kind: .passive,
        symbol: "house.fill",
        text: "While shielded: +{0%} damage and +{1} armour.",
        values: [rv(0.15, 0.08), rv(10, 5)],
        effects: [whileIn(.shielded, .damage, .increased, 0.15, 0.08), whileIn(.shielded, .armor, .flat, 10, 5)],
        requires: ["priest.renewal", "priest.sacredWard"]
    )

    static let overflowingGrace = skill(
        "priest.overflowingGrace", "Overflowing Grace", path: "priest", tier: .three, ranks: 3, kind: .passive,
        symbol: "drop.halffull",
        text: "Healing beyond full health becomes a barrier at {0%} strength. +{1%} healing received.",
        values: [rv(0.4, 0.2), rv(0.1, 0.05)],
        effects: [flat(.overhealBarrier, 0.4, 0.2), inc(.healingReceived, 0.1, 0.05)],
        requires: ["priest.renewal", "priest.sacredWard"]
    )

    static let miracle = skill(
        "priest.miracle", "Miracle", path: "priest", tier: .four, ranks: 3, kind: .ultimate,
        symbol: "sparkles",
        text: "Fully heal, become untouchable for {0} s, and release a burst of {1%} holy power.",
        values: [rv(2.5, 0.5), rv(4, 1)],
        effects: [ability("miracle", "Miracle", symbol: "sparkles", cooldown: rv(90, -8), ultimate: true,
                          .all([.heal(1), .invulnerable(rv(2.5, 0.5)),
                                nova(rv(3.5), dmg(4, 1, .holy, [.spell, .area, .ability], knockback: 2), .holy)]))],
        requires: ["priest.sanctuary", "priest.overflowingGrace"]
    )

    static let beatified = skill(
        "priest.beatified", "Beatified", path: "priest", tier: .capstone, ranks: 1, kind: .proc,
        symbol: "sun.haze.fill",
        text: "Your regeneration is tripled, and at full health you pulse holy light every second for 150% power.",
        effects: [more(.healthRegen, 2, 0),
                  proc(.interval(1), requires: .healthAbove(0.99),
                       nova(rv(2.2), dmg(1.5, 0, .holy, [.spell, .area], knockback: 0.4), .holy))],
        requires: ["priest.miracle"]
    )

    // MARK: Dawnbringer

    static let radiance = skill(
        "dawnbringer.radiance", "Radiance", path: "dawnbringer", tier: .two, ranks: 3, kind: .aura,
        symbol: "sun.max.circle.fill",
        text: "Light burns everything near you for {0%} holy power every 0.6 s.",
        values: [rv(0.5, 0.2)],
        effects: [.aura(zone(rv(2.4), duration: 0, tick: 0.6, dmg(0.5, 0.2, .holy, [.spell, .area], knockback: 0.1),
                             follows: true, .holy))]
    )

    static let dawnburst = skill(
        "dawnbringer.dawnburst", "Dawnburst", path: "dawnbringer", tier: .two, ranks: 3, kind: .active,
        symbol: "sunrise.fill",
        text: "Flare like the rising sun: {0%} holy power around you, and enemies are left weakened.",
        values: [rv(3, 0.8)],
        effects: [ability("dawnburst", "Dawnburst", symbol: "sunrise.fill", cooldown: rv(10, -0.8),
                          nova(rv(3.5), dmg(3, 0.8, .holy, [.spell, .area, .ability], knockback: 1.4),
                               status: status(.weaken, potency: 0.3, duration: 4), .holy))]
    )

    static let halo = skill(
        "dawnbringer.halo", "Halo", path: "dawnbringer", tier: .three, ranks: 3, kind: .active,
        symbol: "circle.circle",
        text: "{0} motes of light circle you for 10 s.",
        values: [rv(4, 1)],
        effects: [ability("halo", "Halo", symbol: "circle.circle", cooldown: rv(16, -1.5),
                          .summon(SummonCatalog.with(SummonCatalog.lightOrb, count: rv(4, 1), duration: 10)))],
        requires: ["dawnbringer.radiance", "dawnbringer.dawnburst"]
    )

    static let brilliance = skill(
        "dawnbringer.brilliance", "Brilliance", path: "dawnbringer", tier: .three, ranks: 3, kind: .passive,
        symbol: "light.max",
        text: "+{0%} area size and +{1%} holy damage.",
        values: [rv(0.12, 0.06), rv(0.08, 0.06)],
        effects: [inc(.areaSize, 0.12, 0.06), inc(.holyDamage, 0.08, 0.06)],
        requires: ["dawnbringer.radiance", "dawnbringer.dawnburst"]
    )

    static let secondSun = skill(
        "dawnbringer.secondSun", "Second Sun", path: "dawnbringer", tier: .four, ranks: 3, kind: .ultimate,
        symbol: "sun.max.fill",
        text: "Become a second sun for {0} s: everything around you takes {1%} holy power three times a second and burns.",
        values: [rv(8, 1), rv(1.2, 0.35)],
        effects: [ability("secondSun", "Second Sun", symbol: "sun.max.fill", cooldown: rv(55, -4), ultimate: true,
                          .zone(zone(rv(4.5), duration: rv(8, 1), tick: 0.35,
                                     dmg(1.2, 0.35, .holy, [.spell, .area, .ability], knockback: 0.2),
                                     status: status(.burn, potency: 0.5, duration: 2), follows: true, .holy)))],
        requires: ["dawnbringer.halo", "dawnbringer.brilliance"]
    )

    static let lightbearer = skill(
        "dawnbringer.lightbearer", "Lightbearer", path: "dawnbringer", tier: .capstone, ranks: 1, kind: .passive,
        symbol: "crown.fill",
        text: "30% larger areas and 40% more holy damage.",
        effects: [more(.areaSize, 0.3, 0), more(.holyDamage, 0.4, 0)],
        requires: ["dawnbringer.secondSun"]
    )

    static let skills: [SkillDefinition] = [
        hallowedGround, devotion, radiantFaith,
        purgingLight, judgment, rebuke, zealotry, wrathOfHeaven, exorcism,
        renewal, sacredWard, sanctuary, overflowingGrace, miracle, beatified,
        radiance, dawnburst, halo, brilliance, secondSun, lightbearer,
    ]
}
