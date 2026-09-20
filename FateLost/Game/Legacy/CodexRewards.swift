import Foundation

/// What filling in the relic codex earns.
///
/// Discovery is the one part of the record that is not a total or a best: a
/// relic is found the first time one is carried, and nothing can take that
/// back. So it pays out in the one currency that never becomes the reason a
/// run was won: more chances to be picked at. Every twentieth-or-so relic
/// discovered adds a reroll to every find, for good.
enum CodexRewards {
    /// Relics to have discovered for each extra reroll.
    static let thresholds = [20, 44]

    static func bonusRerolls(discovered: Int) -> Int {
        thresholds.filter { discovered >= $0 }.count
    }

    /// The next milestone still ahead, or nil once all are met.
    static func nextThreshold(discovered: Int) -> Int? {
        thresholds.first { discovered < $0 }
    }
}
