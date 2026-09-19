import Foundation

/// Paladin: armoured holy steel. Templars cannot be moved, Justicars pass
/// sentence, Crusaders charge headlong into the dark.
enum PaladinSkills: SkillContent {
    static let archetype = ArchetypeID.paladin

    static let definition = ArchetypeDefinition(
        id: .paladin, name: "Paladin", tagline: "An oath, a hammer, and light that answers both.",
        symbol: "cross.fill", color: RGBA(hex: 0xD8C890),
        paths: [
            PathDefinition(id: pathID("templar"), name: "Templar",
                           summary: "Auras, vengeful plate and unshakeable faith."),
            PathDefinition(id: pathID("justicar"), name: "Justicar",
                           summary: "Blessed steel, verdicts and the hammer of dawn."),
            PathDefinition(id: pathID("crusader"), name: "Crusader",
                           summary: "Charges, holy fire and a crusade that never stops."),
        ],
        resonance: [StatModifier(.armor, .flat, 1), StatModifier(.holyDamage, .increased, 0.012)],
        resonanceText: "+1 armour and +1.2% holy damage per point"
    )

    // MARK: Core

    static let hallowedStorm = skill(
        "core.hallowedStorm", "Hallowed Storm", tier: .one, ranks: 5, kind: .active, symbol: "tornado",
        text: "Whirl with holy force: {0%} holy power around you, and heal {1%} of your max health.",
        values: [rv(2.2, 0.5), rv(0.03, 0.01)],
        effects: [ability("hallowedStorm", "Hallowed Storm", symbol: "tornado", cooldown: rv(9, -0.5),
                          .all([nova(rv(2.8), dmg(2.2, 0.5, .holy, [.melee, .area, .ability], knockback: 1.2), .holy),
                                .heal(rv(0.03, 0.01))]))],
        tags: [.holy, .melee]
    )

    static let smite = skill(
        "core.smite", "Smite", tier: .one, ranks: 5, kind: .proc, symbol: "bolt.fill",
        text: "Every 4th attack calls a smite down on the target for {0%} holy power.",
        values: [rv(2, 0.5)],
        effects: [proc(.everyNthAttack(4), nova(rv(1.2), dmg(2, 0.5, .holy, [.spell, .area], knockback: 0.6),
                                                at: .origin, .holy))]
    )

    static let consecratedPlate = skill(
        "core.consecratedPlate", "Consecrated Plate", tier: .one, ranks: 5, kind: .passive, symbol: "shield.fill",
        text: "+{0} armour, +{1%} max health and +{2} health per second.",
        values: [rv(8, 8), rv(0.04, 0.04), rv(1, 1)],
        effects: [flat(.armor, 8), inc(.maxHealth, 0.04), flat(.healthRegen, 1)]
    )

    // MARK: Templar

    static let auraOfResolve = skill(
        "templar.auraOfResolve", "Aura of Resolve", path: "templar", tier: .two, ranks: 3, kind: .aura,
        symbol: "circle.circle.fill",
        text: "Enemies near you are weakened by {0%}.",
        values: [rv(0.15, 0.05)],
        effects: [.aura(zone(rv(2.6), duration: 0, tick: 0.5, nil,
                             status: status(.weaken, potency: rv(0.15, 0.05), duration: 1), follows: true, .holy))]
    )

    static let vengefulPlate = skill(
        "templar.vengefulPlate", "Vengeful Plate", path: "templar", tier: .two, ranks: 3, kind: .proc,
        symbol: "arrow.uturn.backward.circle.fill",
        text: "When struck, holy light lashes out around you for {0%} power.",
        values: [rv(1.5, 0.5)],
        effects: [proc(.hurt, cooldown: 0.8, nova(rv(2), dmg(1.5, 0.5, .holy, [.spell, .area], knockback: 1), .holy))]
    )

    static let shieldOfFaith = skill(
        "templar.shieldOfFaith", "Shield of Faith", path: "templar", tier: .three, ranks: 3, kind: .proc,
        symbol: "checkmark.shield.fill",
        text: "Every 15 s, gain a barrier of {0%} of your max health.",
        values: [rv(0.15, 0.05)],
        effects: [proc(.interval(15), .barrier(rv(0.15, 0.05)))],
        requires: ["templar.auraOfResolve", "templar.vengefulPlate"]
    )

    static let steadfast = skill(
        "templar.steadfast", "Steadfast", path: "templar", tier: .three, ranks: 3, kind: .passive,
        symbol: "figure.stand",
        text: "Standing still: +{0} armour and +{1%} damage.",
        values: [rv(25, 10), rv(0.1, 0.05)],
        effects: [whileIn(.stationary, .armor, .flat, 25, 10), whileIn(.stationary, .damage, .increased, 0.1, 0.05)],
        requires: ["templar.auraOfResolve", "templar.vengefulPlate"]
    )

    static let hallowedBastion = skill(
        "templar.hallowedBastion", "Hallowed Bastion", path: "templar", tier: .four, ranks: 3, kind: .ultimate,
        symbol: "building.columns.fill",
        text: "Raise a bastion for {0} s. Inside: +50 armour and +20 health per second, and enemies burn in holy light.",
        values: [rv(8, 1)],
        effects: [ability("hallowedBastion", "Hallowed Bastion", symbol: "building.columns.fill", cooldown: rv(60, -5),
                          ultimate: true,
                          .zone(zone(rv(3.5), duration: rv(8, 1), tick: 0.5,
                                     dmg(0.6, 0.2, .holy, [.spell, .area, .ability], knockback: 0.3),
                                     buff: [mod(.armor, .flat, 50), mod(.healthRegen, .flat, 20)], .holy)))],
        requires: ["templar.shieldOfFaith", "templar.steadfast"]
    )

    static let unyieldingFaith = skill(
        "templar.unyieldingFaith", "Unyielding Faith", path: "templar", tier: .capstone, ranks: 1, kind: .passive,
        symbol: "crown.fill",
        text: "Your armour strengthens your blows: +1% damage for every 4 armour.",
        effects: [.statFromStat(source: .armor, target: mod(.damage, .increased, 0.0025)), flat(.armor, 20, 0)],
        requires: ["templar.hallowedBastion"]
    )

    // MARK: Justicar

    static let blessedWeapon = skill(
        "justicar.blessedWeapon", "Blessed Weapon", path: "justicar", tier: .two, ranks: 3, kind: .passive,
        symbol: "sparkles",
        text: "Your weapon deals an extra {0%} of its damage as holy.",
        values: [rv(0.2, 0.1)],
        effects: [.weapon(.addedDamage(.holy, rv(0.2, 0.1)))]
    )

    static let verdict = skill(
        "justicar.verdict", "Verdict", path: "justicar", tier: .two, ranks: 3, kind: .active, symbol: "hammer.fill",
        text: "Pass judgment ahead of you: {0%} holy power, stunning for 0.5 s.",
        values: [rv(3, 0.8)],
        effects: [ability("verdict", "Verdict", symbol: "hammer.fill", cooldown: rv(7, -0.5),
                          .cone(ConeSpec(range: rv(3), arcDegrees: 75,
                                         damage: dmg(3, 0.8, .holy, [.melee, .area, .ability], knockback: 1.2),
                                         status: status(.stun, duration: 0.5), visual: .holy)))]
    )

    static let zeal = skill(
        "justicar.zeal", "Zeal", path: "justicar", tier: .three, ranks: 3, kind: .proc, symbol: "flame.fill",
        text: "Kills grant +{0%} attack speed for 4 s, stacking up to 8 times.",
        values: [rv(0.04, 0.02)],
        effects: [proc(.kill(killedBy: nil), buff("zeal", [mod(.attackSpeed, .increased, 0.04, 0.02)],
                                                  duration: 4, stacks: 8))],
        requires: ["justicar.blessedWeapon", "justicar.verdict"]
    )

    static let condemn = skill(
        "justicar.condemn", "Condemn", path: "justicar", tier: .three, ranks: 3, kind: .passive,
        symbol: "exclamationmark.shield.fill",
        text: "Holy hits have a {0%} chance to condemn: the target takes 20% more damage for 5 s.",
        values: [rv(0.15, 0.08)],
        effects: [.inflict(HitFilter(type: .holy), status(.shock, chance: rv(0.15, 0.08), potency: 0.2, duration: 5))],
        requires: ["justicar.blessedWeapon", "justicar.verdict"]
    )

    static let hammerOfDawn = skill(
        "justicar.hammerOfDawn", "Hammer of Dawn", path: "justicar", tier: .four, ranks: 3, kind: .ultimate,
        symbol: "hammer.circle.fill",
        text: "A colossal hammer of light falls on the crowd: {0%} holy power, stunning for 1.5 s.",
        values: [rv(10, 2.5)],
        effects: [ability("hammerOfDawn", "Hammer of Dawn", symbol: "hammer.circle.fill", cooldown: rv(40, -3),
                          ultimate: true,
                          .strikes(StrikeSpec(count: 1, radius: rv(3.5), scatter: 0, delay: 0.7,
                                              damage: dmg(10, 2.5, .holy, [.spell, .area, .ability], knockback: 2.5),
                                              status: status(.stun, duration: 1.5), visual: .holy)))],
        requires: ["justicar.zeal", "justicar.condemn"]
    )

    static let avenger = skill(
        "justicar.avenger", "Avenger", path: "justicar", tier: .capstone, ranks: 1, kind: .proc,
        symbol: "crown.fill",
        text: "Every 2nd attack calls down a smite on the target for 250% holy power.",
        effects: [proc(.everyNthAttack(2), nova(rv(1.5), dmg(2.5, 0, .holy, [.spell, .area], knockback: 0.8),
                                                at: .origin, .holy))],
        requires: ["justicar.hammerOfDawn"]
    )

    // MARK: Crusader

    static let charge = skill(
        "crusader.charge", "Crusader's Charge", path: "crusader", tier: .two, ranks: 3, kind: .active,
        symbol: "chevron.forward.2",
        text: "Charge forward, striking everything in your path for {0%} holy power and stunning it.",
        values: [rv(2, 0.6)],
        effects: [ability("charge", "Crusader's Charge", symbol: "chevron.forward.2", cooldown: rv(8, -0.6),
                          .dash(DashSpec(distance: rv(4.2), damage: dmg(2, 0.6, .holy, [.melee, .ability], knockback: 1.5),
                                         status: status(.stun, duration: 0.5), invulnerability: 0.35, visual: .holy)))]
    )

    static let fervor = skill(
        "crusader.fervor", "Fervor", path: "crusader", tier: .two, ranks: 5, kind: .passive, symbol: "figure.run",
        text: "+{0%} movement speed and +{1%} damage.",
        values: [rv(0.04, 0.04), rv(0.06, 0.06)],
        effects: [inc(.moveSpeed, 0.04), inc(.damage, 0.06)]
    )

    static let holyFire = skill(
        "crusader.holyFire", "Holy Fire", path: "crusader", tier: .three, ranks: 3, kind: .passive,
        symbol: "flame.circle.fill",
        text: "Holy hits have a {0%} chance to set the target burning for {1%} power per second.",
        values: [rv(0.3, 0.1), rv(0.4, 0.2)],
        effects: [.inflict(HitFilter(type: .holy), status(.burn, chance: rv(0.3, 0.1), potency: rv(0.4, 0.2),
                                                          duration: 3))],
        requires: ["crusader.charge", "crusader.fervor"]
    )

    static let righteousMomentum = skill(
        "crusader.righteousMomentum", "Righteous Momentum", path: "crusader", tier: .three, ranks: 3, kind: .proc,
        symbol: "arrow.up.forward",
        text: "Using an ability grants +{0%} damage for 3 s.",
        values: [rv(0.3, 0.1)],
        effects: [proc(.abilityCast, buff("righteousMomentum", [mod(.damage, .increased, 0.3, 0.1)], duration: 3))],
        requires: ["crusader.charge", "crusader.fervor"]
    )

    static let crusade = skill(
        "crusader.crusade", "Crusade", path: "crusader", tier: .four, ranks: 3, kind: .ultimate,
        symbol: "flag.fill",
        text: "For {0} s holy light surrounds you, dealing {1%} power three times a second, and you move 30% faster.",
        values: [rv(6, 1), rv(1.5, 0.4)],
        effects: [ability("crusade", "Crusade", symbol: "flag.fill", cooldown: rv(50, -4), ultimate: true,
                          .all([.zone(zone(rv(3), duration: rv(6, 1), tick: 0.3,
                                           dmg(1.5, 0.4, .holy, [.melee, .area, .ability], knockback: 0.5),
                                           follows: true, .holy)),
                                buff("crusade", [mod(.moveSpeed, .increased, 0.3)], duration: rv(6, 1))]))],
        requires: ["crusader.holyFire", "crusader.righteousMomentum"]
    )

    static let vanguard = skill(
        "crusader.vanguard", "Vanguard of Light", path: "crusader", tier: .capstone, ranks: 1, kind: .proc,
        symbol: "crown.fill",
        text: "While moving, you unleash a wave of holy light every 3 s for 300% power.",
        effects: [proc(.interval(3), requires: .moving,
                       nova(rv(3), dmg(3, 0, .holy, [.spell, .area], knockback: 1.2), .holy))],
        requires: ["crusader.crusade"]
    )

    static let skills: [SkillDefinition] = [
        hallowedStorm, smite, consecratedPlate,
        auraOfResolve, vengefulPlate, shieldOfFaith, steadfast, hallowedBastion, unyieldingFaith,
        blessedWeapon, verdict, zeal, condemn, hammerOfDawn, avenger,
        charge, fervor, holyFire, righteousMomentum, crusade, vanguard,
    ]
}
