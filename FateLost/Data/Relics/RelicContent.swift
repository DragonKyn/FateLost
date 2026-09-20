import Foundation

/// Shorthand for writing relics as data, in the same vocabulary as the skill
/// trees: `inc`, `flat`, `proc`, `nova` and the rest come from
/// `EffectShorthand`, so a relic reads like a skill with no tree around it.
///
/// Each rarity gets its own content type. That keeps each `static let` a small
/// expression for the compiler and each relic easy to find.
protocol RelicContent: EffectShorthand {}

extension RelicContent {
    static var namespace: String { "relic" }

    static func relic(_ id: String, _ name: String, _ rarity: ItemRarity, symbol: String, ranks: Int = 3,
                      text: String, values: [RankValue] = [], effects: [SkillEffect]) -> RelicDefinition {
        RelicDefinition(id: "relic.\(id)", name: name, rarity: rarity, symbol: symbol, maxRank: ranks,
                        text: text, values: values, effects: effects)
    }
}
