import CoreGraphics
import Foundation

/// A roll of the dice on one particular creature.
///
/// Two goblins from the same line are not the same goblin: one is a runt,
/// one came back from something that should have killed it. A strain bends
/// an enemy's numbers and its colour without needing a definition of its
/// own, so a roster of thirty kinds reads as a roster of hundreds.
///
/// Strains are deliberately small: none of them turns fodder into a threat
/// on its own, and the rare ones announce themselves by colour so a player
/// can decide whether to take the fight.
struct EnemyStrain: Equatable {
    let id: String
    let name: String
    /// Prefix on the creature's name: "Feral Goblin".
    let titlePrefix: String?
    var healthScale: Double = 1
    var damageScale: Double = 1
    var speedScale: CGFloat = 1
    var sizeScale: CGFloat = 1
    /// Colour washed over the sprite, and how strongly.
    var tint: RGBA?
    var tintStrength: CGFloat = 0
    /// Changes what its blows are made of, when the strain has a nature of
    /// its own. Enemies carry no statuses onto the player, so a strain
    /// shows itself in colour, numbers and damage type rather than debuffs.
    var damageType: DamageType?
    /// Relative chance of being rolled.
    var weight: Double
    /// Waves before this strain starts appearing at all.
    var earliestWave: Int = 1
    /// Extra experience, since a tougher roll takes longer to put down.
    var experienceBonus: Int = 0

    /// The unremarkable roll: most of what you fight.
    static let common = EnemyStrain(id: "strain.common", name: "Common", titlePrefix: nil, weight: 100)

    static let runt = EnemyStrain(
        id: "strain.runt", name: "Runt", titlePrefix: "Runt",
        healthScale: 0.65, damageScale: 0.8, speedScale: 1.18, sizeScale: 0.85,
        tint: RGBA(hex: 0xBFC4A8), tintStrength: 0.2, weight: 22
    )

    static let hardened = EnemyStrain(
        id: "strain.hardened", name: "Hardened", titlePrefix: "Hardened",
        healthScale: 1.7, damageScale: 1.1, speedScale: 0.88, sizeScale: 1.12,
        tint: RGBA(hex: 0x7C8496), tintStrength: 0.35, weight: 16, earliestWave: 3, experienceBonus: 1
    )

    static let feral = EnemyStrain(
        id: "strain.feral", name: "Feral", titlePrefix: "Feral",
        healthScale: 0.9, damageScale: 1.2, speedScale: 1.32, sizeScale: 0.96,
        tint: RGBA(hex: 0xB4442E), tintStrength: 0.35, weight: 15, earliestWave: 2, experienceBonus: 1
    )

    static let blighted = EnemyStrain(
        id: "strain.blighted", name: "Blighted", titlePrefix: "Blighted",
        healthScale: 1.15, damageScale: 0.95, speedScale: 0.96, sizeScale: 1.02,
        tint: RGBA(hex: 0x6E9142), tintStrength: 0.4, damageType: .poison,
        weight: 11, earliestWave: 4, experienceBonus: 1
    )

    static let emberTouched = EnemyStrain(
        id: "strain.ember", name: "Ember-Touched", titlePrefix: "Ember-Touched",
        healthScale: 1.1, damageScale: 1.1, speedScale: 1.05, sizeScale: 1.02,
        tint: RGBA(hex: 0xD9762B), tintStrength: 0.42, damageType: .fire,
        weight: 9, earliestWave: 5, experienceBonus: 2
    )

    static let gravechilled = EnemyStrain(
        id: "strain.gravechilled", name: "Gravechilled", titlePrefix: "Gravechilled",
        healthScale: 1.25, damageScale: 1, speedScale: 0.9, sizeScale: 1.04,
        tint: RGBA(hex: 0x5FA8C4), tintStrength: 0.42, damageType: .cold,
        weight: 8, earliestWave: 6, experienceBonus: 2
    )

    /// Rare, gold, and worth the trouble.
    static let chosen = EnemyStrain(
        id: "strain.chosen", name: "Fate-Chosen", titlePrefix: "Fate-Chosen",
        healthScale: 2.8, damageScale: 1.35, speedScale: 1.05, sizeScale: 1.22,
        tint: RGBA(hex: 0xE8C25A), tintStrength: 0.5, weight: 3, earliestWave: 5, experienceBonus: 8
    )

    static let all: [EnemyStrain] = [
        common, runt, hardened, feral, blighted, emberTouched, gravechilled, chosen,
    ]

    /// A strain rolled for one creature at a point in the run.
    ///
    /// Bosses and elites never roll: they are already exactly what they are
    /// meant to be, and a "Runt" boss would read as a bug.
    static func roll(for rank: EnemyRank, wave: Int, random: inout SeededRandom) -> Int {
        guard rank <= .soldier else { return 0 }
        var total = 0.0
        for strain in all where strain.earliestWave <= wave {
            total += strain.weight
        }
        guard total > 0 else { return 0 }
        var pick = random.unit() * total
        for (index, strain) in all.enumerated() where strain.earliestWave <= wave {
            pick -= strain.weight
            if pick < 0 { return index }
        }
        return 0
    }

    static func strain(at index: Int) -> EnemyStrain {
        index >= 0 && index < all.count ? all[index] : common
    }

    /// The creature's name with its strain, for banners and the bestiary.
    func title(for name: String) -> String {
        guard let titlePrefix else { return name }
        return "\(titlePrefix) \(name)"
    }
}
