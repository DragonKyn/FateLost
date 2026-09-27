import Foundation

/// Which realms the player has conquered. Persisted with the Legacy profile
/// from Phase 6; until then it lives in memory.
struct RealmProgress: Codable, Equatable {
    var conquered: Set<RealmID> = []
    /// Difficulty modifiers switched on for a realm, kept between runs so a
    /// chosen build of hardship doesn't have to be redone every time.
    var activeModifiers: [RealmID: [RunModifierSelection]] = [:]
    /// Set the first time Fate falls, and never cleared: it is what opens
    /// Fate's Echo for every run after, whether or not Fate is fought again.
    var hasEverDefeatedFate = false
    /// How many times the ending has been seen, so the second and later
    /// times it can be dismissed at once rather than read through again.
    var endingsSeen = 0

    init(conquered: Set<RealmID> = [], activeModifiers: [RealmID: [RunModifierSelection]] = [:],
         hasEverDefeatedFate: Bool = false, endingsSeen: Int = 0) {
        self.conquered = conquered
        self.activeModifiers = activeModifiers
        self.hasEverDefeatedFate = hasEverDefeatedFate
        self.endingsSeen = endingsSeen
    }

    /// Decoded field by field so a profile written before this field existed
    /// still loads.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        conquered = try container.decodeIfPresent(Set<RealmID>.self, forKey: .conquered) ?? []
        activeModifiers = try container.decodeIfPresent([RealmID: [RunModifierSelection]].self,
                                                        forKey: .activeModifiers) ?? [:]
        hasEverDefeatedFate = try container.decodeIfPresent(Bool.self, forKey: .hasEverDefeatedFate) ?? false
        endingsSeen = try container.decodeIfPresent(Int.self, forKey: .endingsSeen) ?? 0
        // A save from before the flag existed, by a player who had already
        // conquered the Abyss, has beaten Fate all the same.
        if conquered.contains(.abyss) { hasEverDefeatedFate = true }
    }
}

/// Campaign unlock rules, kept separate from UI and persistence so they can
/// be tested directly.
enum RealmUnlockRules {
    /// The first realm is always open; each later realm opens when the one
    /// before it has been conquered. Fate's Echo is the exception: it opens
    /// only once Fate has fallen, and stays open for good after.
    static func isUnlocked(_ realm: RealmDefinition, progress: RealmProgress, catalog: [RealmDefinition]) -> Bool {
        if realm.id == .fatesEcho { return progress.hasEverDefeatedFate }
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
