import CoreGraphics
import Foundation

/// Base allies. Skills copy these and adjust counts, durations and damage.
enum SummonCatalog {
    static let skeleton = SummonSpec(
        key: "summon.skeleton", name: "Risen Skeleton", sprite: .allySkeleton,
        behavior: .melee(range: 0.45),
        damage: DamageSpec(0.8, .physical, tags: [.summon, .melee]),
        attackInterval: 1.0, moveSpeed: 3.6, radius: 0.28, visual: .shadow,
        variants: [.allySkeleton, .allySkeletonBrute, .allySkeletonArcher],
        vitality: 0.6, resummonCooldown: 6
    )

    static let boneColossus = SummonSpec(
        key: "summon.boneColossus", name: "Bone Colossus", sprite: .allyBoneColossus,
        scale: 1.1, behavior: .melee(range: 0.6),
        damage: DamageSpec(RankValue(1.6, 0.5), .physical, tags: [.summon, .melee, .area], knockback: 1),
        attackInterval: 1.4, moveSpeed: 2.8, radius: 0.5, splash: 1.1, taunts: true, visual: .shadow,
        vitality: 3.5, resummonCooldown: 20
    )

    static let tiger = SummonSpec(
        key: "summon.tiger", name: "Tiger", sprite: .allyTiger,
        behavior: .melee(range: 0.5),
        damage: DamageSpec(RankValue(1.0, 0.35), .physical, tags: [.summon, .melee]),
        attackInterval: 0.65, moveSpeed: 5.6, radius: 0.36, visual: .physical,
        variants: [.allyTiger, .allyTigerWhite],
        vitality: 1.2, resummonCooldown: 10
    )

    static let owl = SummonSpec(
        key: "summon.owl", name: "Owl", sprite: .allyOwl,
        behavior: .ranged(range: 6, projectileSpeed: 11, sprite: .projectileBolt),
        damage: DamageSpec(RankValue(0.8, 0.3), .arcane, tags: [.summon, .projectile]),
        attackInterval: 1.1, moveSpeed: 5, radius: 0.25, visual: .arcane,
        vitality: 0.7, resummonCooldown: 8
    )

    static let bear = SummonSpec(
        key: "summon.bear", name: "Bear", sprite: .allyBear,
        behavior: .melee(range: 0.6),
        damage: DamageSpec(RankValue(1.5, 0.5), .physical, tags: [.summon, .melee, .area], knockback: 1),
        attackInterval: 1.3, moveSpeed: 3.4, radius: 0.5, splash: 0.9, taunts: true, visual: .physical,
        vitality: 2.2, resummonCooldown: 14
    )

    static let spiritWolf = SummonSpec(
        key: "summon.spiritWolf", name: "Spirit Wolf", sprite: .allyWolf, tint: RGBA(hex: 0x7FE0FF, alpha: 0.85),
        behavior: .melee(range: 0.45),
        damage: DamageSpec(RankValue(0.8, 0.3), .physical, tags: [.summon, .melee]),
        attackInterval: 0.8, moveSpeed: 5.2, radius: 0.32, visual: .nature,
        vitality: 0.9, resummonCooldown: 8
    )

    static let imp = SummonSpec(
        key: "summon.imp", name: "Imp", sprite: .allyImp,
        behavior: .ranged(range: 5.5, projectileSpeed: 9, sprite: .projectileBolt),
        damage: DamageSpec(RankValue(0.9, 0.3), .fire, tags: [.summon, .projectile]),
        attackInterval: 1.2, moveSpeed: 4.6, radius: 0.24,
        status: StatusApplication(.burn, chance: 0.4, potency: 0.3, duration: 3), visual: .fire,
        vitality: 0.7, resummonCooldown: 8
    )

    static let hellhound = SummonSpec(
        key: "summon.hellhound", name: "Hellhound", sprite: .allyHellhound,
        scale: 1.05, behavior: .melee(range: 0.5),
        damage: DamageSpec(RankValue(1.0, 0.35), .fire, tags: [.summon, .melee]),
        attackInterval: 0.8, moveSpeed: 5.4, radius: 0.34,
        status: StatusApplication(.burn, chance: 0.5, potency: 0.4, duration: 3), visual: .fire,
        vitality: 1.1, resummonCooldown: 10
    )

    static let fiend = SummonSpec(
        key: "summon.fiend", name: "Pit Fiend", sprite: .allyPitFiend,
        scale: 1.15, behavior: .melee(range: 0.8),
        damage: DamageSpec(RankValue(4, 1), .fire, tags: [.summon, .melee, .area], knockback: 1.4),
        attackInterval: 1.5, moveSpeed: 3.6, radius: 0.6, splash: 1.5, taunts: true,
        status: StatusApplication(.burn, chance: 1, potency: 0.8, duration: 3), visual: .fire,
        vitality: 3.2, resummonCooldown: 22
    )

    static let shadowClone = SummonSpec(
        key: "summon.shadowClone", name: "Shadow", sprite: .playerAdventurer, tint: RGBA(hex: 0x241830, alpha: 0.8),
        behavior: .melee(range: 0.5),
        damage: DamageSpec(RankValue(1.2, 0.4), .shadow, tags: [.summon, .melee], critBonus: 0.2),
        attackInterval: 0.6, moveSpeed: 5.8, radius: 0.32, visual: .shadow,
        vitality: 1.0, resummonCooldown: 10
    )

    static let treant = SummonSpec(
        key: "summon.treant", name: "Ancient", sprite: .allyTreant,
        scale: 1.2, behavior: .melee(range: 0.8),
        damage: DamageSpec(RankValue(3, 1), .physical, tags: [.summon, .melee, .area], knockback: 1.3),
        attackInterval: 1.6, moveSpeed: 2.4, radius: 0.6, splash: 1.5, taunts: true,
        status: StatusApplication(.root, chance: 0.5, duration: 1.5), visual: .nature,
        vitality: 3.0, resummonCooldown: 20
    )

    static let blade = SummonSpec(
        key: "summon.blade", name: "Orbiting Blade", sprite: .allyBlade,
        behavior: .orbit(radius: 1.6, angularSpeed: 4.4),
        damage: DamageSpec(RankValue(1.0, 0.3), .physical, tags: [.summon, .melee], knockback: 0.4),
        attackInterval: 0.3, moveSpeed: 0, radius: 0.3, visual: .physical
    )

    static let arcaneOrb = SummonSpec(
        key: "summon.arcaneOrb", name: "Arcane Orb", sprite: .allyWisp, tint: RGBA(hex: 0xA070FF),
        behavior: .orbit(radius: 2.1, angularSpeed: 2.8),
        damage: DamageSpec(RankValue(1.2, 0.4), .arcane, tags: [.summon, .spell]),
        attackInterval: 0.35, moveSpeed: 0, radius: 0.35, visual: .arcane
    )

    static let lightOrb = SummonSpec(
        key: "summon.lightOrb", name: "Halo Light", sprite: .allyWisp, tint: RGBA(hex: 0xFFE08A),
        behavior: .orbit(radius: 1.8, angularSpeed: 3.4),
        damage: DamageSpec(RankValue(1.0, 0.35), .holy, tags: [.summon, .spell]),
        attackInterval: 0.35, moveSpeed: 0, radius: 0.32, visual: .holy
    )

    static let hornet = SummonSpec(
        key: "summon.hornet", name: "Hornet", sprite: .allyWisp, tint: RGBA(hex: 0xC8E040),
        scale: 0.55, behavior: .orbit(radius: 2.2, angularSpeed: 5),
        damage: DamageSpec(RankValue(0.5, 0.15), .poison, tags: [.summon]),
        attackInterval: 0.4, moveSpeed: 0, radius: 0.22,
        status: StatusApplication(.poison, chance: 0.6, potency: 0.25, duration: 4), visual: .poison
    )

    /// Every base summon, for validation and tooling.
    static let all: [SummonSpec] = [
        skeleton, boneColossus, tiger, owl, bear, spiritWolf, imp, hellhound, fiend, shadowClone, treant,
        blade, arcaneOrb, lightOrb, hornet,
    ]

    /// A copy with a different count and lifetime.
    static func with(_ base: SummonSpec, count: RankValue, duration: RankValue) -> SummonSpec {
        var copy = base
        copy.count = count
        copy.duration = duration
        return copy
    }
}
