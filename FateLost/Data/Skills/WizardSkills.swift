import Foundation

/// Wizard: trained, deliberate magic that controls the battlefield.
/// Arcanists bend time and space, Elementalists deny ground, Frostweavers
/// freeze the world still.
enum WizardSkills: SkillContent {
    static let archetype = ArchetypeID.wizard

    static let definition = ArchetypeDefinition(
        id: .wizard, name: "Wizard", tagline: "Magic studied, measured and placed exactly where it's needed.",
        symbol: "book.closed.fill", color: RGBA(hex: 0x4A7AC8),
        paths: [
            PathDefinition(id: pathID("arcanist"), name: "Arcanist",
                           summary: "Blink, orbiting orbs and mastery of cooldowns."),
            PathDefinition(id: pathID("elementalist"), name: "Elementalist",
                           summary: "Walls of fire, storm glyphs and falling stars."),
            PathDefinition(id: pathID("frostweaver"), name: "Frostweaver",
                           summary: "Chill, freeze and shatter."),
        ],
        resonance: [StatModifier(.magicDamage, .increased, 0.012), StatModifier(.cooldownReduction, .flat, 0.004)],
        resonanceText: "+1.2% magic damage and +0.4% cooldown reduction per point"
    )

    // MARK: Core

    static let rimeBurst = skill(
        "core.rimeBurst", "Rime Burst", tier: .one, ranks: 5, kind: .active, symbol: "snowflake",
        text: "Frost bursts from you: {0%} cold power, chilling everything and freezing it solid for {1} s.",
        values: [rv(1.5, 0.35), rv(0.8, 0.15)],
        effects: [ability("rimeBurst", "Rime Burst", symbol: "snowflake", cooldown: rv(12, -0.8),
                          .all([nova(rv(3), dmg(1.5, 0.35, .cold, [.spell, .area, .ability], knockback: 0.4),
                                     status: status(.freeze, duration: rv(0.8, 0.15)), .frost),
                                .afflict(status(.chill, potency: 0.45, duration: 3), radius: 3)]))],
        tags: [.spell, .area]
    )

    static let studiedArcana = skill(
        "core.studiedArcana", "Studied Arcana", tier: .one, ranks: 5, kind: .passive, symbol: "book.fill",
        text: "+{0%} magic damage and +{1%} cooldown reduction.",
        values: [rv(0.08, 0.08), rv(0.03, 0.03)],
        effects: [inc(.magicDamage, 0.08), flat(.cooldownReduction, 0.03)]
    )

    static let wardingGlyph = skill(
        "core.wardingGlyph", "Warding Glyph", tier: .one, ranks: 5, kind: .proc, symbol: "hexagon.fill",
        text: "Every 12 s a glyph shields you for {0%} of your max health.",
        values: [rv(0.08, 0.03)],
        effects: [proc(.interval(12), .barrier(rv(0.08, 0.03)))]
    )

    // MARK: Arcanist

    static let blink = skill(
        "arcanist.blink", "Blink", path: "arcanist", tier: .two, ranks: 3, kind: .active,
        symbol: "arrow.up.and.down.and.arrow.left.and.right",
        text: "Teleport ahead, leaving an arcane burst of {0%} power where you stood.",
        values: [rv(1.5, 0.5)],
        effects: [ability("blink", "Blink", symbol: "arrow.up.and.down.and.arrow.left.and.right", cooldown: rv(7, -0.7),
                          .all([nova(rv(2), dmg(1.5, 0.5, .arcane, [.spell, .area, .ability], knockback: 1), .arcane),
                                .dash(DashSpec(distance: 4.5, invulnerability: 0.3, visual: .arcane))]))]
    )

    static let clarity = skill(
        "arcanist.clarity", "Clarity", path: "arcanist", tier: .two, ranks: 3, kind: .proc, symbol: "sparkles",
        text: "+{0%} cooldown reduction. Using an ability grants +{1%} magic damage for 3 s.",
        values: [rv(0.05, 0.03), rv(0.15, 0.05)],
        effects: [flat(.cooldownReduction, 0.05, 0.03),
                  proc(.abilityCast, buff("clarity", [mod(.magicDamage, .increased, 0.15, 0.05)], duration: 3))]
    )

    static let orrery = skill(
        "arcanist.orrery", "Orrery", path: "arcanist", tier: .three, ranks: 3, kind: .active,
        symbol: "circle.circle.fill",
        text: "{0} arcane orbs circle you for {1} s.",
        values: [rv(3, 1), rv(10, 2)],
        effects: [ability("orrery", "Orrery", symbol: "circle.circle.fill", cooldown: rv(20, -2),
                          .summon(SummonCatalog.with(SummonCatalog.arcaneOrb, count: rv(3, 1), duration: rv(10, 2))))],
        requires: ["arcanist.blink", "arcanist.clarity"]
    )

    static let spellEcho = skill(
        "arcanist.spellEcho", "Spell Echo", path: "arcanist", tier: .three, ranks: 3, kind: .proc,
        symbol: "arrow.triangle.2.circlepath",
        text: "Using an ability takes {0} s off your other cooldowns.",
        values: [rv(0.8, 0.4)],
        effects: [proc(.abilityCast, .reduceCooldowns(rv(0.8, 0.4)))],
        requires: ["arcanist.blink", "arcanist.clarity"]
    )

    static let stillness = skill(
        "arcanist.stillness", "Stillness of Ages", path: "arcanist", tier: .four, ranks: 3, kind: .ultimate,
        symbol: "hourglass",
        text: "Stop time around you: every enemy nearby is held still for {0} s, and you gain a barrier.",
        values: [rv(3, 0.5)],
        effects: [ability("stillness", "Stillness of Ages", symbol: "hourglass", cooldown: rv(70, -5), ultimate: true,
                          .all([nova(rv(7), nil, status: status(.stun, duration: rv(3, 0.5)), .arcane),
                                .barrier(0.25)]))],
        requires: ["arcanist.orrery", "arcanist.spellEcho"]
    )

    static let archmage = skill(
        "arcanist.archmage", "Archmage", path: "arcanist", tier: .capstone, ranks: 1, kind: .passive,
        symbol: "wand.and.stars",
        text: "30% more magic damage, and your cooldowns recover 20% faster.",
        effects: [more(.magicDamage, 0.3, 0), more(.cooldownReduction, 0.2, 0), flat(.cooldownReduction, 0.1, 0)],
        requires: ["arcanist.stillness"]
    )

    // MARK: Elementalist

    static let firewall = skill(
        "elementalist.firewall", "Firewall", path: "elementalist", tier: .two, ranks: 3, kind: .active,
        symbol: "flame.fill",
        text: "Raise fire under the crowd for 5 s: {0%} fire power every half second, and it burns.",
        values: [rv(0.6, 0.2)],
        effects: [ability("firewall", "Firewall", symbol: "flame.fill", cooldown: rv(12, -1),
                          .zone(zone(rv(2.4), duration: 5, tick: 0.5, dmg(0.6, 0.2, .fire, [.spell, .area, .ability], knockback: 0),
                                     status: status(.burn, potency: 0.4, duration: 2), at: .cluster, .fire)))]
    )

    static let attunement = skill(
        "elementalist.attunement", "Elemental Attunement", path: "elementalist", tier: .two, ranks: 5, kind: .passive,
        symbol: "circle.hexagonpath.fill",
        text: "+{0%} fire, cold and lightning damage.",
        values: [rv(0.1, 0.1)],
        effects: [inc(.fireDamage, 0.1), inc(.coldDamage, 0.1), inc(.lightningDamage, 0.1)]
    )

    static let stormGlyph = skill(
        "elementalist.stormGlyph", "Storm Glyph", path: "elementalist", tier: .three, ranks: 3, kind: .active,
        symbol: "cloud.bolt.fill",
        text: "Draw a glyph that calls lightning on {0} enemies inside it several times a second for 6 s.",
        values: [rv(2, 1)],
        effects: [ability("stormGlyph", "Storm Glyph", symbol: "cloud.bolt.fill", cooldown: rv(16, -1),
                          .zone(ZoneSpec(radius: rv(3.2), duration: 6, tick: 0.4,
                                         damage: dmg(1.1, 0.3, .lightning, [.spell, .ability], knockback: 0.2),
                                         status: status(.shock, chance: 0.5, potency: 0.15, duration: 3),
                                         strikesPerTick: 2, anchor: .cluster, visual: .lightning)))],
        requires: ["elementalist.firewall", "elementalist.attunement"]
    )

    static let combustion = skill(
        "elementalist.combustion", "Combustion", path: "elementalist", tier: .three, ranks: 3, kind: .proc,
        symbol: "flame.circle.fill",
        text: "Burning enemies explode when they die, dealing {0%} fire power around them.",
        values: [rv(1.5, 0.5)],
        effects: [proc(.kill(killedBy: nil), target: .status(.burn),
                       nova(rv(1.8), dmg(1.5, 0.5, .fire, [.area], knockback: 0.8), at: .origin, .fire))],
        requires: ["elementalist.firewall", "elementalist.attunement"]
    )

    static let starfall = skill(
        "elementalist.starfall", "Starfall", path: "elementalist", tier: .four, ranks: 3, kind: .ultimate,
        symbol: "sparkles",
        text: "Call down {0} blazing stars on the crowd, {1%} fire power each.",
        values: [rv(6, 2), rv(5, 1.5)],
        effects: [ability("starfall", "Starfall", symbol: "sparkles", cooldown: rv(45, -3), ultimate: true,
                          .strikes(StrikeSpec(count: rv(6, 2), radius: rv(1.8), scatter: 3.5, delay: 0.8,
                                              damage: dmg(5, 1.5, .fire, [.spell, .area, .ability], knockback: 1.5),
                                              status: status(.burn, potency: 0.8, duration: 3), visual: .fire)))],
        requires: ["elementalist.stormGlyph", "elementalist.combustion"]
    )

    static let confluence = skill(
        "elementalist.confluence", "Confluence", path: "elementalist", tier: .capstone, ranks: 1, kind: .passive,
        symbol: "atom",
        text: "+60% damage against enemies suffering two or more elements at once.",
        effects: [.damageAgainst(.elementalStatuses(2), 0.6), inc(.statusChance, 0.25, 0)],
        requires: ["elementalist.starfall"]
    )

    // MARK: Frostweaver

    static let frostbite = skill(
        "frostweaver.frostbite", "Frostbite", path: "frostweaver", tier: .two, ranks: 3, kind: .passive,
        symbol: "thermometer.snowflake",
        text: "Hits have a {0%} chance to chill for 2 s.",
        values: [rv(0.2, 0.1)],
        effects: [.inflict(.any, status(.chill, chance: rv(0.2, 0.1), potency: 0.35, duration: 2))]
    )

    static let shardstorm = skill(
        "frostweaver.shardstorm", "Shardstorm", path: "frostweaver", tier: .two, ranks: 3, kind: .active,
        symbol: "wind.snow",
        text: "Fire {0} ice shards in a fan: {1%} cold power each, piercing twice and chilling.",
        values: [rv(5, 1), rv(1.3, 0.3)],
        effects: [ability("shardstorm", "Shardstorm", symbol: "wind.snow", cooldown: rv(6, -0.4),
                          .volley(VolleySpec(count: rv(5, 1), pattern: .aimed(spreadDegrees: 40),
                                             damage: dmg(1.3, 0.3, .cold, [.spell, .projectile, .ability]),
                                             speed: 14, pierce: 2, range: 8,
                                             status: status(.chill, potency: 0.35, duration: 2),
                                             sprite: .projectileShard, visual: .frost)))]
    )

    static let shatter = skill(
        "frostweaver.shatter", "Shatter", path: "frostweaver", tier: .three, ranks: 3, kind: .proc,
        symbol: "burst.fill",
        text: "+{0%} damage against frozen enemies. Frozen enemies that die burst into shards.",
        values: [rv(0.5, 0.2)],
        effects: [.damageAgainst(.status(.freeze), rv(0.5, 0.2)),
                  proc(.kill(killedBy: nil), target: .status(.freeze),
                       nova(rv(1.6), dmg(1, 0.4, .cold, [.area]), status: status(.chill, potency: 0.4, duration: 2),
                            at: .origin, .frost))],
        requires: ["frostweaver.frostbite", "frostweaver.shardstorm"]
    )

    static let deepWinter = skill(
        "frostweaver.deepWinter", "Deep Winter", path: "frostweaver", tier: .three, ranks: 3, kind: .proc,
        symbol: "snowflake.circle.fill",
        text: "Cold hits against chilled enemies have a {0%} chance to freeze them for 1 s.",
        values: [rv(0.15, 0.05)],
        effects: [proc(.hit(tags: [], type: .cold), chance: rv(0.15, 0.05), target: .status(.chill),
                       .afflict(status(.freeze, duration: 1), radius: 0))],
        requires: ["frostweaver.frostbite", "frostweaver.shardstorm"]
    )

    static let blizzard = skill(
        "frostweaver.blizzard", "Blizzard", path: "frostweaver", tier: .four, ranks: 3, kind: .ultimate,
        symbol: "cloud.snow.fill",
        text: "A blizzard follows you for {0} s: {1%} cold power several times a second, chilling everything.",
        values: [rv(7, 1), rv(0.7, 0.2)],
        effects: [ability("blizzard", "Blizzard", symbol: "cloud.snow.fill", cooldown: rv(50, -4), ultimate: true,
                          .zone(zone(rv(4.5), duration: rv(7, 1), tick: 0.4,
                                     dmg(0.7, 0.2, .cold, [.spell, .area, .ability], knockback: 0),
                                     status: status(.chill, potency: 0.5, duration: 1), follows: true, .frost)))],
        requires: ["frostweaver.shatter", "frostweaver.deepWinter"]
    )

    static let absoluteZero = skill(
        "frostweaver.absoluteZero", "Absolute Zero", path: "frostweaver", tier: .capstone, ranks: 1, kind: .passive,
        symbol: "snowflake",
        text: "Hits against frozen enemies are always critical, and everything you inflict lasts 30% longer.",
        effects: [.critChanceAgainst(.status(.freeze), 1), inc(.effectDuration, 0.3, 0)],
        requires: ["frostweaver.blizzard"]
    )

    static let skills: [SkillDefinition] = [
        rimeBurst, studiedArcana, wardingGlyph,
        blink, clarity, orrery, spellEcho, stillness, archmage,
        firewall, attunement, stormGlyph, combustion, starfall, confluence,
        frostbite, shardstorm, shatter, deepWinter, blizzard, absoluteZero,
    ]
}
