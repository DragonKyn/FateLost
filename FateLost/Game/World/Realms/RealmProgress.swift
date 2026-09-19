import Foundation

/// Which realms the player has conquered. Persisted with the Legacy profile
/// from Phase 6; until then it lives in memory.
struct RealmProgress: Codable, Equatable {
    var conquered: Set<RealmID> = []
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
