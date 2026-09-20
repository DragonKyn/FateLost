import Foundation

/// The eight orders: what you become when two archetypes meet.
///
/// An order is not a class you pick. It is a small cluster of skills that
/// will not open until you have invested in *two* archetypes, so the only
/// way to reach one is to have spread your points on purpose. Everything
/// before Phase 7 rewarded going deep; orders are the reason to go wide.
enum HybridID: String, CaseIterable, Codable, Identifiable {
    case spellblade
    case hexblade
    case deathknight
    case stormcaller
    case warden
    case inquisitor
    case skirmisher
    case warchanter

    var id: String { rawValue }
}

/// Presentation and requirements for one order.
///
/// `primary` is the archetype an order's points count toward, and whose tier
/// thresholds gate it; `synergy` is the second archetype that must also be
/// invested in. Both matter: a Spellblade is a warrior who studied, not a
/// wizard who picked up a sword.
struct HybridOrderDefinition: Identifiable, Equatable {
    let id: HybridID
    let name: String
    let tagline: String
    /// SF Symbol used as its sigil.
    let symbol: String
    let color: RGBA
    let primary: ArchetypeID
    let synergy: ArchetypeID
}

enum HybridOrders {
    static let all: [HybridOrderDefinition] = [
        HybridOrderDefinition(
            id: .spellblade, name: "Spellblade",
            tagline: "Steel that remembers it was once a spell.",
            symbol: "wand.and.rays", color: RGBA(hex: 0x8AA6E8),
            primary: .warrior, synergy: .wizard
        ),
        HybridOrderDefinition(
            id: .hexblade, name: "Hexblade",
            tagline: "Every cut is a debt called in.",
            symbol: "moon.stars.fill", color: RGBA(hex: 0x9A6FC8),
            primary: .rogue, synergy: .warlock
        ),
        HybridOrderDefinition(
            id: .deathknight, name: "Deathknight",
            tagline: "Plate, a pact, and a retinue that cannot refuse.",
            symbol: "shield.lefthalf.filled.slash", color: RGBA(hex: 0x7E8C74),
            primary: .warrior, synergy: .warlock
        ),
        HybridOrderDefinition(
            id: .stormcaller, name: "Stormcaller",
            tagline: "The weather takes a side.",
            symbol: "cloud.bolt.fill", color: RGBA(hex: 0x6FC4DE),
            primary: .druid, synergy: .sorcerer
        ),
        HybridOrderDefinition(
            id: .warden, name: "Warden",
            tagline: "The wood answers, and it has teeth.",
            symbol: "leaf.fill", color: RGBA(hex: 0x74B564),
            primary: .ranger, synergy: .druid
        ),
        HybridOrderDefinition(
            id: .inquisitor, name: "Inquisitor",
            tagline: "Judgement, delivered quietly and from behind.",
            symbol: "eye.trianglebadge.exclamationmark.fill", color: RGBA(hex: 0xD8C07A),
            primary: .paladin, synergy: .rogue
        ),
        HybridOrderDefinition(
            id: .skirmisher, name: "Skirmisher",
            tagline: "Never where the blow lands.",
            symbol: "figure.run", color: RGBA(hex: 0xE0A05A),
            primary: .monk, synergy: .ranger
        ),
        HybridOrderDefinition(
            id: .warchanter, name: "Warchanter",
            tagline: "A song loud enough to fight beside you.",
            symbol: "music.note.list", color: RGBA(hex: 0xD8748C),
            primary: .bard, synergy: .warrior
        ),
    ]

    static func order(_ id: HybridID) -> HybridOrderDefinition? {
        all.first { $0.id == id }
    }
}
