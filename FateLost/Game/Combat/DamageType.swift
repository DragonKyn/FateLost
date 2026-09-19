import Foundation

/// Elemental/physical category of a hit. Resistances, skills and on-hit
/// reactions key off this, so every damage source must declare one.
enum DamageType: String, Codable, CaseIterable {
    case physical
    case fire
    case cold
    case lightning
    case arcane
    case holy
    case shadow
    case poison

    var displayName: String { rawValue.capitalized }

    /// Stat that boosts this type specifically.
    var stat: StatID {
        switch self {
        case .physical: return .physicalDamage
        case .fire: return .fireDamage
        case .cold: return .coldDamage
        case .lightning: return .lightningDamage
        case .arcane: return .arcaneDamage
        case .holy: return .holyDamage
        case .shadow: return .shadowDamage
        case .poison: return .poisonDamage
        }
    }

    var isMagic: Bool { self != .physical }

    /// Bit for `DamageTypeMask`.
    var bit: UInt16 {
        switch self {
        case .physical: return 1 << 0
        case .fire: return 1 << 1
        case .cold: return 1 << 2
        case .lightning: return 1 << 3
        case .arcane: return 1 << 4
        case .holy: return 1 << 5
        case .shadow: return 1 << 6
        case .poison: return 1 << 7
        }
    }

    init(index: UInt8) {
        let all = DamageType.allCases
        self = all[min(Int(index), all.count - 1)]
    }

    var index: UInt8 { UInt8(DamageType.allCases.firstIndex(of: self) ?? 0) }
}

/// Descriptive tags carried by damage events and content definitions.
///
/// Skills react to tags ("your melee attacks…", "when a poisoned enemy
/// dies…") rather than to concrete classes, which keeps new content from
/// requiring changes to existing skills.
enum CombatTag: String, Codable, CaseIterable {
    case melee
    case projectile
    case spell
    case critical
    case area
    case summon
    case poison
    case burn
    case holy
    case weapon
    case twoHanded
    case ranged
    case magic
    case physical
    case dot
    case ability
}

/// A set of `CombatTag`s as a bit mask, for allocation-free checks in the
/// damage path.
struct TagMask: OptionSet, Hashable {
    let rawValue: UInt32

    init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    init(_ tags: Set<CombatTag>) {
        var mask: UInt32 = 0
        for tag in tags {
            mask |= TagMask.bit(for: tag)
        }
        rawValue = mask
    }

    private static func bit(for tag: CombatTag) -> UInt32 {
        let index = CombatTag.allCases.firstIndex(of: tag) ?? 0
        return 1 << UInt32(index)
    }

    static let melee = TagMask([.melee])
    static let projectile = TagMask([.projectile])
    static let spell = TagMask([.spell])
    static let critical = TagMask([.critical])
    static let area = TagMask([.area])
    static let summon = TagMask([.summon])
    static let weapon = TagMask([.weapon])
    static let ranged = TagMask([.ranged])
    static let dot = TagMask([.dot])
    static let ability = TagMask([.ability])
}
