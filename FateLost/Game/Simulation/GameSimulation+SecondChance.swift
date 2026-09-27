import CoreGraphics
import Foundation

/// Where a lone hero fell, held while the player chooses.
struct SecondChance: Equatable {
    let position: CGPoint
}

enum SecondChanceTuning {
    /// Health a second chance rises with, as a share of the most there is.
    static let healthFraction: Double = 0.5
    /// Seconds nothing can touch the hero after rising, so whatever stood
    /// over the body cannot put them straight back down.
    static let invulnerability: Double = 2.0
}

/// A second chance: one per solo run, paid for with a rewarded advert.
///
/// When the lone hero falls and a second chance is on offer, the run is
/// held exactly as it stood — champions and their barriers, the horde,
/// summons, zones, projectiles in flight, the clock and every echo — and
/// nothing is torn down until the player answers. Taking it raises the hero
/// where they fell; refusing it lets the fall go on as it always has.
extension GameSimulation {
    /// Whether a fall right now would be held for the player's choice.
    var holdsForSecondChance: Bool {
        offersSecondChance && !secondChanceSpent && heroCount == 1 && mirror == nil && !isRealmConquered
    }

    /// Raises the fallen hero where they fell, at half health, with a moment
    /// of immunity, and lets the run go on. Does nothing (and returns false)
    /// unless a fall is waiting on this choice, so it can never raise a hero
    /// twice however many times it is asked.
    @discardableResult
    mutating func takeSecondChance() -> Bool {
        guard let chance = awaitingSecondChance, player.isDefeated else { return false }
        awaitingSecondChance = nil
        secondChanceSpent = true
        player.health = max(1, player.maxHealth * SecondChanceTuning.healthFraction)
        player.position = world.wrap(chance.position)
        player.velocity = .zero
        player.knockback = .zero
        player.pullTarget = nil
        player.pullSecondsRemaining = 0
        player.stunSecondsRemaining = 0
        // A burn still ticking would finish the job the moment the immunity ran out.
        player.burns.removeAll()
        player.invulnerability = max(player.invulnerability, SecondChanceTuning.invulnerability)
        timeSinceDefeat = nil
        alliesNeedSync = true
        syncPlayerSnapshot()
        combat.events.append(.heroRevived(hero: 0, position: player.position))
        return true
    }

    /// Accepts the fall. What the hero held dies with them, as it always has,
    /// and the run ends through the ordinary summary. Any later fall this run
    /// is final.
    mutating func acceptFate() {
        guard awaitingSecondChance != nil else { return }
        awaitingSecondChance = nil
        secondChanceSpent = true
        dismissPlayerForces()
    }
}
