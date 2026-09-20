import Foundation

/// The ten strands of Legacy: what a player invests in between runs.
///
/// Each strand is a way of playing rather than a class — a summoner and a
/// duellist both want Body, and neither is required to take it. Nothing here
/// unlocks content or changes a rule; a strand only makes a small thing
/// slightly better, so a hundred hours of Legacy is a real advantage without
/// ever being the reason a run was won.
enum LegacyBranch: String, CaseIterable, Codable, Identifiable {
    case body
    case blade
    case focus
    case fortune
    case ward
    case flame
    case frost
    case shadow
    case bond
    case fate

    var id: String { rawValue }

    var name: String {
        switch self {
        case .body: return "Body"
        case .blade: return "Blade"
        case .focus: return "Focus"
        case .fortune: return "Fortune"
        case .ward: return "Ward"
        case .flame: return "Flame"
        case .frost: return "Frost"
        case .shadow: return "Shadow"
        case .bond: return "Bond"
        case .fate: return "Fate"
        }
    }

    var subtitle: String {
        switch self {
        case .body: return "What the flesh can take"
        case .blade: return "What the hand can do"
        case .focus: return "What the mind can hold"
        case .fortune: return "What the world gives back"
        case .ward: return "What refuses to land"
        case .flame: return "What burns"
        case .frost: return "What slows"
        case .shadow: return "What is never seen coming"
        case .bond: return "What answers when called"
        case .fate: return "What was always going to happen"
        }
    }

    var symbol: String {
        switch self {
        case .body: return "heart.fill"
        case .blade: return "scissors"
        case .focus: return "brain.head.profile"
        case .fortune: return "sparkles"
        case .ward: return "shield.fill"
        case .flame: return "flame.fill"
        case .frost: return "snowflake"
        case .shadow: return "moon.fill"
        case .bond: return "person.2.fill"
        case .fate: return "circle.hexagongrid.fill"
        }
    }

    var tint: RGBA {
        switch self {
        case .body: return RGBA(hex: 0xB4442E)
        case .blade: return RGBA(hex: 0xC0C4CC)
        case .focus: return RGBA(hex: 0x8A7BE0)
        case .fortune: return RGBA(hex: 0xE8C25A)
        case .ward: return RGBA(hex: 0x6FA8D8)
        case .flame: return RGBA(hex: 0xE2792A)
        case .frost: return RGBA(hex: 0x9FD8EA)
        case .shadow: return RGBA(hex: 0x7A5A9E)
        case .bond: return RGBA(hex: 0x6FBF7A)
        case .fate: return RGBA(hex: 0xE0B060)
        }
    }
}

/// One permanent upgrade: a single small bonus, bought once and kept forever.
///
/// Nodes are deliberately uniform — no node is a decision, the *shape* of
/// what you have bought is. That keeps a five-hundred-node board readable and
/// stops any one node from becoming required reading.
struct LegacyNode: Identifiable, Equatable {
    let id: String
    let branch: LegacyBranch
    /// 1-based depth. Deeper nodes cost more and give a little more.
    let tier: Int
    let name: String
    let modifier: StatModifier
    let cost: Int

    /// How the bonus reads on the card.
    var effectText: String { modifier.displayText }
}

/// What Legacy is bought with.
///
/// Echoes are what a run leaves behind: every enemy put down, every wave
/// held, every champion felled, multiplied by how unforgiving the realm was.
/// A short bad run still pays something, so no session is wasted.
enum LegacyEchoes {
    /// Echoes for a finished run.
    static func earned(from stats: RunStats, wave: Int, level: Int, realmMultiplier: Double,
                       conquered: Bool) -> Int {
        let fromKills = Double(stats.kills) * 0.35
        let fromElites = Double(stats.eliteKills) * 4
        let fromChampions = Double(stats.bossKills) * 40
        let fromWaves = Double(max(0, wave - 1)) * 6
        let fromLevels = Double(max(0, level - 1)) * 2.5
        let base = fromKills + fromElites + fromChampions + fromWaves + fromLevels
        // Taking a realm is worth going back for.
        let bonus = conquered ? 1.5 : 1
        return max(1, Int((base * realmMultiplier * bonus).rounded()))
    }
}
