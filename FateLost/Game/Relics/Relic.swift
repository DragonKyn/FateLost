import Foundation

typealias RelicID = String

/// A relic: something found on the road that changes how the run plays.
///
/// A relic is not a new kind of effect. It is a rank and a list of the same
/// `SkillEffect`s the skill tree is written in, fed through the same
/// `CompiledBuild`, so everything a skill can do a relic can do and nothing
/// about combat had to learn that relics exist. The one exception is by
/// design: relics never grant abilities or forms. Those live in the tree,
/// where slots and the level-up screen can account for them.
///
/// Rank is how strong this copy is. A relic can turn up at a higher rank
/// than one (a rolled power, the same way a strain bends a goblin), and
/// finding one you already carry raises it, up to `maxRank`.
struct RelicDefinition: Identifiable, Equatable {
    let id: RelicID
    let name: String
    let rarity: ItemRarity
    /// SF Symbol shown on its card and in the row of relics you carry.
    let symbol: String
    let maxRank: Int
    /// Template: `{0}` is `values[0]` at the rank, `{0%}` the same as a percentage.
    let text: String
    let values: [RankValue]
    let effects: [SkillEffect]

    init(id: RelicID, name: String, rarity: ItemRarity, symbol: String, maxRank: Int = 3, text: String,
         values: [RankValue] = [], effects: [SkillEffect]) {
        self.id = id
        self.name = name
        self.rarity = rarity
        self.symbol = symbol
        self.maxRank = maxRank
        self.text = text
        self.values = values
        self.effects = effects
    }

    /// The text with this rank's numbers filled in.
    func description(atRank rank: Int) -> String {
        var result = text
        for (index, value) in values.enumerated() {
            let amount = value.at(max(rank, 1))
            result = result.replacingOccurrences(of: "{\(index)%}", with: SkillDefinition.format(amount * 100) + "%")
            result = result.replacingOccurrences(of: "{\(index)}", with: SkillDefinition.format(amount))
        }
        return result
    }

    /// "Whetstone", "Whetstone II", "Whetstone III".
    func title(atRank rank: Int) -> String {
        switch rank {
        case ...1: return name
        case 2: return "\(name) II"
        default: return "\(name) III"
        }
    }
}

/// The relics a run has picked up, in the order they were found.
struct RelicInventory: Equatable {
    private(set) var ranks: [RelicID: Int] = [:]
    private(set) var order: [RelicID] = []

    var count: Int { order.count }
    var isEmpty: Bool { order.isEmpty }

    func rank(of id: RelicID) -> Int { ranks[id] ?? 0 }

    func contains(_ id: RelicID) -> Bool { ranks[id] != nil }

    /// Whether this relic can still get stronger.
    func canImprove(_ definition: RelicDefinition) -> Bool {
        rank(of: definition.id) < definition.maxRank
    }

    /// Everything carried, with its rank, in the order found.
    var held: [(relic: RelicDefinition, rank: Int)] {
        order.compactMap { id in
            RelicCatalog.relic(id).map { ($0, rank(of: id)) }
        }
    }

    /// Takes a relic. Finding one you already have adds to its rank rather
    /// than filling a second slot, up to the relic's limit.
    ///
    /// - Returns: the rank it now stands at, or 0 if no such relic exists.
    @discardableResult
    mutating func add(_ id: RelicID, rank found: Int = 1) -> Int {
        guard let definition = RelicCatalog.relic(id) else { return 0 }
        let now = min(definition.maxRank, rank(of: id) + max(1, found))
        if ranks[id] == nil {
            order.append(id)
        }
        ranks[id] = now
        return now
    }
}

// MARK: - Offers

/// How rich a find is. Decides which rarities it can hold.
///
/// Tiers are weights, not gates: a cache can still surprise you and a hoard
/// can still be disappointing, which is most of what makes opening one worth
/// doing.
enum LootTier: Int, CaseIterable, Comparable {
    /// What an elite drops.
    case cache
    /// What a champion drops.
    case chest
    /// A champion late in a run, or a shrine's bargain.
    case hoard

    static func < (lhs: LootTier, rhs: LootTier) -> Bool { lhs.rawValue < rhs.rawValue }

    var displayName: String {
        switch self {
        case .cache: return "Cache"
        case .chest: return "Chest"
        case .hoard: return "Hoard"
        }
    }

    /// Relative chance of each rarity.
    func weight(of rarity: ItemRarity) -> Int {
        switch (self, rarity) {
        case (.cache, .common): return 60
        case (.cache, .uncommon): return 32
        case (.cache, .rare): return 8
        case (.chest, .common): return 20
        case (.chest, .uncommon): return 42
        case (.chest, .rare): return 28
        case (.chest, .epic): return 9
        case (.chest, .legendary): return 1
        case (.hoard, .uncommon): return 18
        case (.hoard, .rare): return 42
        case (.hoard, .epic): return 32
        case (.hoard, .legendary): return 8
        default: return 0
        }
    }
}

/// One card on offer: a relic and the rank it would arrive at.
struct RelicChoice: Equatable, Identifiable {
    let relic: RelicID
    let rank: Int

    var id: String { "\(relic)#\(rank)" }
}

/// Three relics to pick one from.
struct RelicOffer: Equatable {
    let tier: LootTier
    /// The wave it was opened on, which decides how likely a strong roll is.
    let wave: Int
    var choices: [RelicChoice]
    var rerollsLeft: Int
}
