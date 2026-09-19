import Foundation

/// A character's statistics: every modifier gathered, combined, and capped.
///
/// Final value = (base + Σ flat) × (1 + Σ increased) × Π (1 + more), clamped
/// to the stat's bounds. Damage is special: when a hit is resolved, the
/// *increases* of every relevant damage stat are summed first (so "+20% fire"
/// and "+20% spell" make +40%, not +44%). Additive stacking gives natural
/// diminishing returns: each further +10% is a smaller share of the total,
/// which keeps any one stat from snowballing into the only sensible pick.
struct StatSheet {
    private static let count = StatID.allCases.count

    private var flat: [Double]
    private var increased: [Double]
    private var more: [Double]
    private(set) var values: [Double]

    init() {
        flat = Array(repeating: 0, count: Self.count)
        increased = Array(repeating: 0, count: Self.count)
        more = Array(repeating: 1, count: Self.count)
        values = Array(repeating: 0, count: Self.count)
        finalize()
    }

    subscript(_ stat: StatID) -> Double {
        values[stat.rawValue]
    }

    /// Clears every modifier, keeping array capacity.
    mutating func reset() {
        for index in 0..<Self.count {
            flat[index] = 0
            increased[index] = 0
            more[index] = 1
        }
    }

    mutating func add(_ modifier: StatModifier) {
        let index = modifier.stat.rawValue
        switch modifier.kind {
        case .flat: flat[index] += modifier.value
        case .increased: increased[index] += modifier.value
        case .more: more[index] *= max(0, 1 + modifier.value)
        }
    }

    mutating func add(_ modifiers: [StatModifier]) {
        for modifier in modifiers {
            add(modifier)
        }
    }

    /// Recomputes final values after modifiers change.
    mutating func finalize() {
        for stat in StatID.allCases {
            let index = stat.rawValue
            let raw = (stat.baseValue + flat[index]) * max(0, 1 + increased[index]) * more[index]
            values[index] = raw.clamped(stat.bounds.lowerBound, stat.bounds.upperBound)
        }
    }

    /// Combined multiplier for a hit of `type` carrying `tags`.
    func damageMultiplier(for type: DamageType, tags: TagMask) -> Double {
        var sum = increased[StatID.damage.rawValue]
        var product = more[StatID.damage.rawValue]

        func include(_ stat: StatID) {
            sum += increased[stat.rawValue]
            product *= more[stat.rawValue]
        }

        include(type.isMagic ? .magicDamage : .physicalDamage)
        include(type.stat)
        if tags.contains(.melee) { include(.meleeDamage) }
        if tags.contains(.projectile) { include(.projectileDamage) }
        if tags.contains(.spell) { include(.spellDamage) }
        if tags.contains(.area) { include(.areaDamage) }
        if tags.contains(.summon) { include(.summonDamage) }
        if tags.contains(.dot) { include(.dotDamage) }
        return max(0, 1 + sum) * product
    }
}
