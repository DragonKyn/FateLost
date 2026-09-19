import Foundation

/// Ranger: distance, tracking and the wild. Marksmen never miss, Hunters
/// set the ground against their prey, Beastmasters never fight alone.
enum RangerSkills: SkillContent {
    static let archetype = ArchetypeID.ranger

    static let definition = ArchetypeDefinition(
        id: .ranger, name: "Ranger", tagline: "Patience, a keen eye and the wild at your side.",
        symbol: "scope", color: RGBA(hex: 0x5A8A4A),
        paths: [
            PathDefinition(id: pathID("marksman"), name: "Marksman",
                           summary: "Long shots, split arrows and piercing crits."),
            PathDefinition(id: pathID("hunter"), name: "Hunter",
                           summary: "Marks, snares, traps and the thrill of the chase."),
            PathDefinition(id: pathID("beastmaster"), name: "Beastmaster",
                           summary: "Tiger, owl and bear fight at your side."),
        ],
        resonance: [StatModifier(.damage, .increased, 0.01), StatModifier(.moveSpeed, .increased, 0.005)],
        resonanceText: "+1% damage and +0.5% movement speed per point"
    )

    // MARK: Core

    static let arrowStorm = skill(
        "core.arrowStorm", "Arrow Storm", tier: .one, ranks: 5, kind: .active, symbol: "cloud.hail.fill",
        text: "Rain {0} arrows on the thickest crowd, each dealing {1%} power where it lands.",
        values: [rv(10, 2), rv(1.2, 0.25)],
        effects: [ability("arrowStorm", "Arrow Storm", symbol: "cloud.hail.fill", cooldown: rv(12, -0.8),
                          .strikes(StrikeSpec(count: rv(10, 2), radius: rv(0.7), scatter: 2.4, delay: 0.5,
                                              damage: dmg(1.2, 0.25, .physical, [.projectile, .area, .ability]),
                                              visual: .physical)))],
        tags: [.projectile, .area]
    )

    static let steadyAim = skill(
        "core.steadyAim", "Steady Aim", tier: .one, ranks: 5, kind: .passive, symbol: "scope",
        text: "+{0%} damage. Standing still: +{1%} attack speed.",
        values: [rv(0.07, 0.07), rv(0.1, 0.05)],
        effects: [inc(.damage, 0.07), whileIn(.stationary, .attackSpeed, .increased, 0.1, 0.05)]
    )

    static let fieldcraft = skill(
        "core.fieldcraft", "Fieldcraft", tier: .one, ranks: 5, kind: .passive, symbol: "leaf.fill",
        text: "+{0%} movement speed, +{1%} pickup radius and +{2} health per second.",
        values: [rv(0.05, 0.05), rv(0.12, 0.12), rv(0.8, 0.8)],
        effects: [inc(.moveSpeed, 0.05), inc(.pickupRadius, 0.12), flat(.healthRegen, 0.8)]
    )

    // MARK: Marksman

    static let longshot = skill(
        "marksman.longshot", "Longshot", path: "marksman", tier: .two, ranks: 3, kind: .passive,
        symbol: "arrow.up.right",
        text: "+{0%} damage against enemies more than 4 m away, and +{1%} weapon range.",
        values: [rv(0.25, 0.1), rv(0.1, 0.05)],
        effects: [.damageAgainst(.beyond(4), rv(0.25, 0.1)), .weapon(.reach(rv(0.1, 0.05)))]
    )

    static let splitShot = skill(
        "marksman.splitShot", "Split Shot", path: "marksman", tier: .two, ranks: 3, kind: .passive,
        symbol: "arrow.triangle.branch",
        text: "Attacks fire {0} extra projectiles (melee weapons gain a chance to strike again).",
        values: [rv(1, 1)],
        effects: [.weapon(.extraProjectiles(rv(1, 1)))]
    )

    static let deadeye = skill(
        "marksman.deadeye", "Deadeye", path: "marksman", tier: .three, ranks: 3, kind: .passive, symbol: "eye.fill",
        text: "+{0%} critical chance and +{1%} critical damage.",
        values: [rv(0.04, 0.04), rv(0.2, 0.2)],
        effects: [flat(.critChance, 0.04), flat(.critDamage, 0.2)],
        requires: ["marksman.longshot", "marksman.splitShot"]
    )

    static let heartseeker = skill(
        "marksman.heartseeker", "Heartseeker", path: "marksman", tier: .three, ranks: 3, kind: .active,
        symbol: "arrow.forward",
        text: "Loose a great arrow that passes through everything in a line for {0%} power.",
        values: [rv(6, 1.5)],
        effects: [ability("heartseeker", "Heartseeker", symbol: "arrow.forward", cooldown: rv(10, -1),
                          .volley(VolleySpec(count: 1, pattern: .aimed(spreadDegrees: 0),
                                             damage: dmg(6, 1.5, .physical, [.projectile, .ability], knockback: 1.2),
                                             speed: 22, pierce: 99, size: 0.45, range: 14,
                                             sprite: .projectileArrow, visual: .physical)))],
        requires: ["marksman.longshot", "marksman.splitShot"]
    )

    static let hailOfTheHunt = skill(
        "marksman.hailOfTheHunt", "Hail of the Hunt", path: "marksman", tier: .four, ranks: 3, kind: .ultimate,
        symbol: "cloud.bolt.rain.fill",
        text: "Darken the sky: {0} arrows fall all around you for {1%} power each.",
        values: [rv(36, 8), rv(1.5, 0.3)],
        effects: [ability("hailOfTheHunt", "Hail of the Hunt", symbol: "cloud.bolt.rain.fill", cooldown: rv(55, -4),
                          ultimate: true,
                          .strikes(StrikeSpec(count: rv(36, 8), radius: rv(0.8), scatter: 5.5, delay: 0.7,
                                              damage: dmg(1.5, 0.3, .physical, [.projectile, .area, .ability]),
                                              anchor: .player, visual: .physical)))],
        requires: ["marksman.deadeye", "marksman.heartseeker"]
    )

    static let trueShot = skill(
        "marksman.trueShot", "True Shot", path: "marksman", tier: .capstone, ranks: 1, kind: .proc,
        symbol: "scope",
        text: "Every 4th attack also looses a Heartseeker for 400% power that passes through everything.",
        effects: [proc(.everyNthAttack(4), .volley(VolleySpec(count: 1, pattern: .aimed(spreadDegrees: 0),
                                                                damage: dmg(4, 0, .physical, [.projectile], knockback: 1),
                                                                speed: 22, pierce: 99, size: 0.4, range: 14,
                                                                sprite: .projectileArrow, visual: .physical)))],
        requires: ["marksman.hailOfTheHunt"]
    )

    // MARK: Hunter

    static let huntersMark = skill(
        "hunter.huntersMark", "Hunter's Mark", path: "hunter", tier: .two, ranks: 3, kind: .proc, symbol: "target",
        text: "Hits have a {0%} chance to mark their target for 5 s: +25% critical chance against it.",
        values: [rv(0.2, 0.1)],
        effects: [.inflict(.any, status(.mark, chance: rv(0.2, 0.1), potency: 0.25, duration: 5))]
    )

    static let snareTrap = skill(
        "hunter.snareTrap", "Snare Trap", path: "hunter", tier: .two, ranks: 3, kind: .active, symbol: "lasso",
        text: "Spring a snare under the crowd: enemies inside are rooted and take {0%} power every half second for 5 s.",
        values: [rv(0.5, 0.2)],
        effects: [ability("snareTrap", "Snare Trap", symbol: "lasso", cooldown: rv(12, -1),
                          .zone(zone(rv(2.1), duration: 5, tick: 0.5, dmg(0.5, 0.2, .physical, [.area, .ability], knockback: 0),
                                     status: status(.root, duration: 0.8), at: .cluster, .nature)))]
    )

    static let predator = skill(
        "hunter.predator", "Predator", path: "hunter", tier: .three, ranks: 3, kind: .passive,
        symbol: "pawprint.fill",
        text: "+{0%} damage against marked enemies and +{0%} against rooted ones.",
        values: [rv(0.2, 0.1)],
        effects: [.damageAgainst(.status(.mark), rv(0.2, 0.1)), .damageAgainst(.status(.root), rv(0.2, 0.1))],
        requires: ["hunter.huntersMark", "hunter.snareTrap"]
    )

    static let tumble = skill(
        "hunter.tumble", "Tumble", path: "hunter", tier: .three, ranks: 3, kind: .active, symbol: "figure.roll",
        text: "Roll away, gaining +{0%} attack speed for 2 s.",
        values: [rv(0.3, 0.1)],
        effects: [ability("tumble", "Tumble", symbol: "figure.roll", cooldown: rv(6, -0.5),
                          .all([.dash(DashSpec(distance: 3.2, invulnerability: 0.35, visual: .nature)),
                                buff("tumble", [mod(.attackSpeed, .increased, 0.3, 0.1)], duration: 2)]))],
        requires: ["hunter.huntersMark", "hunter.snareTrap"]
    )

    static let blastTrap = skill(
        "hunter.blastTrap", "Blast Traps", path: "hunter", tier: .four, ranks: 3, kind: .proc, symbol: "flame.fill",
        text: "Every 4 s a trap springs under the nearest crowd: {0%} fire power, and survivors burn.",
        values: [rv(4, 1.5)],
        effects: [proc(.interval(4), .strikes(StrikeSpec(count: 1, radius: rv(1.9), scatter: 0, delay: 0.35,
                                                           damage: dmg(4, 1.5, .fire, [.area], knockback: 1.2),
                                                           status: status(.burn, potency: 0.5, duration: 3),
                                                           visual: .fire)))],
        requires: ["hunter.predator", "hunter.tumble"]
    )

    static let apexPredator = skill(
        "hunter.apexPredator", "Apex Predator", path: "hunter", tier: .capstone, ranks: 1, kind: .proc,
        symbol: "crown.fill",
        text: "Killing a marked enemy marks everything around it and quickens you: +25% attack speed for 3 s.",
        effects: [proc(.kill(killedBy: nil), target: .status(.mark),
                       .all([.afflict(status(.mark, potency: 0.25, duration: 5), radius: 3),
                             buff("apex", [mod(.attackSpeed, .increased, 0.25)], duration: 3)]))],
        requires: ["hunter.blastTrap"]
    )

    // MARK: Beastmaster

    static let callTiger = skill(
        "beastmaster.tiger", "Call the Tiger", path: "beastmaster", tier: .two, ranks: 3, kind: .summon,
        symbol: "pawprint.fill",
        text: "A tiger fights beside you: fast, savage bites for {0%} power.",
        values: [rv(1.0, 0.35)],
        effects: [.companion(SummonCatalog.tiger)]
    )

    static let callOwl = skill(
        "beastmaster.owl", "Call the Owl", path: "beastmaster", tier: .two, ranks: 3, kind: .summon,
        symbol: "bird.fill",
        text: "An owl circles overhead casting arcane feathers for {0%} power. +{1%} cooldown reduction.",
        values: [rv(0.8, 0.3), rv(0.05, 0.03)],
        effects: [.companion(SummonCatalog.owl), flat(.cooldownReduction, 0.05, 0.03)]
    )

    static let callBear = skill(
        "beastmaster.bear", "Call the Bear", path: "beastmaster", tier: .three, ranks: 3, kind: .summon,
        symbol: "pawprint.circle.fill",
        text: "A bear lumbers beside you, drawing enemies to itself and mauling them for {0%} power.",
        values: [rv(1.5, 0.5)],
        effects: [.companion(SummonCatalog.bear)],
        requires: ["beastmaster.tiger", "beastmaster.owl"]
    )

    static let packBond = skill(
        "beastmaster.packBond", "Pack Bond", path: "beastmaster", tier: .three, ranks: 3, kind: .passive,
        symbol: "link",
        text: "+{0%} summon damage and +{1%} movement speed.",
        values: [rv(0.2, 0.1), rv(0.04, 0.02)],
        effects: [inc(.summonDamage, 0.2, 0.1), inc(.moveSpeed, 0.04, 0.02)],
        requires: ["beastmaster.tiger", "beastmaster.owl"]
    )

    static let stampede = skill(
        "beastmaster.stampede", "Stampede", path: "beastmaster", tier: .four, ranks: 3, kind: .ultimate,
        symbol: "hare.fill",
        text: "Summon {0} spirit beasts for {1} s.",
        values: [rv(5, 1), rv(7, 1)],
        effects: [ability("stampede", "Stampede", symbol: "hare.fill", cooldown: rv(50, -4), ultimate: true,
                          .summon(SummonCatalog.with(SummonCatalog.spiritWolf, count: rv(5, 1), duration: rv(7, 1))))],
        requires: ["beastmaster.bear", "beastmaster.packBond"]
    )

    static let alphasCall = skill(
        "beastmaster.alpha", "Alpha's Call", path: "beastmaster", tier: .capstone, ranks: 1, kind: .passive,
        symbol: "crown.fill",
        text: "40% more summon damage, and your beasts' hits mark their prey.",
        effects: [more(.summonDamage, 0.4, 0),
                  .inflict(HitFilter(tags: .summon), status(.mark, chance: 0.3, potency: 0.25, duration: 4))],
        requires: ["beastmaster.stampede"]
    )

    static let skills: [SkillDefinition] = [
        arrowStorm, steadyAim, fieldcraft,
        longshot, splitShot, deadeye, heartseeker, hailOfTheHunt, trueShot,
        huntersMark, snareTrap, predator, tumble, blastTrap, apexPredator,
        callTiger, callOwl, callBear, packBond, stampede, alphasCall,
    ]
}
