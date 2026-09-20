import SwiftUI

/// Which board the skill screen is showing: one of the eleven archetypes,
/// or one of the eight orders.
///
/// The rail, the canvas and the detail panel all take this rather than an
/// `ArchetypeID`, so an order is a first-class place to be rather than a
/// mode bolted onto the side of the tree.
enum TreeBoard: Equatable, Hashable {
    case archetype(ArchetypeID)
    case order(HybridID)

    /// The archetype whose points and tier thresholds gate this board.
    var primary: ArchetypeID {
        switch self {
        case .archetype(let id):
            return id
        case .order(let id):
            return HybridOrders.order(id)?.primary ?? .warrior
        }
    }

    var orderID: HybridID? {
        if case .order(let id) = self { return id }
        return nil
    }

    var name: String {
        switch self {
        case .archetype(let id):
            return SkillCatalog.archetype(id)?.name ?? "Tree"
        case .order(let id):
            return HybridOrders.order(id)?.name ?? "Order"
        }
    }

    var tint: Color {
        switch self {
        case .archetype(let id):
            return SkillCatalog.archetype(id)?.color.color ?? FLTheme.Palette.ember
        case .order(let id):
            return HybridOrders.order(id)?.color.color ?? FLTheme.Palette.ember
        }
    }

    var skills: [SkillDefinition] {
        switch self {
        case .archetype(let id):
            return SkillCatalog.skills(for: id)
        case .order(let id):
            return SkillCatalog.skills(inOrder: id)
        }
    }
}
