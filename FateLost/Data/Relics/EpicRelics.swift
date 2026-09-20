import Foundation

/// Epic relics rewrite a rule for the run, and legendary ones rewrite it
/// again. Both stay tradeoffs or single rules, never bags of numbers.
enum EpicRelics: RelicContent {
    static let phoenixFeather = relic(
        "phoenixFeather", "Phoenix Feather", .epic, symbol: "flame.circle", ranks: 1,
        text: "Once every 150 s, a killing blow is refused and you rise with 40% of your health.",
        effects: [.cheatDeath(CheatDeathSpec(cooldown: 150, restore: 0.4, invulnerability: 2.5, action: nil))]
    )

    static let dragonsTooth = relic(
        "dragonsTooth", "Dragon's Tooth", .epic, symbol: "triangle.fill",
        text: "Every 5th attack detonates around you for {0%} power in fire.",
        values: [rv(2.5, 0.8)],
        effects: [proc(.everyNthAttack(5),
                       nova(rv(2.4), dmg(2.5, 0.8, .fire, [.spell, .area], knockback: 1.5),
                            status: status(.burn, duration: rv(3)), .fire))]
    )

    static let crownOfThorns = relic(
        "crownOfThorns", "Crown of Thorns", .epic, symbol: "crown.fill",
        text: "When struck, holy thorns burst around you for {0%} power.",
        values: [rv(2.2, 0.7)],
        effects: [proc(.hurt, cooldown: 1.5,
                       nova(rv(3), dmg(2.2, 0.7, .holy, [.spell, .area], knockback: 2), .holy))]
    )

    static let stormEngine = relic(
        "stormEngine", "Storm Engine", .epic, symbol: "gearshape.2.fill",
        text: "Every 7 s, {0} bolts fall on the horde for {1%} power each.",
        values: [rv(5, 1), rv(1.8, 0.5)],
        effects: [proc(.interval(7),
                       .strikes(StrikeSpec(count: rv(5, 1), radius: rv(1.3), scatter: 5, delay: 0.4,
                                           damage: dmg(1.8, 0.5, .lightning, [.spell, .area]),
                                           visual: .lightning)))]
    )

    static let phylactery = relic(
        "phylactery", "Necromancer's Phylactery", .epic, symbol: "capsule.fill",
        text: "{0%} chance for a kill to raise the dead for 12 s.",
        values: [rv(0.1, 0.05)],
        effects: [proc(.kill(killedBy: nil), chance: rv(0.1, 0.05), cooldown: 1,
                       .summon(SummonCatalog.with(SummonCatalog.skeleton, count: 1, duration: 12)))]
    )

    static let glassHeart = relic(
        "glassHeart", "Glass Heart", .epic, symbol: "heart.slash.fill",
        text: "{0%} more damage, but 15% less max health.",
        values: [rv(0.2, 0.08)],
        effects: [more(.damage, 0.2, 0.08), inc(.maxHealth, -0.15, 0)]
    )

    static let bloodFrenzy = relic(
        "bloodFrenzy", "Blood Frenzy", .epic, symbol: "bolt.heart.fill",
        text: "Below 40% health: +{0%} damage and +{1%} attack speed.",
        values: [rv(0.25, 0.1), rv(0.15, 0.06)],
        effects: [whileIn(.healthBelow(0.4), .damage, .increased, 0.25, 0.1),
                  whileIn(.healthBelow(0.4), .attackSpeed, .increased, 0.15, 0.06)]
    )

    static let hourglassOfAges = relic(
        "hourglassOfAges", "Hourglass of Ages", .epic, symbol: "hourglass.bottomhalf.filled",
        text: "Cooldowns are {0%} shorter, and every 10 s another {1} s is taken off them.",
        values: [rv(0.06, 0.03), rv(2, 0.5)],
        effects: [flat(.cooldownReduction, 0.06, 0.03), proc(.interval(10), .reduceCooldowns(rv(2, 0.5)))]
    )

    static let all: [RelicDefinition] = [
        phoenixFeather, dragonsTooth, crownOfThorns, stormEngine, phylactery, glassHeart, bloodFrenzy,
        hourglassOfAges,
    ]
}

/// Legendary relics: one rule each, found rarely, and carried for the whole run.
enum LegendaryRelics: RelicContent {
    static let hollowCrown = relic(
        "hollowCrown", "Crown of the Hollow Throne", .legendary, symbol: "crown", ranks: 1,
        text: "+1 projectile, +1 pierce and +1 chain jump on everything you do.",
        effects: [flat(.projectileCount, 1, 0), flat(.pierce, 1, 0), flat(.chainJumps, 1, 0)]
    )

    static let ouroboros = relic(
        "ouroboros", "The Ouroboros", .legendary, symbol: "infinity", ranks: 1,
        text: "You heal for 3% of the damage you deal, +25% healing received, "
            + "and half of any healing beyond full becomes a barrier.",
        effects: [flat(.lifeSteal, 0.03, 0), inc(.healingReceived, 0.25, 0), flat(.overhealBarrier, 0.5, 0)]
    )

    static let lastWord = relic(
        "lastWord", "The Last Word", .legendary, symbol: "quote.closing", ranks: 1,
        text: "20% chance for an ability to be cast again for free, and 12% shorter cooldowns.",
        effects: [flat(.spellEcho, 0.2, 0), flat(.cooldownReduction, 0.12, 0)]
    )

    static let dragonheart = relic(
        "dragonheart", "Dragonheart", .legendary, symbol: "flame.circle.fill", ranks: 1,
        text: "Everything burns: weapon attacks add 30% fire damage, fire deals 25% more, "
            + "and 30% of hits set the target alight.",
        effects: [.weapon(.addedDamage(.fire, rv(0.3))), inc(.fireDamage, 0.25, 0),
                  .inflict(.any, status(.burn, chance: rv(0.3), duration: rv(3)))]
    )

    static let all: [RelicDefinition] = [hollowCrown, ouroboros, lastWord, dragonheart]
}
