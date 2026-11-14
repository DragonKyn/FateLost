import Foundation

/// Limits that keep a build strong without making it unkillable or letting
/// one blast erase a whole screen. Each is a curve, not a wall: more of
/// anything still helps, it just helps less past the point where it would
/// break the game. (Steady healing has its own soft cap in `PlayerTuning`.)
enum BalanceTuning {
    // MARK: Area damage

    /// An area hit (a nova, a cone, a zone's tick, a splash) lands in full on
    /// up to this many enemies.
    static let fullDamageTargets = 8
    /// Past that, every target takes `(fullDamageTargets / targets) ^ this`
    /// of the damage: 16 enemies take about 71% each, 32 take half. The
    /// total still grows with the crowd, so area builds stay the best answer
    /// to a horde, but no longer by a runaway margin.
    static let crowdExponent = 0.5

    /// What each enemy caught in an area hit takes, by how many it caught.
    static func crowdScale(_ targets: Int) -> Double {
        guard targets > fullDamageTargets else { return 1 }
        return pow(Double(fullDamageTargets) / Double(targets), crowdExponent)
    }

    // MARK: Chains of triggered effects

    /// An effect set off by another effect (an explosion from a kill made by
    /// an explosion) lands at this fraction for each step past the first.
    static let depthFalloff = 0.7

    /// The damage scale for an effect `depth` steps from the player's own
    /// attack or cast. The player's attacks (0) and anything they set off
    /// directly (1) are untouched.
    static func depthScale(_ depth: Int) -> Double {
        guard depth > 1 else { return 1 }
        return pow(depthFalloff, Double(depth - 1))
    }

    // MARK: Defence

    /// The most damage armour can ever turn away. With the dodge cap (50%)
    /// a fully defensive hero still takes about an eighth of every blow.
    static let maximumArmorReduction = 0.75
}
