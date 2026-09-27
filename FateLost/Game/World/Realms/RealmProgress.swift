import Foundation

/// Which realms the player has conquered. Persisted with the Legacy profile
/// from Phase 6; until then it lives in memory.
struct RealmProgress: Codable, Equatable {
    var conquered: Set<RealmID> = []
    /// Difficulty modifiers switched on for a realm, kept between runs so a
    /// chosen build of hardship doesn't have to be redone every time.
    var activeModifiers: [RealmID: [RunModifierSelection]] = [:]

    init() {}

    /// Decoded field by field so a profile written before this field existed
    /// still loads.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        conquered = try container.decodeIfPresent(Set<RealmID>.self, forKey: .conquered) ?? []
        activeModifiers = try container.decodeIfPresent([RealmID: [RunModifierSelection]].self,
                                                        forKey: .activeModifiers) ?? [:]
    }
}

/// Campaign unlock rules, kept separate from UI and persistence so they can
/// be tested directly.
enum RealmUnlockRules {
    /// The first realm is always open; each later realm opens when the one
    /// before it has been conquered.
    static func isUnlocked(_ realm: RealmDefinition, progress: RealmProgress, catalog: [RealmDefinition]) -> Bool {
        guard let previous = catalog.first(where: { $0.order == realm.order - 1 }) else {
            return true
        }
        return progress.conquered.contains(previous.id)
    }

    /// The realm that must be conquered to open `realm`, if any.
    static func prerequisite(for realm: RealmDefinition, catalog: [RealmDefinition]) -> RealmDefinition? {
        catalog.first { $0.order == realm.order - 1 }
    }
}
