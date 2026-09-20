import Foundation

/// Common relics: one small, legible number each. Nobody builds around these;
/// they are what a run is made of between the finds that matter.
enum CommonRelics: RelicContent {
    static let whetstone = relic(
        "whetstone", "Whetstone", .common, symbol: "hammer.fill",
        text: "+{0%} damage.",
        values: [rv(0.06, 0.04)],
        effects: [inc(.damage, 0.06, 0.04)]
    )

    static let stridingBoots = relic(
        "stridingBoots", "Striding Boots", .common, symbol: "figure.walk",
        text: "+{0%} movement speed.",
        values: [rv(0.06, 0.04)],
        effects: [inc(.moveSpeed, 0.06, 0.04)]
    )

    static let ironRing = relic(
        "ironRing", "Iron Ring", .common, symbol: "circle.circle",
        text: "+{0} armour.",
        values: [rv(4, 3)],
        effects: [flat(.armor, 4, 3)]
    )

    static let mendingKnot = relic(
        "mendingKnot", "Mending Knot", .common, symbol: "cross.fill",
        text: "+{0} health per second.",
        values: [rv(1, 0.7)],
        effects: [flat(.healthRegen, 1, 0.7)]
    )

    static let heartyTonic = relic(
        "heartyTonic", "Hearty Tonic", .common, symbol: "heart.fill",
        text: "+{0%} max health.",
        values: [rv(0.08, 0.05)],
        effects: [inc(.maxHealth, 0.08, 0.05)]
    )

    static let luckyCoin = relic(
        "luckyCoin", "Lucky Coin", .common, symbol: "sparkles",
        text: "+{0%} experience gained.",
        values: [rv(0.08, 0.05)],
        effects: [inc(.experienceGain, 0.08, 0.05)]
    )

    static let loadstone = relic(
        "loadstone", "Loadstone", .common, symbol: "dot.radiowaves.left.and.right",
        text: "+{0%} pickup radius.",
        values: [rv(0.25, 0.15)],
        effects: [inc(.pickupRadius, 0.25, 0.15)]
    )

    static let swiftQuiver = relic(
        "swiftQuiver", "Swift Quiver", .common, symbol: "arrow.up.forward",
        text: "+{0%} projectile speed.",
        values: [rv(0.1, 0.06)],
        effects: [inc(.projectileSpeed, 0.1, 0.06)]
    )

    static let fletching = relic(
        "fletching", "Fletching", .common, symbol: "wind",
        text: "+{0%} attack speed.",
        values: [rv(0.05, 0.03)],
        effects: [inc(.attackSpeed, 0.05, 0.03)]
    )

    static let sharpEye = relic(
        "sharpEye", "Sharp Eye", .common, symbol: "eye.fill",
        text: "+{0%} critical chance.",
        values: [rv(0.03, 0.02)],
        effects: [flat(.critChance, 0.03, 0.02)]
    )

    static let soldiersSigil = relic(
        "soldiersSigil", "Soldier's Sigil", .common, symbol: "shield.lefthalf.filled",
        text: "+{0%} melee damage.",
        values: [rv(0.08, 0.05)],
        effects: [inc(.meleeDamage, 0.08, 0.05)]
    )

    static let archersGlove = relic(
        "archersGlove", "Archer's Glove", .common, symbol: "scope",
        text: "+{0%} projectile damage.",
        values: [rv(0.08, 0.05)],
        effects: [inc(.projectileDamage, 0.08, 0.05)]
    )

    static let apprenticesFocus = relic(
        "apprenticesFocus", "Apprentice's Focus", .common, symbol: "wand.and.stars",
        text: "+{0%} spell damage.",
        values: [rv(0.08, 0.05)],
        effects: [inc(.spellDamage, 0.08, 0.05)]
    )

    static let emberCharm = relic(
        "emberCharm", "Ember Charm", .common, symbol: "flame.fill",
        text: "+{0%} fire damage.",
        values: [rv(0.1, 0.06)],
        effects: [inc(.fireDamage, 0.1, 0.06)]
    )

    static let frostCharm = relic(
        "frostCharm", "Frost Charm", .common, symbol: "snowflake",
        text: "+{0%} cold damage.",
        values: [rv(0.1, 0.06)],
        effects: [inc(.coldDamage, 0.1, 0.06)]
    )

    static let stormCharm = relic(
        "stormCharm", "Storm Charm", .common, symbol: "bolt.fill",
        text: "+{0%} lightning damage.",
        values: [rv(0.1, 0.06)],
        effects: [inc(.lightningDamage, 0.1, 0.06)]
    )

    static let graveDust = relic(
        "graveDust", "Grave Dust", .common, symbol: "moon.fill",
        text: "+{0%} shadow damage.",
        values: [rv(0.1, 0.06)],
        effects: [inc(.shadowDamage, 0.1, 0.06)]
    )

    static let sunstone = relic(
        "sunstone", "Sunstone", .common, symbol: "sun.max.fill",
        text: "+{0%} holy damage.",
        values: [rv(0.1, 0.06)],
        effects: [inc(.holyDamage, 0.1, 0.06)]
    )

    static let nightshade = relic(
        "nightshade", "Nightshade", .common, symbol: "leaf.fill",
        text: "+{0%} poison damage.",
        values: [rv(0.1, 0.06)],
        effects: [inc(.poisonDamage, 0.1, 0.06)]
    )

    static let all: [RelicDefinition] = [
        whetstone, stridingBoots, ironRing, mendingKnot, heartyTonic, luckyCoin, loadstone, swiftQuiver,
        fletching, sharpEye, soldiersSigil, archersGlove, apprenticesFocus,
        emberCharm, frostCharm, stormCharm, graveDust, sunstone, nightshade,
    ]
}
