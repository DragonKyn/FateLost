import CoreGraphics

/// The campaign. Every realm-specific number lives here.
enum RealmCatalog {
    /// Arena dimensions in tiles. Large enough that the visible area is a
    /// small fraction of the map, so wrapping is felt but never seen.
    private static let standardArenaSize = 128

    static let all: [RealmDefinition] = [
        RealmDefinition(
            id: .ashenWilds, order: 1, name: "The Ashen Wilds",
            tagline: "Where every fate is first lost.",
            introduces: ["The core of survival"],
            conquestWave: 50, legacyMultiplier: 1.0,
            arena: arena(ArenaThemes.ashenWilds)
        ),
        RealmDefinition(
            id: .drownedFen, order: 2, name: "The Drowned Fen",
            tagline: "The marsh remembers the dead it swallowed.",
            introduces: ["Poison", "Slowing terrain", "Swamp undead"],
            conquestWave: 75, legacyMultiplier: 1.15,
            arena: arena(ArenaThemes.drownedFen)
        ),
        RealmDefinition(
            id: .hollowForest, order: 3, name: "The Hollow Forest",
            tagline: "Something watches from between the trunks.",
            introduces: ["Ranged enemies", "Ambushes", "Corrupted beasts"],
            conquestWave: 100, legacyMultiplier: 1.30,
            arena: arena(ArenaThemes.hollowForest)
        ),
        RealmDefinition(
            id: .frozenWastes, order: 4, name: "The Frozen Wastes",
            tagline: "Cold enough to stop a heart mid-beat.",
            introduces: ["Freezing", "Movement slows", "Durable foes"],
            conquestWave: 125, legacyMultiplier: 1.50,
            arena: arena(ArenaThemes.frozenWastes)
        ),
        RealmDefinition(
            id: .blightedKingdom, order: 5, name: "The Blighted Kingdom",
            tagline: "Its king still rules. He simply stopped breathing.",
            introduces: ["Necromancers", "Resurrection", "Enemy support"],
            conquestWave: 150, legacyMultiplier: 1.75,
            arena: arena(ArenaThemes.blightedKingdom)
        ),
        RealmDefinition(
            id: .burningDepths, order: 6, name: "The Burning Depths",
            tagline: "The ground itself wants you dead.",
            introduces: ["Demons", "Fire hazards", "Summoners"],
            conquestWave: 175, legacyMultiplier: 2.0,
            arena: arena(ArenaThemes.burningDepths)
        ),
        RealmDefinition(
            id: .shatteredRealm, order: 7, name: "The Shattered Realm",
            tagline: "Reality broke here, and never healed.",
            introduces: ["Teleporters", "Anomalies", "Mixed factions"],
            conquestWave: 200, legacyMultiplier: 2.30,
            arena: arena(ArenaThemes.shatteredRealm)
        ),
        RealmDefinition(
            id: .fallenCitadel, order: 8, name: "The Fallen Citadel",
            tagline: "Its knights swore to hold the walls forever.",
            introduces: ["Armoured foes", "Corrupted knights", "Siege attacks"],
            conquestWave: 225, legacyMultiplier: 2.60,
            arena: arena(ArenaThemes.fallenCitadel)
        ),
        RealmDefinition(
            id: .gateOfRuin, order: 9, name: "The Gate of Ruin",
            tagline: "Everything you have faced, waiting at once.",
            introduces: ["The culmination of the campaign"],
            conquestWave: 250, legacyMultiplier: 3.0,
            arena: arena(ArenaThemes.gateOfRuin)
        ),
        RealmDefinition(
            id: .abyss, order: 10, name: "The Abyss",
            tagline: "How far can you survive?",
            introduces: ["No end", "Abyssal corruption"],
            conquestWave: nil, legacyMultiplier: 3.5,
            arena: arena(ArenaThemes.abyss)
        ),
    ]

    static func realm(_ id: RealmID) -> RealmDefinition {
        guard let realm = all.first(where: { $0.id == id }) else {
            preconditionFailure("Realm \(id) missing from catalog")
        }
        return realm
    }

    private static func arena(_ theme: ArenaTheme) -> ArenaDefinition {
        ArenaDefinition(columns: standardArenaSize, rows: standardArenaSize, theme: theme)
    }
}
