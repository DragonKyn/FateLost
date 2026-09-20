import CoreGraphics
import Foundation

/// The three bargains a shrine offers.
///
/// A shrine is not a pickup. It asks for something, and the only way to
/// agree is to walk onto it, so the decision is made with the player's feet
/// in the middle of a fight. Blood costs health for a chest, Fortune costs
/// nothing and gives a little of everything, and Ruin curses the realm for
/// a hoard.
enum ShrineKind: CaseIterable, Equatable {
    case blood
    case fortune
    case ruin

    var name: String {
        switch self {
        case .blood: return "Shrine of Blood"
        case .fortune: return "Shrine of Fortune"
        case .ruin: return "Shrine of Ruin"
        }
    }

    /// What it asks and what it gives, in the words shown as you approach.
    var bargain: String {
        switch self {
        case .blood: return "Pay 30% of your health for a chest"
        case .fortune: return "A blessing: experience and a draught"
        case .ruin: return "Curse the realm for a minute, and take a hoard"
        }
    }

    var earliestWave: Int {
        switch self {
        case .blood, .fortune: return 2
        case .ruin: return 4
        }
    }

    var weight: Int {
        switch self {
        case .blood: return 40
        case .fortune: return 40
        case .ruin: return 20
        }
    }
}

/// A shrine standing in the world.
struct Shrine {
    let id: Int
    let kind: ShrineKind
    let position: CGPoint
    var age: Double = 0
}

enum ShrineTuning {
    /// How close the player has to come to agree to a bargain.
    static let touchDistance: CGFloat = 1.1
    /// Seconds an unused shrine stays before the realm takes it back.
    static let lifetime: Double = 150
    /// Chance a wave brings one, and how many may stand at once.
    static let spawnChance = 0.55
    static let maxActive = 2
    /// How far from the player one appears.
    static let nearest = 8.0
    static let farthest = 12.0

    /// Fraction of max health Blood takes, and the least health it will
    /// take you down to. It never kills; it refuses instead.
    static let bloodCost = 0.3
    static let bloodRefusalFraction = 0.4
    /// Ruin's curse: how long, and how much stronger the realm gets.
    static let curseSeconds: Double = 60
    static let curseStrength = 1.3
    /// Fortune: a fraction of the current level, and a fraction of health.
    static let fortuneExperience = 0.6
    static let fortuneHeal = 0.15
}

enum ShrineSystem {
    /// Called when a wave begins: may raise a shrine.
    static func waveBegan(_ wave: Int, isBossWave: Bool, _ combat: inout CombatState, player: PlayerState) {
        guard !isBossWave, combat.shrines.count < ShrineTuning.maxActive,
              combat.lootRandom.chance(ShrineTuning.spawnChance) else { return }

        let eligible = ShrineKind.allCases.filter { $0.earliestWave <= wave }
        let total = eligible.reduce(0) { $0 + $1.weight }
        guard total > 0 else { return }
        var roll = Int(combat.lootRandom.unit() * Double(total))
        var kind = eligible[eligible.count - 1]
        for candidate in eligible {
            roll -= candidate.weight
            if roll < 0 {
                kind = candidate
                break
            }
        }

        let angle = combat.lootRandom.range(0, 2 * Double.pi)
        let distance = combat.lootRandom.range(ShrineTuning.nearest, ShrineTuning.farthest)
        let position = combat.world.wrap(player.position + CGPoint(x: CGFloat(cos(angle) * distance),
                                                                   y: CGFloat(sin(angle) * distance)))
        combat.shrines.append(Shrine(id: combat.makeEntityID(), kind: kind, position: position))
        combat.events.append(.shrineAppeared(kind: kind, position: position))
    }

    /// Ages shrines, and takes up the bargain of any the player has walked onto.
    static func step(_ combat: inout CombatState, player: PlayerState, dt: TimeInterval) {
        guard !combat.shrines.isEmpty else { return }
        var index = combat.shrines.count - 1
        while index >= 0 {
            var shrine = combat.shrines[index]
            shrine.age += dt
            if shrine.age > ShrineTuning.lifetime {
                combat.shrines.remove(at: index)
            } else if !player.isDefeated,
                      combat.world.distance(shrine.position, player.position) <= ShrineTuning.touchDistance,
                      accepts(shrine.kind, player: player, combat: combat) {
                combat.pendingShrines.append(shrine.kind)
                combat.events.append(.shrineUsed(kind: shrine.kind, position: shrine.position))
                combat.shrines.remove(at: index)
            } else {
                combat.shrines[index] = shrine
            }
            index -= 1
        }
    }

    /// Whether the player can take this bargain right now. A shrine that
    /// cannot be taken stays where it is: nothing is wasted by walking past.
    static func accepts(_ kind: ShrineKind, player: PlayerState, combat: CombatState) -> Bool {
        switch kind {
        case .blood: return player.healthFraction > ShrineTuning.bloodRefusalFraction
        case .fortune: return true
        case .ruin: return combat.curseRemaining <= 0
        }
    }
}
