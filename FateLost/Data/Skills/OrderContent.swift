import Foundation

/// Shorthand for writing an order's five nodes.
///
/// An order conforms to `SkillContent` so it gets the same effect helpers
/// every archetype file uses, with `archetype` standing for the order's
/// primary. `node` is the only difference: it stamps the order onto the
/// skill, names ids under `order.<order>.`, and carries the second
/// archetype so the rules know what else to ask for.
protocol OrderContent: SkillContent {
    static var order: HybridID { get }
}

extension OrderContent {
    static var definition: HybridOrderDefinition {
        HybridOrders.order(order) ?? HybridOrders.all[0]
    }

    /// The order's primary archetype, which its points count toward.
    static var archetype: ArchetypeID { definition.primary }

    static func node(_ id: String, _ name: String, tier: SkillTier, ranks: Int, kind: SkillKind,
                     symbol: String, text: String, values: [RankValue] = [], effects: [SkillEffect],
                     requires: [String] = [], tags: Set<CombatTag> = []) -> SkillDefinition {
        SkillDefinition(
            id: "order.\(order.rawValue).\(id)",
            name: name,
            archetype: definition.primary,
            path: nil,
            tier: tier,
            maxRank: ranks,
            kind: kind,
            symbol: symbol,
            text: text,
            values: values,
            effects: effects,
            prerequisites: requires.map { "order.\(order.rawValue).\($0)" },
            tags: tags,
            synergy: definition.synergy,
            order: order
        )
    }

    /// An ability id that cannot collide with another order sharing a
    /// primary archetype.
    static func orderAbility(_ id: String, _ name: String, symbol: String, cooldown: RankValue,
                             ultimate: Bool = false, _ action: EffectAction) -> SkillEffect {
        .ability(AbilityDefinition(id: "order.\(order.rawValue).\(id)", name: name, symbol: symbol,
                                   cooldown: cooldown, isUltimate: ultimate, action: action))
    }
}
