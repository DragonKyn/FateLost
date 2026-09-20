import Foundation

// The eight orders. Each is five nodes: two ways in, one that needs either,
// one that needs that, and a capstone. Nothing here is reachable without
// points in two archetypes, which is the whole point of the board.

/// Spellblade: a warrior who learned enough to make the steel answer.
enum SpellbladeSkills: OrderContent {
    static let order = HybridID.spellblade

    static let arcaneEdge = node(
        "arcaneEdge", "Arcane Edge", tier: .two, ranks: 3, kind: .passive, symbol: "sparkle",
        text: "Your weapon carries arcana: +{0%} of its damage again as arcane.",
        values: [rv(0.15, 0.06)],
        effects: [.weapon(.addedDamage(.arcane, rv(0.15, 0.06)))]
    )

    static let spellHone = node(
        "spellHone", "Spell Hone", tier: .two, ranks: 3, kind: .passive, symbol: "timer",
        text: "+{0%} attack speed and +{1%} arcane damage.",
        values: [rv(0.05, 0.03), rv(0.1, 0.05)],
        effects: [inc(.attackSpeed, 0.05, 0.03), inc(.arcaneDamage, 0.1, 0.05)]
    )

    static let arcCut = node(
        "arcCut", "Arc Cut", tier: .three, ranks: 3, kind: .proc, symbol: "scissors",
        text: "Every 3rd attack tears an arcane cut through everything in front of you for {0%} power.",
        values: [rv(1.8, 0.5)],
        effects: [proc(.everyNthAttack(3),
                       nova(rv(2.4, 0.2), dmg(1.8, 0.5, .arcane, [.melee, .area], knockback: 0.8), .arcane))],
        requires: ["arcaneEdge", "spellHone"]
    )

    static let bladesong = node(
        "bladesong", "Bladesong", tier: .four, ranks: 3, kind: .ultimate, symbol: "waveform.path",
        text: "For {0} s your blade sings: +40% attack speed, and every swing throws arcane edges.",
        values: [rv(8, 1)],
        effects: [orderAbility("bladesong", "Bladesong", symbol: "waveform.path", cooldown: rv(48, -3),
                               ultimate: true,
                               .all([buff("bladesong", [mod(.attackSpeed, .increased, 0.4),
                                                        mod(.arcaneDamage, .increased, 0.3)],
                                          duration: rv(8, 1)),
                                     nova(rv(3), dmg(1.6, 0.4, .arcane, [.spell, .area, .ability]), .arcane)]))],
        requires: ["arcCut"]
    )

    static let runeboundSteel = node(
        "runeboundSteel", "Runebound Steel", tier: .capstone, ranks: 1, kind: .passive, symbol: "wand.and.rays",
        text: "Every weapon attack looses an arcane bolt of its own.",
        effects: [proc(.attack, .volley(VolleySpec(count: 1, pattern: .aimed(spreadDegrees: 0),
                                                   damage: dmg(1.1, 0, .arcane, [.spell, .projectile]),
                                                   speed: 15, pierce: 1, size: 0.4, range: 8,
                                                   sprite: .projectileArcaneBolt, visual: .arcane)))],
        requires: ["bladesong"]
    )

    static let skills = [arcaneEdge, spellHone, arcCut, bladesong, runeboundSteel]
}

/// Hexblade: a rogue who signed something, and now every cut collects.
enum HexbladeSkills: OrderContent {
    static let order = HybridID.hexblade

    static let hexedEdge = node(
        "hexedEdge", "Hexed Edge", tier: .two, ranks: 3, kind: .proc, symbol: "moon.fill",
        text: "{0%} chance on hit to curse the target for {1} s.",
        values: [rv(0.18, 0.07), rv(4, 0.5)],
        effects: [.inflict(.any, status(.curse, chance: rv(0.18, 0.07), duration: rv(4, 0.5)))]
    )

    static let soulTithe = node(
        "soulTithe", "Soul Tithe", tier: .two, ranks: 3, kind: .passive, symbol: "drop.fill",
        text: "+{0%} life steal and +{1%} shadow damage.",
        values: [rv(0.03, 0.015), rv(0.12, 0.06)],
        effects: [flat(.lifeSteal, 0.03, 0.015), inc(.shadowDamage, 0.12, 0.06)]
    )

    static let witheringMark = node(
        "witheringMark", "Withering Mark", tier: .three, ranks: 3, kind: .passive, symbol: "target",
        text: "+{0%} damage against cursed enemies.",
        values: [rv(0.2, 0.08)],
        effects: [.damageAgainst(.status(.curse), rv(0.2, 0.08))],
        requires: ["hexedEdge", "soulTithe"]
    )

    static let nightfall = node(
        "nightfall", "Nightfall", tier: .four, ranks: 3, kind: .ultimate, symbol: "moon.stars.fill",
        text: "Night falls for {0} s: everything inside is cursed and takes {1%} power a tick.",
        values: [rv(7, 1), rv(0.7, 0.2)],
        effects: [orderAbility("nightfall", "Nightfall", symbol: "moon.stars.fill", cooldown: rv(55, -4),
                               ultimate: true,
                               .zone(zone(rv(4, 0.3), duration: rv(7, 1), tick: 0.5,
                                          dmg(0.7, 0.2, .shadow, [.spell, .area, .ability]),
                                          status: status(.curse, duration: rv(3)), follows: true, .shadow)))],
        requires: ["witheringMark"]
    )

    static let debtCollector = node(
        "debtCollector", "Debt Collector", tier: .capstone, ranks: 1, kind: .passive, symbol: "hourglass",
        text: "Killing a cursed enemy heals you for 4% of your health and takes 1 s off your cooldowns.",
        effects: [proc(.kill(killedBy: nil), cooldown: 0.2, target: .status(.curse),
                       .all([.heal(rv(0.04)), .reduceCooldowns(rv(1))]))],
        requires: ["nightfall"]
    )

    static let skills = [hexedEdge, soulTithe, witheringMark, nightfall, debtCollector]
}

/// Deathknight: plate, a pact, and a retinue that cannot refuse.
enum DeathknightSkills: OrderContent {
    static let order = HybridID.deathknight

    static let unholyPlate = node(
        "unholyPlate", "Unholy Plate", tier: .two, ranks: 3, kind: .passive, symbol: "shield.lefthalf.filled",
        text: "+{0} armour, +{1%} max health and +{2%} shadow damage.",
        values: [rv(10, 6), rv(0.05, 0.03), rv(0.1, 0.05)],
        effects: [flat(.armor, 10, 6), inc(.maxHealth, 0.05, 0.03), inc(.shadowDamage, 0.1, 0.05)]
    )

    static let graveBound = node(
        "graveBound", "Grave Bound", tier: .two, ranks: 3, kind: .passive, symbol: "person.2.fill",
        text: "+{0%} companion damage, and you keep {1%} of what they deal.",
        values: [rv(0.15, 0.07), rv(0.02, 0.01)],
        effects: [inc(.summonDamage, 0.15, 0.07), flat(.summonLifeSteal, 0.02, 0.01)]
    )

    static let raiseTheFallen = node(
        "raiseTheFallen", "Raise the Fallen", tier: .three, ranks: 3, kind: .proc, symbol: "figure.stand",
        text: "{0%} chance on a kill to raise the body for 14 s.",
        values: [rv(0.12, 0.06)],
        effects: [proc(.kill(killedBy: nil), chance: rv(0.12, 0.06), cooldown: 1,
                       .summon(SummonCatalog.with(SummonCatalog.skeleton, count: 1, duration: 14)))],
        requires: ["unholyPlate", "graveBound"]
    )

    static let deathPact = node(
        "deathPact", "Death Pact", tier: .four, ranks: 3, kind: .ultimate, symbol: "figure.walk.motion",
        text: "Call a bone colossus for {0} s, and everything near you recoils.",
        values: [rv(22, 4)],
        effects: [orderAbility("deathPact", "Death Pact", symbol: "figure.walk.motion", cooldown: rv(75, -5),
                               ultimate: true,
                               .all([.summon(SummonCatalog.with(SummonCatalog.boneColossus, count: 1,
                                                                duration: rv(22, 4))),
                                     nova(rv(3), dmg(1.4, 0.4, .shadow, [.spell, .area, .ability],
                                                     knockback: 2), .shadow)]))],
        requires: ["raiseTheFallen"]
    )

    static let theColdBelow = node(
        "theColdBelow", "The Cold Below", tier: .capstone, ranks: 1, kind: .aura, symbol: "snowflake.circle.fill",
        text: "The ground around you is a grave: enemies near you are weakened by 20%.",
        effects: [.aura(zone(rv(3.2), duration: 0, tick: 0.5, nil,
                             status: status(.weaken, potency: rv(0.2), duration: 1), follows: true, .shadow)),
                  flat(.summonLifeSteal, 0.03)],
        requires: ["deathPact"]
    )

    static let skills = [unholyPlate, graveBound, raiseTheFallen, deathPact, theColdBelow]
}

/// Stormcaller: a druid who stopped asking the weather politely.
enum StormcallerSkills: OrderContent {
    static let order = HybridID.stormcaller

    static let chargedGrowth = node(
        "chargedGrowth", "Charged Growth", tier: .two, ranks: 3, kind: .passive, symbol: "bolt.circle.fill",
        text: "+{0%} lightning damage and +{1} chain jump.",
        values: [rv(0.12, 0.06), rv(1, 0)],
        effects: [inc(.lightningDamage, 0.12, 0.06), flat(.chainJumps, 1, 0)]
    )

    static let staticField = node(
        "staticField", "Static Field", tier: .two, ranks: 3, kind: .proc, symbol: "bolt.horizontal.fill",
        text: "Every 4 s a charge jumps between nearby enemies for {0%} power.",
        values: [rv(1.2, 0.4)],
        effects: [proc(.interval(4),
                       .chain(ChainSpec(jumps: 3, damage: dmg(1.2, 0.4, .lightning, [.spell]),
                                        visual: .lightning)))]
    )

    static let thunderhead = node(
        "thunderhead", "Thunderhead", tier: .three, ranks: 3, kind: .passive, symbol: "cloud.bolt.fill",
        text: "+{0%} chance to inflict statuses and +{1%} damage against shocked enemies.",
        values: [rv(0.15, 0.07), rv(0.18, 0.07)],
        effects: [inc(.statusChance, 0.15, 0.07), .damageAgainst(.status(.shock), rv(0.18, 0.07))],
        requires: ["chargedGrowth", "staticField"]
    )

    static let theStorm = node(
        "theStorm", "The Storm", tier: .four, ranks: 3, kind: .ultimate, symbol: "cloud.bolt.rain.fill",
        text: "{0} strikes fall around you for {1%} power each, shocking what they hit.",
        values: [rv(14, 3), rv(1.6, 0.4)],
        effects: [orderAbility("theStorm", "The Storm", symbol: "cloud.bolt.rain.fill", cooldown: rv(60, -4),
                               ultimate: true,
                               .strikes(StrikeSpec(count: rv(14, 3), radius: rv(1.4), scatter: 5, delay: 0.35,
                                                   damage: dmg(1.6, 0.4, .lightning, [.spell, .area, .ability]),
                                                   status: status(.shock, duration: rv(3)), visual: .lightning)))],
        requires: ["thunderhead"]
    )

    static let eyeOfTheStorm = node(
        "eyeOfTheStorm", "Eye of the Storm", tier: .capstone, ranks: 1, kind: .aura, symbol: "tornado",
        text: "The storm follows you: everything close is shocked, and takes lightning for it.",
        effects: [.aura(zone(rv(3), duration: 0, tick: 0.6,
                             dmg(0.5, 0, .lightning, [.spell, .area]),
                             status: status(.shock, chance: rv(0.35), duration: rv(2)),
                             follows: true, .lightning))],
        requires: ["theStorm"]
    )

    static let skills = [chargedGrowth, staticField, thunderhead, theStorm, eyeOfTheStorm]
}

/// Warden: a ranger the wood started answering back to.
enum WardenSkills: OrderContent {
    static let order = HybridID.warden

    static let thornArrows = node(
        "thornArrows", "Thorn Arrows", tier: .two, ranks: 3, kind: .passive, symbol: "leaf.arrow.circlepath",
        text: "+{0%} of your weapon damage again as poison, and your attacks reach further.",
        values: [rv(0.14, 0.06)],
        effects: [.weapon(.addedDamage(.poison, rv(0.14, 0.06))), .weapon(.pierce(rv(1, 0)))]
    )

    static let wildBond = node(
        "wildBond", "Wild Bond", tier: .two, ranks: 3, kind: .passive, symbol: "pawprint.fill",
        text: "+{0%} companion damage and +{1%} effect duration.",
        values: [rv(0.16, 0.07), rv(0.1, 0.05)],
        effects: [inc(.summonDamage, 0.16, 0.07), inc(.effectDuration, 0.1, 0.05)]
    )

    static let brambleWard = node(
        "brambleWard", "Bramble Ward", tier: .three, ranks: 3, kind: .aura, symbol: "circle.hexagonpath.fill",
        text: "Thorns close around you: {0%} power a tick, and what they catch is slowed.",
        values: [rv(0.5, 0.2)],
        effects: [.aura(zone(rv(2.6, 0.2), duration: 0, tick: 0.5,
                             dmg(0.5, 0.2, .poison, [.spell, .area]),
                             status: status(.chill, chance: rv(0.4), potency: rv(0.25), duration: rv(1.5)),
                             follows: true, .nature))],
        requires: ["thornArrows", "wildBond"]
    )

    static let callTheWood = node(
        "callTheWood", "Call the Wood", tier: .four, ranks: 3, kind: .ultimate, symbol: "tree.fill",
        text: "A treant answers for {0} s, and roots everything around it.",
        values: [rv(20, 4)],
        effects: [orderAbility("callTheWood", "Call the Wood", symbol: "tree.fill", cooldown: rv(70, -5),
                               ultimate: true,
                               .all([.summon(SummonCatalog.with(SummonCatalog.treant, count: 1,
                                                                duration: rv(20, 4))),
                                     .afflict(status(.root, duration: rv(2, 0.3)), radius: rv(3.5))]))],
        requires: ["brambleWard"]
    )

    static let wardenOfTheDeepWood = node(
        "wardenOfTheDeepWood", "Warden of the Deep Wood", tier: .capstone, ranks: 1, kind: .passive,
        symbol: "leaf.fill",
        text: "Each kill mends you for 2% of your health, and your companions hit 25% harder.",
        effects: [proc(.kill(killedBy: nil), cooldown: 0.1, .heal(rv(0.02))),
                  inc(.summonDamage, 0.25, 0)],
        requires: ["callTheWood"]
    )

    static let skills = [thornArrows, wildBond, brambleWard, callTheWood, wardenOfTheDeepWood]
}

/// Inquisitor: a paladin who stopped announcing himself first.
enum InquisitorSkills: OrderContent {
    static let order = HybridID.inquisitor

    static let quietOath = node(
        "quietOath", "Quiet Oath", tier: .two, ranks: 3, kind: .passive, symbol: "figure.walk",
        text: "+{0%} movement speed and +{1%} holy damage.",
        values: [rv(0.04, 0.02), rv(0.12, 0.06)],
        effects: [inc(.moveSpeed, 0.04, 0.02), inc(.holyDamage, 0.12, 0.06)]
    )

    static let judgement = node(
        "judgement", "Judgement", tier: .two, ranks: 3, kind: .passive, symbol: "scalemass.fill",
        text: "+{0%} critical chance against anything already suffering, and +{1%} critical damage.",
        values: [rv(0.08, 0.04), rv(0.15, 0.07)],
        effects: [.critChanceAgainst(.afflicted, rv(0.08, 0.04)), flat(.critDamage, 0.15, 0.07)]
    )

    static let sentence = node(
        "sentence", "Sentence", tier: .three, ranks: 3, kind: .proc, symbol: "bolt.fill",
        text: "Critical hits call down light for {0%} power.",
        values: [rv(1.8, 0.5)],
        effects: [proc(.criticalHit, cooldown: 0.4,
                       nova(rv(1.6), dmg(1.8, 0.5, .holy, [.spell, .area]), at: .origin, .holy))],
        requires: ["quietOath", "judgement"]
    )

    static let finalVerdict = node(
        "finalVerdict", "Final Verdict", tier: .four, ranks: 3, kind: .ultimate, symbol: "hammer.fill",
        text: "{0} pillars of light fall on the guilty for {1%} power each.",
        values: [rv(10, 2), rv(2.4, 0.6)],
        effects: [orderAbility("finalVerdict", "Final Verdict", symbol: "hammer.fill", cooldown: rv(58, -4),
                               ultimate: true,
                               .strikes(StrikeSpec(count: rv(10, 2), radius: rv(1.6), scatter: 4.5, delay: 0.5,
                                                   damage: dmg(2.4, 0.6, .holy, [.spell, .area, .ability]),
                                                   status: status(.mark, duration: rv(4)), visual: .holy)))],
        requires: ["sentence"]
    )

    static let nothingIsHidden = node(
        "nothingIsHidden", "Nothing Is Hidden", tier: .capstone, ranks: 1, kind: .passive,
        symbol: "eye.trianglebadge.exclamationmark.fill",
        text: "Your hits mark what they land on, and you deal 25% more to anything marked.",
        effects: [.inflict(.any, status(.mark, chance: rv(0.5), duration: rv(4))),
                  .damageAgainst(.status(.mark), rv(0.25))],
        requires: ["finalVerdict"]
    )

    static let skills = [quietOath, judgement, sentence, finalVerdict, nothingIsHidden]
}

/// Skirmisher: a monk who took up the hunt, and never stands still.
enum SkirmisherSkills: OrderContent {
    static let order = HybridID.skirmisher

    static let footwork = node(
        "footwork", "Footwork", tier: .two, ranks: 3, kind: .passive, symbol: "shoe.fill",
        text: "+{0%} dodge chance and +{1%} movement speed.",
        values: [rv(0.03, 0.015), rv(0.05, 0.025)],
        effects: [flat(.dodgeChance, 0.03, 0.015), inc(.moveSpeed, 0.05, 0.025)]
    )

    static let harrier = node(
        "harrier", "Harrier", tier: .two, ranks: 3, kind: .passive, symbol: "arrow.left.and.right",
        text: "While moving: +{0%} damage and +{1%} attack speed.",
        values: [rv(0.1, 0.05), rv(0.06, 0.03)],
        effects: [whileIn(.moving, .damage, .increased, 0.1, 0.05),
                  whileIn(.moving, .attackSpeed, .increased, 0.06, 0.03)]
    )

    static let bladeDance = node(
        "bladeDance", "Blade Dance", tier: .three, ranks: 3, kind: .proc, symbol: "figure.martial.arts",
        text: "Every dodge answers with a sweep for {0%} power.",
        values: [rv(1.6, 0.5)],
        effects: [proc(.dodge, cooldown: 0.3,
                       nova(rv(2.2), dmg(1.6, 0.5, .physical, [.melee, .area], knockback: 1), .physical))],
        requires: ["footwork", "harrier"]
    )

    static let windRun = node(
        "windRun", "Wind Run", tier: .four, ranks: 3, kind: .ultimate, symbol: "wind",
        text: "Run the line: dash {0} units through everything, untouchable, then move 40% faster for 6 s.",
        values: [rv(7, 1)],
        effects: [orderAbility("windRun", "Wind Run", symbol: "wind", cooldown: rv(45, -3), ultimate: true,
                               .all([.dash(DashSpec(distance: rv(7, 1),
                                                    damage: dmg(2.2, 0.6, .physical, [.melee, .ability],
                                                                knockback: 1.4),
                                                    invulnerability: 0.8, visual: .physical)),
                                     buff("windRun", [mod(.moveSpeed, .increased, 0.4)], duration: rv(6))]))],
        requires: ["bladeDance"]
    )

    static let untouchable = node(
        "untouchable", "Untouchable", tier: .capstone, ranks: 1, kind: .passive, symbol: "figure.run",
        text: "For 3 s after a dodge you take 30% less and move 20% faster.",
        effects: [whileIn(.recentDodge(3), .armor, .flat, 40, 0),
                  whileIn(.recentDodge(3), .moveSpeed, .increased, 0.2, 0)],
        requires: ["windRun"]
    )

    static let skills = [footwork, harrier, bladeDance, windRun, untouchable]
}

/// Warchanter: a bard who took the front rank on purpose.
enum WarchanterSkills: OrderContent {
    static let order = HybridID.warchanter

    static let marchingSong = node(
        "marchingSong", "Marching Song", tier: .two, ranks: 3, kind: .passive, symbol: "music.note",
        text: "+{0%} attack speed and +{1%} movement speed.",
        values: [rv(0.05, 0.025), rv(0.04, 0.02)],
        effects: [inc(.attackSpeed, 0.05, 0.025), inc(.moveSpeed, 0.04, 0.02)]
    )

    static let ironRefrain = node(
        "ironRefrain", "Iron Refrain", tier: .two, ranks: 3, kind: .passive, symbol: "shield.fill",
        text: "+{0} armour and +{1%} companion damage.",
        values: [rv(8, 5), rv(0.14, 0.06)],
        effects: [flat(.armor, 8, 5), inc(.summonDamage, 0.14, 0.06)]
    )

    static let warCry = node(
        "warCry", "War Cry", tier: .three, ranks: 3, kind: .active, symbol: "megaphone.fill",
        text: "A shout that frightens everything near you and gives you {0%} damage for 8 s.",
        values: [rv(0.2, 0.08)],
        effects: [orderAbility("warCry", "War Cry", symbol: "megaphone.fill", cooldown: rv(16, -1),
                               .all([.afflict(status(.fear, duration: rv(2, 0.3)), radius: rv(3.2)),
                                     buff("warCry", [mod(.damage, .increased, 0.2, 0.08)], duration: rv(8))]))],
        requires: ["marchingSong", "ironRefrain"]
    )

    static let anthem = node(
        "anthem", "Anthem", tier: .four, ranks: 3, kind: .ultimate, symbol: "music.note.list",
        text: "Hold the line for {0} s: inside the anthem you gain 30% damage, 30% speed and 30 armour.",
        values: [rv(10, 1.5)],
        effects: [orderAbility("anthem", "Anthem", symbol: "music.note.list", cooldown: rv(65, -5),
                               ultimate: true,
                               .zone(zone(rv(3.6), duration: rv(10, 1.5), tick: 0.5,
                                          dmg(0.5, 0.2, .sonic, [.spell, .area, .ability]),
                                          buff: [mod(.damage, .increased, 0.3),
                                                 mod(.attackSpeed, .increased, 0.3),
                                                 mod(.armor, .flat, 30)],
                                          follows: true, .sonic)))],
        requires: ["warCry"]
    )

    static let lastVerse = node(
        "lastVerse", "Last Verse", tier: .capstone, ranks: 1, kind: .passive, symbol: "flame.fill",
        text: "Below half health you deal 30% more and attack 20% faster.",
        effects: [whileIn(.healthBelow(0.5), .damage, .increased, 0.3, 0),
                  whileIn(.healthBelow(0.5), .attackSpeed, .increased, 0.2, 0)],
        requires: ["anthem"]
    )

    static let skills = [marchingSong, ironRefrain, warCry, anthem, lastVerse]
}

/// Every order's nodes, in board order.
enum OrderCatalog {
    static let byOrder: [HybridID: [SkillDefinition]] = [
        .spellblade: SpellbladeSkills.skills,
        .hexblade: HexbladeSkills.skills,
        .deathknight: DeathknightSkills.skills,
        .stormcaller: StormcallerSkills.skills,
        .warden: WardenSkills.skills,
        .inquisitor: InquisitorSkills.skills,
        .skirmisher: SkirmisherSkills.skills,
        .warchanter: WarchanterSkills.skills,
    ]

    static let all: [SkillDefinition] = HybridID.allCases.flatMap { byOrder[$0] ?? [] }
}
