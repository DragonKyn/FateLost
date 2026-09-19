import Foundation

/// A number that grows with a skill's rank: `first` at rank 1, plus
/// `perRank` for each rank after.
///
/// Skill content is written in these so one definition covers every rank.
/// When an effect fires, its values are *resolved* for the current rank into
/// fixed numbers (`perRank` zero), and runtime code reads `value`.
struct RankValue: Equatable, Codable, ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral {
    var first: Double
    var perRank: Double

    init(_ first: Double, _ perRank: Double = 0) {
        self.first = first
        self.perRank = perRank
    }

    init(floatLiteral value: Double) {
        self.init(value)
    }

    init(integerLiteral value: Int) {
        self.init(Double(value))
    }

    func at(_ rank: Int) -> Double {
        first + perRank * Double(max(rank, 1) - 1)
    }

    /// The value once resolved for a rank.
    var value: Double { first }

    func resolved(_ rank: Int) -> RankValue {
        RankValue(at(rank))
    }

    static let zero = RankValue(0)
}
