import CoreGraphics
import Foundation

/// What falls from what.
///
/// The numbers are deliberately stingy at the bottom and certain at the top.
/// The horde only ever leaves the odd vial; elites sometimes leave a cache;
/// a champion always leaves a chest. That keeps a chest an event worth
/// walking toward rather than something a wave scatters about like ash.
enum DropTable {
    /// Fraction of max health a vial restores.
    static let vialHeal = 0.25
    /// Chance an ordinary creature leaves a vial, and a magnet if it did not.
    static let vialChance = 0.012
    static let magnetChance = 0.004
    /// What an elite leaves.
    static let eliteCacheChance = 0.28
    static let eliteVialChance = 0.4
    /// A champion late in a run leaves a hoard instead of a chest.
    static let hoardWave = 15
    /// Vials a champion drops alongside its chest.
    static let bossVials = 2
    /// Loose vials and magnets on the ground at once. Chests are never
    /// counted: a find should not be lost to clutter.
    static let looseLimit = 24
    /// Seconds a cache waits before someone else takes it. Chests and
    /// hoards wait forever.
    static let cacheLifetime: Double = 75

    /// How close the player must come to open a chest.
    static let chestOpenDistance: CGFloat = 0.9
}

extension CombatState {
    /// Rolls what a fallen enemy leaves behind, besides experience.
    mutating func dropLoot(for definition: EnemyDefinition, at position: CGPoint) {
        if definition.isBoss {
            let tier: LootTier = stats.wave >= DropTable.hoardWave ? .hoard : .chest
            place(.chest(tier), near: position, scatter: 0)
            for _ in 0..<DropTable.bossVials {
                place(.vial, near: position, scatter: 1.1)
            }
        } else if definition.rank >= .elite {
            if lootRandom.chance(DropTable.eliteCacheChance) {
                place(.chest(.cache), near: position, scatter: 0.3)
            }
            if lootRandom.chance(DropTable.eliteVialChance) {
                place(.vial, near: position, scatter: 0.8)
            }
        } else if lootRandom.chance(DropTable.vialChance) {
            place(.vial, near: position, scatter: 0.4)
        } else if lootRandom.chance(DropTable.magnetChance) {
            place(.magnet, near: position, scatter: 0.4)
        }
    }

    mutating func place(_ kind: DropKind, near position: CGPoint, scatter: Double) {
        if case .chest = kind {
            // Always placed.
        } else {
            let loose = drops.reduce(0) { count, drop in
                if case .chest = drop.kind { return count }
                return count + 1
            }
            guard loose < DropTable.looseLimit else { return }
        }
        var at = position
        if scatter > 0 {
            let angle = lootRandom.range(0, 2 * Double.pi)
            let distance = lootRandom.range(0.2, scatter)
            at = world.wrap(position + CGPoint(x: CGFloat(cos(angle) * distance),
                                               y: CGFloat(sin(angle) * distance)))
        }
        drops.append(Drop(id: makeEntityID(), kind: kind, position: at))
    }
}
