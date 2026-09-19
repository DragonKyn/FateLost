import Foundation

/// Conditions that can afflict an enemy.
///
/// Damage-over-time statuses (burn, poison, bleed) store their damage per
/// second as potency, computed when applied. Other statuses store a fraction
/// (slow amount, extra damage taken, extra crit chance, damage reduction).
enum StatusKind: Int, CaseIterable, Codable {
    /// Fire damage over time. Reapplying keeps the strongest.
    case burn
    /// Poison damage over time. Applications stack up to a limit.
    case poison
    /// Physical damage over time.
    case bleed
    /// Slowed by `potency` (0…0.7).
    case chill
    /// Cannot move or strike.
    case freeze
    /// Takes `potency` more damage.
    case shock
    /// Takes `potency` more damage; some skills react to cursed deaths.
    case curse
    /// Hits against it gain `potency` critical chance.
    case mark
    /// Cannot move or strike (brief).
    case stun
    /// Cannot move, can still strike.
    case root
    /// Wanders and strikes other enemies.
    case confuse
    /// Flees from the player.
    case fear
    /// Deals `potency` less damage.
    case weaken

    var bit: UInt16 { 1 << UInt16(rawValue) }

    var isDamageOverTime: Bool {
        self == .burn || self == .poison || self == .bleed
    }

    var damageType: DamageType {
        switch self {
        case .burn: return .fire
        case .poison: return .poison
        default: return .physical
        }
    }

    /// Statuses that stop an enemy acting entirely.
    static let incapacitating: UInt16 = StatusKind.freeze.bit | StatusKind.stun.bit

    /// The elemental statuses counted by "affected by several elements".
    static let elemental: [StatusKind] = [.burn, .chill, .freeze, .shock, .poison]

    var displayName: String {
        switch self {
        case .burn: return "Burning"
        case .poison: return "Poisoned"
        case .bleed: return "Bleeding"
        case .chill: return "Chilled"
        case .freeze: return "Frozen"
        case .shock: return "Shocked"
        case .curse: return "Cursed"
        case .mark: return "Marked"
        case .stun: return "Stunned"
        case .root: return "Rooted"
        case .confuse: return "Confused"
        case .fear: return "Terrified"
        case .weaken: return "Weakened"
        }
    }
}

/// Inflicting a status: how likely, how strong, how long.
///
/// For damage-over-time statuses, `potency` is damage per second as a
/// multiple of skill power (see `SkillPower`).
struct StatusApplication: Equatable {
    var kind: StatusKind
    var chance: RankValue
    var potency: RankValue
    var duration: RankValue

    init(_ kind: StatusKind, chance: RankValue = 1, potency: RankValue = 0, duration: RankValue) {
        self.kind = kind
        self.chance = chance
        self.potency = potency
        self.duration = duration
    }

    func resolved(_ rank: Int) -> StatusApplication {
        StatusApplication(kind, chance: chance.resolved(rank), potency: potency.resolved(rank),
                          duration: duration.resolved(rank))
    }
}
