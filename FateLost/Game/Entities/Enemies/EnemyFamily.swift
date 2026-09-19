import Foundation

/// What kind of thing an enemy is.
///
/// Families are how a realm says what walks its ground without listing every
/// creature: the Drowned Fen fields undead and aberrations, the Burning
/// Depths fields demons. They also give the player something to read at a
/// glance — a wall of bone asks a different question than a pack of beasts.
enum EnemyFamily: String, CaseIterable, Codable {
    case goblinoid
    case undead
    case beast
    case demon
    case construct
    case aberration
    case cultist
    case elemental

    var displayName: String {
        switch self {
        case .goblinoid: return "Goblinoid"
        case .undead: return "Undead"
        case .beast: return "Beast"
        case .demon: return "Demon"
        case .construct: return "Construct"
        case .aberration: return "Aberration"
        case .cultist: return "Cultist"
        case .elemental: return "Elemental"
        }
    }
}

/// How much of a threat one enemy is meant to be.
///
/// Rank drives what the game does around a creature rather than its numbers:
/// elites are announced and drop more, bosses hold the wave open and own the
/// banner across the top of the screen.
enum EnemyRank: Int, Comparable, Codable {
    /// Fodder. Dangerous in a crowd and nowhere else.
    case minion = 0
    /// The backbone of a wave.
    case soldier = 1
    /// A named threat among the rank and file.
    case elite = 2
    /// Holds the wave open until it falls.
    case boss = 3

    static func < (lhs: EnemyRank, rhs: EnemyRank) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Multiplier on the experience its death leaves behind.
    var experienceMultiplier: Double {
        switch self {
        case .minion: return 1
        case .soldier: return 1
        case .elite: return 4
        case .boss: return 25
        }
    }
}
