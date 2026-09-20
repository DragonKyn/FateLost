import Foundation

/// Rare relics: each one adds a behaviour, and a few are worth building a
/// run toward without ever being required.
enum RareRelics: RelicContent {
    static let twinNock = relic(
        "twinNock", "Twin Nock", .rare, symbol: "arrow.up.and.down", ranks: 2,
        text: "+{0} projectiles per attack. Melee weapons may strike again instead.",
        values: [rv(1, 1)],
        effects: [.weapon(.extraProjectiles(rv(1, 1)))]
    )

    static let stormcallersRing = relic(
        "stormcallersRing", "Stormcaller's Ring", .rare, symbol: "bolt.horizontal.circle.fill",
        text: "Critical hits leap lightning to two more foes for {0%} power.",
        values: [rv(1.2, 0.5)],
        effects: [proc(.criticalHit, cooldown: 0.5,
                       .chain(ChainSpec(jumps: 2, damage: dmg(1.2, 0.5, .lightning, [.spell]),
                                        visual: .lightning)))]
    )

    static let emberheart = relic(
        "emberheart", "Emberheart", .rare, symbol: "flame.circle.fill",
        text: "{0%} chance for a kill to burst into flame for {1%} power.",
        values: [rv(0.15, 0.07), rv(1.4, 0.5)],
        effects: [proc(.kill(killedBy: nil), chance: rv(0.15, 0.07), cooldown: 0.3,
                       nova(rv(1.6), dmg(1.4, 0.5, .fire, [.spell, .area], knockback: 0.8),
                            status: status(.burn, duration: rv(3)), at: .origin, .fire))]
    )

    static let winterKiss = relic(
        "winterKiss", "Winter's Kiss", .rare, symbol: "snowflake.circle.fill",
        text: "{0%} chance on hit to freeze the air around the target for {1%} power, chilling all it touches.",
        values: [rv(0.06, 0.03), rv(1.2, 0.4)],
        effects: [proc(.hit(tags: [], type: nil), chance: rv(0.06, 0.03), cooldown: 0.4,
                       nova(rv(1.6), dmg(1.2, 0.4, .cold, [.spell, .area]),
                            status: status(.chill, potency: rv(0.3), duration: rv(2)), at: .origin, .frost))]
    )

    static let bulwarkCharm = relic(
        "bulwarkCharm", "Bulwark Charm", .rare, symbol: "checkmark.shield.fill",
        text: "Every 12 s, gain a barrier of {0%} of your max health.",
        values: [rv(0.1, 0.05)],
        effects: [proc(.interval(12), .barrier(rv(0.1, 0.05)))]
    )

    static let bloodstone = relic(
        "bloodstone", "Bloodstone", .rare, symbol: "diamond.fill",
        text: "Each kill heals you for {0%} of your max health.",
        values: [rv(0.01, 0.006)],
        effects: [proc(.kill(killedBy: nil), cooldown: 0.2, .heal(rv(0.01, 0.006)))]
    )

    static let hourglassShard = relic(
        "hourglassShard", "Hourglass Shard", .rare, symbol: "hourglass",
        text: "Ability cooldowns are {0%} shorter.",
        values: [rv(0.05, 0.03)],
        effects: [flat(.cooldownReduction, 0.05, 0.03)]
    )

    static let houndsWhistle = relic(
        "houndsWhistle", "Hound's Whistle", .rare, symbol: "pawprint.fill", ranks: 2,
        text: "Spirit wolves run with you: {0} at your side.",
        values: [rv(1, 1)],
        effects: [.companion(SummonCatalog.with(SummonCatalog.spiritWolf, count: rv(1, 1), duration: 0))]
    )

    static let scholarsMonocle = relic(
        "scholarsMonocle", "Scholar's Monocle", .rare, symbol: "magnifyingglass",
        text: "+{0%} spell damage and +{1%} area size.",
        values: [rv(0.08, 0.05), rv(0.06, 0.04)],
        effects: [inc(.spellDamage, 0.08, 0.05), inc(.areaSize, 0.06, 0.04)]
    )

    static let dreadBanner = relic(
        "dreadBanner", "Dread Banner", .rare, symbol: "flag.fill",
        text: "Enemies close to you are weakened by {0%}.",
        values: [rv(0.12, 0.05)],
        effects: [.aura(zone(rv(3), duration: 0, tick: 0.5, nil,
                             status: status(.weaken, potency: rv(0.12, 0.05), duration: rv(1)),
                             follows: true, .physical))]
    )

    static let titansBelt = relic(
        "titansBelt", "Titan's Belt", .rare, symbol: "figure.strengthtraining.traditional",
        text: "+{0%} max health and +{1} armour.",
        values: [rv(0.12, 0.07), rv(6, 4)],
        effects: [inc(.maxHealth, 0.12, 0.07), flat(.armor, 6, 4)]
    )

    static let tricksterDie = relic(
        "tricksterDie", "Trickster's Die", .rare, symbol: "dice.fill",
        text: "{0%} chance for an ability to be cast again for free.",
        values: [rv(0.06, 0.03)],
        effects: [flat(.spellEcho, 0.06, 0.03)]
    )

    static let quicksilverVial = relic(
        "quicksilverVial", "Quicksilver Vial", .rare, symbol: "bolt.heart.fill",
        text: "For 3 s after a kill: +{0%} attack speed.",
        values: [rv(0.12, 0.06)],
        effects: [whileIn(.recentKill(3), .attackSpeed, .increased, 0.12, 0.06)]
    )

    static let warlordsBrand = relic(
        "warlordsBrand", "Warlord's Brand", .rare, symbol: "scope",
        text: "{0%} chance on hit to mark the target, and marked enemies take +{1%} damage.",
        values: [rv(0.2, 0.1), rv(0.1, 0.05)],
        effects: [.inflict(.any, status(.mark, chance: rv(0.2, 0.1), duration: rv(4))),
                  .damageAgainst(.status(.mark), rv(0.1, 0.05))]
    )

    static let all: [RelicDefinition] = [
        twinNock, stormcallersRing, emberheart, winterKiss, bulwarkCharm, bloodstone, hourglassShard,
        houndsWhistle, scholarsMonocle, dreadBanner, titansBelt, tricksterDie, quicksilverVial, warlordsBrand,
    ]
}
