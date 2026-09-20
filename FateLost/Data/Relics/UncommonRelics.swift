import Foundation

/// Uncommon relics: the first ones that change what an attack does rather
/// than how big its number is.
enum UncommonRelics: RelicContent {
    static let vampiricFang = relic(
        "vampiricFang", "Vampiric Fang", .uncommon, symbol: "cross.vial.fill",
        text: "You heal for {0%} of the damage you deal.",
        values: [rv(0.012, 0.008)],
        effects: [flat(.lifeSteal, 0.012, 0.008)]
    )

    static let duelistsGlove = relic(
        "duelistsGlove", "Duelist's Glove", .uncommon, symbol: "target",
        text: "+{0%} critical damage.",
        values: [rv(0.2, 0.12)],
        effects: [flat(.critDamage, 0.2, 0.12)]
    )

    static let cleaversGrip = relic(
        "cleaversGrip", "Cleaver's Grip", .uncommon, symbol: "arrow.left.and.right",
        text: "Melee arcs are {0} degrees wider. Ranged attacks burst where they land.",
        values: [rv(20, 12)],
        effects: [.weapon(.cleave(rv(20, 12)))]
    )

    static let longreach = relic(
        "longreach", "Longreach", .uncommon, symbol: "arrow.up.left.and.arrow.down.right",
        text: "+{0%} weapon reach.",
        values: [rv(0.1, 0.06)],
        effects: [.weapon(.reach(rv(0.1, 0.06)))]
    )

    static let echoStone = relic(
        "echoStone", "Echo Stone", .uncommon, symbol: "arrow.triangle.2.circlepath",
        text: "{0%} chance for an attack to be followed at once by another.",
        values: [rv(0.08, 0.05)],
        effects: [.weapon(.multistrike(rv(0.08, 0.05)))]
    )

    static let ashenBlade = relic(
        "ashenBlade", "Ashen Blade", .uncommon, symbol: "flame",
        text: "Weapon attacks deal {0%} of their damage again as fire.",
        values: [rv(0.1, 0.06)],
        effects: [.weapon(.addedDamage(.fire, rv(0.1, 0.06)))]
    )

    static let rimedBlade = relic(
        "rimedBlade", "Rimed Blade", .uncommon, symbol: "snowflake.circle",
        text: "Weapon attacks deal {0%} of their damage again as cold.",
        values: [rv(0.1, 0.06)],
        effects: [.weapon(.addedDamage(.cold, rv(0.1, 0.06)))]
    )

    static let stormForged = relic(
        "stormForged", "Storm-Forged", .uncommon, symbol: "bolt.circle",
        text: "Weapon attacks deal {0%} of their damage again as lightning.",
        values: [rv(0.1, 0.06)],
        effects: [.weapon(.addedDamage(.lightning, rv(0.1, 0.06)))]
    )

    static let thornmail = relic(
        "thornmail", "Thornmail", .uncommon, symbol: "burst.fill",
        text: "When struck, lash out around you for {0%} power.",
        values: [rv(1.2, 0.5)],
        effects: [proc(.hurt, cooldown: 1,
                       nova(rv(1.8), dmg(1.2, 0.5, .physical, [.melee, .area], knockback: 1), .physical))]
    )

    static let bloodletter = relic(
        "bloodletter", "Bloodletter's Knife", .uncommon, symbol: "drop.fill",
        text: "{0%} chance on hit to make the target bleed.",
        values: [rv(0.15, 0.08)],
        effects: [.inflict(.any, status(.bleed, chance: rv(0.15, 0.08), duration: rv(3)))]
    )

    static let venomVial = relic(
        "venomVial", "Venom Vial", .uncommon, symbol: "testtube.2",
        text: "{0%} chance on hit to poison the target.",
        values: [rv(0.15, 0.08)],
        effects: [.inflict(.any, status(.poison, chance: rv(0.15, 0.08), duration: rv(4)))]
    )

    static let frostbittenAmulet = relic(
        "frostbittenAmulet", "Frostbitten Amulet", .uncommon, symbol: "thermometer.snowflake",
        text: "{0%} chance on hit to chill the target.",
        values: [rv(0.15, 0.08)],
        effects: [.inflict(.any, status(.chill, chance: rv(0.15, 0.08), potency: rv(0.25), duration: rv(2.5)))]
    )

    static let featherfallCloak = relic(
        "featherfallCloak", "Featherfall Cloak", .uncommon, symbol: "wind.snow",
        text: "+{0%} dodge chance.",
        values: [rv(0.04, 0.02)],
        effects: [flat(.dodgeChance, 0.04, 0.02)]
    )

    static let berserkersHorn = relic(
        "berserkersHorn", "Berserker's Horn", .uncommon, symbol: "speaker.wave.3.fill",
        text: "While three or more enemies press in: +{0%} damage.",
        values: [rv(0.12, 0.06)],
        effects: [whileIn(.surrounded(3), .damage, .increased, 0.12, 0.06)]
    )

    static let executionersHood = relic(
        "executionersHood", "Executioner's Hood", .uncommon, symbol: "eye.slash.fill",
        text: "+{0%} damage against enemies suffering any affliction.",
        values: [rv(0.1, 0.06)],
        effects: [.damageAgainst(.afflicted, rv(0.1, 0.06))]
    )

    static let runnersCharm = relic(
        "runnersCharm", "Runner's Charm", .uncommon, symbol: "hare.fill",
        text: "While moving: +{0%} damage.",
        values: [rv(0.1, 0.06)],
        effects: [whileIn(.moving, .damage, .increased, 0.1, 0.06)]
    )

    static let sentinelsSeal = relic(
        "sentinelsSeal", "Sentinel's Seal", .uncommon, symbol: "tortoise.fill",
        text: "While standing still: +{0} armour.",
        values: [rv(15, 8)],
        effects: [whileIn(.stationary, .armor, .flat, 15, 8)]
    )

    static let sextonsBell = relic(
        "sextonsBell", "Sexton's Bell", .uncommon, symbol: "bell.fill",
        text: "Each kill heals you for {0%} of your max health.",
        values: [rv(0.004, 0.002)],
        effects: [proc(.kill(killedBy: nil), cooldown: 0.5, .heal(rv(0.004, 0.002)))]
    )

    static let tinkersLoop = relic(
        "tinkersLoop", "Tinker's Loop", .uncommon, symbol: "circle.dashed",
        text: "+{0%} area size.",
        values: [rv(0.1, 0.06)],
        effects: [inc(.areaSize, 0.1, 0.06)]
    )

    static let all: [RelicDefinition] = [
        vampiricFang, duelistsGlove, cleaversGrip, longreach, echoStone, ashenBlade, rimedBlade, stormForged,
        thornmail, bloodletter, venomVial, frostbittenAmulet, featherfallCloak, berserkersHorn,
        executionersHood, runnersCharm, sentinelsSeal, sextonsBell, tinkersLoop,
    ]
}
